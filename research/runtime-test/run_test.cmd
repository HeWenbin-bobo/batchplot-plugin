@echo off
set ACC=D:\Program Files\Autodesk\AutoCAD 2025\accoreconsole.exe
"%ACC%" /i "D:\Claude\batchplot-plugin\research\runtime-test\test_dwg.dwg" /s "D:\Claude\batchplot-plugin\research\runtime-test\marker.scr" > "D:\Claude\batchplot-plugin\research\runtime-test\m.log" 2>&1
echo EXIT=%errorlevel%
