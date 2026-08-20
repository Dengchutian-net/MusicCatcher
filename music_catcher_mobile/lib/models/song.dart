class Song {
  final String title;
  final String filePath;
  final Duration duration;

  Song({
    required this.title,
    required this.filePath,
    this.duration = Duration.zero,
  });

  String get fileName => filePath.split('/').last;
}
