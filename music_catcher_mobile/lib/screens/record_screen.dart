import 'package:flutter/material.dart';
import '../services/record_service.dart';
import '../widgets/mechanical_button.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _recordService = RecordService();
  bool _isRecording = false;
  String _status = '准备就绪';
  String? _lastRecordPath;
  Duration _recordDuration = Duration.zero;
  DateTime? _recordStart;

  @override
  void dispose() {
    _recordService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recordService.stopRecording();
      setState(() {
        _isRecording = false;
        _status = '录制完成';
        _lastRecordPath = path;
        _recordDuration = DateTime.now().difference(_recordStart!);
      });
    } else {
      await _recordService.startRecording();
      setState(() {
        _isRecording = true;
        _status = '正在录制...';
        _recordStart = DateTime.now();
        _lastRecordPath = null;
      });
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('录制')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(_status, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 24),
                    // 时间显示
                    if (_isRecording)
                      StreamBuilder<double>(
                        stream: _recordService.amplitudeStream,
                        builder: (context, snapshot) {
                          final elapsed = DateTime.now().difference(_recordStart!);
                          return Column(
                            children: [
                              Text(
                                _formatDuration(elapsed),
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w200,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 电平指示器
                              _LevelIndicator(
                                amplitude: snapshot.data ?? -160,
                              ),
                            ],
                          );
                        },
                      )
                    else if (_recordDuration > Duration.zero)
                      Text(
                        _formatDuration(_recordDuration),
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w200,
                          fontFamily: 'monospace',
                        ),
                      )
                    else
                      Icon(Icons.mic, size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 录制按钮 - 机械按键风格
            MechanicalButton(
              onPressed: _toggleRecording,
              color: _isRecording
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              depth: 7,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record, size: 22),
                  const SizedBox(width: 10),
                  Text(_isRecording ? '停止录制' : '开始录制',
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_lastRecordPath != null)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                  title: Text('已保存', style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  subtitle: Text(_lastRecordPath!.split('/').last,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer)),
                ),
              ),
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
                      '使用手机麦克风录制周围声音。\n适合录制无法直接下载的音乐。',
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

class _LevelIndicator extends StatelessWidget {
  final double amplitude;

  const _LevelIndicator({required this.amplitude});

  @override
  Widget build(BuildContext context) {
    // amplitude is in dB, range roughly -160 to 0
    final normalized = ((amplitude + 160) / 160).clamp(0.0, 1.0);
    final barCount = 20;
    final activeBars = (normalized * barCount).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(barCount, (i) {
        final isActive = i < activeBars;
        Color color;
        if (i < barCount * 0.6) {
          color = Colors.green;
        } else if (i < barCount * 0.85) {
          color = Colors.orange;
        } else {
          color = Colors.red;
        }

        return Container(
          width: 6,
          height: 24 + (i * 1.5),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
