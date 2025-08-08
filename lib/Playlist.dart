class Playlist {
  final int id;
  final String name;
  final String creatorEmail;
  final List<int> songIds;

  Playlist({
    required this.id,
    required this.name,
    required this.creatorEmail,
    required this.songIds,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      name: json['name'] as String,
      creatorEmail: json['creatorEmail'] as String,
      songIds: (json['songIds'] as List<dynamic>?)?.cast<int>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'creatorEmail': creatorEmail,
    'songIds': songIds,
  };
}