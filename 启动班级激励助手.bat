@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"
title 班级激励助手 - 源码启动器

rem ============================================================
rem  班级激励助手 · 源码启动器
rem  双击本文件即可从源码运行程序。
rem  首次运行若缺少 PyQt5，会自动用国内镜像安装。
rem ============================================================

rem ---- 第一步：定位可用的 Python 3（真实安装，自动跳过微软商店假 python）----
set "PY="

rem 1) 优先 py 启动器（永远指向真实安装的 Python）
where py >nul 2>&1
if not errorlevel 1 (
    py -3 -c "import sys" >nul 2>&1
    if not errorlevel 1 set "PY=py -3"
)

rem 2) 其次 python 命令（微软商店占位符运行失败会自动跳过）
if not defined PY (
    where python >nul 2>&1
    if not errorlevel 1 (
        python -c "import sys" >nul 2>&1
        if not errorlevel 1 set "PY=python"
    )
)

rem 3) 兜底：常见安装目录
if not defined PY (
    for %%P in (
        "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
        "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
        "C:\Python313\python.exe"
        "C:\Python312\python.exe"
        "C:\Python311\python.exe"
        "C:\Python310\python.exe"
    ) do (
        if exist "%%~P" set "PY=%%~P"
    )
)

if not defined PY (
    echo [错误] 未找到 Python 3，请先安装 Python 并勾选 "Add to PATH"。
    echo 下载地址：https://www.python.org/downloads/
    echo.
    pause
    exit /b 1
)

echo 使用 Python：%PY%

rem ---- 第二步：检查 PySide6，缺失则自动安装（国内镜像）----
%PY% -c "import PySide6" >nul 2>&1
if errorlevel 1 (
    echo 首次运行：正在安装依赖 PySide6 ...
    %PY% -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
    if errorlevel 1 (
        echo.
        echo [错误] 依赖安装失败，请联网后重试。
        echo 也可以手动执行： %PY% -m pip install PySide6
        echo.
        pause
        exit /b 1
    )
    echo 依赖安装完成。
    echo.
)

rem ---- 第三步：启动程序 ----
echo 正在启动 班级激励助手 ...
echo （若出现黑色窗口，是正常的，请最小化它，不要关闭）
echo.
%PY% main.py

echo.
echo 程序已退出。
pause
exit /b 0
