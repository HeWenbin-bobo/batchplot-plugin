# BPPlot uninstaller
#
# 移除本项目写入的一切，不碰别人的东西：
#   - HKCU 下所有 ACAD 版本里的 Applications\BPPlot 键（按需加载）
#   - %APPDATA%\BPPlot\bin（两套产物）
#   - %APPDATA%\Autodesk\ApplicationPlugins\BPPlot.bundle（若曾放置）
#
# 刻意保留：%APPDATA%\BPPlot\config.json（用户学习到的图框块名/属性标签）。
# 用户重装后不用重新 BPTEACH。要彻底清干净请手工删该文件。

$ErrorActionPreference = 'Continue'

$removed = 0

Write-Output "1/2 移除按需加载注册表 ..."
$root = 'HKCU:\Software\Autodesk\AutoCAD'
if (Test-Path $root) {
  foreach ($rel in Get-ChildItem $root) {
    foreach ($prod in Get-ChildItem $rel.PSPath) {
      $appKey = $prod.PSPath + '\Applications\BPPlot'
      if (Test-Path $appKey) {
        Remove-Item $appKey -Recurse -Force
        Write-Output ("  removed " + $rel.PSChildName + " / " + $prod.PSChildName)
        $removed++
      }
    }
  }
}
if ($removed -eq 0) { Write-Output "  （注册表里没有 BPPlot 项，可能已卸载）" }

Write-Output "2/2 删除程序文件 ..."
$paths = @(
  "$env:APPDATA\BPPlot\bin",
  "$env:APPDATA\Autodesk\ApplicationPlugins\BPPlot.bundle"
)
foreach ($p in $paths) {
  if (Test-Path $p) {
    Remove-Item $p -Recurse -Force
    Write-Output ("  removed " + $p)
  }
}

$cfg = "$env:APPDATA\BPPlot\config.json"
if (Test-Path $cfg) {
  Write-Output ""
  Write-Output ("保留 " + $cfg + "（图框学习记录，重装后免于重新 BPTEACH）")
  Write-Output "如需彻底清除，手工删除该文件即可。"
}

Write-Output ""
Write-Output "卸载完成。重启 AutoCAD 后生效。"
exit 0
