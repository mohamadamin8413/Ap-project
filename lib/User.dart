class User {
  final int? id;
  final String email;
  final String username;
  final String password;
  final bool allowSharing;

  User({
    this.id,
    required this.email,
    required this.username,
    required this.password,
    this.allowSharing = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int?,
      email: json['email'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      allowSharing: json['allowSharing'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'password': password,
    'allowSharing': allowSharing,
  };
}