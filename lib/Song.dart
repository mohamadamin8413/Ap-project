class Music {
  final int id;
  final String title;
  final String artist;
  final String filePath;
  final DateTime uploadDate;

  Music({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    required this.uploadDate,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      filePath: json['filePath'],
      uploadDate: DateTime.parse(json['uploadDate']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'filePath': filePath,
    'uploadDate': uploadDate.toIso8601String(),
  };
}