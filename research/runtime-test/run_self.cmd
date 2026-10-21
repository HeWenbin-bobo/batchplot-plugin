@echo off
set ACC=D:\Program Files\Autodesk\AutoCAD 2025\accoreconsole.exe
"%ACC%" /i "D:\Claude\batchplot-plugin\research\runtime-test\test_dwg.dwg" /s "D:\Claude\batchplot-plugin\research\runtime-test\selftest2.scr" /loadmodule "D:\Claude\batchplot-plugin\research\runtime-test\BPPlotNet8.dll" > "D:\Claude\batchplot-plugin\research\runtime-test\self.log" 2>&1
echo EXIT=%errorlevel%
