# 探测 DLL 里是否含指定标记（ASCII，出现在 #Strings 堆里的方法名）。
# 用法: powershell -File marker_check.ps1 <dll> <marker>
# 退出码: 0 = 含, 1 = 不含或文件不存在
#
# 为什么不直接用 Select-String：它在 Windows PowerShell 5.1 的 -Encoding 参数
# 不接受 Byte，会直接报错。ReadAllBytes + ASCII 解码最稳，且对大文件也够快。

param(
  [Parameter(Mandatory=$true)][string]$Path,
  [Parameter(Mandatory=$true)][string]$Marker
)

if (-not (Test-Path $Path)) { exit 1 }

try {
  $bytes = [IO.File]::ReadAllBytes((Resolve-Path $Path).Path)
  $text  = [Text.Encoding]::ASCII.GetString($bytes)
  if ($text.Contains($Marker)) { exit 0 } else { exit 1 }
} catch {
  exit 1
}
