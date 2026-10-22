# AGENTS.md

本文件是 BPPlot 仓库内 AI 协作规则的**唯一真源**。目标：让改动与既有架构契约一致、让验证可复现、避免把已经踩过的坑再踩一遍。

若本文件与脚本、代码现状不一致，**以实际可执行内容为准**，并在本次改动中顺手修正本文件，避免规则继续漂移。

---

## 1. 仓库速览

- **项目定位**：AutoCAD 批量打印插件（BPPlot）。识别模型空间图框 → 按比例自动选纸 → 精确比例输出 PDF → PdfSharp 矢量裁切到真实图幅 → 可合并单 PDF 并加书签 → 附带图纸目录 CSV。支持 accoreconsole 无头批打。
- **技术栈**：C#（**语法上限 C# 5**），.NET Framework 4.x，WinForms，ObjectARX Managed API，PdfSharp（MIT，`libs/`）。
- **无构建系统**：没有 `.sln`、没有 MSBuild、没有 NuGet、没有 CI。构建就是 `csc.exe` 直编。
- **无网络、无遥测、无硬件指纹**（源码顶部已声明，保持这条性质）。

### 目录与职责

| 路径 | 职责 |
|---|---|
| `src/BPPlot.cs` | 主逻辑全部（约 1960 行）：命令入口、图框收集、选纸、BuildPage、出图、裁切、合并、CSV、配置 |
| `src/BpForm.cs` | `BPLOT` 出图对话框（WinForms） |
| `src/BpMenu.cs` | 菜单栏「BP-批量打印」：AcCui 生成 CUI + COM 挂载；`BPHELP`/`BPABOUT` |
| `src/BpDiag.cs` | 图纸结构诊断，**独立 DLL**（`BPDiag.dll`），只读不改图 |
| `libs/PdfSharp.dll` | 编译引用副本（根目录同名文件是运行时部署副本，两者必须同版本） |
| `libs/pc3_dwg2pdf_body.bin` | pc3 程序化生成的种子数据（M3 用），勿删 |
| `test/` | accoreconsole 无头回归脚本 `.scr` + 运行器 `.cmd` + GUI 自动化 `.ps1` |
| `deploy/` | 安装器 `install.ps1`/`uninstall.ps1`、bundle、`make_bundle.cmd`、中文 cmd 外壳、使用说明 |
| `docs/DESIGN.md` | 后续开发设计方案（M1–M8 模块、P0–P7 分期）。**改架构先读它** |
| `README.md` | 首页级信息：定位/快速开始/命令总表/踩坑记录/路线图 |

### 命令总表（改命令必须同步的地方见 §4.3）

`BPLOT` `BPLOTAUTO` `BP1` `BPPREVIEW` `BPLOTMERGE` `BPL` `BPSPLIT` `BPTEACH` `BPREV` `BPSELFTEST` `BPHELP` `BPABOUT`，外加 LispFunction `BPVER`。

---

## 2. 硬规则

- **未经用户明确确认，不执行 `git commit` / `git tag` / `git push`。**
- **禁止改写历史**：`git reset --hard`、`git rebase`、强制推送、`filter-branch` 等一律需用户明确指示。

### 2.1 上游保护（红线，最高优先级）

- **本仓库是 `HeWenbin-bobo/batchplot-plugin` 的 fork。**
- **只允许向 `origin` 推送**：`origin` → `https://github.com/HeWenbin-bobo/batchplot-plugin.git`。
- **禁止向任何上游仓库推送**：`git push upstream ...`、`git push hwdemtv ...`、任何指向 `hwdemtv/batchplot-plugin`（原作者仓库）的写操作一律不执行。该仓库只允许作为**只读参考**（`git fetch` 读取代码用于对比）。
- **禁止向上游提 PR / issue / comment**：不执行 `gh pr create --repo hwdemtv/...`、`gh issue create --repo hwdemtv/...`、网页版"New pull request"指向原作者仓库、也不向原作者仓库的任何 PR/issue 发表评论。
- **禁止向上游推送 tag**：`git push upstream <tag>`、`git push --tags upstream` 一律禁止。
- **不把 `upstream` 恢复成可写**：若本机已用 `git remote set-url --push upstream DISABLE` 固化保护，**不要改回真实 URL**。该设置是从配置层面根除误推的最终防线。
- 若用户要求"向上游提交/提 PR"，**必须先停下来确认**：说明这会向非本 fork 的仓库写入，请用户明确重申意图并确认目标仓库全名。

### 2.2 其余硬规则

- **不手改二进制**：`BPPlot.dll`、`BPDiag.dll`、`PdfSharp.dll`、`deploy/*.zip`、`test/out_*/` 内的 PDF 只能由构建/运行产生，绝不手工编辑或替换。
- **不写死机器相关信息**：新增代码不得写死绝对路径、盘符、用户名、AutoCAD 安装路径、端口。AutoCAD SDK 路径只允许出现在 `build*.cmd` 顶部的 `ACAD=` 变量里。
  - 现存违规待清理：`build_diag.cmd` 第 2 行 `cd /d C:\Users\hwdem\...`（原机路径，本机不存在），改它时顺手用 `%~dp0` 替掉。
  - 全部 `test/*.cmd` / `test/*.ps1` / `test/*.scr` 已普遍写死原作者路径（见 §5.6），重构时一并处理。
- **不加网络访问**：不引入 HTTP 请求、遥测、自动更新、崩溃上报。
- **不改变输出定位**：打印设备固定 `DWG To PDF.pc3`（`Cmds.DeviceName`），不开放设备选择、不做实体打印机输出——这是产品定位，不是待办。
- **不加签名/印章库**（DESIGN.md 已明确不做）。
- **不静默吞掉出图失败**：失败必须写日志 + `Editor.WriteMessage` + CSV 记 `FAIL`。禁止"失败了但什么都没有提示"。
- **不擅自修改本文件与 `CLAUDE.md`**：由 AI 出草案、用户确认后落地。
- **不给仓库引入"平行实现"**：新能力优先接到既有管线（`CollectFrames` → `BuildPage` → `PlotFrames2` → `CropPdf`/`MergePdfs`），而不是另写一套出图流程。

---

## 3. 构建与验证

### 3.1 构建（先确认 ACAD 路径！）

```cmd
:: 1. 打开 build.cmd，把 ACAD= 改为本机实际路径（当前仓库里写的是 AutoCAD 2023）
:: 2. 再执行
cmd /c build.cmd          :: 产出根目录 BPPlot.dll（主产物：BPPlot.cs + BpForm.cs + BpMenu.cs）
cmd /c build_diag.cmd     :: 产出 BPDiag.dll（诊断工具，独立编译）
```

**实测环境差异（务必先读）**：

- 本机（开发机）装的是 **AutoCAD 2025**（`D:\Program Files\Autodesk\AutoCAD 2025`，R25.0.58.0），而 `build.cmd` / 各 `.cmd` / `.ps1` 里写的是 `D:\Program Files\AutoCAD 2023\AutoCAD 2023`——**不改路径直接跑会 CS0006 全量失败**。
- 2021–2024 与 2025 是**硬分界**：前者的 managed 程序集是 `.NETFramework 4.x`，2025 起是 **`.NETCoreApp v8.0`**（已用 `TargetFrameworkAttribute` 实测确认）。.NET Framework 的 `csc.exe` 无法引用 2025 程序集（报 `CS0012` 缺 `System.Runtime` 8.0 / `CS0616` `CommandMethodAttribute` 非特性类）。这不是代码问题，是产物目标问题。
- **两条已实测可行的产物路线**（详见 `research/报告.md`）：

  | 产物 | 工具链 | 引用 | 覆盖 |
  |---|---|---|---|
  | `BPPlot.dll` | `csc.exe`（.NET Framework 4.0） | 2021–2024 安装目录程序集 | 2013–2024 |
  | `BPPlot.dll`（net8 同名产物） | `dotnet build`（`net8.0-windows`） | **2025 安装目录程序集，无需 ObjectARX SDK** | 2025+ |

- **net8 构建入口**：`build_net8.cmd` → `build/BPPlotNet8.csproj`（已随仓库提供，`ACAD_DIR` 环境变量可覆盖版本）。
- **net8 产物无需改源码**：`BPPlot.cs` + `BpForm.cs` + `BpMenu.cs` 三个文件零修改即可编译。
- **net8 必须的三项适配**（缺一分钟都不行，详见 `research/功能验证报告.md`）：
  1. `App.Initialize()` 加 `Encoding.RegisterProvider(CodePagesEncodingProvider.Instance)`（`#if NET8_0_OR_GREATER` 包裹）——否则 `Save()` 抛 `NotSupportedException`（缺 encoding 1252）。
  2. **PdfSharp 必须用 6.x**（`PackageReference`）——1.50 **无法解析 AutoCAD 2025 打印引擎产出的 PDF**，抛 `PdfReaderException: Invalid entry in XRef table`，裁切/合并全废。
  3. csproj 设 **`<CopyLocalLockFileAssemblies>true</CopyLocalLockFileAssemblies>`**——PdfSharp 6 依赖 8 个 `Microsoft.Extensions.*` 包，缺一个就在 `PdfDocument..ctor()` 抛 `FileNotFoundException`。
- **这三项失败的共同表现是"静默"**：`CropPdf` 用 `catch { return false; }`，`MergePdfs` 失败只在日志提一句。**验证裁切是否真的生效，必须读 PDF 的 `/MediaBox`**（见 §5.5），不能信 CSV 的 `OK` 或日志的 `[crop]`。
- **`.NET Framework` 产物这三点都不需要**（自带全部代码页、PdfSharp 1.50 够用、csc 无 NuGet 概念）。
- **交付纪律**：能在本机实测的就说"已实测"；只能审阅的必须写"未编译验证"。**不得把"设计上应该可行"说成"已验证"**。

`build.cmd` 必需引用：`acmgd.dll`、`acdbmgd.dll`、`accoremgd.dll`、`AcCui.dll`、`Autodesk.AutoCAD.Interop.dll`、`Autodesk.AutoCAD.Interop.Common.dll`、`libs/PdfSharp.dll`、`System.Windows.Forms.dll`、`System.Drawing.dll`。

`csc` 选项含义：`/codepage:65001`（UTF-8 源文件，**别删**）、`/optimize+`、`/target:library`、`/warn:4`（主产物）。

### 3.2 C# 5 语法上限（csc 4.0.30319 硬限制）

