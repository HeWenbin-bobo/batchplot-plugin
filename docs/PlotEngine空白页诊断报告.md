# PlotEngine 空白页问题：诊断报告

> 记录时间：2026-10-22
> 触发场景：天正(TArch)图纸批量出图后，`PDF_OUT` 里有 PDF 但页面全白
> 结论状态：**根因已确证，但 BPPlot（PlotEngine 路线）无法自行修复**

---

## 1. 现象

用户用 `BPLOTMERGE` 处理一份天正图纸（`2026-9-7张槎大江同建村何伟浩住宅（报建）.dwg`）：

- `PDF_OUT` 目录有 PDF 文件，`图纸目录.csv` 全记 `OK`
- 打开 PDF 全白，文件只有 2.8 KB
- 同一操作在普通图纸上完全正常

## 2. 铁证：`-plot` 能出，`PlotEngine` 不能

**同一份图纸、同一个窗口坐标、同一纸张、同一比例**：

| 方式 | 输出 | 内容流 |
|---|---|---|
| 原生 `-plot` 命令 | 408,540 字节 | **3 个绘制流** ✅ |
| `PlotEngine` API（BPPlot） | 2,814 字节 | **0 个绘制流** ❌ |

复现命令（`test/` 下的临时验证曾验证过，可重建）：

```lisp
;; -plot 版：能出图
_.-plot
_y
Model

DWG To PDF.pc3
ISO_full_bleed_A2_(420.00_x_594.00_MM)
_m
_l
_n
_w
452108,-708770
511508,-666770
_f
_c
_y
monochrome.ctb
_y

<输出路径>.pdf
_n
_y
```

BPPlot 走的是 `PlotFactory.CreatePublishEngine()` + `BeginDocument/BeginPage/BeginGenerateGraphics/EndPage/EndDocument`，产出空页。

## 3. 已排除的原因（20+ 项，逐项实测）

| 类别 | 具体项 | 结论 |
|---|---|---|
| 坐标 | 远坐标（y≈-710000）、平移到原点 | 无关 |
| 纸张/比例 | A2/4A0/B0、1:100、ScaleToFit、标准比例 | 无关 |
| 旋转 | `rot=90` 与否（强制 `Degrees000`） | 无关 |
| 图层 | 89 个图层全部未关闭/未冻结/可打印 | 无关 |
| 实体类型 | 只保留 LINE/LWPOLYLINE、删 HATCH/DIMENSION/OLE | 无关 |
| 颜色 | ByLayer(256) / 索引色 7 | 无关 |
| 字体 | 缺失 rs.shx/tssdeng.shx 等，`PROXYSHOW=1` | 无关 |
| 代理对象 | `ACAD_PROXY_ENTITY` 全图 35 个，**目标 A2 窗口内 0 个** | 无关 |
| 打印设置 | `ShadePlot`、`PlotTransparency`、`PlotViewportBorders` | 无关 |
| 布局 | `LayoutManager.Current.CurrentLayout` 显式设为 Model | 无关 |
| 图纸变量 | `INSBASE`、`LTSCALE`、`DIMSCALE`、`LIMITS` 等 39 项 | 无关 |
| 绘图顺序 | `SORTENTSTABLE` / `DRAWORDER` 重置 | 无关 |
| 工作副本 | `wblock` 重建、`saveas` 重写、`AUDIT`+`PURGE` | 无关 |
| 刷新 | 出图前 `_.regenall` + `_.zoom _e` | 无关 |
| 状态污染 | 先跑一次 `-plot` 预热再跑 API | 无关 |

**关键一条**：用 `BPDIAGPLOT` 临时命令，把 `-plot` 的参数（同窗口、同纸张、同方向、ScaleToFit）逐项复刻给 `PlotEngine` 手写 `PlotSettings`，依然输出 2,290 字节 / 0 绘制流。

→ 证明：**与参数完全无关，是 `PlotEngine` API 本身在这台机器的 AutoCAD 2025 上对这份图纸失效。**

## 4. 参考实现（易出图 / Tulink Yichutu）为什么能出

对已安装的第三方插件做只读观察（未反编译、未修改）：

- `Tulink.Yichutu.25x64.dll` 引用了 **`Tulink.Yichutu.COM.Autodesk.AutoCAD.Interop.dll`**（自带一份 Interop）
- 有独立进程 `Tulink.Yichutu.Proxy.exe`
- 字符串含 `Plots a layout to the specified file`、`Gets the Plot object for the document`
- 自带 `Plotters25.0/输出PDF.pc3`（JSON 明文 v3.0，参数均为 PDF 引擎默认值）

