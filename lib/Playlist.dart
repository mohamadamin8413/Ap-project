class Playlist {
  final int id;
  final String name;
  final String creatorEmail;
  final List<int> songIds;
  final List<Map<String, dynamic>> musics;

  Playlist({
    required this.id,
    required this.name,
    required this.creatorEmail,
    required this.songIds,
    required this.musics,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final musicsJson = (json['musics'] as List<dynamic>?) ?? [];
    final musics = musicsJson.map<Map<String,dynamic>>((m) {
      return {
        'id': m['id'],
        'title': m['title'],
        'artist': m['artist'],
        'filePath': m['filePath'],
      };
    }).toList();
    final ids = (json['songIds'] as List<dynamic>?)
        ?.map<int>((e) => e as int)
        .toList() ?? (musics.map((m) => m['id'] as int).toList());
    return Playlist(
      id: json['id'] as int,
      name: json['name'] as String,
      creatorEmail: json['creatorEmail'] as String? ?? '',
      songIds: ids,
      musics: musics,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'creatorEmail': creatorEmail,
    'songIds': songIds,
    'musics': musics,
  };
}