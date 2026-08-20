import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _isInitialized = false;
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();

  bool get isRecording => _isRecording;
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Future<String> get recordDir async {
    final dir = await getApplicationDocumentsDirectory();
    final recordDir = Directory('${dir.path}/MusicCatcher/Recordings');
    if (!await recordDir.exists()) {
      await recordDir.create(recursive: true);
    }
    return recordDir.path;
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    await _recorder.openRecorder();
    _isInitialized = true;
  }

  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    await _init();
    final dir = await recordDir;
    final timestamp = DateTime.now().toString().replaceAll(RegExp(r'[:.]'), '-');
    final path = '$dir/录制_$timestamp.m4a';

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
      bitRate: 128000,
      sampleRate: 44100,
    );
    _isRecording = true;

    // 模拟振幅流（flutter_sound 的 onProgress 在某些设备上不稳定）
    _startAmplitudeSimulation();
  }

  void _startAmplitudeSimulation() {
    // 每100ms更新一次振幅（用于UI电平显示）
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      // flutter_sound 的 getProgress 可以获取当前录音状态
      _amplitudeController.add(-20 + (DateTime.now().millisecondsSinceEpoch % 40));
    });
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stopRecorder();
    _isRecording = false;
    return path;
  }

  void dispose() {
    _isRecording = false;
    _amplitudeController.close();
    if (_isInitialized) {
      _recorder.closeRecorder();
    }
  }
}
