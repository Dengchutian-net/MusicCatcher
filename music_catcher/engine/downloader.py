"""yt-dlp 下载引擎，封装为 QThread 供 GUI 异步调用。"""

import os
import glob
import shutil
import yt_dlp
from PySide6.QtCore import QThread, Signal


def _find_ffmpeg() -> str | None:
    """自动查找 ffmpeg 路径。"""
    import sys
    # 1. exe 同级目录的 ffmpeg/ 子目录（安装程序部署的位置）
    if getattr(sys, "frozen", False):
        base = os.path.dirname(sys.executable)
    else:
        base = os.path.dirname(os.path.abspath(__file__))
    local = os.path.join(base, "ffmpeg")
    if os.path.isfile(os.path.join(local, "ffmpeg.exe")):
        return local
    local2 = os.path.join(base, "..", "ffmpeg")
    if os.path.isfile(os.path.join(local2, "ffmpeg.exe")):
        return os.path.abspath(local2)
    # 2. 系统 PATH
    path = shutil.which("ffmpeg")
    if path:
        return os.path.dirname(path)
    # 3. WinGet 安装路径
    winget_dir = os.path.join(
        os.environ.get("LOCALAPPDATA", ""),
        "Microsoft", "WinGet", "Packages",
    )
    if os.path.isdir(winget_dir):
        matches = glob.glob(os.path.join(winget_dir, "Gyan.FFmpeg_*", "ffmpeg-*", "bin"))
        if matches:
            return matches[0]
    return None


_FFMPEG_DIR = _find_ffmpeg()


class DownloadWorker(QThread):
    """后台线程：下载并转码音频。"""

    progress = Signal(float, str)   # (百分比 0-100, 速度描述)
    finished = Signal(str)          # 文件保存路径
    error = Signal(str)             # 错误信息

    def __init__(self, url: str, output_dir: str,
                 audio_format: str = "mp3", bitrate: str = "320"):
        super().__init__()
        self.url = url
        self.output_dir = output_dir
        self.audio_format = audio_format
        self.bitrate = bitrate
        self._cancelled = False

    def cancel(self):
        self._cancelled = True

    def run(self):
        try:
            os.makedirs(self.output_dir, exist_ok=True)

            def progress_hook(d):
                if self._cancelled:
                    raise Exception("用户取消下载")
                if d["status"] == "downloading":
                    total = d.get("total_bytes") or d.get("total_bytes_estimate", 0)
                    downloaded = d.get("downloaded_bytes", 0)
                    pct = (downloaded / total * 100) if total else 0
                    speed = d.get("_speed_str", "")
                    self.progress.emit(pct, speed)
                elif d["status"] == "finished":
                    self.progress.emit(100, "转换中...")

            output_template = os.path.join(self.output_dir, "%(title)s.%(ext)s")

            ydl_opts = {
                "format": "bestaudio/best",
                "outtmpl": output_template,
                "progress_hooks": [progress_hook],
                "quiet": True,
                "no_warnings": True,
                "ffmpeg_location": _FFMPEG_DIR,
                "postprocessors": [{
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": self.audio_format,
                    "preferredquality": self.bitrate,
                }],
                # 嵌入元数据
                "writethumbnail": True,
                "postprocessors_args": {
                    "ffmpeg": ["-id3v2_version", "3"],
                },
                "addmetadata": True,
            }

            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(self.url, download=True)
                title = info.get("title", "未知")
                # yt-dlp 会把扩展名改成 postprocessor 设定的格式
                filename = ydl.prepare_filename(info)
                # 替换扩展名
                base, _ = os.path.splitext(filename)
                final_path = f"{base}.{self.audio_format}"

                # 如果文件不存在（postprocessor 可能用不同路径），尝试查找
                if not os.path.exists(final_path):
                    # 在输出目录中查找最近创建的同名文件
                    for f in os.listdir(self.output_dir):
                        if f.startswith(os.path.basename(base)):
                            final_path = os.path.join(self.output_dir, f)
                            break

                self.finished.emit(final_path)

        except Exception as e:
            if not self._cancelled:
                self.error.emit(str(e))


def probe_url(url: str) -> dict | None:
    """解析 URL，返回视频/音频信息（不下载）。"""
    try:
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "ffmpeg_location": _FFMPEG_DIR,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            return {
                "title": info.get("title", "未知"),
                "duration": info.get("duration", 0),
                "uploader": info.get("uploader", "未知"),
                "thumbnail": info.get("thumbnail", ""),
            }
    except Exception:
        return None
