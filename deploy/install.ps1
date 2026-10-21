# BPPlot installer
#
# 双产物部署：
#   AutoCAD 2021-2024  ->  bin\netfx\    (.NET Framework 4.x, 2 个 DLL)
#   AutoCAD 2025+      ->  bin\net8\     (.NET 8.0,          13 个 DLL)
#
# 为什么不能只装一份：2025 起 ObjectARX 托管程序集改成 .NET 8，与 Framework
# 产物不兼容。Framework 产物在 2025 上能被 NETLOAD 接受，但 PdfSharp 1.x 读不了
# 2025 打印引擎的 PDF，裁切/合并静默失效（页尺寸停在整张纸，日志仍全 OK）。
#
# 按需加载注册表（HKCU，MSteel 同款机制）：每个已安装的 AutoCAD 版本各写一份，
# LOADER 指向该版本对应的那份产物。LOADCTRLS=2 表示"命令被调用时才加载"。
#
# 失败不静默：任何一步没做成都会累计到 $errors，最后以非 0 退出码收尾，
# 避免用户看到"安装完成"却发现插件没生效。

$ErrorActionPreference = 'Continue'

$src     = Split-Path -Parent $MyInvocation.MyCommand.Path
$binRoot = "$env:APPDATA\BPPlot\bin"
$netfxSrc = "$src\bin\netfx"
$net8Src  = "$src\bin\net8"

$errors = New-Object System.Collections.ArrayList

function Note($msg) { Write-Output $msg }
function Fail($msg) { [void]$errors.Add($msg); Write-Output ("  [ERR] " + $msg) }

# ---------------------------------------------------------------- 1) 复制程序
Note "1/3 复制程序到 $binRoot ..."

if (-not (Test-Path "$netfxSrc\BPPlot.dll") -and -not (Test-Path "$net8Src\BPPlot.dll")) {
  Note "  [FATAL] zip 内既没有 bin\netfx\ 也没有 bin\net8\，安装包不完整"
  exit 1
}

New-Item -ItemType Directory -Force -Path $binRoot | Out-Null

$hasNetfx = Test-Path "$netfxSrc\BPPlot.dll"
$hasNet8  = Test-Path "$net8Src\BPPlot.dll"

if ($hasNetfx) {
  $d = "$binRoot\netfx"
  New-Item -ItemType Directory -Force -Path $d | Out-Null
  Copy-Item "$netfxSrc\*" $d -Force
  Note ("  netfx  " + (@(Get-ChildItem $d -Filter *.dll).Count) + " 个 DLL -> $d")
} else {
  Note "  netfx  缺失（本包不支持 2021-2024）"
}

if ($hasNet8) {
  $d = "$binRoot\net8"
  New-Item -ItemType Directory -Force -Path $d | Out-Null
  Copy-Item "$net8Src\*" $d -Force
  $n = @(Get-ChildItem $d -Filter *.dll).Count
  Note ("  net8   " + $n + " 个 DLL -> $d")
  # 13 个是当前基线：BPPlot + PdfSharp 6.1.1 + 6 个 Microsoft.Extensions.*
  # + 5 个 PdfSharp.* 附属程序集。少于这个数说明打包漏了依赖。
  if ($n -lt 13) { Fail ("net8 产物只有 $n 个 DLL，期望 >=13（缺依赖会在运行时抛 FileNotFoundException）") }
} else {
  Note "  net8   缺失（本包不支持 2025+）"
}

# ------------------------------------------------- 2) 写按需加载注册表（HKCU）
Note "2/3 写入按需加载注册表（HKCU，逐版本匹配产物）..."

# AutoCAD 版本号 -> 产物目录
function Pick-Variant($series) {
  # R25.0 起是 .NET 8；R24.x 及更早是 .NET Framework
  if ($series -match '^R(\d+)\.' ) {
    $major = [int]$Matches[1]
    if ($major -ge 25) { return 'net8' }
  }
  return 'netfx'
}