**禁止**：字符串插值 `$"..."`、`nameof`、空条件运算符 `?.`、`out var`、表达式体成员 `=> ...;`、元组、`$@""`、模式匹配、默认接口方法。

**允许**：泛型、`delegate` 匿名方法（当前代码就是这样用的）、`var`、`using` 语句、`out` 显式变量、集合初始化器。

**注意**：本机 `csc.exe` 只支持到 C# 5，没有 `dotnet build` 兜底。语法越界不会有友好的报错定位，只能靠实际编译（需可用的 AutoCAD SDK 引用）或人工审阅。改动涉及 `$""`、`?.`、`=>` 表达式体这类写法时，**逐处人工确认**。

### 3.3 验证矩阵（按改动面）

| 改动面 | 必须验证 |
|---|---|
| `src/BPPlot.cs` 出图/裁切/合并逻辑 | accoreconsole 无头回归至少覆盖 §5.5 表里的 6 个场景；**逐页提取 `/MediaBox` 与黄金值比对**（不是肉眼看"差不多"） |
| `src/BpForm.cs` 对话框 | 界面模式实跑 `BPLOT`，勾选/改比例/改文件名/黑白/留白/合成 全部点一遍；**必须截图看真实渲染**（DPI 缩放、控件遮挡靠读代码发现不了）。**特别测"点表头排序后再出图"**（见 §6 第 16 条） |
| `src/BpMenu.cs` 菜单 | 重启 CAD 后直接点菜单项能自动加载并执行；`MENUBAR` 为 0 时行为符合 README 说明 |
| `src/BpDiag.cs` | `BPDiag.dll` 能编译；对样例图跑出诊断报告 |
| `deploy/**` | 装 → 重启 CAD → 命令可用 → 卸载 → 注册表键 `HKCU\Software\Autodesk\AutoCAD\*\*\Applications\BPPlot` 已清除 |
| `docs/**`、`README.md`、`AGENTS.md` | 不强制跑 CAD；但必须逐条核对文件路径、命令名、版本号、注册表键、环境变量与实际一致 |
| 纯注释/文案 | 无需编译，但仍要确认未破坏 C# 5 语法 |

**无法验证时必须写明**：原因（如"本机无 AutoCAD 2023 编译器环境"）、已验证到什么程度、遗留风险。

---

## 4. 架构契约（改动前必读）

### 4.1 出图管线（不要绕开）

```
CollectFrames(手选/自动识别) → DropContained(去重剔包含)
  → [BpForm 对话框，仅 BPLOT]
  → BuildPage(选纸 PickMedia + 窗口 + 比例 + 旋转 + CTB)   ← 每页设置构建
  → PlotEngine(Publish=出图 / Preview=预览) BeginPlot→BeginDocument→BeginPage→EndPage→EndDocument→EndPlot
  → CropPdf(矢量裁切到真实图幅，rot=90 需反转置)  → MergePdfs(可选，加书签)
  → WriteCsvAndStats(图纸目录.csv + A4 当量)
```

- **参数一律走 `BuildPage`**：新增任何出图入口（含预览）都必须复用它，否则参数与正式出图不一致。`BPPREVIEW` 就是照此实现的。
- **`BPPREVIEW` 取"最大图框"靠 `DropContained` 的排序副作用**：`CollectFrames` 按选择集顺序返回，`DropContained` 内部 `frames.Sort(按 AreaX 降序)` 才是 `BPPREVIEW` 那句 `frames[0]` 取到最大框的原因。**不要给 `DropContained` 加"保持原序"优化**，否则 `BPPREVIEW` 会随机预览某一张。若将来解耦，应显式 `frames.OrderByDescending(AreaX).First()`。
- **`PlotSettings` 属性只读**，全部走 `PlotSettingsValidator.SetXxx()`。
- **必须 `SetPlotWindowArea` 在 `SetPlotType(Window)` 之前**，否则 `eInvalidInput`。
- **用 detached `PlotSettings` + `PlotInfo.OverrideSettings`**（`new PlotSettings(lay.ModelType)`），否则 `MatchingPolicy.MatchEnabled` 会覆盖显式选纸。
- **`Run()` 的未保存图纸回退是有缺陷的**：`Run()` 直接用 `Path.Combine(Path.GetDirectoryName(db.Filename), "PDF_OUT")`，而 `Path.GetDirectoryName("")` 在 .NET Framework 4.x 下**抛 `ArgumentException`**（已实测）。`DefaultOutDir()` 才有 `IsNullOrEmpty` 兜底到"我的文档"。所以 `BPLOTAUTO`/`BP1`/`BPLOT` 走 `Run()` 路径时，未保存图纸会异常；`BPL`/`BPSPLIT` 走 `DefaultOutDir()` 才正确。README 第 71 行"未保存图纸默认输出到我的文档\PDF_OUT"对 `Run()` 不成立。**动这块优先把 `Run()` 改为调 `DefaultOutDir()`**，而不是再写一份兜底。
- **所有"改系统变量"必须成对恢复**：`BACKGROUNDPLOT` 已在 `BpMerge`/`BpLayouts`/`PlotFrames2` 三处按 `oldBg` 存取恢复。注意 `BpLayouts` 的恢复在方法末尾而非 `finally`，异常路径会漏——改它时挪进 `finally`。将来做 `TEXTFILL` 包裹（DESIGN.md M7）同样适用。
- **`rot=90` 的裁切变换是实测标定值，不是推导值**：`CropPdf` 里 `TranslateTransform(-fy, trueH*pt + fx)` + `RotateTransform(-90)`。动它必须用 `BPPLOT_KEEP_ORIG=1` 留中间 PDF 重新标定并用文字位置校验（历史要求误差 <1pt）。**不要凭几何直觉"修正"这段**。

### 4.2 系统变量与环境变量通道（accoreconsole 唯一可行的入参方式）

| 通道 | 含义 |
|---|---|
| `USERS1` | 全局比例分母（如 `100` = 1:100）；逐框属性比例优先于它 |
| `USERS2` | 输出目录。**accoreconsole 下非空即触发"加载即出图"，且在触发时立即被清空**（`App.Initialize` 里 `SetSystemVariable("USERS2","")`，防重复触发） |
| `USERS3` | `0` = 关闭黑白（默认黑白开） |
| `USERS4` | 留白 mm（正=放大纸张保比例；负=固定纸张外扩图面） |
| `BPPLOT_MERGE=1`（环境变量） | 合并单 PDF（**`USERS6` 不存在，AutoCAD 只有 USERS1–5**） |
| `BPPLOT_KEEP_ORIG=1`（环境变量） | 保留裁切前中间 PDF（`*.orig.pdf`），裁切排障专用 |

**USERS2 的真实语义（README 有一处夸大，勿照抄）**：`SetSystemVariable("USERS2","")` **全代码只有一处**，在 `App.Initialize` 的 accoreconsole 分支里。也就是说：**只有"加载即出图"这条路会清空 USERS2**；GUI 下执行 `BPLOTAUTO`/`BPLOT`**不会**清空它。README 第 240 行"执行后 USERS2 自动清空"对 GUI 路径不成立。改这块时以代码为准，或一并修 README。

**读 USERS2 的 Trim 不一致（潜在缺陷）**：`BPLOTAUTO`(L428) 与 `BP1`(L576) 用 `u2.ToString()` **未 Trim**，而 `BPLOT`/`BPL`/`BPSPLIT`/`Initialize` 都 Trim 了。用户在 `.scr` 里多打一个空格，前两者会把尾随空格带进路径 → `Directory.CreateDirectory` 建出名字带空格的目录或失败。**修 USERS2 相关逻辑时统一走 Trim**。

**红线**：「加载即出图」必须**只在 accoreconsole 生效**（`App.Initialize` 按进程名判断）。完整版 acad 的 `USERS2` 是通用变量，其他插件/LISP 可能正在用，GUI 下误触发整图批打属于事故。

### 4.3 加一个新命令，必须同步这 3 处（漏一处就有一半失效）

1. `src/BPPlot.cs`（或 `BpMenu.cs`）里的 `[CommandMethod("BPXXX", CommandFlags.Modal)]`
2. `deploy/install.ps1` 的 `$commands` 数组——否则注册表按需加载的 `COMMANDS` 子键里没有它，用户输入命令会报未知命令
3. `src/BpMenu.cs` 的 `Items` 二维数组（若要出现在菜单里）——否则菜单栏看不到

另外同步：`README.md` 命令总表、`deploy/使用说明.txt` 速查、`docs/DESIGN.md`（如涉及模块能力）。

`BPSELFTEST` 刻意**不进菜单**（非交互自检，仅供排障/验收），但必须留在 `$commands` 里。

**当前数字基线（改完逐一复核）**：

| 位置 | 数量 | 缺失项 |
|---|---|---|
| `[CommandMethod]` | **12** | — （`BPPlot.cs` 10 + `BpMenu.cs` 2） |
| `[LispFunction]` | **1** | `BPVER`（`BPPlot.cs`，仅控制台探针用，不是用户命令） |
| `install.ps1 $commands` | **12** | 与 `[CommandMethod]` 一致 ✅ |
| `BpMenu.Items` | **11** | 比 `$commands` 少 `BPSELFTEST`（刻意不进菜单） |
| `README.md` 命令总表 | 10 行 | **缺 `BPSELFTEST`**（`BPHELP`/`BPABOUT` 挤在同一行） |
| `deploy/使用说明.txt` | 10 项 | **缺 `BPHELP`、`BPABOUT`** |

这些数字**没有任何自动化校验**（无 CI）。加/删命令后必须人工对一遍这六处。

### 4.4 线程/事务

- 所有数据库访问必须在 `Transaction` 内，`using` 包裹，结束 `Commit()`。
- **写入图纸（改实体/属性/WBLOCK）必须 `doc.LockDocument()`**。当前只有 `BPREV`、`BPSPLIT` 两处加了（它们真写库）；其余命令只读图纸、只写文件，因此没有 DocumentLock。**新增任何写库命令必须补上**，否则在文档未锁定时会抛 `eLockViolation`。
- 无多线程、无 `async`/`Task`。所有出图是单线程同步阻塞（`BPPREVIEW` 的预览窗口本身就是靠阻塞等待人工关闭）。**不要引入线程池/异步**，AutoCAD 的 DB 访问非线程安全。
- 静默操作（诊断、自检、CSV、裁切）不得弹对话框；GUI 交互只允许出现在 `BpForm` 与 `ShowAlertDialog`（`BPHELP` 失败兜底、`BPABOUT`）。
- 长循环（逐框出图）必须有进度反馈或至少逐框日志，不允许整批静默卡住。

