@echo off
setlocal

call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"
if errorlevel 1 exit /b 1

set "BENCH_DIR=%~dp0"
set "OUT_DIR=%BENCH_DIR%Win64\Release"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

dcc64 -B -Q -TX.exe -E"%OUT_DIR%" -N0"%OUT_DIR%" -NU"%OUT_DIR%" "%BENCH_DIR%SerifDrawTextRenderBenchmark.dpr"
if errorlevel 1 exit /b 1

copy /Y "%BDS%\bin64\sk4d.dll" "%OUT_DIR%\sk4d.dll" >nul
if errorlevel 1 exit /b 1

"%OUT_DIR%\SerifDrawTextRenderBenchmark.exe"
exit /b %errorlevel%