**结论：它走 COM `IAcadPlot` 接口，等价于 `-plot` 命令路径，因此不受 `PlotEngine` 失效影响。**

它还暴露了值得借鉴的识别逻辑（方法名可读）：

```
GetFrameBlocks
  ├─ extract all / extract selections frame blocks
  ├─ AddRectForSelectedFrames        给识别到的图框加矩形标记
  ├─ RemoveRectForUnselectedFrames   移除误识别
  └─ HideRectInFrame                 处理内部标题栏矩形

图号图名提取 4 条路径：
  SelectTextsInViewByTextBound   按文字包围盒（BPPlot 目前没有）
  SelectTextsUseAtt              按块属性（≈ BPPlot 的 AttrByTags）
  SelectTextsUseLayer            按图层
  SelectAtt / SelectTextLayer

纸张查找三级 fallback：
  SearchNoPadding → SearchStandardMediaName → SearchUserDefineMedia
```

## 5. 尝试过但未采纳的修复方案

### 5.1 子进程 DXF 往返（实现后放弃）

思路：检测到空页后，起独立 `accoreconsole` 子进程做 `wblock` → `dxfout` → `dxfin` → 出图。

实测结果：

| 环节 | 结果 |
|---|---|
| 整图 `dxfout` → `dxfin` | **AutoCAD 直接 AccessViolation 崩溃** |
| 逐窗口 `wblock` | 含代理对象的窗口被拒：`代理对象不允许复制，因此写块操作被拒绝` |
| 小窗口（A2 真图框，3330 实体） | 通过，DXF 往返后出图 393 KB **有内容** ✅ |
| 9 页成功率 | 仅 2 页稳定成功，单页耗时约 9 分钟 |

→ 成功率与性能都无法交付，代码已全部回退。

### 5.2 COM `Plot`（评估后放弃）

思路：用 `Marshal.GetActiveObject("AutoCAD.Application")` 拿 COM 对象，调 `IAcadPlot`。

两个硬障碍：

1. **`Marshal.GetActiveObject` 在 .NET 8 已移除**——BPPlot 的 net8 产物（AutoCAD 2025）直接编译失败，需改用 P/Invoke（`CoGetObject`/`GetActiveObject` 原生导出）
2. **accoreconsole 没有 COM 服务器**——无头批打场景覆盖不到

→ 未实现。

## 6. 结论与建议

**根因**：`PlotEngine` API（BPPlot 当前路线）在 AutoCAD 2025 上对这类图纸失效；`-plot` 命令与 COM `Plot` 接口正常。这不是 BPPlot 的参数错误，也不是图纸损坏。

**推荐处置**：

1. **装天正插件或 Autodesk 对象激活器（Object Enabler）** —— 治本，装完 BPPlot 原样可用
2. **用易出图处理天正图纸，BPPlot 处理普通图纸** —— 各司其职，零改动
3. 让原设计方导出 PDF

**若将来要动代码**，优先级建议（风险从低到高）：

| 优先级 | 改动 | 收益 | 风险 |
|---|---|---|---|
| 高 | 补 `SelectTextsInViewByTextBound`：按文字包围盒识别图号图名 | 现有 `AttrByTags` 只认块属性，很多图纸抓不到 | 低 |
| 高 | 纸张三级 fallback（满幅 → 标准 → 自定义） | 畸形图框选不出合适纸张 | 低 |
| 中 | 空页检测 + 明确报错（不静默记 OK） | 消除"空白但显示 OK"的误导 | 低 |
| 低 | 换 COM `Plot` 出图 | 直接解决空白 | **高**：需 P/Invoke 绕过 .NET 8 限制；accoreconsole 不可用 |

## 7. 复现要点（供以后核对）

- 图纸需要有天正(TArch)对象；普通图纸复现不了
- 判断"是否真出图"**必须解压 PDF 内容流看绘制算子**，不能只看文件大小或 CSV 状态
  - 空白页特征：内容流只有 `0.12 0 0 0.12 0 0 cm`，长度约 18~20 字节
  - 正常页特征：有 `m`/`l`/`c`/`S`/`Tj` 算子，内容流数百 KB
- PDF 的 `/FlateDecode` 是 zlib 封装：.NET 用 `ZLibStream`（.NET 6+），`DeflateStream` 只吃裸 deflate，直接用会把正常 PDF 误判为空