### 4.5 配置契约（`%APPDATA%\BPPlot\config.json`）

只有 `BPConfig` 一个配置载体，UTF-8，**无 schema 版本号**。键名由手写迷你 JSON 解析器（`JsonParseObject`）消费，**大小写不敏感**：

| 键 | 类型 | 默认值 | 语义 |
|---|---|---|---|
| `frameBlocks` | string[] | `[]` | 学习到的图框块名白名单（`BPTEACH` 写入；自动识别时超出关键字规则的补充） |
| `numberTags` / `nameTags` / `scaleTags` / `revTags` / `dateTags` | string[] | `[]` | 属性标签映射（图号/图名/比例/版次/日期） |
| `minPolylineSide` | number | `15000` | 自动模式多段线图框最短边（图形单位）；`0` = 关闭该过滤 |
| `fileTemplate` | string | `"{图号}_{图名}"` | 文件名模板，占位符 `{图号}{图名}{比例}{日期}{序号}` |

- **解析器只支持该子集**：对象 / 字符串数组 / 数字 / 字符串。**不支持嵌套对象、布尔、null、数组套对象**。加配置项前先确认真需要，或同步扩展解析器（`JsonParseObject` + `Save` + `Escape` 三处）。
- **解析失败静默回退默认值**（`Load()` 整体包在 `catch {}` 里）。后果：用户手编 config.json 出错时不会报错，只会"图框突然识别不到了"。改动这里时**必须考虑是否要让错误可见**（至少 `WriteMessage` 提示一次）。
- `Cfg` 是 `Cmds` 的 `static` 字段，进程生命周期内缓存；**只有 `BPTEACH` 会重新 `BPConfig.Load()` 刷新**。手改 config.json 后必须重启 CAD 或重跑 `BPTEACH` 才生效——文档里不要承诺"改完立即生效"。
- `Save()` 是全量重写（不是增量合并）。`BPTEACH` 每次学习后把整个结构写回。

### 4.6 `pages[]` 位置索引契约（最脆弱处）

`PlotFrames2` 用 `object[]` 承载每页的全部状态，**靠下标取值**，无类型保护：

| 下标 | 类型 | 含义 |
|---|---|---|
| 0 | `PlotInfo` | 页面设置 |
| 1 | `string` | 唯一文件名主干（不含 `.pdf`） |
| 2 | `string` | CSV/日志显示名（合并模式为 `#第N页`） |
| 3 | `string[]` | CSV 行（下标 6 = 结果状态 `OK`/`FAIL`，由 `csvRowPatch` 追加 `->WxHmm`） |
| 4/5 | `double` | 纸张宽/高 mm（`paperW`/`paperH`） |
| 6/7 | `double` | 真实图幅宽/高 mm（`trueW`/`trueH`） |
| 8 | `bool` | 是否需要裁切 |
| 9 | `int` | 旋转角 0/90 |

改动这三阶段（构建 → 出图 → 裁切）任何一环时，**逐一核对下标**；下标错位不会编译报错，只会静默产出错页。若要做较大改动，优先把它重构成具名类而非继续加下标。

### 4.7 三条阶段的顺序不可调换

1. **阶段一** 逐框 `BuildPage` 建 `PlotInfo`（顺便空窗判定 + CSV SKIP 行）
2. **阶段二** 逐框 `BeginDocument`/`EmitPage`/`EndDocument` 出 PDF
3. **阶段三** 逐框 `CropPdf` 裁切（`BPPLOT_KEEP_ORIG=1` 留中间件）
4. **合并**（可选）`MergePdfs` → 追加 CSV 行 → `WriteCsvAndStats`

**为何必须是这个顺序**：`PlotEngine` 的 `BeginDocument…EndDocument` 是一次性串行会话，中途不能插入裁切（裁切读的是已落盘的成品 PDF）；合并必须等所有页裁切完，否则书签页顺序与真实图幅对不上。**不要把裁切挪到出图循环内**。

**已知缺陷（合并模式）**：`MergePdfs` 遇到缺失文件会 `continue` 跳过，但调用方在成功路径打印的是 `todo.Count` 而非实际写入页数，且**成功时不输出 `mergeErr`**。所以"某页阶段二失败"时：CSV 标 `FAIL`、合并 PDF 少一页、日志仍报 `todo.Count 页,含书签`。要验证合并结果必须**独立数 PDF 页数**（见 §5.5），不能信日志。

**已知缺陷（PlotEngine 空白页，2026-10 实测）**：某些图纸（已确认是天正/TArch 图纸）用 `PlotEngine` 出图会**静默产出空白页**——PDF 页面尺寸正确、CSV 记 `OK`，但内容流只有 `0.12 0 0 0.12 0 0 cm`，没有任何绘制算子。**同一图纸同窗口用原生 `-plot` 命令则完全正常（408KB vs 2.8KB）**。已排除 20+ 项（窗口/纸张/比例/旋转/图层/实体类型/颜色/字体/代理对象/`ShadePlot`/`CurrentLayout`/`INSBASE`/`DRAWORDER`/`wblock`/`saveas`/`AUDIT`/`REGEN`），并逐项复刻 `-plot` 的参数给 `PlotEngine` 仍为空白 → **是 API 本身失效，不是参数问题**。

- **不要在无替代方案时"修参数"**：这不是调参能解决的，已实测穷尽。
- **验证出图是否真的成功，必须解压 PDF 内容流看绘制算子**，不能只看文件大小/CSV/日志。PDF 的 `/FlateDecode` 是 zlib 封装，.NET 用 `ZLibStream`（.NET 6+）；用 `DeflateStream` 会把正常 PDF 误判成空。
- **治本方案**：装天正插件或对象激活器（Object Enabler）。或改用 COM `IAcadPlot`（等价 `-plot`，但需 P/Invoke 绕过 .NET 8 移除了的 `Marshal.GetActiveObject`，且 accoreconsole 无 COM）。
- 完整诊断报告见 `docs/PlotEngine空白页诊断报告.md`。

### 4.8 裁切触发条件（魔数，改前先理解）

```csharp
bool crop = margin >= 0 && trueW > 0 && (paperW - trueW > 0.5 || paperH - trueH > 0.5);
```

- `0.5` mm 是"纸张明显大于内容"的阈值，小于该值不裁（避免为 0.1mm 差距白跑一次 PdfSharp 全流程）。
- `margin >= 0` 才裁：**负留白语义 = 固定纸张微调比例，纸张本来就小于内容，裁了会丢图**。
- `trueW > 0` 兜住 `BuildPage` 异常返回。
- 其余相关魔数：`FitTol = 0.6`（mm，选纸匹配容差）、`MaxNameLen = 80`、`DropContained` 的 `eps = 最长边 × 1e-4`、`ParseScaleText` 的比例分母上限 `100000`。

---

## 5. 测试与回归

### 5.1 accoreconsole 无头回归（主要手段）

```cmd
cd test
runfixtest.cmd        :: fixtest.scr → out_fix/     基础三框；★设 BPPLOT_KEEP_ORIG=1（会产出 *.orig.pdf）
runt12.cmd            :: t12b.scr    → out_t12/     非标 900×630 加长幅
runscaletests.cmd     :: scaletest150 + scaletest1000 + fixtest_merge → out_s150/ out_s1000/ out_merge/（三条全跑）
runbatch.cmd          :: run_test.scr → out_real/   真实图纸（需 real.dwg，不入库，本机不适用）
rundiag.cmd           :: diag_real.scr → diag_report.txt  图纸结构诊断（需真实图纸）
runreal.cmd           :: diag_real.scr 的 /readonly 版本（需 real.dwg）
runrealfix.cmd        :: real_fix.scr  → out_fix_real/（需 real.dwg）
```

**注意 `runfixtest.cmd` 会留下 `*.orig.pdf`**（`BPPLOT_KEEP_ORIG=1`），这就是 `test/out_fix/Sheet00{1,3}.pdf.orig.pdf` 的来源。跑完它必须手动清理或确认不要提交——这不是新产生的 bug，是脚本的既有行为。若只想验证裁切结果而不要中间件，跑前把它改成 `0`。

- `.scr` 脚本必备开头：`secureload 0`、`filedia 0`、`cmddia 0`、`users1`、`users2`。
- 结尾 `_.quit _y`——**accoreconsole 里 `_y` = 放弃修改；完整版 acad 里 `_y` = 保存并关闭并会把测试几何/USERS 写进图纸**。GUI 自动化脚本里不要照抄。
- `accoreconsole /s` **只认绝对路径**（相对路径会"未找到文件"然后空转）。
- 控制台里 `(command "_.netload")` 能加载程序集、能跑 `Initialize`，**但 `CommandMethod` 命令不注册**——所以无头自动化只能走「USERS2 触发 + 加载即出图」，不能指望在 `.scr` 里敲 `BPLOT`。
- **`.scr` 的行尾必须有 CRLF**。当前 12 个 `.scr` 在 git 里存的是 LF，只有 `bundle_selftest.scr` 是 CRLF——因为 `.gitattributes` 里 `*.scr text` **没写 `eol`**，而本机 `core.autocrlf=true`：检出的磁盘文件是 CRLF（能跑），但 commit 进去的 blob 是 LF。**在别的机器/CI 上检出可能就是 LF → `.scr` 命令被 AutoCAD 当成一整行**。改 `.gitattributes` 为 `*.scr text eol=crlf` 可从根上修；在那之前，**提交前后都用 `git diff --stat -- *.scr` 确认没有意外的整文件行尾变更**（当前 `test/bundle_selftest.scr` 就有一处这种待提交差异）。
- 相关坑：`git diff` 对 `.scr` 会显示"整个文件都改了"但其实只有行尾不同。用 `git diff --ignore-cr-at-eol` 或 `git cat-file -p HEAD:<file> | od -c` 确认真实差异。
- **【2026-10 新增，已验证】accoreconsole 2025 必须经 `cmd.exe` 包装调用**。在 Git Bash 里直接跑 `accoreconsole.exe ... > log 2>&1` 会**永久挂起**：进程存活、日志停在 `命令:` 提示符、`.scr` 完全不执行、`_.quit _y` 无效、只能 `timeout` 强杀。根因是 Git Bash 的 POSIX 重定向与 accoreconsole 的 `Redirect stdout` 机制冲突。正确写法：

  ```cmd
  :: run.cmd
  @echo off
  set ACC=D:\Program Files\Autodesk\AutoCAD 2025\accoreconsole.exe
  "%ACC%" /i "输入.dwg" /s "脚本.scr" > "日志.log" 2>&1
  echo EXIT=%errorlevel%
  ```
  然后 `cmd //c run.cmd`（Git Bash 里）或直接双击。**2023 上未验证是否存在同样问题**——但那台机器的既有脚本都是 `.cmd` 包装，天然规避。
