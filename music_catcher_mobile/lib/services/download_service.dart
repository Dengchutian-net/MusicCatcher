import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final Dio _dio = Dio();

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
      f.path.endsWith('.flac')
    ).toList();
  }

  Future<void> downloadAudio(String url, String fileName,
      void Function(double progress, String status)? onProgress) async {
    final dir = await downloadDir;
    final filePath = '$dir/$fileName';

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
      );
      onProgress?.call(1.0, '下载完成');
    } catch (e) {
      onProgress?.call(0, '下载失败: $e');
      rethrow;
    }
  }
}
