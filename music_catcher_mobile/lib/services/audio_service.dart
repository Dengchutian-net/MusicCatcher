import 'package:just_audio/just_audio.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  SongInfo? _currentSong;

  AudioPlayer get player => _player;
  SongInfo? get currentSong => _currentSong;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> playFile(String filePath, String title) async {
    _currentSong = SongInfo(title: title, filePath: filePath);
    await _player.setFilePath(filePath);
    await _player.play();
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);

  void dispose() {
    _player.dispose();
  }
}

class SongInfo {
  final String title;
  final String filePath;
  SongInfo({required this.title, required this.filePath});
}