- **诊断"脚本到底跑没跑"的可靠办法**：在 `.scr` 里写标记文件，别信日志
  ```lisp
  (setq f (open "D:/path/marker.txt" "w"))
  (write-line "SCRIPT_RAN" f)
  (close f)
  ```
  标记文件出现 = 脚本执行；否则是启动/重定向阶段就卡了。
- **`/loadmodule <dll>` 不会注册 `CommandMethod`**（`Initialize` 会执行，但命令报"未知命令"）。必须用 `.scr` 里的 `(command "_.netload" "...")`。2025 已实测确认，与 2023 行为一致。

### 5.2 GUI 自动化（`.ps1`，走 COM）

`test/menu_test.ps1`（菜单栏验证 + 截图）、`test/preview_run.ps1`（`BPPREVIEW` 全流程 + ESC 关闭）、`test/selftest_run.ps1`（`BPSELFTEST`）、`test/menu_macro_test.ps1`（菜单跨会话持久性 + 宏前缀验证）、`test/menu_reflect.ps1`（COM 菜单接口反射探针，排障用）。

统一模式：`Start-Process acad.exe` → `Marshal.GetActiveObject('AutoCAD.Application')` 轮询 → `doc.SendCommand(...)` 注入 → 读 `%APPDATA%\BPPlot\*.log` 断言。日志断言的字符串是**契约**，改日志文案要同步改 `.ps1`。

### 5.3 部署自检

任何部署方式下执行 `BPSELFTEST`：验证 PdfSharp 加载/保存/裁切，结果写 `%APPDATA%\BPPlot\selftest.log`。**每次发布前必跑**，作为环境基线。

### 5.3 部署自检

任何部署方式下执行 `BPSELFTEST`：验证 PdfSharp 加载/保存/裁切，结果写 `%APPDATA%\BPPlot\selftest.log`。**每次发布前必跑**，作为环境基线。

### 5.5 回归基线：可机器校验的黄金数据（重要）

`test/out_*/` 里的 PDF 与 CSV **不是随手放的样张，是可量化的回归基线**。改出图/选纸/裁切/比例逻辑后，**必须重新提取并逐格比对**。实测基线（2026 核对，PDF `/MediaBox` 换算成 mm）：

| 样张 | 脚本输入 | 期望页尺寸 (mm) | 选纸 | 裁切 |
|---|---|---|---|---|
| `out_fix/Sheet001.pdf` | `fixtest.scr` 400000–518900 × 0–84570 图形单位，1:100 | **1189.0 × 845.7** | `ISO_full_bleed_B0_(1000×1414)` | 是 → `->1189x845.7mm` |
| `out_fix/Sheet002.pdf` | 200000–284100 × 0–59400，1:100 | **594.1 × 841.0** | `ISO_full_bleed_A1` | 否（正好满纸） |
| `out_fix/Sheet003.pdf` | 0–59400 × 0–84100，1:100 | **841.0 × 594.0** | `ISO_full_bleed_A1` | 是 → `->841x594mm`（**rot=90 转置**） |
| `out_t12/Sheet001.pdf` | `t12b.scr` 90000×63000，1:100 | **900.0 × 630.0** | `ISO_full_bleed_B1_(1000×707)` | 是 |
| `out_s150/Sheet001.pdf` | `scaletest150.scr` 45000×30000，**1:150** | **300.0 × 200.0** | `ISO_full_bleed_B4_(250×353)` | 是 |
| `out_s1000/Sheet001.pdf` | `scaletest1000.scr` 84100×59400，**1:1000** | **84.1 × 59.4** | `ISO_full_bleed_A5_(148×210)` | 是 |
| `out_merge/test_dwg_合并.pdf` | `fixtest_merge.scr` + `BPPLOT_MERGE=1` | 3 页，页序 = 1189×845.7 / 594.1×841 / 841×594 | — | 书签 = `Sheet001/002/003` |

**一键回归**（推荐）：

```cmd
build_net8.cmd
test\run_all_net8.cmd        :: 全量：自检 + 出图 + 连跑 + 合并 + 拆分 + 改版次（14 项）
test\run_golden_net8.cmd     :: 只验页尺寸黄金基线（3 框 1:100）
```

`run_all_net8.cmd` 会临时写入 `%APPDATA%\BPPlot\config.json`（模拟 `BPTEACH` 的学习结果），**跑完自动还原**：原文件存在则备份后恢复，不存在则删除。别去掉这段——否则会吃掉用户真实的标签配置。

判定核心是 `test/golden_check.py`（正则读 `/MediaBox` 换算 mm，容差 0.6mm），可单独复用：

```cmd
python test\golden_check.py <pdf目录> 1189.0x845.7 594.1x841.0 841.0x594.0
```

脚本自带以下纪律（改动前先读）：产物从 `build/bin/Release/net8.0-windows` 取（不是根目录 DLL，也不是旧的手工目录）；`.scr` 里 `USERS2` 必须先设空、`netload` 之后再设真值、最后显式 `BPLOTAUTO`（避开坑 #27 的"加载即出图"分支）；两个脚本的工作区分别是 `test/_golden/` 与 `test/_all/`（均 gitignore）。

**手工提取方法（无需 pymupdf，正则读 `/MediaBox` 即可）**：

```python
import re, glob
for f in sorted(glob.glob('test/out_*/Sheet*.pdf')):
    b = open(f,'rb').read()
    for x0,y0,x1,y1 in re.findall(rb'/MediaBox\s*\[\s*([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s+([\d\.\-]+)\s*\]', b)[:1]:
        print(f, round((float(x1)-float(x0))/72*25.4,1), 'x', round((float(y1)-float(y0))/72*25.4,1), 'mm')
```

**书签校验**：合并 PDF 的书签标题是 UTF-16BE 十六进制串，形如 `/Title<FEFF0053...>`。`Sheet001` → `0053 0068 0065 0065 0074 0030 0030 0031`。可解流后用正则提取，或直接 grep `/Title<FEFF` 数条数（应为页数）。

**裁切是否生效的唯一可信判据 = `/MediaBox`**。以下三个信号**都不能**证明裁切成功：

| 信号 | 为什么不可信 |
|---|---|
| CSV 里的 `OK` | 裁切在 CSV 写入之后单独执行，失败也不改状态 |
| CSV 纸张列的 `->1189x845.7mm` | 这是**期望值**，由 `csvRowPatch` 在 `CropPdf` 返回 true 时才追加……但若裁切整体未执行（如 `crop` 判定为 false），列里就没有 `->`。有 `->` 基本可信，但仍建议核对字节 |
| 日志的 `[crop] xxx -> 真实图幅` | 同上；失败时打的是 `[crop失败]`，中文在 UTF-16 日志里可能被吞，看起来像正常行 |

**必须实测**：读 PDF 的 `/MediaBox` 换算成 mm，与 §5.5 表的期望值逐个比对。2026-10 在 AutoCAD 2025 上就是靠这个发现"PdfSharp 1.50 无法解析 2025 的 PDF"——CSV 全 `OK`、日志全 `[crop]`，但页尺寸仍是整张纸。

**几何自洽校验（改比例逻辑时最有价值的检查）**：

```
真实图幅 = 图框图形单位尺寸 ÷ 比例分母
1:150  × 45000×30000  → 300×200 mm   ✓ 与样张一致
1:1000 × 84100×59400  → 84.1×59.4 mm ✓ 与样张一致
```

**输出编号顺序 = 面积降序，不是脚本创建顺序**：`DropContained` 先按 `AreaX` 降序排。所以 `fixtest.scr` 里第三个 pline（加长 A0）反而成为 `Sheet001`，面积相等的两个 A1 保持原有相对顺序（竖版在前）。**看到"Sheet001 不是第一个画的框"不要当 bug**。

**`A4 当量` 折算的边界**：`FoldStandard` 容差 3mm，取"能容纳的最小 A 系"。实测：`1189×845.7→A0`、`900×630→A0`、`300×200→A4`、`84.1×59.4→A4`（比 A4 小也算 A4）、超出 A0 一律归 `A0`（无更大档）。`out_fix` 统计 `A0x1；A1x2，A4当量 32` = 16+8+8 ✓。

### 5.6 测试资产的红线

- **`test/` 脚本里的绝对路径是历史包袱**：`test/` 下共 86 处 `C:/Users/hwdem/.zcode/workspace/default/batchplot-plugin/...` 与 15 处 `D:\Program Files\AutoCAD 2023\AutoCAD 2023` 硬编码（原作者机器路径，本机不存在）。换机器跑测试前必须批量替换，或用 `%~dp0` + 顶部变量重构。
- 新增脚本**不要**继续复制写死路径：把仓库根与 ACAD 路径提到 `.cmd` 顶部的 `set` 变量里，或让 `.cmd` 用 `%~dp0` 推导。
- `test/out_*/` 是回归样张（含 PDF/CSV），已入库。重跑测试会覆盖它们——提交前必须确认差异是预期改进而非回归。
- **`test/out_fix/Sheet00{1,3}.pdf.orig.pdf` 是 `runfixtest.cmd` 里 `BPPLOT_KEEP_ORIG=1` 的正常产物**，不是异常残留——但**不该入库**。已入库的两份属历史遗留；`.gitignore` 无 `*.orig.pdf` 规则。**不要让新增中间件提交**（建议补 `*.orig.pdf` 到 `.gitignore`）。它们本身也有用：`Sheet001.pdf.orig.pdf` 实测 `1000.1×1413.9`（未裁切的整幅 B0），`Sheet003.pdf.orig.pdf` 实测 `594.1×841.0`（未转置的 A1）——可用于对照验证 `rot=90` 的反转置是否正确。
- **`test/*.log` 含原作者机器路径**（`C:\Users\hwdem\.zcode\workspace\default\batchplot-plugin\...`，`fixtest.log`/`merge.log`/`s150.log`/`s1000.log`/`t12.log` 都有，UTF-16 编码）。虽然只是路径不是客户图纸内容，但**新增日志前必须脱敏或改存到 `.gitignore` 覆盖处**。见 §9。
- `test/create_dwg.scr` 会 `_.saveas` 覆盖 `test/test_dwg.dwg`（已入库的样例图）；`t11.scr`/`t12b.scr` 等有 `_.erase _all`。**跑测试会改写已入库的样例文件**，提交前 `git status` 必须确认这些变更是否预期。
- **`test/` 里有一批"孤儿资产"（无任何 runner 调用）**，别误以为跑哪个 `.cmd` 就覆盖了全部：
  - 无 runner 调用的 `.scr`：`create_dwg.scr`（建样例图，一次性）、`t11.scr`、`t12.scr`（已被 `t12b.scr` 取代）、`bundle_merge_test.scr`、`bundle_selftest.scr`
  - 无文档提及的 runner：`_compile_probe.cmd`、`runconsole.cmd`（通用壳，`%1`=脚本 `%2`=日志）、`runreal.cmd`、`runrealfix.cmd`（都需 `real.dwg`，本机不适用）
  - `test/loadprobe.cs` + `loadprobe.dll`：Bundle 自动加载机制的**最小探针**（v0.7 用它证明本机构建不支持 bundle 自动加载），属一次性取证资产，保留但不再运行
