@echo off
rem ===========================================================================
rem BPPlot - AutoCAD 2025+ (net8.0-windows) build
rem
rem Output : build\bin\Release\net8.0-windows\BPPlot.dll
rem          + PdfSharp 6.x and its dependencies (13 DLLs total)
rem
rem Override AutoCAD version:
rem   set ACAD_DIR=D:\Program Files\Autodesk\AutoCAD 2026
rem   build_net8.cmd
rem
rem Prereq: .NET SDK 8.0+ (10.x can target 8.0)
rem vs build.cmd : build.cmd uses csc / .NET Framework, covers AutoCAD 2013-2024
rem                this script uses dotnet / net8.0,      covers AutoCAD 2025+
rem ===========================================================================
setlocal
cd /d "%~dp0"

if "%ACAD_DIR%"=="" set ACAD_DIR=D:\Program Files\Autodesk\AutoCAD 2025

if not exist "%ACAD_DIR%\acmgd.dll" (
  echo BUILD FAILED: AutoCAD SDK not found at "%ACAD_DIR%"
  echo   set ACAD_DIR=^<AutoCAD install dir^>  then retry
  exit /b 1
)

echo Building BPPlot for net8.0 (AutoCAD 2025+) ...
echo   ACAD_DIR=%ACAD_DIR%

dotnet build build\BPPlotNet8.csproj -c Release -v minimal
if errorlevel 1 (
  echo BUILD FAILED
  exit /b 1
)

echo.
echo BUILD OK: %~dp0build\bin\Release\net8.0-windows\BPPlot.dll
echo.
echo DEPLOYMENT: all DLLs in that folder must be copied together.
echo   PdfSharp.dll + Microsoft.Extensions.*.dll (12 deps)
echo   A missing dependency throws FileNotFoundException at runtime,
echo   which CropPdf swallows - symptom is "crop silently not applied".
