class Music {
  final int id;
  final String title;
  final String artist;
  final String filePath;

  Music({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      filePath: json['filePath'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'filePath': filePath,
  };
}