- `test/real.dwg`、`test/out_real/`、真实项目日志已在 `.gitignore` 排除，**永不入库**。

### 5.7 无头 GUI / 交互验证（`test/gui/` + `test/fixtures/`）

AutoCAD 插件最难验证的两块——**WinForms 对话框**和**需要交互选点的命令**——已各有可复现的绕过方案，都在 `test/gui/`：

| 资产 | 用途 | 用法 |
|---|---|---|
| `test/gui/BpFormTest.csproj` + `BpFormTest.cs` | `BpForm` 出图对话框**无头单测**（24 项：控件/行列/勾选/比例联动/写回/取消/列不可排序） | `dotnet run --project test\gui\BpFormTest.csproj -c Release`，退出码 0 = 全过，日志在 `%TEMP%\bpform_test.log` |
| `test/gui/MkBlockDwg.csproj` + `MkBlockDwg.cs` | 生成"图块式图框"图纸 `blk.dwg`（块 `TITLEBLOCK_A3` + 属性 `TUHAO/TUMING/BILI/BANCI/RIQI` + 框内几何） | accoreconsole 里 `netload` 后跑 `MKBLK`；输出到 `%BPBLK_OUT%`（默认 `%TEMP%`） |
| `test/fixtures/content.dwg` | 3 个**有内容**的空白框（118900×84570 / 84100×59400 / 59400×84100）——出图链路回归用 | 直接 `/i` 打开 |
| `test/fixtures/blk.dwg` | 上面 `MKBLK` 的产物，2 个图块式图框 | 同上 |

**为什么 `BpForm` 可以无头测**：它只吃 `List<FrameInfo>` + `List<Media>` + 几个标量，不碰 `Application`。`form.Show(); Application.DoEvents();` 之后 `PerformClick()` 即走完整交互路径。**必须 `Show()`**，否则 `PerformClick()` 静默无效（坑 #32）。

**为什么需要 `blk.dwg`**：`test/test_dwg.dwg` 只有 3 个**空**多段线框，`CountVisibleInWindow` 会把它们全判 `SKIP`，覆盖不到"图块+属性标签"链路（`BPTEACH`/`BPREV`/`BPSPLIT`）。块名与标签刻意不用中文，以证明识别结果来自 `config.json` 学习记录而非内置中文规则。

**accoreconsole 交互能力边界**（详见坑 #33）：

| API | 可脚本化 | 喂法 |
|---|---|---|
| `GetSelection()` | ✅ | 裸 `ALL` + 空行 |
| `GetString()` / `GetInteger()` | ✅ | 下一行直接写值 |
| `GetEntity()` | ❌ | 5 种写法全失败（坐标串/端点/线上点/隐式选择集/补空行） |
| `ShowModalDialog()` | ❌ | 占住主线程，后续 COM 全 `RPC_E_CALL_REJECTED`；窗口枚举也找不到独立顶层窗口 |

**跨机器注意**：这些工程用 `$(AcadDir)`（可由 `ACAD_DIR` 环境变量覆盖）定位 AutoCAD 程序集，用 `$(RepoRoot)` 定位 `BPPlot.dll`，**没有硬编码本机路径**。`BpFormTest` 引用的是 `build/bin/Release/net8.0-windows/BPPlot.dll`，跑测试前先 `build_net8.cmd`。

---

## 6. 已知坑（AutoCAD 2023 实测结论，勿重复试错）

1. `accoreconsole` 不带 `/i` 的空白图模式已失效（报错 53）——无头脚本必须 `/i` 指定一个 DWG（可用空白模板图）。
2. `Plotting` 命名空间在本版叫 `Autodesk.AutoCAD.PlottingServices`（不是 `Autodesk.AutoCAD.Plotting`）。
3. **`DWG To PDF.pc3` 的 ISO 纸型名是竖版命名**：A1=594x841、A2=420x594、B0=1000x1414（B1 例外 1000x707）。判断纸张尺寸要按宽高比兼容横竖，不能假定"名字即方向"。
4. 旋转页（`PlotRotation.Degrees090`）的内容在名义纸上是**转置放置**的（图面 X → 纸面 Y 向下），裁切必须反转置回正。v0.5 全部竖版页裁坏的根因。
5. `Editor.SelectAll` ≡ `(ssget "_X")`，**跨布局包含图纸空间**；图框收集必须按 `OwnerId` 过滤模型空间，否则把纸面坐标当模型窗口打印。
6. 非标准比例（1:150/250/500/1000）走 `SetUseStandardScale(false)` + `SetCustomPrintScale(new CustomScale(1, n))`；`StdScaleType` 枚举**没有 1:1000**（只有 1000:1），别按分母硬套枚举。
7. 动态块取原始块名（`*U` 匿名名要解析回原块名）。
8. 天正图框是自定义对象，自动识别不保证；`BPLOT` 手选任意实体取外接框可用。
9. 本机构建（24.2s LMS Tech）**不支持 `ApplicationPlugins` bundle 自动加载**（最小标准探针包对照实验证实）→ 部署主路径是 HKCU 注册表按需加载（`LOADCTRLS=2` + `COMMANDS` 子键），bundle 仅作标准构建的双保险。
10. 菜单**跨会话持久但插件不自动加载** → 每个菜单项宏自带"静默 NETLOAD 当前 DLL（正斜杠路径 + 临时 `FILEDIA=0`）"前缀。`NETLOAD` 对已加载程序集是幂等空操作。
11. 菜单栏默认随功能区隐藏，用户看不到时提示 `MENUBAR` 输入 `1`。
12. **DLL 与源码必须同批提交的证据**：v0.7 的 `f25f39f` 就同时改了 `src/BPPlot.cs`(+136) 和 `BPPlot.dll`(51712→57344)，`bb1798a` 同理。历史一直如此，别破例。
    **唯一例外（`research/autocad-2025-compat` 分支）**：本机只装了 AutoCAD 2025，**没有 2023**，`build.cmd` 引用的 `D:\Program Files\AutoCAD 2023\...` 不存在，根目录 `BPPlot.dll`（Framework 4.x 产物）**无法重编**。因此本分支上的源码改动**只有 net8 产物同步**（`build_net8.cmd` → `build/bin/Release/net8.0-windows/`，该目录不入库、可随时重建）。
    - 合并回 `main` 前必须在有 2023 的机器上跑一次 `build.cmd` 重编根 DLL 并同批提交，否则根 DLL 与源码脱节。
    - 这不是"省一步"，是**已知的临时欠账**，`main` 上不能沿用。
13. **`build.cmd` 的引用列表会随功能增长**：v0.7 加菜单时才补上 `AcCui.dll` + `Autodesk.AutoCAD.Interop.dll` + `...Interop.Common.dll` 并加入 `src/BpMenu.cs`。新增依赖 AutoCAD 程序集的功能时，**改源码的同时改 `build.cmd`，否则报 CS0246 找不到类型**。
14. `.cs` 源码是 **UTF-8 无 BOM + CRLF**，编译必须带 `/codepage:65001`；去掉该参数会让中文注释/字符串按 GBK 解析而编译报错。
15. `PackageContents.xml` 在仓库与 zip 内是**同一份字节**（已核对一致）；改它要重新打包 zip，否则 bundle 里的还是旧配置。
16. **【已修复 v0.8】`BpForm` 的 DataGridView 曾允许点表头排序，排完导出错图**。`DataGridViewTextBoxColumn.SortMode` 默认是 `Automatic`（已用 csc 实测确认），原代码从未设置 `SortMode`。而 `ApplyAndClose()` 用 `_frames[r.Index]` 取值——`r.Index` 是**显示行号**，一旦用户点了"图号"或"比例"表头排序，显示行与 `_frames` 下标就错位，**勾选 A 图框却按 B 图框的比例/文件名出图**（静默错图，不崩溃）。
    修复：`_grid.Columns.AddRange(...)` 之后逐列 `col.SortMode = DataGridViewColumnSortMode.NotSortable`。**新增任何列都必须同样处理，否则重新引入本缺陷**。
    实证（`gui/formtest/`，无头实例化）：修复前"排序后首行显示 A-102，写回却落到 A-101"；修复后 0 列可排、显示与写回一致。
17. **`BpForm` 里"无内容/无纸张"的降级文案**：`PaperPreview` 返回 `"-"`，`UpdatePaper` 失败时 `catch {}` 静默——用户在比例栏输入非法值（如 `0`、`abc`）后，纸张列显示上一次的值或空白，没有任何提示。改对话框时补可见提示。
18. **`DropContained` 的包含判定是包含式（`>=`/`<=` + eps）**：**两个完全重合的图框会互相判为"被包含"，只保留一个**。这是刻意的去重行为（与 MSteel 一致），但用户"画了两个完全相同的框想各打一份"时会被静默合并。若需求变化，改判定为严格包含。
19. **`PlotFrames2` 开头会再跑一次 `DropContained`，推翻用户在对话框里的预期**：
    - 对话框里勾选/取消的顺序被忽略——`seq`（决定 `Sheet001/002/...` 编号与 CSV 序号）是在 `DropContained` 排序**之后**才递增的，所以**编号永远按面积降序，与用户在列表里看到的行序无关**；
    - 用户勾选了"大框 A + 完全被 A 包含的小框 B"，B 会在这一步被静默剔掉（有 `WriteMessage` 提示剔除数量，但对话框里已勾选的事实让人以为会出）。
    
    这不是 bug 而是"自动去重"语义，但**改对话框（DESIGN M5 多行编辑/图号重编）时必须决定：出图顺序是听用户的还是听 `DropContained` 的**。当前是听 `DropContained`。
