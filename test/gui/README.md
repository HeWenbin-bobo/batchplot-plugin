# test/gui — 无头 GUI / 交互行为验证

AutoCAD 插件里最难验证的两类东西：

1. **WinForms 对话框**（`BpForm`）—— 传统做法是"打开 AutoCAD 手点一遍"，不可复现、无法进 CI。
2. **需要交互选点/选块的命令**（`BPTEACH`）—— `accoreconsole` 的 `.scr` 喂不进拾取点（见 AGENTS.md 坑 #33）。

本目录用两个探针绕开这两个限制，都可独立运行、退出码即结论。

---

## 1. `BpFormTest` — 出图对话框无头单测

**原理**：`BpForm` 是独立 WinForms 窗体，构造函数只吃 `List<FrameInfo>` + `List<Media>` + 几个标量，**不依赖 AutoCAD 运行时**。所以可以脱离 AutoCAD 直接 `new`，`Show()` 之后 `PerformClick()` 走完整交互路径。

覆盖 24 项：标题/控件存在性、行数列数、默认勾选、全选/全不选、比例改动联动纸张预览、留白联动、行内改比例/文件名写回、出图与取消两条 DialogResult 路径、**列不可排序**（防错图回归）。

```cmd
:: 前置：仓库根先出 net8 产物
build_net8.cmd
:: 跑测试（退出码 0 = 全过）
dotnet run --project test\gui\BpFormTest.csproj -c Release
type %TEMP%\bpform_test.log
```

`ACAD_DIR` 环境变量可覆盖 AutoCAD 安装目录（默认 `D:\Program Files\Autodesk\AutoCAD 2025`），仅用于 `AssemblyResolve` 兜底。

**踩坑提醒**：`PerformClick()` 要求控件可见，必须 `form.Show(); Application.DoEvents();` 之后再点，否则静默无效（AGENTS.md 坑 #32）。

---

## 2. `MkBlockDwg` — 生成"图块式图框"测试图纸

**为什么需要**：仓库自带的 `test/test_dwg.dwg` 只有 3 个**空白**多段线框，覆盖不到「图块 + 属性标签」这条链路（`BPTEACH` 学习、`BPREV` 改版次、`BPSPLIT` 按块拆分）。

**生成内容**：新建空数据库 → 定义块 `TITLEBLOCK_A3`（42000×29700 矩形 + 5 个属性定义）→ 模型空间插入 2 个实例并填属性 → 每个框内画圆/线/文字（否则会被空窗检测判 `SKIP`）。

块名与属性标签刻意**不含中文**（`TITLEBLOCK_A3` / `TUHAO` / `TUMING` / `BILI` / `BANCI` / `RIQI`），以证明后续识别结果只可能来自 `config.json` 的学习记录，而不是内置的中文猜测规则。

```cmd
dotnet build test\gui\MkBlockDwg.csproj -c Release
:: 用 accoreconsole 跑（空图 + netload 本 DLL + MKBLK）
"%ACAD%\accoreconsole.exe" /i empty.dwg /s mkblk.scr
:: 产物：%BPBLK_OUT%\blk.dwg（默认 %TEMP%\blk.dwg）
```

---

## 3. 已验证 / 未验证的边界（如实记录）

`accoreconsole` 脚本模式下：

| 交互 API | 能否脚本化 | 说明 |
|---|---|---|
| `Editor.GetSelection()` | ✅ 能 | 裸 `ALL` + 空行（回车结束选择）即可。`BP1`/`BPLOTMERGE`/`BPREV`/`BPSPLIT` 都靠这个测通 |
| `Editor.GetEntity()` | ❌ 不能 | 坐标串/端点/线上点/隐式选择集 5 种写法全部返回"未选中对象" |
| `Editor.GetString/GetInteger` | ✅ 能 | 直接下一行写值 |
| `Application.ShowModalDialog()` | ❌ 不能（且会卡死主线程） | GUI 侧所有 COM 调用一律 `RPC_E_CALL_REJECTED` |

因此 `BPTEACH` 的**拾取动作本身**未验证；替代覆盖是"手工写入同格式 `config.json` → 验证下游识别/命名链路消费"（见 `research/功能验证报告.md` §4.5）。
