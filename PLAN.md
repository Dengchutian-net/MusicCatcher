# Music Catcher Android 版 — 实现方案

## 框架
Flutter (Dart)，跨平台，UI 美观，音频生态成熟。

## 功能
1. 链接下载 — 粘贴 URL → 解析 → 下载音频
2. 播放器 — 内置播放器，播放已下载的歌曲
3. 录音 — 手机麦克风录音并保存
4. 后台下载 — 下载过程中切后台不中断 + 通知栏进度

## 技术栈
| 组件 | 选型 |
|------|------|
| 框架 | Flutter 3.x |
| 下载引擎 | yt-dlp Python → 通过 Method Channel 桥接，或用 Dart 的 dio 下载 |
| 音频播放 | just_audio |
| 录音 | record |
| 后台任务 | flutter_background_service + flutter_local_notifications |
| 文件管理 | path_provider |
| 状态管理 | Provider 或 Riverpod |

## 项目结构
```
music_catcher_mobile/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── home_screen.dart        # 主页（底部导航）
│   │   ├── download_screen.dart    # 下载页
│   │   ├── player_screen.dart      # 播放器页
│   │   ├── record_screen.dart      # 录音页
│   │   └── settings_screen.dart    # 设置页
│   ├── services/
│   │   ├── download_service.dart   # 下载逻辑
│   │   ├── audio_service.dart      # 播放逻辑
│   │   └── record_service.dart     # 录音逻辑
│   ├── widgets/
│   │   ├── song_tile.dart          # 歌曲列表项
│   │   └── player_bar.dart         # 底部迷你播放条
│   └── models/
│       └── song.dart               # 歌曲数据模型
├── android/
├── pubspec.yaml
└── README.md
```

## 实现步骤
1. Flutter 项目初始化
2. 下载页 — URL 输入 + 下载
3. 播放器页 — 歌曲列表 + 播放控制
4. 录音页 — 录音 + 保存
5. 后台下载 + 通知栏
6. Android 权限配置
7. 构建 APK
