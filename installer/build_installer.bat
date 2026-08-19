@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo ╔══════════════════════════════════════════════╗
echo ║       Music Catcher 安装程序构建工具         ║
echo ╚══════════════════════════════════════════════╝
echo.

REM ── 路径设置 ──
set "PROJECT_DIR=%~dp0..\music_catcher"
set "INSTALLER_DIR=%~dp0"
set "DIST_DIR=%~dp0..\dist"

REM ── Step 1: 检查依赖 ──
echo [1/4] 检查依赖...

python --version >nul 2>&1
if errorlevel 1 (
    echo ✗ 未找到 Python，请先安装 Python 3.10+
    pause
    exit /b 1
)

pip show pyinstaller >nul 2>&1
if errorlevel 1 (
    echo   安装 PyInstaller...
    pip install pyinstaller
)

REM 检查 Inno Setup
set "ISCC="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
)
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
)
if "%ISCC%"=="" (
    echo ✗ 未找到 Inno Setup 6
    echo   请下载安装: https://jrsoftware.org/isinfo.php
    echo   安装后重新运行此脚本
    pause
    exit /b 1
)
echo   ✓ Python
echo   ✓ PyInstaller
echo   ✓ Inno Setup 6

REM ── Step 2: 安装项目依赖 ──
echo.
echo [2/4] 安装项目依赖...
cd /d "%PROJECT_DIR%"
pip install -r requirements.txt -q

REM ── Step 3: PyInstaller 打包 ──
echo.
echo [3/4] 打包主程序...
cd /d "%PROJECT_DIR%"

pyinstaller --noconfirm --onefile --windowed ^
    --name "MusicCatcher" ^
    --add-data "app;app" ^
    --add-data "engine;engine" ^
    --hidden-import "yt_dlp" ^
    --hidden-import "pyaudiowpatch" ^
    --hidden-import "mutagen" ^
    --hidden-import "numpy" ^
    main.py

if errorlevel 1 (
    echo ✗ PyInstaller 打包失败
    pause
    exit /b 1
)
echo   ✓ MusicCatcher.exe 已生成

REM ── Step 4: 编译安装程序 ──
echo.
echo [4/4] 编译安装程序...
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
"%ISCC%" /O"%DIST_DIR%" "%INSTALLER_DIR%setup.iss"

if errorlevel 1 (
    echo ✗ Inno Setup 编译失败
    pause
    exit /b 1
)

echo.
echo ╔══════════════════════════════════════════════╗
echo ║  ✅ 构建完成！                               ║
echo ║                                              ║
echo ║  安装包位置: dist\MusicCatcherSetup.exe      ║
echo ║                                              ║
echo ║  将此文件发给别人即可一键安装                ║
echo ╚══════════════════════════════════════════════╝
echo.
pause
