import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// yt-dlp 本地执行服务
/// 下载到 app 私有目录，复制到 /data/local/tmp/ 执行
class YtdlpService {
  static const _binaryName = 'yt-dlp';
  static const _channel = MethodChannel('com.musiccatcher/native_exec');

  static const _downloadUrls = [
    'https://ghfast.top/https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64',
    'https://ghproxy.cn/https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64',
    'https://mirror.ghproxy.com/https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64',
    'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64',
  ];

  final Dio _dio = Dio();
  String? _storagePath;   // 存储路径（app 私有目录）
  String? _execPath;      // 可执行路径（/data/local/tmp/）
  bool _initialized = false;
  String _initStatus = '未初始化';
  double _initProgress = 0;
  String? _lastError;

  bool get isReady => _initialized;
  String get initStatus => _initStatus;
  double get initProgress => _initProgress;
  String? get lastError => _lastError;

  Future<String> getAbi() async {
    try {
      return await _channel.invokeMethod<String>('getAbi') ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// 将二进制复制到可执行目录
  Future<String?> _prepareBinary(String srcPath) async {
    try {
      final result = await _channel.invokeMethod<String>('prepareBinary', {
        'srcPath': srcPath,
        'name': _binaryName,
      });
      return result;
    } catch (e) {
      _lastError = 'prepareBinary 异常: $e';
      return null;
    }
  }

  Future<bool> init({void Function(double progress, String status)? onProgress}) async {
    if (_initialized) return true;
    _lastError = null;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final storageDir = Directory('${appDir.path}/bin');
      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }

      _storagePath = '${storageDir.path}/$_binaryName';
      final storageFile = File(_storagePath!);

      // 检查已下载的二进制
      if (await storageFile.exists()) {
        final fileSize = await storageFile.length();
        if (fileSize < 10000) {
          await storageFile.delete();
        } else {
          // 已下载，尝试复制到可执行目录并验证
          _initStatus = '准备执行环境...';
          onProgress?.call(1.0, _initStatus);

          _execPath = await _prepareBinary(_storagePath!);
          if (_execPath != null) {
            final result = await _execBinary(['--version']);
            if (result['exitCode'] == 0) {
              _initialized = true;
              final version = (result['stdout'] as String).trim();
              _initStatus = 'yt-dlp 就绪 (v$version)';
              onProgress?.call(1.0, _initStatus);
              return true;
            }
            _lastError = '执行失败: ${result['stderr']}';
          } else {
            _lastError = '无法创建可执行目录';
          }
          // 重新下载
          await storageFile.delete();
        }
      }

      // 下载 yt-dlp
      _initStatus = '正在下载 yt-dlp...';
      _initProgress = 0;
      onProgress?.call(0, _initStatus);

      bool downloaded = false;
      for (final url in _downloadUrls) {
        final mirrorName = _getMirrorName(url);
        _initStatus = '下载 yt-dlp ($mirrorName)...';
        onProgress?.call(0, _initStatus);

        try {
          await _dio.download(
            url,
            _storagePath!,
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
              receiveTimeout: const Duration(seconds: 180),
              connectTimeout: const Duration(seconds: 30),
            ),
          );

          final file = File(_storagePath!);
          if (await file.exists() && await file.length() > 10000) {
            downloaded = true;
            break;
          }
          if (await file.exists()) await file.delete();
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

      // 复制到可执行目录
      _initStatus = '准备执行环境...';
      onProgress?.call(0.9, _initStatus);

      _execPath = await _prepareBinary(_storagePath!);
      if (_execPath == null) {
        _initStatus = '无法创建可执行环境';
        onProgress?.call(0, _initStatus);
        return false;
      }

      // 验证
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

      _lastError = '验证失败: exitCode=${result['exitCode']}\nstderr: ${result['stderr']}';
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

  /// 通过原生层执行 yt-dlp
  Future<Map<String, dynamic>> _execBinary(List<String> args) async {
    if (_execPath == null) {
      return {'exitCode': -1, 'stdout': '', 'stderr': '可执行路径未设置'};
    }

    try {
      final appDir = (await getApplicationDocumentsDirectory()).path;
      final tmpDir = (await getTemporaryDirectory()).path;

      final result = await _channel.invokeMethod<Map>('exec', {
        'binaryPath': _execPath,
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

  void dispose() {
    _dio.close();
  }
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
