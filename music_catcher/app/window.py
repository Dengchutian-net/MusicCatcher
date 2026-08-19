"""主窗口。"""

from PySide6.QtWidgets import QMainWindow, QTabWidget, QWidget, QVBoxLayout
from PySide6.QtCore import Qt
from PySide6.QtGui import QIcon

from app.download_tab import DownloadTab
from app.record_tab import RecordTab
from app.settings_tab import SettingsTab
from app.settings import load_config


DARK_STYLE = """
QMainWindow {
    background-color: #0d0d1a;
}
QTabWidget::pane {
    border: 1px solid #2a2a3e;
    background-color: #0d0d1a;
    border-radius: 4px;
}
QTabBar::tab {
    background-color: #1a1a2e;
    color: #888;
    padding: 10px 24px;
    margin-right: 2px;
    border-top-left-radius: 4px;
    border-top-right-radius: 4px;
    font-size: 13px;
}
QTabBar::tab:selected {
    background-color: #0d0d1a;
    color: #eee;
    border-bottom: 2px solid #1DB954;
}
QTabBar::tab:hover {
    color: #ccc;
}
QLabel {
    color: #ccc;
    font-size: 13px;
}
QLineEdit {
    background-color: #1a1a2e;
    color: #eee;
    border: 1px solid #333;
    border-radius: 4px;
    padding: 8px;
    font-size: 13px;
}
QLineEdit:focus {
    border: 1px solid #1DB954;
}
QComboBox {
    background-color: #1a1a2e;
    color: #eee;
    border: 1px solid #333;
    border-radius: 4px;
    padding: 6px 12px;
    font-size: 13px;
}
QComboBox::drop-down {
    border: none;
}
QComboBox QAbstractItemView {
    background-color: #1a1a2e;
    color: #eee;
    selection-background-color: #1DB954;
}
QPushButton {
    background-color: #2a2a3e;
    color: #ccc;
    border: 1px solid #333;
    border-radius: 4px;
    padding: 8px 16px;
    font-size: 13px;
}
QPushButton:hover {
    background-color: #3a3a4e;
    color: #eee;
}
QPushButton:disabled {
    background-color: #1a1a2e;
    color: #555;
}
QProgressBar {
    background-color: #1a1a2e;
    border: 1px solid #333;
    border-radius: 4px;
    text-align: center;
    color: #eee;
    height: 20px;
}
QProgressBar::chunk {
    background-color: #1DB954;
    border-radius: 3px;
}
QGroupBox {
    color: #aaa;
    border: 1px solid #2a2a3e;
    border-radius: 4px;
    margin-top: 8px;
    padding-top: 16px;
    font-size: 13px;
}
QGroupBox::title {
    subcontrol-origin: margin;
    left: 12px;
    padding: 0 6px;
}
QTextEdit {
    font-family: Consolas, 'Courier New', monospace;
}
"""


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.config = load_config()
        self.setWindowTitle("Music Catcher")
        self.setMinimumSize(520, 480)
        self.resize(560, 520)
        self.setStyleSheet(DARK_STYLE)

        # 中心控件
        central = QWidget()
        layout = QVBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)

        self.tabs = QTabWidget()
        self.download_tab = DownloadTab(self.config)
        self.record_tab = RecordTab(self.config)
        self.settings_tab = SettingsTab(self.config)

        self.tabs.addTab(self.download_tab, "下载")
        self.tabs.addTab(self.record_tab, "录制")
        self.tabs.addTab(self.settings_tab, "设置")

        layout.addWidget(self.tabs)
        self.setCentralWidget(central)
