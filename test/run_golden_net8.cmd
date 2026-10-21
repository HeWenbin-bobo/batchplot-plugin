@echo off
rem ===========================================================================
rem BPPlot - golden page-size regression (AutoCAD 2025 / net8)
rem
rem Runs test\fixtures\content.dwg (3 frames with content, 1:100) and checks
rem every produced PDF page size in mm against the golden values below.
rem
rem   Sheet001.pdf  1189.0 x 845.7
rem   Sheet002.pdf   594.1 x 841.0   (rot=90 transposed)
rem   Sheet003.pdf   841.0 x 594.0
rem
rem Why /MediaBox only: CSV "OK" and log "[crop]" lines both lie. See
rem AGENTS.md 5.5 -- only the PDF /MediaBox proves the crop really happened.
rem
rem Prereq : build_net8.cmd at repo root
rem Usage  : test\run_golden_net8.cmd
rem Env    : ACAD_DIR (default D:\Program Files\Autodesk\AutoCAD 2025)
rem ===========================================================================
setlocal

set "ROOT=%~dp0.."
set "SRC=%ROOT%\build\bin\Release\net8.0-windows"
set "W=%~dp0_golden"

if "%ACAD_DIR%"=="" set "ACAD_DIR=D:\Program Files\Autodesk\AutoCAD 2025"
set "ACC=%ACAD_DIR%\accoreconsole.exe"

if not exist "%ACC%" (
  echo FAIL: accoreconsole not found: %ACC%
  echo       set ACAD_DIR=^<AutoCAD install dir^> then retry
  exit /b 1
)
if not exist "%SRC%\BPPlot.dll" (
  echo FAIL: %SRC%\BPPlot.dll not found
  echo       run build_net8.cmd at repo root first
  exit /b 1
)

if exist "%W%" rmdir /s /q "%W%"
mkdir "%W%"
mkdir "%W%\out"
copy /y "%SRC%\*.dll" "%W%\" >nul
copy /y "%~dp0fixtures\content.dwg" "%W%\" >nul

rem accoreconsole wants forward slashes inside the script
set "P=%W:\=/%"

rem USERS2 must be set AFTER netload, otherwise App.Initialize takes the
rem "console load = plot now" branch (AGENTS.md pitfall #27).
> "%W%\a.scr" echo (setvar "secureload" 0)
>>"%W%\a.scr" echo (setvar "filedia" 0)
>>"%W%\a.scr" echo (setvar "users1" "100")
>>"%W%\a.scr" echo (setvar "users2" "")
>>"%W%\a.scr" echo (command "_.netload" "%P%/BPPlot.dll")
>>"%W%\a.scr" echo (setvar "users2" "%P%/out")
>>"%W%\a.scr" echo BPLOTAUTO
>>"%W%\a.scr" echo _.quit _y

> "%W%\a.cmd" echo @echo off
>>"%W%\a.cmd" echo "%ACC%" /i "%W%\content.dwg" /s "%W%\a.scr" ^> "%W%\a.log" 2^>^&1

pushd "%W%"
cmd /c a.cmd >nul 2>&1
popd

echo === golden page-size regression (3 frames @ 1:100) ===
python "%~dp0golden_check.py" "%W%\out" 1189.0x845.7 594.1x841.0 841.0x594.0
if errorlevel 1 (
  echo FAIL: page sizes differ from golden baseline, see %W%\a.log
  exit /b 1
)
echo OK: all matched
exit /b 0
