"""应用配置管理。"""

import json
import os

DEFAULT_CONFIG = {
    "output_dir": os.path.join(os.path.expanduser("~"), "Music", "MusicCatcher"),
    "audio_format": "mp3",
    "bitrate": "320",
    "record_bitrate": "192",
    "theme": "dark",
}

_CONFIG_PATH = os.path.join(os.path.expanduser("~"), ".music_catcher_config.json")


def load_config() -> dict:
    cfg = dict(DEFAULT_CONFIG)
    if os.path.exists(_CONFIG_PATH):
        try:
            with open(_CONFIG_PATH, "r", encoding="utf-8") as f:
                saved = json.load(f)
                cfg.update(saved)
        except Exception:
            pass
    return cfg


def save_config(cfg: dict):
    try:
        with open(_CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, ensure_ascii=False, indent=2)
    except Exception:
        pass
