class Music {
  final int id;
  final String title;
  final String artist;
  final String filePath;
  final String? coverPath; // مسیر کاور

  Music({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    this.coverPath,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      filePath: json['filePath'],
      coverPath: json['coverPath'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'filePath': filePath,
    'coverPath': coverPath,
  };
}