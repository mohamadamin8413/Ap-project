import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'User.dart';

class AppStorage {
  late final File _userFile;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _userFile = File('${dir.path}/user.json');
    if (!await _userFile.exists()) await _userFile.create();
  }

  Future<User?> loadCurrentUser() async {
    if (!await _userFile.exists()) return null;
    final data = await _userFile.readAsString();
    if (data.trim().isEmpty) return null;
    return User.fromJson(jsonDecode(data));
  }

  Future<void> saveCurrentUser(User user) async {
    await _userFile.writeAsString(jsonEncode(user.toJson()));
  }

  Future<void> resetCurrentUser() async {
    await _userFile.writeAsString('');
  }
}