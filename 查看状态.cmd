@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Capy 中文补丁 - 查看状态
if not exist "%~dp0CapyZhPatch.ps1" (
    echo 安装文件不完整，请先完整解压压缩包。
    set "RESULT=2"
    goto :finish
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0CapyZhPatch.ps1" -Action Status %*
set "RESULT=%ERRORLEVEL%"
:finish
echo.
if "%RESULT%"=="0" (
    echo 操作完成。
) else (
    echo 操作未完成，请查看上方中文说明。
)
if /I not "%CAPY_ZH_NO_PAUSE%"=="1" (
    echo 按任意键关闭本窗口。
    pause >nul
)
exit /b %RESULT%