$commands = @('BPLOT','BPLOTAUTO','BP1','BPPREVIEW','BPLOTMERGE','BPL','BPSPLIT','BPTEACH','BPREV','BPSELFTEST','BPHELP','BPABOUT')
$root = 'HKCU:\Software\Autodesk\AutoCAD'
$written = 0
$skipped = New-Object System.Collections.ArrayList

if (Test-Path $root) {
  foreach ($rel in Get-ChildItem $root) {                       # R24.0 / R25.0 / ...
    foreach ($prod in Get-ChildItem $rel.PSPath) {              # ACAD-xxxx:lang
      $variant = Pick-Variant $rel.PSChildName
      $loader  = "$binRoot\$variant\BPPlot.dll"

      if (-not (Test-Path $loader)) {
        [void]$skipped.Add($rel.PSChildName + " (需要 " + $variant + " 产物，本包未包含)")
        continue
      }

      $appKey = $prod.PSPath + '\Applications\BPPlot'
      New-Item -Path $appKey -Force | Out-Null
      New-ItemProperty -Path $appKey -Name 'DESCRIPTION' -Value 'BPPlot batch plot' -PropertyType String -Force | Out-Null
      New-ItemProperty -Path $appKey -Name 'LOADCTRLS'  -Value 0x2 -PropertyType DWord -Force | Out-Null
      New-ItemProperty -Path $appKey -Name 'MANAGED'    -Value 1    -PropertyType DWord -Force | Out-Null
      New-ItemProperty -Path $appKey -Name 'LOADER'     -Value $loader -PropertyType String -Force | Out-Null

      $cmdsKey = $appKey + '\COMMANDS'
      New-Item -Path $cmdsKey -Force | Out-Null
      foreach ($c in $commands) {
        New-ItemProperty -Path $cmdsKey -Name $c -Value $c -PropertyType String -Force | Out-Null
      }

      $written++
      Note ("  " + $rel.PSChildName + " / " + $prod.PSChildName + " -> " + $variant)
    }
  }
}

if ($written -eq 0) {
  Note "  未找到可安装的 AutoCAD 版本（本机未装或非标准布局）"
  Fail "按需加载注册表一项都没写入"
}
foreach ($s in $skipped) { Note ("  跳过 " + $s) }

# ------------------------------------------- 3) bundle 双保险（标准构建上生效）
# 注意：本机构建（24.2s LMS Tech）实测不支持 ApplicationPlugins 自动加载，
# 主路径始终是上面的注册表；bundle 只是给标准 Autodesk 构建的兜底。
$bundleDest = "$env:APPDATA\Autodesk\ApplicationPlugins\BPPlot.bundle"
if (Test-Path "$src\BPPlot.bundle") {
  Note "3/3 另放置 ApplicationPlugins bundle（标准构建备用）..."
  Copy-Item "$src\BPPlot.bundle" $bundleDest -Recurse -Force
  if (-not (Test-Path "$bundleDest\PackageContents.xml")) { Fail "bundle 复制后缺 PackageContents.xml" }
} else {
  Note "3/3 本包未含 bundle（仅注册表加载）"
}

# ---------------------------------------------------------------- 收尾
Write-Output ""
if ($errors.Count -gt 0) {
  Write-Output ("安装完成但有问题，共 " + $errors.Count + " 项：")
  foreach ($e in $errors) { Write-Output ("  - " + $e) }
  Write-Output ""
  Write-Output "插件可能无法正常工作。请把以上内容反馈给作者。"
  exit 2
}

Write-Output ("安装成功（已为 " + $written + " 个 AutoCAD 产品项写入按需加载）。")
Write-Output "请完全退出并重新启动 AutoCAD："
Write-Output "  - 启动后菜单栏出现「BP-批量打印」（如未显示，命令行执行 MENUBAR 输入 1）"
Write-Output "  - 命令行输入 BPLOT / BPLOTAUTO / BPPREVIEW 等可直接执行，无需 NETLOAD"
Write-Output "  - 首次使用前建议先跑 BPSELFTEST 确认 PdfSharp 依赖齐全"
exit 0
