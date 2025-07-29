import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'User.dart';

class AppStorage {
  late final File _userFile;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _userFile = File('${dir.path}/user.json');
    if (!await _userFile.exists()) await _userFile.create();
    _isInitialized = true;
  }

  Future<User?> loadCurrentUser() async {
    await init();
    if (!await _userFile.exists()) return null;
    final data = await _userFile.readAsString();
    if (data.trim().isEmpty) return null;
    return User.fromJson(jsonDecode(data));
  }

  Future<void> saveCurrentUser(User user) async {
    await init();
    await _userFile.writeAsString(jsonEncode(user.toJson()));
  }

  Future<void> resetCurrentUser() async {
    await init();
    await _userFile.writeAsString('');
  }
}