20. **【PdfSharp + .NET 8 = 静默失败】**（AutoCAD 2025 路线必读）：`.NET 5+` 默认不内置 ANSI 代码页（1252/936/GBK），而 PdfSharp 1.50 内部 `Encoding.GetEncoding(1252)`。症状是 `PdfDocument` 构造成功、`AddPage` 成功，但 **`Save()` 抛 `NotSupportedException: No data is available for encoding 1252`**，只写出 39 字节废文件。因为 `CropPdf` 用 `catch { return false; }`，失败完全无声——用户只看到"PDF 没裁切"或"合并失败"。修复：`App.Initialize()` 开头 `Encoding.RegisterProvider(CodePagesEncodingProvider.Instance)`。**这是 net8 产物唯一必需的代码改动**。
21. **2025 的 `Application` 命名空间未变**：DESIGN.md 原写"2025 起 `Application` → `Autodesk.AutoCAD.ApplicationServices.Core`"，实测**不必改**——现有 `using Autodesk.AutoCAD.ApplicationServices;` 在 2025 下直接编译通过。
22. **net8 工程引用 2025 程序集必须 `<Private>false</Private>`**：AutoCAD 宿主提供这些 DLL，若复制到输出目录会与宿主版本冲突。构建时 `MSB3277`（`AdWindows.dll` 等版本冲突）警告可忽略。
23. **`LangVersion` 在 net8 工程里不要锁 C# 5**：C# 5 上限只是 `csc v4.0.30319` 的限制。net8 用 Roslyn，可自由使用现代语法——但**若要源码双轨共用，仍须保持 C# 5 可编译**，这是硬约束。
24. **【PdfSharp 1.50 读不了 AutoCAD 2025 的 PDF】**：`PdfReaderException: Invalid entry in XRef table, ID=13, Generation=0, Position=...`。AutoCAD 2025 打印引擎生成的 xref 偏移量 1.50 解析不了（PDF 1.7、传统 xref 表、19KB 量级的小文件也会失败）。**net8 产物必须用 PdfSharp 6.x**；6.x 实测能正确读取（`pages=1, 2835×4008pt`）并完成裁切/合并。
25. **【PdfSharp 6.x 有 8 个传递依赖】**：`Microsoft.Extensions.{Logging,Logging.Abstractions,DependencyInjection,DependencyInjection.Abstractions,Options,Primitives}`、`System.Diagnostics.DiagnosticSource`、`System.Runtime.CompilerServices.Unsafe`。缺任一个 → `PdfDocument..ctor()` 抛 `FileNotFoundException`。SDK 风格库工程**默认不复制** PackageReference 的 DLL，必须设 `<CopyLocalLockFileAssemblies>true</CopyLocalLockFileAssemblies>`。部署时 13 个 DLL 必须同目录。
26. **【已修复 v0.8】`BPL` 布局批量出图**（原报 `eLayoutNotCurrent` 后进程崩溃）。两个独立缺陷叠加：遍历布局字典时**从不切换** `LayoutManager.Current.CurrentLayout`（→ `eLayoutNotCurrent`，API 要求目标布局必须是当前布局）；`finally` 里无条件 `EndPlot()`（→ 零 `BeginDocument` 时 AccessViolation 杀进程）。
    修复：先收集布局名（不在遍历字典时改布局上下文）→ 循环内 `CurrentLayout = layName` → `plotStarted` 守卫 → `finally` 恢复 `prevLayout`。验证：2 布局 → 2 个 PDF，`BPL_SUMMARY OK=2 FAIL=0`，`/MediaBox` 均 297×420mm。
27. **`USERS2` 预设会误触发"加载即出图"**：若 `.scr` 先 `(setvar "users2" "<dir>")` 再 `netload`，`App.Initialize` 会判定为 accoreconsole 场景并直接跑 `BPLOTAUTO`（可能崩溃）。**正确顺序：先 netload（USERS2 为空）→ 再设 USERS2 → 再执行目标命令**：
    ```lisp
    (setvar "users2" "")
    (command "_.netload" "D:/path/BPPlot.dll")
    (setvar "users2" "D:/output")
    BPSPLIT
    ```
28. **`BP1` 不是"只打一个图框"**：它只是"不弹对话框、用 USERS1/USERS2 默认参数"，`CollectFrames` 仍会收集选择集里的**全部**图框。想只打一个就在选择时只选一个。

29. **【高危，已修复 v0.8】零文档 `EndPlot` → AccessViolation 0xC0000005，进程直接消失**。`PlotEngine.EndPlot()` 在没有成功 `BeginDocument` 过的状态下调用会触发访问违例，**不是可捕获异常**，`try/catch` 完全拦不住，AutoCAD 无任何提示直接退出。典型触发：所有图框都被空窗检测判为 `SKIP`（`pages.Count == 0`）、或所有布局 `BuildPage` 全失败。
    修复：`PlotFrames2` / `BpLayouts` 各加 `bool plotStarted = false;`，每次 `BeginDocument` 成功后置 `true`，`finally` 里 `if (pe != null && plotStarted) EndPlot()`。**新增任何出图入口都必须照抄这个守卫**。
30. **【已修复 v0.8】出图引擎不释放 → 同一 AutoCAD 会话第二次出图静默失败**。`EndPlot()` 只结束这一轮出图事务，**不回收 COM 端 `PlotEngine` 实例**。同一会话内第二次出图抛 `BPLOT 致命错误: ePlotAlreadyStarted`，且统计是 `OK=0 FAIL=0`——用户只看到"第二次没出图"，没有失败计数。`PlotEngine` 同时实现 `IDisposable` 和显式 `Destroy()`，**两个都要调**。
    修复：`ReleaseEngine(pe)` 辅助方法（`Destroy()` + `Dispose()`，各自 try/catch），在 `PlotFrames2` / `BpLayouts` / `BPPREVIEW` 的所有退出路径调用。
    验证：同一会话连跑 3 次 `BPLOTAUTO` 三次全绿；`BP1 → BP1 → BPLOTMERGE` 连跑同样三次全绿。
31. **`List.Sort` 是不稳定排序 → Sheet 编号跨次抖动**。A1 横版与 A1 竖版图框面积完全相同（4.99M 图形单位²），按面积单键排序时两次运行顺序互换，`Sheet001/Sheet002` 对应的图框漂移，黄金样张无法复现。
    修复：`DropContained` 用多级排序键 —— 面积降序 → `MinX` → `MinY` → 宽度。**任何"按面积/尺寸排序"的新逻辑都必须补二级键**。
32. **`DataGridView` 的 `PerformClick()` 只有控件可见才生效**。无头单测 `BpForm` 时若只 `new BpForm(...)` 不 `Show()`，`Button.PerformClick()` 静默无效（`CanSelect == false`），`DialogResult` 停在 `None`——看起来像"按钮没绑事件"，实际是测试方法问题。
    正确写法：`form.Show(); Application.DoEvents();` 之后再 `PerformClick()`。
33. **accoreconsole 下 `GetEntity` 无法用 `.scr` 喂点**。实测 5 种写法全部失败：`2000,28000`（坐标串）、`21000,0`（端点）、`7000,7000`（线上点）、`(sssetfirst nil (ssget ...))` 隐式选择集、单点命令后补空行。坐标串会被当作文本吃掉并返回"未选中对象"。
    例外：`GetSelection` **可以**用裸 `ALL` + 空行喂进去——`BP1`/`BPLOTMERGE`/`BPREV`/`BPSPLIT` 都是这么测通的。所以**选面（GetSelection）能脚本化，选点/选单体（GetEntity）不能**。验证 `BPTEACH` 这类 `GetEntity` 命令时，改用"手工写入同格式配置 → 验证下游链路消费"的替代覆盖。

---

## 7. 版本与发布

### 7.1 版本号落点（改版本必须全改，漏一处就出现版本不一致）

| 位置 | 形式 |
|---|---|
| `deploy/PackageContents.xml` | `AppVersion="0.8"` + 两处 `ComponentEntry Version="0.8"` |
| `deploy/make_bundle.cmd` | `set VER=0.8`（决定 zip 文件名） |
| `src/BpMenu.cs` | `BPABOUT` 弹窗文案 |
| `src/BpForm.cs` | 对话框标题 |
| `src/BPPlot.cs` | `BPVER` LispFunction 返回值 + `BPLOT` 启动日志 |
| `README.md` | 新增版本段 + 快速开始里的 zip 名 |
| `docs/DESIGN.md` | 基线声明 |

另需核对：`PackageContents.xml` 的 `SeriesMin/Max`（当前 `R24.0`–`R24.3` = 2021–2024）与 README 兼容性声明一致。

**仓库 URL 待统一**：`git remote origin` 指向 `HeWenbin-bobo/batchplot-plugin`，而 README 徽章、`PackageContents.xml`、`src/BpMenu.cs`（`BPHELP`/`BPABOUT`）、`deploy/使用说明.txt` 全部指向 `hwdemtv/batchplot-plugin`。发布前必须确认哪个是真仓库并统一，否则 `BPHELP` 会打开错地址。

### 7.2 打包

**双产物打包（v0.7 起）**

```cmd
cmd /c build.cmd                :: netfx: 根 BPPlot.dll（需机器上装有 AutoCAD 2021-2024）
cmd /c build_net8.cmd           :: net8 : build/bin/Release/net8.0-windows/（需 2025）
cd deploy && make_bundle.cmd    :: 组装双产物 zip
```

产物布局（zip 内）：

```
BPPlot.bundle/PackageContents.xml
BPPlot.bundle/Contents/netfx/*.dll      A2021-2024  2 个 DLL
BPPlot.bundle/Contents/net8/*.dll       A2025+     13 个 DLL
bin/netfx/*.dll  bin/net8/*.dll         安装器取用
install.ps1  uninstall.ps1  <安装.cmd>  <卸载.cmd>  <说明.txt>
```

