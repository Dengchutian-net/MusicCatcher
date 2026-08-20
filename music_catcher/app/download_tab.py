"""下载标签页：粘贴 URL → 选择格式 → 一键下载。"""

import os
import re
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QLineEdit, QComboBox, QPushButton, QProgressBar,
    QTextEdit, QFileDialog,
)
from PySide6.QtCore import Qt, QThread, Signal
from engine.downloader import DownloadWorker, probe_url


def extract_urls(text: str) -> list[str]:
    """从文本中提取所有 URL。

    支持从分享文字中提取，如：
    - "xxx-哔哩哔哩】 https://b23.tv/abc"
    - "前奏一响... https://xhslink.cn/o/xxx 【小红书】"
    """
    # 匹配 http/https 链接，遇到空白或非ASCII字符就截止
    pattern = r'https?://[\w\-._~:/?#\[\]@!$&\'()*+,;=%]+'
    urls = re.findall(pattern, text)
    # 清理尾部可能误捕获的标点
    cleaned = []
    for url in urls:
        url = url.rstrip('.,;:!?\'")]}')
        cleaned.append(url)
    return cleaned


class ProbeWorker(QThread):
    """后台解析 URL 信息。"""
    result = Signal(dict)
    error = Signal(str)

    def __init__(self, url: str):
        super().__init__()
        self.url = url

    def run(self):
        info = probe_url(self.url)
        if info:
            self.result.emit(info)
        else:
            self.error.emit("无法解析该链接，请检查 URL 是否正确")


class DownloadTab(QWidget):
    def __init__(self, config: dict):
        super().__init__()
        self.config = config
        self._worker = None
        self._probe_worker = None
        self._init_ui()

    def _init_ui(self):
        layout = QVBoxLayout(self)
        layout.setSpacing(12)

        # URL 输入
        url_row = QHBoxLayout()
        url_label = QLabel("链接:")
        self.url_input = QLineEdit()
        self.url_input.setPlaceholderText("粘贴链接或分享文字...")
        self.url_input.returnPressed.connect(self._on_download)
        url_row.addWidget(url_label)
        url_row.addWidget(self.url_input, 1)
        layout.addLayout(url_row)

        # 歌曲信息预览
        self.info_label = QLabel("")
        self.info_label.setStyleSheet("color: #888; font-size: 12px;")
        layout.addWidget(self.info_label)

        # 格式和音质选择
        opt_row = QHBoxLayout()
        opt_row.addWidget(QLabel("格式:"))
        self.format_combo = QComboBox()
        self.format_combo.addItems(["mp3", "flac", "wav", "aac", "ogg"])
        self.format_combo.setCurrentText(self.config.get("audio_format", "mp3"))
        opt_row.addWidget(self.format_combo)

        opt_row.addWidget(QLabel("音质:"))
        self.bitrate_combo = QComboBox()
        self.bitrate_combo.addItems(["128", "192", "256", "320"])
        self.bitrate_combo.setCurrentText(self.config.get("bitrate", "320"))
        opt_row.addWidget(self.bitrate_combo)

        # 输出目录选择
        self.dir_label = QLabel(self.config.get("output_dir", ""))
        self.dir_label.setStyleSheet("color: #666; font-size: 11px;")
        self.dir_btn = QPushButton("选择目录")
        self.dir_btn.clicked.connect(self._choose_dir)
        opt_row.addWidget(self.dir_btn)
        layout.addLayout(opt_row)
        layout.addWidget(self.dir_label)

        # 按钮
        btn_row = QHBoxLayout()
        self.download_btn = QPushButton("开始下载")
        self.download_btn.setStyleSheet(
            "QPushButton { background-color: #1DB954; color: white; "
            "border: none; padding: 10px 24px; border-radius: 6px; font-size: 14px; }"
            "QPushButton:hover { background-color: #1ed760; }"
            "QPushButton:disabled { background-color: #555; }"
        )
        self.download_btn.clicked.connect(self._on_download)

        self.cancel_btn = QPushButton("取消")
        self.cancel_btn.setEnabled(False)
        self.cancel_btn.clicked.connect(self._on_cancel)
        btn_row.addWidget(self.download_btn)
        btn_row.addWidget(self.cancel_btn)
        layout.addLayout(btn_row)

        # 进度条
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        self.progress_bar.setTextVisible(True)
        layout.addWidget(self.progress_bar)

        # 状态日志
        self.log_area = QTextEdit()
        self.log_area.setReadOnly(True)
        self.log_area.setMaximumHeight(120)
        self.log_area.setStyleSheet(
            "QTextEdit { background-color: #1a1a2e; color: #ccc; "
            "border: 1px solid #333; border-radius: 4px; font-size: 12px; }"
        )
        layout.addWidget(self.log_area)

        layout.addStretch()

    def _choose_dir(self):
        d = QFileDialog.getExistingDirectory(self, "选择保存目录",
                                             self.config.get("output_dir", ""))
        if d:
            self.config["output_dir"] = d
            self.dir_label.setText(d)

    def _on_download(self):
        raw = self.url_input.text().strip()
        if not raw:
            self._log("请先输入链接")
            return

        # 从文本中提取 URL
        urls = extract_urls(raw)
        if not urls:
            self._log("未识别到链接，请检查输入")
            return

        # 多个链接时提示，取第一个
        if len(urls) > 1:
            self._log(f"检测到 {len(urls)} 个链接，使用第一个")

        url = urls[0]
        if url != raw:
            self._log(f"提取链接: {url}")
            self.url_input.setText(url)

        self.download_btn.setEnabled(False)
        self.cancel_btn.setEnabled(True)
        self.progress_bar.setValue(0)
        self.info_label.setText("解析中...")

        # 先解析
        self._probe_worker = ProbeWorker(url)
        self._probe_worker.result.connect(self._on_probe_result)
        self._probe_worker.error.connect(self._on_probe_error)
        self._probe_worker.start()

    def _on_probe_result(self, info: dict):
        title = info.get("title", "未知")
        duration = info.get("duration", 0)
        mins, secs = divmod(duration, 60)
        self.info_label.setText(f"{title}  ({int(mins)}:{int(secs):02d})")
        self._log(f"解析成功: {title}")
        self._start_download()

    def _on_probe_error(self, msg: str):
        self.info_label.setText("")
        self._log(f"{msg}")
        self.download_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)

    def _start_download(self):
        url = self.url_input.text().strip()
        fmt = self.format_combo.currentText()
        bitrate = self.bitrate_combo.currentText()
        output_dir = self.config.get("output_dir", "")

        self._worker = DownloadWorker(url, output_dir, fmt, bitrate)
        self._worker.progress.connect(self._on_progress)
        self._worker.finished.connect(self._on_finished)
        self._worker.error.connect(self._on_error)
        self._worker.start()

    def _on_progress(self, pct: float, speed: str):
        self.progress_bar.setValue(int(pct))
        if speed:
            self.progress_bar.setFormat(f"{pct:.1f}%  {speed}")

    def _on_finished(self, path: str):
        self.progress_bar.setValue(100)
        self._log(f"已保存: {os.path.basename(path)}")
        self.info_label.setText(f"完成 -> {path}")
        self.download_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)

    def _on_error(self, msg: str):
        self._log(f"下载失败: {msg}")
        self.progress_bar.setValue(0)
        self.download_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)

    def _on_cancel(self):
        if self._worker:
            self._worker.cancel()
            self._worker.wait(3000)
        self._log("已取消下载")
        self.download_btn.setEnabled(True)
        self.cancel_btn.setEnabled(False)
        self.progress_bar.setValue(0)

    def _log(self, text: str):
        self.log_area.append(text)
