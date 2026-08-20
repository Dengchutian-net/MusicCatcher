import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/download_service.dart';
import '../services/audio_service.dart';
import '../widgets/mechanical_button.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _downloadService = DownloadService();
  final _audioService = AudioPlayerService();
  List<FileSystemEntity> _songs = [];
  int? _playingIndex;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    final songs = await _downloadService.getDownloadedSongs();
    setState(() => _songs = songs);
  }

  Future<void> _playSong(int index) async {
    final file = _songs[index];
    final title = file.path.split('/').last;
    await _audioService.playFile(file.path, title);
    setState(() => _playingIndex = index);
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSongs),
        ],
      ),
      body: _songs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_off, size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('暂无歌曲', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('去下载页添加歌曲', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final file = _songs[index];
                final name = file.path.split('/').last;
                final isPlaying = _playingIndex == index;
                final size = file.statSync().size;
                final sizeStr = size > 1048576
                    ? '${(size / 1048576).toStringAsFixed(1)} MB'
                    : '${(size / 1024).toStringAsFixed(0)} KB';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPlaying
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      isPlaying ? Icons.music_note : Icons.audiotrack,
                      color: isPlaying
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(sizeStr),
                  trailing: isPlaying
                      ? StreamBuilder<PlayerState>(
                          stream: _audioService.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return MechanicalIconButton(
                              size: 36,
                              icon: playing ? Icons.pause : Icons.play_arrow,
                              onPressed: () {
                                playing ? _audioService.pause() : _audioService.play();
                              },
                            );
                          },
                        )
                      : null,
                  onTap: () => _playSong(index),
                );
              },
            ),
      bottomSheet: _playingIndex != null ? _buildPlayerBar() : null,
    );
  }

  Widget _buildPlayerBar() {
    return StreamBuilder<Duration>(
      stream: _audioService.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _audioService.duration;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _songs[_playingIndex!].path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: progress),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position),
                      style: Theme.of(context).textTheme.bodySmall),
                  MechanicalIconButton(
                    size: 44,
                    icon: _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                    onPressed: () {
                      _audioService.isPlaying
                          ? _audioService.pause()
                          : _audioService.play();
                    },
                  ),
                  Text(_formatDuration(duration),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
