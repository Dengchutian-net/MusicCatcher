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
  bool _ytdlpLoading = true;
  String _ytdlpStatus = '检查中...';

  @override
  void initState() {
    super.initState();
    _initYtdlp();
  }

  Future<void> _initYtdlp() async {
    setState(() {
      _ytdlpLoading = true;
      _ytdlpStatus = '正在初始化 yt-dlp...';
    });
    final ok = await _downloadService.ytdlp.init(
      onProgress: (p, s) {
        if (mounted) setState(() => _ytdlpStatus = s);
      },
    );
    if (mounted) {
      setState(() {
        _ytdlpReady = ok;
        _ytdlpLoading = false;
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

  void _showErrorDetail() {
    final error = _downloadService.ytdlp.lastError ?? '未知错误';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('yt-dlp 初始化详情'),
        content: SingleChildScrollView(
          child: Text(error, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
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
            // yt-dlp 状态
            Card(
              color: _ytdlpReady
                  ? Theme.of(context).colorScheme.primaryContainer
                  : _ytdlpLoading
                      ? Theme.of(context).colorScheme.surfaceContainerHigh
                      : Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    if (_ytdlpLoading)
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      )
                    else
                      Icon(
                        _ytdlpReady ? Icons.check_circle : Icons.error_outline,
                        size: 16,
                        color: _ytdlpReady
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_ytdlpStatus, style: TextStyle(fontSize: 12,
                        color: _ytdlpReady
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : _ytdlpLoading
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onErrorContainer,
                      ), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    if (!_ytdlpReady && !_ytdlpLoading) ...[
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _showErrorDetail,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _initYtdlp,
                      ),
                    ],
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
            MechanicalButton(
              onPressed: _isDownloading ? null : _download,
              depth: 5,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isDownloading)
                    const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Icons.download, size: 20),
                  const SizedBox(width: 8),
                  Text(_isDownloading ? '下载中...' : '开始下载'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              Text(_status, style: Theme.of(context).textTheme.bodySmall),
            ],
            const Spacer(),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 32,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      '支持 B站、YouTube 等主流网站。\n'
                      'yt-dlp 引擎已内置，无需额外下载。\n'
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
