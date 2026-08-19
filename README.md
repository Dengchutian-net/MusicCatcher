# Music Catcher

网页音乐抓取工具 — 从任意网站提取音乐并保存为本地音频文件。

## 功能

- **链接下载** — 粘贴 B站 / YouTube / 网易云 等链接，一键下载为 MP3/FLAC/WAV
- **系统录音** — 录制电脑正在播放的任何声音（WASAPI Loopback），适合无法直接下载的场景
- **格式转换** — 支持 MP3、FLAC、WAV、AAC、OGG 多种格式，可选 128/192/256/320kbps 音质
- **一键安装** — 提供 Windows 安装程序，自动部署 FFmpeg 依赖

## 技术栈

| 组件 | 技术 |
|------|------|
| 下载引擎 | [yt-dlp](https://github.com/yt-dlp/yt-dlp)（支持 1000+ 网站） |
| 系统录音 | [pyaudiowpatch](https://github.com/s0d3s/pyaudiowpatch)（WASAPI Loopback） |
| 音频转码 | [FFmpeg](https://ffmpeg.org/) |
| 界面 | PySide6（Qt for Python） |
| 打包 | PyInstaller + Inno Setup |

## 快速开始

### 直接运行

```bash
# 安装依赖
pip install -r music_catcher/requirements.txt

# 运行
python music_catcher/main.py
```

> 需要安装 [FFmpeg](https://ffmpeg.org/download.html) 并添加到 PATH。

### 使用安装程序

1. 下载 `MusicCatcherSetup.exe`
2. 双击安装，自动下载 FFmpeg
3. 桌面快捷方式启动

### 自己打包安装程序

```bash
# 安装 Inno Setup 6: https://jrsoftware.org/isinfo.php
# 然后运行
installer/build_installer.bat
```

## 项目结构

```
music_catcher/              主程序
├── main.py                 入口
├── app/                    界面层
│   ├── window.py           主窗口
│   ├── download_tab.py     下载页
│   ├── record_tab.py       录制页
│   └── settings_tab.py     设置页
├── engine/                 引擎层
│   ├── downloader.py       yt-dlp 封装
│   └── recorder.py         WASAPI 录制封装
└── requirements.txt

installer/                  安装程序（独立于主程序）
├── build_installer.bat     一键构建脚本
├── setup.iss               Inno Setup 脚本
└── download_ffmpeg.ps1     FFmpeg 下载脚本
```

## 系统要求

- Windows 10 / 11（64 位）
- Python 3.10+（直接运行时）
- 网络连接（下载音乐 / 安装时下载 FFmpeg）

## 许可证

MIT License
