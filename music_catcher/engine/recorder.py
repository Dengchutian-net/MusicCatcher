"""WASAPI Loopback 系统音频录制引擎。"""

import os
import struct
import wave
import threading
import numpy as np

from PySide6.QtCore import QThread, Signal

try:
    import pyaudiowpatch as pyaudio
except ImportError:
    pyaudio = None


class RecordWorker(QThread):
    """后台线程：录制系统声音，实时回传电平。"""

    level = Signal(float)       # 0.0 ~ 1.0 电平值
    finished = Signal(str)      # 保存的 WAV 文件路径
    error = Signal(str)

    CHUNK = 1024

    def __init__(self, output_path: str):
        super().__init__()
        self.output_path = output_path
        self._stop_event = threading.Event()

    def stop(self):
        self._stop_event.set()

    def run(self):
        if pyaudio is None:
            self.error.emit("pyaudiowpatch 未安装，请运行: pip install pyaudiowpatch")
            return

        pa = pyaudio.PyAudio()
        stream = None
        wf = None

        try:
            # 找到默认 WASAPI 输出设备的 loopback 对应设备
            wasapi_info = pa.get_host_api_info_by_type(pyaudio.paWASAPI)
            default_speakers = pa.get_device_info_by_index(
                wasapi_info["defaultOutputDevice"]
            )

            # 尝试获取 loopback 设备
            loopback_device = None
            for i in range(pa.get_device_count()):
                dev = pa.get_device_info_by_index(i)
                if (dev.get("isLoopbackDevice", False) and
                        dev["hostApi"] == wasapi_info["index"]):
                    loopback_device = dev
                    break

            if loopback_device is None:
                # 没找到显式 loopback，用默认输出设备（某些驱动支持）
                loopback_device = default_speakers

            rate = int(loopback_device["defaultSampleRate"])
            channels = int(loopback_device["maxInputChannels"])
            if channels < 1:
                channels = 2

            stream = pa.open(
                format=pyaudio.paInt16,
                channels=channels,
                rate=rate,
                input=True,
                input_device_index=loopback_device["index"],
                frames_per_buffer=self.CHUNK,
            )

            os.makedirs(os.path.dirname(self.output_path) or ".", exist_ok=True)
            wf = wave.open(self.output_path, "wb")
            wf.setnchannels(channels)
            wf.setsampwidth(2)  # 16-bit
            wf.setframerate(rate)

            while not self._stop_event.is_set():
                data = stream.read(self.CHUNK, exception_on_overflow=False)
                wf.writeframes(data)

                # 计算 RMS 电平
                samples = np.frombuffer(data, dtype=np.int16)
                if len(samples) > 0:
                    rms = np.sqrt(np.mean(samples.astype(np.float32) ** 2))
                    level = min(rms / 32768.0, 1.0)
                    self.level.emit(float(level))

            self.finished.emit(self.output_path)

        except Exception as e:
            if not self._stop_event.is_set():
                self.error.emit(f"录制失败: {e}")
        finally:
            if stream:
                stream.stop_stream()
                stream.close()
            if wf:
                wf.close()
            pa.terminate()


def _find_ffmpeg_exe() -> str:
    """查找 ffmpeg 可执行文件路径。"""
    import sys
    import shutil
    import glob
    # 1. exe 同级目录的 ffmpeg/ 子目录
    if getattr(sys, "frozen", False):
        base = os.path.dirname(sys.executable)
    else:
        base = os.path.dirname(os.path.abspath(__file__))
    local = os.path.join(base, "ffmpeg", "ffmpeg.exe")
    if os.path.isfile(local):
        return local
    local2 = os.path.join(base, "..", "ffmpeg", "ffmpeg.exe")
    if os.path.isfile(local2):
        return os.path.abspath(local2)
    # 2. 系统 PATH
    path = shutil.which("ffmpeg")
    if path:
        return path
    # 3. WinGet
    winget_dir = os.path.join(
        os.environ.get("LOCALAPPDATA", ""),
        "Microsoft", "WinGet", "Packages",
    )
    if os.path.isdir(winget_dir):
        matches = glob.glob(os.path.join(winget_dir, "Gyan.FFmpeg_*", "ffmpeg-*", "bin", "ffmpeg.exe"))
        if matches:
            return matches[0]
    return "ffmpeg"


def convert_wav_to_mp3(wav_path: str, mp3_path: str, bitrate: str = "192") -> bool:
    """用 FFmpeg 将 WAV 转为 MP3。"""
    import subprocess
    try:
        ffmpeg = _find_ffmpeg_exe()
        cmd = [
            ffmpeg, "-y", "-i", wav_path,
            "-codec:a", "libmp3lame",
            "-b:a", f"{bitrate}k",
            mp3_path,
        ]
        result = subprocess.run(cmd, capture_output=True, timeout=120)
        if result.returncode == 0:
            os.remove(wav_path)
            return True
        else:
            return False
    except Exception:
        return False


def list_wasapi_devices() -> list[dict]:
    """列出所有 WASAPI 设备，供设置页选择。"""
    if pyaudio is None:
        return []
    devices = []
    pa = pyaudio.PyAudio()
    try:
        wasapi_info = pa.get_host_api_info_by_type(pyaudio.paWASAPI)
        for i in range(pa.get_device_count()):
            dev = pa.get_device_info_by_index(i)
            if dev["hostApi"] == wasapi_info["index"]:
                devices.append({
                    "index": i,
                    "name": dev["name"],
                    "is_loopback": dev.get("isLoopbackDevice", False),
                    "channels": dev["maxInputChannels"],
                    "rate": dev["defaultSampleRate"],
                })
    except Exception:
        pass
    finally:
        pa.terminate()
    return devices
