import 'dart:typed_data';
import 'dart:io';

class Music {
  final int id;
  final String title;
  final String artist;
  final String filePath;
  final String? coverPath;

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

class Homepagesong {
  final int id;
  final String title;
  final String artist;
  final String filePath;
  final String? localPath;
  final String? uploaderEmail;
  final bool isFromServer;
  final DateTime addedAt;
  final Uint8List? coverBytes;

  Homepagesong({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    this.localPath,
    this.uploaderEmail,
    this.isFromServer = false,
    DateTime? addedAt,
    this.coverBytes,
  }) : addedAt = addedAt ?? DateTime.now();

  factory Homepagesong.fromJson(Map<String, dynamic> json) {
    String addedAtString = json['addedAt'] as String? ?? DateTime.now().toIso8601String();
    DateTime addedAt;
    try {
      addedAt = DateTime.parse(addedAtString);
    } catch (e) {
      addedAt = DateTime.now();
    }
    return Homepagesong(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String? ?? 'Unknown',
      filePath: json['filePath'] as String? ?? '',
      localPath: json['localPath'] as String?,
      uploaderEmail: json['uploaderEmail'] as String?,
      isFromServer: json['uploaderEmail'] != null && json['uploaderEmail'] != '',
      addedAt: addedAt,
      coverBytes: null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'filePath': filePath,
    'localPath': localPath,
    'uploaderEmail': uploaderEmail,
    'isFromServer': isFromServer,
    'addedAt': addedAt.toIso8601String(),
  };

  Homepagesong copyWith({
    Uint8List? coverBytes,
    String? localPath,
    String? title,
    String? artist,
  }) {
    return Homepagesong(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      filePath: filePath,
      localPath: localPath ?? this.localPath,
      uploaderEmail: uploaderEmail,
      isFromServer: isFromServer,
      addedAt: addedAt,
      coverBytes: coverBytes ?? this.coverBytes,
    );
  }

  Music toMusic() {
    return Music(
      id: id,
      title: title,
      artist: artist,
      filePath: localPath != null && File(localPath!).existsSync() ? localPath! : filePath,
      coverPath: localPath != null ? '${localPath!.replaceAll('.mp3', '')}-cover.jpg' : null,
    );
  }
}