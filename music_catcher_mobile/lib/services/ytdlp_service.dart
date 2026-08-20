import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// yt-dlp 本地执行服务
/// 在 Android 上下载并运行 yt-dlp 二进制文件，提取音频下载链接
class YtdlpService {
  static const _binaryName = 'yt-dlp';
  static const _downloadUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64';

  final Dio _dio = Dio();
  String? _binaryPath;
  bool _initialized = false;
  String _initStatus = '未初始化';
  double _initProgress = 0;

  bool get isReady => _initialized;
  String get initStatus => _initStatus;
  double get initProgress => _initProgress;
  String? get binaryPath => _binaryPath;

  /// 初始化：检查或下载 yt-dlp 二进制
  Future<bool> init({void Function(double progress, String status)? onProgress}) async {
    if (_initialized) return true;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final binDir = Directory('${appDir.path}/bin');
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      _binaryPath = '${binDir.path}/$_binaryName';
      final binaryFile = File(_binaryPath!);

      if (await binaryFile.exists()) {
        // 已存在，验证是否可执行
        _initStatus = '验证 yt-dlp...';
        onProgress?.call(1.0, _initStatus);
        final result = await _runBinary(['--version']);
        if (result.exitCode == 0) {
          _initialized = true;
          _initStatus = 'yt-dlp 就绪 (v${result.stdout.toString().trim()})';
          onProgress?.call(1.0, _initStatus);
          return true;
        }
        // 二进制损坏，重新下载
        await binaryFile.delete();
      }

      // 下载 yt-dlp 二进制
      _initStatus = '正在下载 yt-dlp...';
      _initProgress = 0;
      onProgress?.call(0, _initStatus);

      await _dio.download(
        _downloadUrl,
        _binaryPath!,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _initProgress = received / total;
            final percent = (_initProgress * 100).toStringAsFixed(0);
            _initStatus = '下载 yt-dlp $percent%';
            onProgress?.call(_initProgress, _initStatus);
          }
        },
        options: Options(
          headers: {'Accept': 'application/octet-stream'},
          followRedirects: true,
        ),
      );

      // 设置可执行权限
      _initStatus = '设置权限...';
      onProgress?.call(1.0, _initStatus);
      await Process.run('chmod', ['+x', _binaryPath!]);

      // 验证
      _initStatus = '验证安装...';
      onProgress?.call(1.0, _initStatus);
      final result = await _runBinary(['--version']);
      if (result.exitCode == 0) {
        _initialized = true;
        _initStatus = 'yt-dlp 就绪 (v${result.stdout.toString().trim()})';
        onProgress?.call(1.0, _initStatus);
        return true;
      }

      _initStatus = 'yt-dlp 验证失败';
      onProgress?.call(0, _initStatus);
      return false;
    } catch (e) {
      _initStatus = '初始化失败: $e';
      onProgress?.call(0, _initStatus);
      return false;
    }
  }

  /// 从视频链接提取最佳音频下载 URL
  Future<AudioInfo?> extractAudio(String videoUrl) async {
    if (!_initialized || _binaryPath == null) {
      final ok = await init();
      if (!ok) return null;
    }

    try {
      // yt-dlp 获取音频信息（不下载）
      final result = await _runBinary([
        '--no-warnings',
        '--no-playlist',
        '-j',            // 输出 JSON
        '-f', 'bestaudio/best',  // 最佳音频
        '--no-check-certificates',
        videoUrl,
      ]);

      if (result.exitCode != 0) {
        final stderr = result.stderr.toString();
        throw Exception('yt-dlp 错误: $stderr');
      }

      final jsonStr = result.stdout.toString().trim();
      if (jsonStr.isEmpty) throw Exception('yt-dlp 返回为空');

      // 解析 JSON 获取关键信息
      final info = _parseAudioInfo(jsonStr);
      return info;
    } catch (e) {
      throw Exception('提取音频失败: $e');
    }
  }

  /// 直接获取音频下载 URL（简化版，只返回 URL）
  Future<String?> getAudioUrl(String videoUrl) async {
    if (!_initialized || _binaryPath == null) {
      final ok = await init();
      if (!ok) return null;
    }

    try {
      final result = await _runBinary([
        '--no-warnings',
        '--no-playlist',
        '--get-url',     // 只输出 URL
        '-f', 'bestaudio/best',
        '--no-check-certificates',
        videoUrl,
      ]);

      if (result.exitCode != 0) return null;
      final url = result.stdout.toString().trim();
      return url.isNotEmpty ? url : null;
    } catch (e) {
      return null;
    }
  }

  /// 获取视频标题
  Future<String?> getTitle(String videoUrl) async {
    if (!_initialized || _binaryPath == null) {
      final ok = await init();
      if (!ok) return null;
    }

    try {
      final result = await _runBinary([
        '--no-warnings',
        '--no-playlist',
        '--get-title',
        '--no-check-certificates',
        videoUrl,
      ]);

      if (result.exitCode != 0) return null;
      final title = result.stdout.toString().trim();
      return title.isNotEmpty ? title : null;
    } catch (e) {
      return null;
    }
  }

  /// 解析 yt-dlp JSON 输出
  AudioInfo _parseAudioInfo(String jsonStr) {
    // 简单 JSON 解析（不依赖额外包）
    String? extractString(String key) {
      final pattern = RegExp('"$key"\\s*:\\s*"([^"]*)"');
      final match = pattern.firstMatch(jsonStr);
      return match?.group(1);
    }

    int? extractInt(String key) {
      final pattern = RegExp('"$key"\\s*:\\s*(\\d+)');
      final match = pattern.firstMatch(jsonStr);
      return match != null ? int.tryParse(match.group(1)!) : null;
    }

    final title = extractString('title') ?? '未知标题';
    final url = extractString('url');
    final webpageUrl = extractString('webpage_url') ?? '';
    final extractor = extractString('extractor') ?? '';
    final duration = extractInt('duration') ?? 0;
    final ext = extractString('ext') ?? 'm4a';

    return AudioInfo(
      title: title,
      url: url ?? webpageUrl,
      extractor: extractor,
      duration: duration,
      extension: ext,
    );
  }

  /// 运行 yt-dlp 二进制
  Future<ProcessResult> _runBinary(List<String> args) async {
    return await Process.run(
      _binaryPath!,
      args,
      environment: {
        'HOME': (await getApplicationDocumentsDirectory()).path,
        'TMPDIR': (await getTemporaryDirectory()).path,
      },
    );
  }

  void dispose() {
    _dio.close();
  }
}

/// 音频信息
class AudioInfo {
  final String title;
  final String url;
  final String extractor;
  final int duration;
  final String extension;

  AudioInfo({
    required this.title,
    required this.url,
    this.extractor = '',
    this.duration = 0,
    this.extension = 'm4a',
  });

  String get sanitizedTitle {
    // 移除文件名中的非法字符
    return title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  String get durationText {
    if (duration <= 0) return '';
    final mins = (duration ~/ 60).toString().padLeft(2, '0');
    final secs = (duration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
