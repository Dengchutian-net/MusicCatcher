import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// yt-dlp 本地执行服务
/// 从 APK assets 提取二进制到 native lib 目录执行
class YtdlpService {
  static const _channel = MethodChannel('com.musiccatcher/native_exec');

  bool _initialized = false;
  String? _binaryPath;
  String _initStatus = '未初始化';
  String? _lastError;

  bool get isReady => _initialized;
  String get initStatus => _initStatus;
  String? get lastError => _lastError;

  Future<bool> init({void Function(double progress, String status)? onProgress}) async {
    if (_initialized) return true;
    _lastError = null;

    try {
      _initStatus = '正在准备 yt-dlp 引擎...';
      onProgress?.call(0.3, _initStatus);

      // 从 assets 提取到可执行目录
      final path = await _channel.invokeMethod<String>('extractBinary', {
        'assetPath': 'bin/yt-dlp',
      });

      if (path == null) {
        _lastError = '无法提取 yt-dlp 二进制到可执行目录';
        _initStatus = '初始化失败';
        onProgress?.call(0, _initStatus);
        return false;
      }

      _binaryPath = path;
      _initStatus = '验证 yt-dlp...';
      onProgress?.call(0.8, _initStatus);

      // 验证
      final result = await _execBinary(['--version']);
      if (result['exitCode'] == 0) {
        _initialized = true;
        final version = (result['stdout'] as String).trim();
        _initStatus = 'yt-dlp 就绪 (v$version)';
        onProgress?.call(1.0, _initStatus);
        return true;
      }

      _lastError = '验证失败: exitCode=${result['exitCode']}\n'
          'stderr: ${result['stderr']}\n'
          'path: $_binaryPath';
      _initStatus = 'yt-dlp 验证失败';
      onProgress?.call(0, _initStatus);
      return false;
    } catch (e) {
      _lastError = '初始化异常: $e';
      _initStatus = '初始化失败';
      onProgress?.call(0, _initStatus);
      return false;
    }
  }

  Future<Map<String, dynamic>> _execBinary(List<String> args) async {
    if (_binaryPath == null) {
      return {'exitCode': -1, 'stdout': '', 'stderr': '二进制路径未设置'};
    }

    try {
      final appDir = (await getApplicationDocumentsDirectory()).path;
      final tmpDir = (await getTemporaryDirectory()).path;

      final result = await _channel.invokeMethod<Map>('exec', {
        'binaryPath': _binaryPath,
        'args': args,
        'env': {
          'HOME': appDir,
          'TMPDIR': tmpDir,
          'PATH': '/system/bin:/system/xbin',
        },
        'timeout': 120,
      });

      if (result == null) {
        return {'exitCode': -1, 'stdout': '', 'stderr': '原生层返回 null'};
      }

      return {
        'exitCode': result['exitCode'] ?? -1,
        'stdout': result['stdout'] ?? '',
        'stderr': result['stderr'] ?? '',
        'timeout': result['timeout'] ?? false,
      };
    } catch (e) {
      return {'exitCode': -1, 'stdout': '', 'stderr': 'MethodChannel 异常: $e'};
    }
  }

  Future<AudioInfo?> extractAudio(String videoUrl) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) return null;
    }

    final result = await _execBinary([
      '--no-warnings', '--no-playlist', '-j',
      '-f', 'bestaudio/best', '--no-check-certificates',
      videoUrl,
    ]);

    if (result['exitCode'] != 0) {
      throw Exception('yt-dlp 错误: ${result['stderr']}');
    }

    final jsonStr = (result['stdout'] as String).trim();
    if (jsonStr.isEmpty) throw Exception('yt-dlp 返回为空');
    return _parseAudioInfo(jsonStr);
  }

  Future<String?> getAudioUrl(String videoUrl) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) return null;
    }

    final result = await _execBinary([
      '--no-warnings', '--no-playlist', '--get-url',
      '-f', 'bestaudio/best', '--no-check-certificates',
      videoUrl,
    ]);

    if (result['exitCode'] != 0) return null;
    final url = (result['stdout'] as String).trim();
    return url.isNotEmpty ? url : null;
  }

  Future<String?> getTitle(String videoUrl) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) return null;
    }

    final result = await _execBinary([
      '--no-warnings', '--no-playlist', '--get-title',
      '--no-check-certificates', videoUrl,
    ]);

    if (result['exitCode'] != 0) return null;
    final title = (result['stdout'] as String).trim();
    return title.isNotEmpty ? title : null;
  }

  AudioInfo _parseAudioInfo(String jsonStr) {
    String? extractString(String key) {
      final pattern = RegExp('"$key"\\s*:\\s*"([^"]*)"');
      return pattern.firstMatch(jsonStr)?.group(1);
    }

    int? extractInt(String key) {
      final pattern = RegExp('"$key"\\s*:\\s*(\\d+)');
      final match = pattern.firstMatch(jsonStr);
      return match != null ? int.tryParse(match.group(1)!) : null;
    }

    return AudioInfo(
      title: extractString('title') ?? '未知标题',
      url: extractString('url') ?? extractString('webpage_url') ?? '',
      extractor: extractString('extractor') ?? '',
      duration: extractInt('duration') ?? 0,
      extension: extractString('ext') ?? 'm4a',
    );
  }

  void dispose() {}
}

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
    return title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  String get durationText {
    if (duration <= 0) return '';
    final mins = (duration ~/ 60).toString().padLeft(2, '0');
    final secs = (duration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
