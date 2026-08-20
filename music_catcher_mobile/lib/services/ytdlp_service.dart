import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// yt-dlp 本地执行服务
/// 通过 Android MethodChannel 在原生层执行 yt-dlp 二进制
class YtdlpService {
  static const _binaryName = 'yt-dlp';
  static const _channel = MethodChannel('com.musiccatcher/native_exec');

  /// 多个下载源（国内镜像 + 官方），依次尝试
  static const _downloadUrls = [
    'https://ghfast.top/https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64',
    'https://ghproxy.cn/https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64',
    'https://mirror.ghproxy.com/https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64',
    'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64',
  ];

  final Dio _dio = Dio();
  String? _binaryPath;
  bool _initialized = false;
  String _initStatus = '未初始化';
  double _initProgress = 0;
  String? _lastError;

  bool get isReady => _initialized;
  String get initStatus => _initStatus;
  double get initProgress => _initProgress;
  String? get binaryPath => _binaryPath;
  String? get lastError => _lastError;

  /// 获取设备 CPU 架构
  Future<String> getAbi() async {
    try {
      final abi = await _channel.invokeMethod<String>('getAbi');
      return abi ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// 通过原生层设置文件可执行权限
  Future<bool> _setExecutable(String path) async {
    try {
      final result = await _channel.invokeMethod<bool>('setExecutable', {'path': path});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 初始化：检查或下载 yt-dlp 二进制
  Future<bool> init({void Function(double progress, String status)? onProgress}) async {
    if (_initialized) return true;
    _lastError = null;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final binDir = Directory('${appDir.path}/bin');
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      _binaryPath = '${binDir.path}/$_binaryName';
      final binaryFile = File(_binaryPath!);

      // 检查已有的二进制
      if (await binaryFile.exists()) {
        final fileSize = await binaryFile.length();
        if (fileSize < 10000) {
          await binaryFile.delete();
        } else {
          _initStatus = '验证 yt-dlp...';
          onProgress?.call(1.0, _initStatus);
          final result = await _execBinary(['--version']);
          if (result['exitCode'] == 0) {
            _initialized = true;
            final version = (result['stdout'] as String).trim();
            _initStatus = 'yt-dlp 就绪 (v$version)';
            onProgress?.call(1.0, _initStatus);
            return true;
          }
          _lastError = '执行失败: ${result['stderr']}';
          await binaryFile.delete();
        }
      }

      // 获取设备架构
      final abi = await getAbi();
      _lastError = '设备架构: $abi';

      // 尝试多个镜像下载
      _initStatus = '正在下载 yt-dlp...';
      _initProgress = 0;
      onProgress?.call(0, _initStatus);

      bool downloaded = false;
      for (int i = 0; i < _downloadUrls.length; i++) {
        final url = _downloadUrls[i];
        final mirrorName = _getMirrorName(url);
        _initStatus = '下载 yt-dlp ($mirrorName)...';
        onProgress?.call(0, _initStatus);

        try {
          await _dio.download(
            url,
            _binaryPath!,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                _initProgress = received / total;
                final percent = (_initProgress * 100).toStringAsFixed(0);
                _initStatus = '下载 yt-dlp $percent% ($mirrorName)';
                onProgress?.call(_initProgress, _initStatus);
              }
            },
            options: Options(
              headers: {'Accept': 'application/octet-stream'},
              followRedirects: true,
              receiveTimeout: const Duration(seconds: 120),
              connectTimeout: const Duration(seconds: 30),
            ),
          );

          final file = File(_binaryPath!);
          if (await file.exists() && await file.length() > 10000) {
            downloaded = true;
            break;
          } else {
            _lastError = '$mirrorName: 下载文件太小';
            if (await file.exists()) await file.delete();
          }
        } catch (e) {
          _lastError = '$mirrorName: $e';
          continue;
        }
      }

      if (!downloaded) {
        _initStatus = '下载失败：所有镜像均不可用';
        onProgress?.call(0, _initStatus);
        return false;
      }

      // 通过原生层设置可执行权限
      _initStatus = '设置权限...';
      onProgress?.call(0.9, _initStatus);
      final chmodOk = await _setExecutable(_binaryPath!);
      if (!chmodOk) {
        _lastError = '设置可执行权限失败';
      }

      // 验证二进制
      _initStatus = '验证安装...';
      onProgress?.call(1.0, _initStatus);
      final result = await _execBinary(['--version']);
      if (result['exitCode'] == 0) {
        _initialized = true;
        final version = (result['stdout'] as String).trim();
        _initStatus = 'yt-dlp 就绪 (v$version)';
        onProgress?.call(1.0, _initStatus);
        return true;
      }

      final stderr = result['stderr'] ?? '';
      final exitCode = result['exitCode'];
      _lastError = '验证失败: exitCode=$exitCode\nstderr: $stderr\npath: $_binaryPath';
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

  String _getMirrorName(String url) {
    if (url.contains('ghfast.top')) return '镜像1';
    if (url.contains('ghproxy.cn')) return '镜像2';
    if (url.contains('mirror.ghproxy')) return '镜像3';
    return '官方';
  }

  /// 通过原生层执行 yt-dlp 二进制
  Future<Map<String, dynamic>> _execBinary(List<String> args) async {
    try {
      final appDir = (await getApplicationDocumentsDirectory()).path;
      final tmpDir = (await getTemporaryDirectory()).path;

      final result = await _channel.invokeMethod<Map>('exec', {
        'command': _binaryPath,
        'args': args,
        'env': {
          'HOME': appDir,
          'TMPDIR': tmpDir,
          'PATH': '/system/bin:/system/xbin:$appDir/bin',
        },
        'workDir': appDir,
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

  /// 从视频链接提取最佳音频下载 URL
  Future<AudioInfo?> extractAudio(String videoUrl) async {
    if (!_initialized || _binaryPath == null) {
      final ok = await init();
      if (!ok) return null;
    }

    try {
      final result = await _execBinary([
        '--no-warnings',
        '--no-playlist',
        '-j',
        '-f', 'bestaudio/best',
        '--no-check-certificates',
        videoUrl,
      ]);

      if (result['exitCode'] != 0) {
        throw Exception('yt-dlp 错误: ${result['stderr']}');
      }

      final jsonStr = (result['stdout'] as String).trim();
      if (jsonStr.isEmpty) throw Exception('yt-dlp 返回为空');

      return _parseAudioInfo(jsonStr);
    } catch (e) {
      throw Exception('提取音频失败: $e');
    }
  }

  /// 直接获取音频下载 URL
  Future<String?> getAudioUrl(String videoUrl) async {
    if (!_initialized || _binaryPath == null) {
      final ok = await init();
      if (!ok) return null;
    }

    try {
      final result = await _execBinary([
        '--no-warnings',
        '--no-playlist',
        '--get-url',
        '-f', 'bestaudio/best',
        '--no-check-certificates',
        videoUrl,
      ]);

      if (result['exitCode'] != 0) return null;
      final url = (result['stdout'] as String).trim();
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
      final result = await _execBinary([
        '--no-warnings',
        '--no-playlist',
        '--get-title',
        '--no-check-certificates',
        videoUrl,
      ]);

      if (result['exitCode'] != 0) return null;
      final title = (result['stdout'] as String).trim();
      return title.isNotEmpty ? title : null;
    } catch (e) {
      return null;
    }
  }

  /// 解析 yt-dlp JSON 输出
  AudioInfo _parseAudioInfo(String jsonStr) {
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
    return title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }

  String get durationText {
    if (duration <= 0) return '';
    final mins = (duration ~/ 60).toString().padLeft(2, '0');
    final secs = (duration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
