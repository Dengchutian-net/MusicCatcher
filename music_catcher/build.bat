@echo off
REM Music Catcher 打包脚本
REM 需要先安装: pip install pyinstaller

echo === Music Catcher 打包 ===
echo.

REM 安装依赖
echo [1/2] 安装依赖...
pip install -r requirements.txt
pip install pyinstaller

REM 打包
echo.
echo [2/2] 打包为 exe...
pyinstaller --noconfirm --onefile --windowed ^
    --name "MusicCatcher" ^
    --add-data "app;app" ^
    --add-data "engine;engine" ^
    --hidden-import "yt_dlp" ^
    --hidden-import "pyaudiowpatch" ^
    --hidden-import "mutagen" ^
    --hidden-import "numpy" ^
    main.py

echo.
echo === 打包完成 ===
echo 输出文件: dist\MusicCatcher.exe
pause
