import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/download_service.dart';
import '../widgets/mechanical_button.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _urlController = TextEditingController();
  final _downloadService = DownloadService();
  double _progress = 0;
  String _status = '';
  bool _isDownloading = false;
  bool _ytdlpReady = false;
  String _ytdlpStatus = '检查中...';

  @override
  void initState() {
    super.initState();
    _initYtdlp();
  }

  Future<void> _initYtdlp() async {
    setState(() => _ytdlpStatus = '正在初始化 yt-dlp...');
    final ok = await _downloadService.ytdlp.init(
      onProgress: (p, s) {
        if (mounted) setState(() => _ytdlpStatus = s);
      },
    );
    if (mounted) {
      setState(() {
        _ytdlpReady = ok;
        _ytdlpStatus = _downloadService.ytdlp.initStatus;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _downloadService.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!.trim();
    }
  }

  Future<void> _download() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _status = '请输入链接');
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _status = '准备下载...';
    });

    try {
      await _downloadService.downloadAudio(url, null, (progress, status) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _status = status;
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _status = '下载失败: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下载')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // yt-dlp 状态指示
            Card(
              color: _ytdlpReady
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _ytdlpReady ? Icons.check_circle : Icons.sync,
                      size: 18,
                      color: _ytdlpReady
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _ytdlpStatus,
                        style: TextStyle(
                          fontSize: 12,
                          color: _ytdlpReady
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_ytdlpReady)
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 链接输入
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('音乐链接', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              hintText: '粘贴 B站 / YouTube 等链接...',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.paste),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 下载按钮
            MechanicalButton(
              onPressed: _isDownloading ? null : _download,
              depth: 5,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isDownloading)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.download, size: 20),
                  const SizedBox(width: 8),
                  Text(_isDownloading ? '下载中...' : '开始下载'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 进度
            if (_status.isNotEmpty) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              Text(_status, style: Theme.of(context).textTheme.bodySmall),
            ],
            const Spacer(),
            // 提示
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline,
                        size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      '支持 B站、YouTube 等主流网站。\n'
                      '首次使用需下载 yt-dlp 引擎（约15MB）。\n'
                      '也可直接粘贴 .mp3/.m4a 音频直链。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