**为什么必须双产物**：AutoCAD 2025 起 ObjectARX 托管程序集改成 .NET 8。Framework 产物在 2025 上虽然能被 `NETLOAD` 接受（实测命令能注册、图能出），但 PdfSharp 1.x 读不了 2025 打印引擎的 PDF，**裁切/合并静默失效**——页尺寸停在整张纸，而 CSV 和日志全是 `OK`。详见坑 #20/#24。

**`make_bundle.cmd` 的过期 netfx 守卫（重要）**：
脚本会用 `deploy/marker_check.ps1` 探测 netfx DLL 里有没有 `ReleaseEngine` 这个符号（当前源码才有）。没有就判定 netfx 过期，**丢弃 netfx 并改出 `BPPlot-v0.7-a2025.zip`**（2025-only 包，同时换用 `PackageContents-2025.xml` 清单）。
理由：在没有 2021-2024 的机器上，netfx 产物编不出来，若照常打包就会把带旧 bug 的 DLL（BPL 崩溃 / 引擎泄漏 / 错图）发给 2021-2024 用户。
`set BPPLOT_ALLOW_STALE_NETFX=1` 可强行打包混合版本，仅在复现历史 bug 时才用。

**清单选择与产物一致**：`PackageContents.xml` 声明 netfx+net8 两份；`PackageContents-2025.xml` 只声明 net8。**声明了 netfx 却不存在对应目录**会让 2021-2024 尝试加载缺失模块，所以两者必须成对切换。

**编码纪律**：
- `make_bundle.cmd` 是 **ASCII-only**（中文名包装文件用 `for %%f in (*.cmd)` 通配复制，不写死中文名），改它别引入非 ASCII 字符。
- `deploy/使用说明.txt`、`安装到本机.cmd`、`卸载本机.cmd` 是 **GBK + CRLF**，改这些必须按 GBK 保存，否则中文全乱。
- `deploy/*.ps1` 是 **UTF-8 with BOM + CRLF**（BOM 不能去，Windows PowerShell 5.1 靠它正确识别中文）。
- `deploy/PackageContents*.xml` 是 UTF-8 无 BOM + CRLF。
- `.cs` / `.md` 为 UTF-8 **无 BOM**。保存时保持原状，别让编辑器统一加/去 BOM。
- `.gitattributes` 已声明 `* text=auto`、`*.cmd text eol=crlf`、`*.scr text`、`*.dll binary`、`*.dwg binary`、`*.pdf binary` 等，别随意改。
  - **已知问题**：`*.scr text` 缺 `eol=crlf`，配合本机 `core.autocrlf=true` 会导致 git 里存 LF、检出的磁盘是 CRLF。建议改为 `*.scr text eol=crlf`（见 §5.1）。
- zip 内的 netfx `BPPlot.dll` 必须与仓库根目录 `BPPlot.dll` **完全一致**，net8 目录必须与 `build/bin/Release/net8.0-windows/` 一致，不得分别编译。

### 7.3 产物入库策略（本仓库特意入库，别"顺手清理"）

跟踪在 git 里的二进制：根目录 `BPPlot.dll` / `BPDiag.dll` / `PdfSharp.dll`、`libs/PdfSharp.dll`、`deploy/BPPlot-v0.7.zip`、`test/out_*/` 下的 PDF+CSV 样张、`test/*.log`、`test/test_dwg.dwg`、`test/menu_proof.png`、`test/preview_proof.png`、`test/loadprobe.dll`。

- DLL 入库是刻意的：用户 `NETLOAD` 即用、无需自备编译环境（README 已声明）。
- 因此**改源码必须重编译并同批提交 DLL**，否则仓库里的 DLL 与源码脱节。
- 根目录 `PdfSharp.dll` 与 `libs/PdfSharp.dll` 当前内容一致（**1.50.5147.0**，同一版本）；升级 PdfSharp 必须两处同步 + 重新打包 zip。DESIGN.md M8 计划的 net8 产物需改用 PdfSharp 6.x（源码共用、双轨引用）。
- `deploy/BPPlot-v0.7.zip` 入库意味着**每次发版都要重新生成它**，否则用户下载到旧包。
- **v0.7 起发布包可能是 `BPPlot-v0.7-a2025.zip`**（2025-only）。这是 `make_bundle.cmd` 的过期 netfx 守卫在起作用：本机没有 2021-2024，netfx 编不出来。在有 2021-2024 的机器上重编后重跑 `make_bundle.cmd`，会重新产出双产物 `BPPlot-v0.7.zip`。**两个 zip 不要同时存在**，旧的删掉，避免用户下错。
- `libs/pc3_dwg2pdf_body.bin` 是 M3 的 pc3 种子数据（**当前代码未引用**，纯预留），勿删勿改。

### 7.3.1 DLL 入库的代价与纪律

因为 DLL 入库，**代码审阅者看到的源码可能与 DLL 不一致**。因此：

- 每次改 `src/**` 都在同一个 commit 里重编 `BPPlot.dll`（`BPDiag.dll` 仅在改 `BpDiag.cs` 时需要）。
- 提交前用 `git status` 确认 DLL 的 `Bin` 大小真的变了（历史三个版本：51712 → 57344 → 59904 字节）。
- **不要提交"仅 DLL 变化、源码没变"的 commit**——那说明本地源码与仓库不同步。
- 二进制 diff 无法 review，**PR 里必须用文字说明源码改了什么**。

**如何验证 DLL 与源码一致（无需反编译器）**——对照法，实测有效：

```python
# 1) 元数据 #Strings 堆里是 UTF-8，命令名/类型名可直接搜
b = open('BPPlot.dll','rb').read()
for cmd in [b'BPLOT', b'BPPREVIEW', b'BPSELFTEST', b'BPABOUT', b'BPVER']:
    assert cmd in b, cmd

# 2) 用户可见字符串是 UTF-16LE（#US 堆），要按 UTF-16 搜
('BPPlot v0.7'.encode('utf-16-le') in b)          # → True
('BPPlot 批量打印插件'.encode('utf-16-le') in b)   # → True
('DWG To PDF.pc3'.encode('utf-16-le') in b)       # → True

# 3) 反例：BPDiag.dll 里不应有 BPPlot 的命令
('BPPREVIEW'.encode('utf-16-le') in open('BPDiag.dll','rb').read())  # → False（已验证）
```

**当前基线（2026 核对，三者一致）**：`BPPlot.dll` 59904 B（13 个命令名齐 / `BPPlot v0.7` 在）/ `BPDiag.dll` 10240 B（含 `PROXY[`、`ModelSpace 实体普查`、`DIAG ERROR`，**无 `CommandMethod`**）/ `PdfSharp.dll` 535040 B（1.50.5147.0）。

**`BPDiag.dll` 是开发工具，不进发布包**：`make_bundle.cmd` 和 `install.ps1` 里都没有它（已核对 0 处引用）。它靠 `diag_real.scr` 手动 `netload` 跑。**改 `BpDiag.cs` 只需重编 `BPDiag.dll`，不影响 zip**。

**zip 完整性核对**：zip 内 5 个文本文件（`install.ps1`、`uninstall.ps1`、`使用说明.txt`、`安装到本机.cmd`、`卸载本机.cmd`）与 `deploy/` 下同名文件**逐字节一致**（已核对）；`bin/BPPlot.dll` 与 `Contents/BPPlot.dll` 也彼此一致且等于仓库根 DLL。**改 deploy 下任何文件后都必须重跑 `make_bundle.cmd`**，否则 zip 里是旧版。

### 7.4 发布前检查

`BPSELFTEST` 通过 → 安装/卸载往返干净 → 菜单项 11 条宏路径指向正式安装目录 → `install.ps1` 的 `$commands` 12 项齐全 → README 与 `使用说明.txt` 命令表与实际 `CommandMethod` 一一对应 → 版本号 7 处一致 → **zip 重新生成并与 `deploy/` 逐字节一致** → **`test/out_*/` 黄金值复核（§5.5）无回归**。

---

## 8. 文档规则

- `README.md` 只放：定位、核心能力、快速开始、命令总表、踩坑记录、路线图、兼容性。**非必要不改**，避免膨胀。
- 模块设计、分期、风险、测试策略 → `docs/DESIGN.md`。
- **改架构/加模块前先读 `docs/DESIGN.md`**，落地后同步更新对应 M/P 条目的状态（哪期已完成、基线变成哪版）。
- 不删除、不覆盖 `docs/` 下的历史分析记录。发现历史数字与现状不符时先查 `git log` 再下结论，不凭当前代码臆断历史行为。
- 引用实测数字必须带条件与样本量（如"24 页真实工程图，7 万实体，天正 T20 V8"），不脱离语境。
- 注释少而精：解释**为什么**，不复述是什么。修 bug 请在文件顶部版本注释块里补一条带编号说明（现有 `v0.6 修复` 1–11 条的格式），便于回溯。
- 用户可见文案（对话框、`WriteMessage`、错误提示、CSV 表头）一律中文。
- **README / DESIGN.md 里有已知不准的表述，别照抄**（下表为实测核对结果）：

| 文档表述 | 实际情况 |
|---|---|
| README:240「BPLOTAUTO / BPLOT，执行后 USERS2 自动清空」 | 只有 accoreconsole 的"加载即出图"会清空；GUI 命令不清空 |
| README:71 / 源码头注释「未保存图纸默认输出到我的文档\PDF_OUT」 | `DefaultOutDir()` 有此兜底，但 `Run()` 直接 `Path.GetDirectoryName(db.Filename)`，空路径会抛 `ArgumentException` |
| DESIGN:42「现 `BPPlot.cs`（约 1600 行单文件）拆分为…」 | 实际 **1961 行**；§2 计划拆成 14 个 `.cs`，其中**除 `BpForm.cs` 外 13 个都还没建**，P0 代码拆分尚未开工 |
| DESIGN §7 标题「v0.6 现状基线」 | 表内已含 v0.7 三条挂点，标题未同步 |
| README 徽章「AutoCAD 2021–2024」/ `PackageContents.xml` `SeriesMin=R24.0 Max=R24.3` | 与 DESIGN M8 的「2013–2027 双产物」规划不一致；当前产物实际只覆盖 2021–2024 |
| DESIGN M3 提到 `libs/pc3_dwg2pdf_body.bin` 作 Pc3Factory 种子 | 代码里**尚无任何引用**（纯预留资产，别误以为在用） |
| DESIGN M5「重复标红」「多行批量编辑」「表头统一改」「图号重编」「进度对话框」「预览列」 | `BpForm.cs` 里**一个都没有**——只有勾选列、图号/图名只读列、比例可编辑列、文件名可编辑列、纸张预览只读列。M5 未开工 |
| README「菜单项 11 项全命令入口 + 使用说明/关于」 | 数字对（11），但其中 `BPHELP`/`BPABOUT` 是"使用说明/关于"，即 **9 项真命令 + 2 项辅助**，表述容易让人以为 11 个都是出图命令 |
| DESIGN M6「`runall.bat` / `BpBatch.exe`」 | 两者**都不存在**；`batch/` 目录也没建。当前多 DWG 只能手写循环调 `accoreconsole`（README 路线图已如实说"待办"） |
| DESIGN M8「net8 双产物 `BPPlot-net8.dll`」 | 不存在；无 `#if ACAD_NET8`、无 `build_net8.cmd`、无 ObjectARX 2025 SDK 引用 |

