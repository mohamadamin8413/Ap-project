class Playlist {
  final int id;
  String name;
  String creatorEmail;
  final List<int> songIds;
  DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.creatorEmail,
    required this.songIds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      creatorEmail: json['creatorEmail'],
      songIds: (json['songIds'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'creatorEmail': creatorEmail,
    'songIds': songIds,
    'createdAt': createdAt.toIso8601String(),
  };
}