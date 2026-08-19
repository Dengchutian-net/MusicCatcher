"""录制标签页：WASAPI Loopback 录制系统声音。"""

import os
import time
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QFileDialog, QComboBox, QLineEdit,
)
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QPainter, QColor

from engine.recorder import RecordWorker, convert_wav_to_mp3


class LevelMeter(QWidget):
    """实时音频电平显示条。"""

    def __init__(self):
        super().__init__()
        self._level = 0.0
        self.setMinimumHeight(40)
        self.setMinimumWidth(200)

    def set_level(self, level: float):
        self._level = max(0.0, min(1.0, level))
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        w = self.width()
        h = self.height()

        # 背景
        painter.fillRect(0, 0, w, h, QColor("#1a1a2e"))

        # 电平条
        bar_w = int(w * self._level)
        if self._level < 0.6:
            color = QColor("#1DB954")  # 绿色
        elif self._level < 0.85:
            color = QColor("#FFA500")  # 橙色
        else:
            color = QColor("#FF4444")  # 红色
        painter.fillRect(0, 0, bar_w, h, color)

        # 刻度线
        painter.setPen(QColor("#333"))
        for i in range(1, 10):
            x = int(w * i / 10)
            painter.drawLine(x, 0, x, h)

        painter.end()


class RecordTab(QWidget):
    def __init__(self, config: dict):
        super().__init__()
        self.config = config
        self._worker = None
        self._recording = False
        self._start_time = 0
        self._timer = QTimer()
        self._timer.timeout.connect(self._update_time)
        self._init_ui()

    def _init_ui(self):
        layout = QVBoxLayout(self)
        layout.setSpacing(12)

        # 说明
        hint = QLabel("录制系统正在播放的声音（WASAPI Loopback）")
        hint.setStyleSheet("color: #888; font-size: 12px;")
        layout.addWidget(hint)

        # 文件名输入
        name_row = QHBoxLayout()
        name_row.addWidget(QLabel("文件名:"))
        self.name_input = QLineEdit()
        self.name_input.setPlaceholderText("留空则自动命名")
        name_row.addWidget(self.name_input, 1)

        name_row.addWidget(QLabel("格式:"))
        self.format_combo = QComboBox()
        self.format_combo.addItems(["mp3", "wav"])
        name_row.addWidget(self.format_combo)
        layout.addLayout(name_row)

        # 电平显示
        self.level_meter = LevelMeter()
        layout.addWidget(self.level_meter)

        # 时间显示
        self.time_label = QLabel("00:00")
        self.time_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.time_label.setStyleSheet("font-size: 28px; font-weight: bold; color: #eee;")
        layout.addWidget(self.time_label)

        # 状态
        self.status_label = QLabel("就绪")
        self.status_label.setStyleSheet("color: #888;")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.status_label)

        # 按钮
        btn_row = QHBoxLayout()
        self.record_btn = QPushButton("开始录制")
        self.record_btn.setStyleSheet(
            "QPushButton { background-color: #FF4444; color: white; "
            "border: none; padding: 12px 32px; border-radius: 6px; font-size: 14px; font-weight: bold; }"
            "QPushButton:hover { background-color: #ff6666; }"
        )
        self.record_btn.clicked.connect(self._toggle_record)

        self.stop_btn = QPushButton("停止并保存")
        self.stop_btn.setEnabled(False)
        self.stop_btn.setStyleSheet(
            "QPushButton { background-color: #555; color: white; "
            "border: none; padding: 12px 32px; border-radius: 6px; font-size: 14px; }"
            "QPushButton:hover { background-color: #666; }"
            "QPushButton:disabled { background-color: #333; color: #666; }"
        )
        self.stop_btn.clicked.connect(self._stop_and_save)
        btn_row.addWidget(self.record_btn)
        btn_row.addWidget(self.stop_btn)
        layout.addLayout(btn_row)

        layout.addStretch()

    def _toggle_record(self):
        if not self._recording:
            self._start_record()

    def _start_record(self):
        # 生成输出路径
        output_dir = self.config.get("output_dir", "")
        os.makedirs(output_dir, exist_ok=True)

        custom_name = self.name_input.text().strip()
        if custom_name:
            filename = f"{custom_name}.wav"
        else:
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            filename = f"录制_{timestamp}.wav"

        output_path = os.path.join(output_dir, filename)

        self._worker = RecordWorker(output_path)
        self._worker.level.connect(self.level_meter.set_level)
        self._worker.finished.connect(self._on_record_finished)
        self._worker.error.connect(self._on_record_error)

        self._recording = True
        self._start_time = time.time()
        self._timer.start(100)

        self.record_btn.setEnabled(False)
        self.stop_btn.setEnabled(True)
        self.status_label.setText("🔴 录制中...  （播放你想录制的音乐）")
        self.status_label.setStyleSheet("color: #FF4444;")

        self._worker.start()

    def _stop_and_save(self):
        if self._worker:
            self._worker.stop()
            self._worker.wait(5000)

    def _on_record_finished(self, wav_path: str):
        self._timer.stop()
        self._recording = False
        self.level_meter.set_level(0.0)
        self.record_btn.setEnabled(True)
        self.stop_btn.setEnabled(False)

        # 如果选择 mp3 格式，转换
        fmt = self.format_combo.currentText()
        if fmt == "mp3":
            self.status_label.setText("正在转换为 MP3...")
            self.status_label.setStyleSheet("color: #FFA500;")
            mp3_path = wav_path.replace(".wav", ".mp3")
            bitrate = self.config.get("record_bitrate", "192")
            if convert_wav_to_mp3(wav_path, mp3_path, bitrate):
                self.status_label.setText(f"✅ 已保存: {os.path.basename(mp3_path)}")
                self.status_label.setStyleSheet("color: #1DB954;")
            else:
                self.status_label.setText(f"✅ 已保存 WAV: {os.path.basename(wav_path)}  （MP3转换失败，需安装FFmpeg）")
                self.status_label.setStyleSheet("color: #FFA500;")
        else:
            self.status_label.setText(f"✅ 已保存: {os.path.basename(wav_path)}")
            self.status_label.setStyleSheet("color: #1DB954;")

    def _on_record_error(self, msg: str):
        self._timer.stop()
        self._recording = False
        self.level_meter.set_level(0.0)
        self.record_btn.setEnabled(True)
        self.stop_btn.setEnabled(False)
        self.status_label.setText(f"✗ {msg}")
        self.status_label.setStyleSheet("color: #FF4444;")

    def _update_time(self):
        elapsed = int(time.time() - self._start_time)
        mins, secs = divmod(elapsed, 60)
        self.time_label.setText(f"{mins:02d}:{secs:02d}")