**处置原则**：改到上述任一处时，以代码为准修正文档表述；不要为了让文档"看起来对"去改代码。

---

## 9. 保密与敏感数据

- **真实客户图纸、出图成果、真实工程日志一律不入库**。`.gitignore` 已排除 `test/real.dwg`、`test/out_real/`、`test/out_fix_real/`、`test/real_fix.log`、`test/real_plot.log`、`test/run_test.log`、`test/diag_real.log`、`test/diag_report.txt`——**不要删除这些排除项**。
- ⚠️ **已入库的 `test/*.log` 含原作者绝对路径**（`C:\Users\hwdem\.zcode\workspace\default\batchplot-plugin\...`），实测 `fixtest.log` / `merge.log` / `s150.log` / `s1000.log` / `t12.log` 五份都有。目前不含客户工程名，属低敏感，但：
  - **新增运行日志不要入库**；
  - 若要清理，改这些文件时顺手去掉路径行，或把 `test/*.log` 加入 `.gitignore` 并 `git rm --cached`。
- 公开仓库里的工程名必须泛化（历史已做过一次脱敏，见 commit `0b6c49a`）。新增文档/截图不得出现客户名称、项目名、内部路径。
- 截图（`test/menu_proof.png`、`test/preview_proof.png`）属回归证据，入库前确认画面里没有客户图纸内容。
- 本仓库无 API Key / 凭据。若将来引入（如 pc3 服务），**只放本机 `.env`，不入库、不打印、不写日志**。

---

## 10. 工作流

### 10.1 开工前

1. 判定任务类型：`fix / feat / refactor / docs / chore / test`。
2. 读现有实现与 `docs/DESIGN.md` 对应条目，确认该能力是否已在分期计划中、属于哪期。
3. 判定改动面：出图管线 / 对话框 / 菜单 / 部署 / 文档 / 测试资产。
4. 判定是否命中高危区（**必须额外小心**）：
   - `CropPdf` 的旋转变换（实测标定值）
   - `BuildPage` 的选纸与比例逻辑（`PickMedia` / `TryStdScaleType` / `SetCustomPrintScale` 分支）
   - `PlotFrames2` 的三阶段顺序与 `pages[]` 下标
   - `App.Initialize` 的 accoreconsole/GUI 分支
   - `install.ps1` 的注册表写入与 `$commands`
   - `BpMenu` 的菜单宏字符串
   - `DropContained`（`BPPREVIEW` 依赖它的排序副作用）
   - `BPConfig` 的解析/保存（无 schema 版本，坏配置静默回退）
   - 任何"改系统变量"的地方（恢复是否成对）
5. 只做与当前任务直接相关的最小改动，不顺手夹带重构。

### 10.1.1 顺手清理窗口（只在这些时候动）

以下问题已确认存在但**不属于任何当前任务**，不要主动夹带；等碰到相关模块或用户点名时再改：

| 位置 | 问题 | 优先级 |
|---|---|---|
| `BpForm.cs` 列 `SortMode` | **未设 `NotSortable`，点表头排序会导致图框与行错位（静默错图）** | 🔴 高 |
| `Run()` | 未保存图纸时 `Path.GetDirectoryName("")` 抛异常，应改用 `DefaultOutDir()` | 🟡 中 |
| `PlotFrames2` 合并日志 | 成功路径报 `todo.Count` 而非实际合并页数，且不输出 `mergeErr` | 🟡 中 |
| `BpForm.PaperPreview`/`UpdatePaper` | 非法比例输入后 `catch {}` 静默，纸张列显示陈旧值无提示 | 🟡 中 |
| `BPLOTAUTO`/`BP1` | 读 `USERS2` 未 `.Trim()`（其余命令都 Trim 了） | 🟢 低 |
| `BpLayouts` | `BACKGROUNDPLOT` 恢复在方法末尾而非 `finally`，异常路径会漏 | 🟢 低 |
| `CropPdf` | `File.Delete(file)` 后 `File.Move(tmp,file)`，Move 失败则**成品被删只剩 `.crop.pdf`**；失败提示只提 PdfSharp 不覆盖此情形 | 🟢 低 |
| `.gitattributes` | `*.scr text` 缺 `eol=crlf` | 🟢 低 |
| `.gitignore` | 未排除 `.idea/`、`.omc/`、`*.orig.pdf` | 🟢 低 |
| `.zcodeignore` 同步段 | 比 `.gitignore` **少最后 3 行**（`# AutoCAD 锁文件` / `*.dwl` / `*.dwl2`）——ZCode 下锁文件不会被忽略 | 🟢 低 |
| `build_diag.cmd` | 第 2 行硬编码 `cd /d C:\Users\hwdem\...` | 🟢 低 |
| `test/*.cmd`、`*.ps1`、`*.scr` | 86 处原作者绝对路径 | 🟢 低 |
| 仓库 URL | `origin`(`HeWenbin-bobo`) 与文档/`BPHELP`(`hwdemtv`) 不一致 | 🟡 中 |
| `CLAUDE.md~HEAD` | 别项目备份文件，应删 | 🟢 低 |
| `test/out_fix/*.pdf.orig.pdf` | 中间件入库（有用但非回归基线），建议加 `.gitignore` 规则 | 🟢 低 |
| 源码空 `catch` | `src/BPPlot.cs` 32 处、`BpDiag.cs` 4、`BpForm.cs` 3、`BpMenu.cs` 3。多数是"系统变量/清理/日志"合理兜底，但**新增空 catch 必须在注释里写明为什么可以吞**，否则按"失败必须可见"违规处理 | 🟡 中 |

### 10.2 提交规范

- 标题 `<type>: <中文描述>`，type 取 `feat`/`fix`/`refactor`/`docs`/`chore`/`test`/`perf`/`ci`。
- 正文分块说明**用户可感知的变化**（能做什么新事、修了什么症状），不写"修复若干问题"。
- **不添加 `Co-Authored-By` 或其他工具署名**（本仓库历史保持此约定）。
- 源码改动与对应 DLL / zip 产物**同批提交**，不要出现"源码已改但 DLL 是旧的"状态。
- 提交前 `git status` 抽查暂存清单。当前忽略状态：`.idea/workspace.xml` 由 `.idea/.gitignore` 忽略、`.remember/` 全忽略；但**根目录 `.gitignore` 并未排除 `.idea/` 与 `.omc/`**（实测 `git status` 会出现 `?? .idea/misc.xml`、`?? .omc/project-memory.json`）。这两类是本机 IDE / 工具状态，**不要提交**；必要时先补 `.gitignore` 规则再 `git add`。

### 10.3 交付格式

```
改了什么
为什么这么改
验证情况（构建/无头回归/GUI 实测，分别列明）
未验证项（含原因，如"本机无 AutoCAD 2023 编译环境"）
风险点
回滚方式
```

`docs` 类任务可写 `Docs only, tests not run`，但必须说明是否核对了命令名、路径、版本号。

---

## 11. AI 协作资产治理

- **`AGENTS.md` 是本仓库 AI 协作规则的唯一真源。**
- `CLAUDE.md` 是**单行指针文件**，内容恒为 `AGENTS.md`（9 字节，无换行）。本机 `core.symlinks=false`，所以它不是软链接——**不要试图把它改成软链接**，保持纯文本指针。
- `CLAUDE.md~HEAD` 是编辑器/工具留下的历史备份，内容属于另一项目，**应删除，不要作为规则参考**。
- 目前无 `.github/`（无 CI、无 Copilot 指令）。若将来新增 agent 专用目录或镜像文件，必须先明确单一真源，再用脚本同步；禁止手工长期维护多份同义内容。

---

## 12. 长会话纪律

- 写大文件前先在脑中过一遍完整内容再落笔；出现乱码、重复、语言混杂立即停止，用 `git checkout -- <file>` 恢复，改小块 `Edit` 逐段应用。
- 每次 Write/Edit 大文件后用 `git diff` 人工核对。`src/BPPlot.cs` 已近 2000 行，**优先小块 Edit，不要整文件重写**。
- 中文文本编辑后确认编码未被破坏（`.cmd`/`.txt` 应为 GBK，`.cs`/`.md` 应为 UTF-8）。

---

## 13. 探索模式

**触发**：用户说"进入探索模式"/"进入检查模式"或语义等价表述。

**任务定义**：检查插件是否存在需修复的缺陷或值得补的功能，自主实施后做端到端验证，循环直到无新发现。范围限定在当前已支持能力内（签名/印章库、实体打印机、多 DWG 遍历属计划中或不做，不算缺陷）。

**执行要点**：

1. **先扫描**：列缺陷清单（裁切/旋转错位、失败不可见、超时缺失、系统变量未恢复、C# 5 语法越界、注册表/菜单不同步）与功能缺口（DESIGN.md 已排期项优先）。
2. **无头回归优先**：`.scr` 脚本可全自动、可重复、有 PDF 产物可量化比对（页尺寸、墨迹 bbox）。
3. **GUI 必须真点**：菜单项、对话框勾选、预览窗口开关，用 `test/*.ps1` COM 注入模式实跑，**截图看渲染**，纯读代码不算测试。
4. **修完即回归全绿才算关闭**；先复现取证（留 `BPPLOT_KEEP_ORIG=1` 中间 PDF / 日志 / 截图）再改。
5. **一轮修完换角度再扫**（未测命令、边界图幅、极端比例、并发/重复 NETLOAD），连续一轮无新发现才收尾。
6. **产出**：发现清单、修复清单、未验证边界（尤其"本机缺 AutoCAD 2023 编译环境"这类）、可复用经验写入记忆。
