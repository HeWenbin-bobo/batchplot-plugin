@echo off
rem ===========================================================================
rem  BPPlot - assemble release zip (dual artifact: netfx + net8)
rem
rem  Run AFTER build.cmd (netfx) and build_net8.cmd (net8).
rem  Output: BPPlot-v<VER>.zip        full package (both artifacts)
rem          BPPlot-v<VER>-a2025.zip  net8 only, when netfx is unavailable
rem
rem  Layout inside the zip:
rem    BPPlot.bundle/PackageContents.xml
rem    BPPlot.bundle/Contents/netfx/*.dll     A2021-2024, .NET Framework
rem    BPPlot.bundle/Contents/net8/*.dll      A2025+,    .NET 8
rem    bin/netfx/*.dll                        installer source
rem    bin/net8/*.dll
rem    install.ps1 / uninstall.ps1
rem    <install.cmd> / <uninstall.cmd> / <readme.txt>   (Chinese names)
rem
rem  ASCII-only on purpose: the Chinese-named wrapper files are copied by
rem  wildcard enumeration instead of being spelled out, so nobody has to care
rem  about this script's own code page. Keep it that way.
rem
rem  STALE NETFX GUARD
rem  The netfx artifact (root BPPlot.dll) can only be built on a machine that
rem  has AutoCAD 2021-2024 installed - i.e. NOT on a 2025-only box. Shipping a
rem  stale netfx DLL beside a fresh net8 DLL would silently hand 2021-2024 users
rem  the old bugs (BPL crash / engine leak / wrong-frame plotting).
rem  We therefore probe the netfx DLL for a marker that only exists in current
rem  source:
rem      ReleaseEngine   - the engine-release helper added by the 5-defect fix
rem  If required, netfx is dropped and the package becomes 2025-only.
rem  Override with BPPLOT_ALLOW_STALE_NETFX=1 only if you knowingly want a
rem  mixed-vintage package (e.g. reproducing a historical bug report).
rem ===========================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

set VER=0.8
set STAGE=%TEMP%\bpplot_bundle_stage
set MARKER=ReleaseEngine
set MFEXE=%~dp0marker_check.ps1

set NETFX=%1
if "%NETFX%"=="" set NETFX=..\BPPlot.dll

set NET8DIR=%2
if "%NET8DIR%"=="" set NET8DIR=..\build\bin\Release\net8.0-windows

rem ---- preflight -----------------------------------------------------------
if not exist "%NET8DIR%\BPPlot.dll" goto :nonet8

rem ---- net8 sanity: all 13 DLLs must ship together -------------------------
set N8=0
for %%f in ("%NET8DIR%\*.dll") do set /a N8+=1
if %N8% LSS 13 (
  echo FAIL: net8 payload has only %N8% DLLs, expected ^>=13
  echo       PdfSharp 6.x needs its Microsoft.Extensions.* dependencies, or
  echo       PdfDocument constructor throws FileNotFoundException at runtime.
  goto :fail
)

rem ---- decide whether netfx takes part ------------------------------------
set INCLUDENETFX=1
if not exist "%NETFX%"          set INCLUDENETFX=0
if not exist "..\PdfSharp.dll"  set INCLUDENETFX=0

if "%INCLUDENETFX%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%MFEXE%" "%NETFX%" %MARKER% >nul 2>&1
  if errorlevel 1 (
    if not "%BPPLOT_ALLOW_STALE_NETFX%"=="1" (
      echo.
      echo WARNING: netfx artifact is STALE - it lacks '%MARKER%'.
      echo          %NETFX%
      echo          It predates the 5-defect fix, so 2021-2024 would keep the
      echo          old bugs ^(BPL crash / engine leak / wrong-frame plotting^).
      echo          Dropping netfx: this package will be AutoCAD 2025+ only.
      echo          For a full package, run build.cmd on a machine that has
      echo          AutoCAD 2021-2024 installed, then re-run this script.
      echo          Override with: set BPPLOT_ALLOW_STALE_NETFX=1
      echo.
      set INCLUDENETFX=0
    ) else (
      echo WARNING: shipping STALE netfx anyway ^(BPPLOT_ALLOW_STALE_NETFX=1^)
    )
  ) else (
    echo netfx artifact OK ^(contains '%MARKER%'^)
  )
) else (
  echo netfx artifact absent - building a 2025-only package
)

rem ---- stage --------------------------------------------------------------
rd /s /q "%STAGE%" 2>nul
mkdir "%STAGE%\BPPlot.bundle\Contents\net8" || goto :fail
mkdir "%STAGE%\bin\net8" || goto :fail

copy /y "%NET8DIR%\*.dll" "%STAGE%\BPPlot.bundle\Contents\net8\" >nul || goto :fail
copy /y "%NET8DIR%\*.dll" "%STAGE%\bin\net8\"                     >nul || goto :fail

if "%INCLUDENETFX%"=="1" (
  mkdir "%STAGE%\BPPlot.bundle\Contents\netfx" || goto :fail
  mkdir "%STAGE%\bin\netfx" || goto :fail
  copy /y "%NETFX%"         "%STAGE%\BPPlot.bundle\Contents\netfx\" >nul || goto :fail
  copy /y "..\PdfSharp.dll" "%STAGE%\BPPlot.bundle\Contents\netfx\" >nul || goto :fail
  copy /y "%NETFX%"         "%STAGE%\bin\netfx\"                    >nul || goto :fail
  copy /y "..\PdfSharp.dll" "%STAGE%\bin\netfx\"                    >nul || goto :fail
)

rem Pick the manifest that matches what actually shipped: declaring a netfx
rem component whose directory is absent makes 2021-2024 try to load a missing
rem module.
if "%INCLUDENETFX%"=="1" (
  copy /y "PackageContents.xml"      "%STAGE%\BPPlot.bundle\" >nul || goto :fail
) else (
  copy /y "PackageContents-2025.xml" "%STAGE%\BPPlot.bundle\PackageContents.xml" >nul || goto :fail
)

copy /y "install.ps1"   "%STAGE%\" >nul || goto :fail
copy /y "uninstall.ps1" "%STAGE%\" >nul || goto :fail

rem Chinese-named wrappers and readme, copied by wildcard (see header).
rem Exclude this script and its helper so they never land inside the zip.
for %%f in (*.cmd) do if /i not "%%~nxf"=="make_bundle.cmd" copy /y "%%f" "%STAGE%\" >nul || goto :fail
for %%f in (*.txt) do copy /y "%%f" "%STAGE%\" >nul || goto :fail

rem ---- zip ---------------------------------------------------------------
if "%INCLUDENETFX%"=="1" (
  set ZIPNAME=BPPlot-v%VER%.zip
) else (
  set ZIPNAME=BPPlot-v%VER%-a2025.zip
)

del "%ZIPNAME%" 2>nul
powershell -NoProfile -Command "Compress-Archive -Path '%STAGE%\*' -DestinationPath '%ZIPNAME%' -Force"
if errorlevel 1 goto :fail

echo.
echo BUNDLE ZIP  : %~dp0!ZIPNAME!
echo NET8  DLLs  : %N8%   ^(AutoCAD 2025+^)
if "%INCLUDENETFX%"=="1" (echo NETFX DLLs  : 2    ^(AutoCAD 2021-2024^)) else (echo NETFX DLLs  : none - 2025-only package)
echo STAGE       : %STAGE%
exit /b 0

:nonet8
echo FAIL: net8 artifact not found: %NET8DIR%\BPPlot.dll
echo       run build_net8.cmd at repo root first
exit /b 1

:fail
echo.
echo BUILD BUNDLE FAILED
exit /b 1
