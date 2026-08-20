import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'ytdlp_service.dart';

class DownloadService {
  final Dio _dio = Dio();
  final YtdlpService _ytdlp = YtdlpService();

  YtdlpService get ytdlp => _ytdlp;

  Future<String> get downloadDir async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/MusicCatcher');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<List<FileSystemEntity>> getDownloadedSongs() async {
    final dir = await downloadDir;
    final directory = Directory(dir);
    final files = directory.listSync()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files.where((f) =>
      f.path.endsWith('.mp3') ||
      f.path.endsWith('.m4a') ||
      f.path.endsWith('.wav') ||
      f.path.endsWith('.flac') ||
      f.path.endsWith('.ogg') ||
      f.path.endsWith('.webm') ||
      f.path.endsWith('.opus')
    ).toList();
  }

  /// 智能下载：自动识别是否为平台链接，使用 yt-dlp 提取后下载
  Future<void> downloadAudio(String url, String? fileName,
      void Function(double progress, String status)? onProgress) async {

    // 1. 初始化 yt-dlp（如果还没初始化）
    onProgress?.call(0, '正在初始化 yt-dlp...');
    final ytdlpReady = await _ytdlp.init(
      onProgress: (p, s) => onProgress?.call(p * 0.2, s),
    );

    if (!ytdlpReady) {
      // yt-dlp 不可用，尝试直接下载
      onProgress?.call(0.2, 'yt-dlp 不可用，尝试直接下载...');
      await _directDownload(url, fileName, (p, s) {
        onProgress?.call(0.2 + p * 0.8, s);
      });
      return;
    }

    // 2. 用 yt-dlp 提取音频信息
    onProgress?.call(0.2, '正在解析链接...');

    try {
      final audioInfo = await _ytdlp.extractAudio(url);
      if (audioInfo == null || audioInfo.url.isEmpty) {
        throw Exception('无法提取音频链接');
      }

      // 3. 确定文件名
      final ext = audioInfo.extension;
      final safeTitle = audioInfo.sanitizedTitle;
      final finalFileName = fileName ?? '$safeTitle.$ext';

      onProgress?.call(0.3, '准备下载: $safeTitle');

      // 4. 下载音频文件
      final dir = await downloadDir;
      final filePath = '$dir/$finalFileName';

      await _dio.download(
        audioInfo.url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = 0.3 + (received / total) * 0.7;
            final percent = ((received / total) * 100).toStringAsFixed(0);
            onProgress?.call(progress, '下载中 $percent%');
          }
        },
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
          },
          followRedirects: true,
        ),
      );

      onProgress?.call(1.0, '下载完成: $safeTitle');
    } catch (e) {
      // yt-dlp 失败，尝试直接下载
      onProgress?.call(0.2, '解析失败，尝试直接下载...');
      await _directDownload(url, fileName, (p, s) {
        onProgress?.call(0.2 + p * 0.8, s);
      });
    }
  }

  /// 直接下载（用于直链 URL）
  Future<void> _directDownload(String url, String? fileName,
      void Function(double progress, String status)? onProgress) async {
    final dir = await downloadDir;

    // 推断文件名
    final finalFileName = fileName ?? _inferFileName(url);
    final filePath = '$dir/$finalFileName';

    try {
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            final progress = received / total;
            onProgress(progress, '下载中 ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
          },
          followRedirects: true,
        ),
      );
      onProgress?.call(1.0, '下载完成');
    } catch (e) {
      onProgress?.call(0, '下载失败: $e');
      rethrow;
    }
  }

  /// 从 URL 推断文件名
  String _inferFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final last = pathSegments.last;
        if (last.contains('.')) {
          return last;
        }
      }
    } catch (_) {}
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'audio_$timestamp.mp3';
  }

  void dispose() {
    _dio.close();
    _ytdlp.dispose();
  }
}
