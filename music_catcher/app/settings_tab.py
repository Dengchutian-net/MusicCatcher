"""设置标签页。"""

import os
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QComboBox, QPushButton, QFileDialog, QGroupBox,
)
from app.settings import save_config


class SettingsTab(QWidget):
    def __init__(self, config: dict):
        super().__init__()
        self.config = config
        self._init_ui()

    def _init_ui(self):
        layout = QVBoxLayout(self)
        layout.setSpacing(16)

        # 下载设置
        dl_group = QGroupBox("下载设置")
        dl_layout = QVBoxLayout(dl_group)

        # 输出目录
        dir_row = QHBoxLayout()
        dir_row.addWidget(QLabel("保存目录:"))
        self.dir_label = QLabel(self.config.get("output_dir", ""))
        self.dir_label.setStyleSheet("color: #aaa;")
        dir_row.addWidget(self.dir_label, 1)
        dir_btn = QPushButton("更改")
        dir_btn.clicked.connect(self._choose_dir)
        dir_row.addWidget(dir_btn)
        dl_layout.addLayout(dir_row)

        # 默认格式
        fmt_row = QHBoxLayout()
        fmt_row.addWidget(QLabel("默认格式:"))
        self.fmt_combo = QComboBox()
        self.fmt_combo.addItems(["mp3", "flac", "wav", "aac", "ogg"])
        self.fmt_combo.setCurrentText(self.config.get("audio_format", "mp3"))
        self.fmt_combo.currentTextChanged.connect(self._on_format_changed)
        fmt_row.addWidget(self.fmt_combo)

        fmt_row.addWidget(QLabel("默认音质:"))
        self.bitrate_combo = QComboBox()
        self.bitrate_combo.addItems(["128", "192", "256", "320"])
        self.bitrate_combo.setCurrentText(self.config.get("bitrate", "320"))
        self.bitrate_combo.currentTextChanged.connect(self._on_bitrate_changed)
        fmt_row.addWidget(self.bitrate_combo)
        dl_layout.addLayout(fmt_row)

        # 录制音质
        rec_row = QHBoxLayout()
        rec_row.addWidget(QLabel("录制音质:"))
        self.rec_bitrate_combo = QComboBox()
        self.rec_bitrate_combo.addItems(["128", "192", "256", "320"])
        self.rec_bitrate_combo.setCurrentText(self.config.get("record_bitrate", "192"))
        self.rec_bitrate_combo.currentTextChanged.connect(self._on_rec_bitrate_changed)
        rec_row.addWidget(self.rec_bitrate_combo)
        rec_row.addStretch()
        dl_layout.addLayout(rec_row)

        layout.addWidget(dl_group)

        # 关于
        about_group = QGroupBox("关于")
        about_layout = QVBoxLayout(about_group)
        about_layout.addWidget(QLabel("Music Catcher v1.0"))
        about_layout.addWidget(QLabel("网页音乐抓取工具"))
        about_layout.addWidget(QLabel("技术栈: Python + yt-dlp + PySide6 + WASAPI"))
        layout.addWidget(about_group)

        layout.addStretch()

    def _choose_dir(self):
        d = QFileDialog.getExistingDirectory(
            self, "选择保存目录", self.config.get("output_dir", "")
        )
        if d:
            self.config["output_dir"] = d
            self.dir_label.setText(d)
            save_config(self.config)

    def _on_format_changed(self, fmt: str):
        self.config["audio_format"] = fmt
        save_config(self.config)

    def _on_bitrate_changed(self, br: str):
        self.config["bitrate"] = br
        save_config(self.config)

    def _on_rec_bitrate_changed(self, br: str):
        self.config["record_bitrate"] = br
        save_config(self.config)
