
import 'Song.dart';

class User {
  final int id;
  String username;
  String password;
  String email;
  final List<Music> likedSongs;

  User({
    required this.id,
    required this.username,
    required this.password,
    required this.email,
    List<Music>? likedSongs,
  }) : likedSongs = likedSongs ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      password: json['password'],
      email: json['email'],
      likedSongs: (json['likedMusics'] as List<dynamic>?)
          ?.map((e) => Music.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'password': password,
    'email': email,
    'likedMusics': likedSongs.map((s) => s.toJson()).toList(),
  };

  int getid() => id;
}