import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:projectap/Homepage.dart';
import 'package:projectap/Playlist.dart';
import 'package:projectap/ProfilePage.dart';
import 'package:projectap/Song.dart';
import 'package:projectap/User.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/playermusicpage.dart';

AppStorage storage = AppStorage();

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  List<Playlist> playlists = [];
  List<Homepagesong> userSongs = [];
  bool isLoading = false;
  User? currentUser;
  final TextEditingController _playlistNameController = TextEditingController();
  int _selectedIndex = 1;

  // StreamController برای مدیریت state پلی‌لیست‌ها
  final StreamController<List<Playlist>> _playlistStreamController =
      StreamController<List<Playlist>>.broadcast();

  // StreamController برای مدیریت state آهنگ‌ها
  final StreamController<List<Homepagesong>> _songStreamController =
      StreamController<List<Homepagesong>>.broadcast();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();

    // گوش دادن به تغییرات در پلی‌لیست‌ها
    _playlistStreamController.stream.listen((updatedPlaylists) {
      if (mounted) {
        setState(() {
          playlists = updatedPlaylists;
        });
      }
    });
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    _playlistStreamController.close();
    _songStreamController.close();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await storage.loadCurrentUser();
    if (mounted) {
      setState(() {
        currentUser = user;
      });
    }
    if (user != null) {
      await _refreshData();
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() => isLoading = true);
    }
    try {
      await Future.wait([
        _loadUserPlaylists(), // فقط پلی‌لیست‌های سروری
        _loadUserSongs(),
      ]);
    } catch (e) {
      print('Error refreshing data: $e');
      _showMessage('Error refreshing data: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadUserPlaylists() async {
    if (currentUser == null) return;

    try {
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'list_user_playlists',
        data: {'email': currentUser!.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      print('Sending list_user_playlists request: ${request.toJson()}');
      final response = await socketService.send(request);
      print(
          'Raw server response for list_user_playlists: ${response.toJson()}');
      socketService.close();

      final serverPlaylists = <Playlist>[];
      if (response.isSuccess && response.data != null) {
        for (var json in response.data as List<dynamic>) {
          if (json['id'] != null && json['name'] != null && json['name'].toString().isNotEmpty) {
            final musics = (json['musics'] as List<dynamic>?) ?? [];
            final songIds = musics
                .where((m) => m['id'] != null)
                .map((m) => m['id'] as int)
                .toList();

            final playlist = Playlist.fromJson({
              'id': json['id'],
              'name': json['name'],
              'creatorEmail': json['creatorEmail'] ?? currentUser!.email,
              'songIds': songIds,
            });

            serverPlaylists.add(playlist);
          }
        }
        print('Loaded ${serverPlaylists.length} server playlists');
      }
      _playlistStreamController.add(serverPlaylists);
    } catch (e) {
      _showMessage('Error loading playlists: $e', error: true);
    }
  }

  Future<void> _loadUserSongs() async {
    if (currentUser == null) return;

    try {
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'list_user_musics',
        data: {'email': currentUser!.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      print('Sending list_user_musics request: ${request.toJson()}');
      final response = await socketService.send(request);
      print('Server response: ${response.toJson()}');
      socketService.close();

      if (response.isSuccess && response.data != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final loadedSongs = (response.data as List<dynamic>)
            .where((json) =>
                json['id'] != null &&
                json['title'] != null &&
                json['filePath'] != null)
            .map((json) {
          String? localPath;
          final expectedPath = '${appDir.path}/${json['title']}.mp3';
          if (File(expectedPath).existsSync()) {
            localPath = expectedPath;
          }

          String? coverPath;
          final possibleCoverNames = [
            if (json['coverPath'] != null) json['coverPath'],
            '${json['title']}-cover.jpg',
            'cover_${json['title']}.jpg',
          ];

          for (final coverName in possibleCoverNames) {
            final coverFile = File('${appDir.path}/$coverName');
            if (coverFile.existsSync()) {
              coverPath = coverFile.path;
              break;
            }
          }

          return Homepagesong.fromJson({
            'id': json['id'],
            'title': (json['title'] as String).trim(),
            'artist': json['artist'] ?? 'Unknown',
            'filePath': json['filePath'],
            'uploaderEmail': json['uploaderEmail'] ?? currentUser!.email,
            'isFromServer': json['uploaderEmail'] != null &&
                json['uploaderEmail'] != currentUser!.email,
            'addedAt': json['addedAt'] ?? DateTime.now().toIso8601String(),
            'localPath': localPath,
            'coverPath': coverPath,
          });
        }).toList();

        if (mounted) {
          setState(() {
            userSongs = loadedSongs;
          });
        }

        _songStreamController.add(loadedSongs);
        print('Loaded ${loadedSongs.length} user songs from server');
      } else {
        _showMessage('Failed to load songs: ${response.message}', error: true);
        if (mounted) {
          setState(() {
            userSongs = [];
          });
        }
      }
    } catch (e) {
      _showMessage('Error loading songs: $e', error: true);
      if (mounted) {
        setState(() {
          userSongs = [];
        });
      }
    }
  }

  List<Homepagesong> _getUserSongsOnly() {
    return userSongs
        .where((song) => song.uploaderEmail == currentUser?.email)
        .toList();
  }

  Future<List<Map<String, String>>> _loadUsers() async {
    if (currentUser == null) {
      print('No user logged in for loading users');
      _showMessage('Please log in to load users', error: true);
      return [];
    }

    try {
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'list_users',
        data: {},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      print('Sending list_users request: ${request.toJson()}');
      final response = await socketService.send(request);
      print('Raw server response for list_users: ${response.toJson()}');
      socketService.close();

      if (response.isSuccess && response.data != null) {
        final users = (response.data as List<dynamic>)
            .where((json) =>
                json['email'] != null &&
                json['email'] is String &&
                json['email'] != currentUser!.email)
            .map((json) => {
                  'email': json['email'] as String,
                  'username': json['username'] as String? ?? 'Unknown',
                })
            .toList();

        print('Loaded ${users.length} users');
        return users;
      } else {
        print('No users found in response: ${response.message}');
        _showMessage('No users available: ${response.message}', error: true);
        return [];
      }
    } catch (e) {
      print('Error loading users: $e');
      _showMessage('Error loading users: $e', error: true);
      return [];
    }
  }

  Future<void> _createPlaylist() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Create New Playlist',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: _playlistNameController,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: GoogleFonts.poppins(color: Colors.white54),
            prefixIcon: const Icon(Icons.queue_music, color: Color(0xFFCE93D8)),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFFCE93D8)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _playlistNameController.text.trim();
              if (name.isEmpty) {
                _showMessage('Please enter a playlist name', error: true);
                return;
              }

              // بررسی تکراری نبودن در پلی‌لیست‌های سروری
              if (playlists.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
                _showMessage('A playlist with this name already exists', error: true);
                return;
              }

              Navigator.pop(context);

              if (mounted) {
                setState(() => isLoading = true);
              }

              try {
                final socketService = SocketService();
                final request = SocketRequest(
                  action: 'create_playlist',
                  data: {
                    'email': currentUser!.email,
                    'name': name,
                  },
                  requestId: DateTime.now().millisecondsSinceEpoch.toString(),
                );

                print('Sending create_playlist request: ${request.toJson()}');
                final response = await socketService.send(request);
                print('Create playlist response: ${response.toJson()}');
                socketService.close();

                if (response.isSuccess) {
                  _showMessage('Playlist created successfully');
                  await _refreshData(); // دریافت مجدد از سرور
                } else {
                  _showMessage('Failed to create playlist: ${response.message}', error: true);
                }
              } catch (e) {
                _showMessage('Error creating playlist: $e', error: true);
              } finally {
                if (mounted) {
                  setState(() => isLoading = false);
                }
                _playlistNameController.clear();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCE93D8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Create',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Playlist',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${playlist.name}"?',
          style: GoogleFonts.poppins(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFFCE93D8)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'delete_playlist',
        data: {
          'email': currentUser!.email,
          'playlist_name': playlist.name,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      print('Sending delete_playlist request: ${request.toJson()}');
      final response = await socketService.send(request);
      print('Delete playlist response: ${response.toJson()}');
      socketService.close();

      if (response.isSuccess) {
        _showMessage('Playlist deleted successfully');
        final updatedPlaylists =
            playlists.where((p) => p.id != playlist.id).toList();
        _playlistStreamController.add(updatedPlaylists);
      } else {
        _showMessage('Failed to delete playlist: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error deleting playlist: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _sharePlaylist(Playlist playlist) async {
    if (currentUser == null) {
      _showMessage('No user logged in', error: true);
      return;
    }

    final users = await _loadUsers();
    if (users.isEmpty) {
      _showMessage('No users available for sharing', error: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Share Playlist: ${playlist.name}',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(
                  user['username']!,
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                subtitle: Text(
                  user['email']!,
                  style: GoogleFonts.poppins(color: Colors.white54),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  if (mounted) {
                    setState(() => isLoading = true);
                  }

                  final socketService = SocketService();
                  try {
                    final request = SocketRequest(
                      action: 'share_playlist',
                      data: {
                        'email': currentUser!.email,
                        'target_email': user['email'],
                        'playlist_name': playlist.name,
                      },
                      requestId:
                          DateTime.now().millisecondsSinceEpoch.toString(),
                    );

                    print(
                        'Sending share_playlist request: ${request.toJson()}');
                    final response = await socketService.send(request);
                    print('Share playlist response: ${response.toJson()}');

                    if (response.isSuccess) {
                      _showMessage(
                          'Playlist shared successfully with ${user['username']}');
                    } else {
                      _showMessage(
                          'Failed to share playlist: ${response.message}',
                          error: true);
                    }
                  } catch (e) {
                    _showMessage('Error sharing playlist: $e', error: true);
                  } finally {
                    socketService.close();
                    if (mounted) {
                      setState(() => isLoading = false);
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFFCE93D8)),
            ),
          ),
        ],
      ),
    );
  }

  void _onNavBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MusicHomePage()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        backgroundColor: error ? Colors.redAccent : const Color(0xFFCE93D8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        duration: const Duration(seconds: 3),
        elevation: 10,
      ),
    );
  }

  void _updateUserSongs(List<Homepagesong> updatedSongs) {
    setState(() {
      userSongs = updatedSongs;
    });
    _songStreamController.add(updatedSongs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Playlists',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _createPlaylist,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(
                          'New Playlist',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCE93D8),
                          padding: const EdgeInsets.only(right: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: SpinKitThreeBounce(
                          color: Color(0xFFCE93D8), size: 24))
                  : StreamBuilder<List<Playlist>>(
                      stream: _playlistStreamController.stream,
                      initialData: playlists,
                      builder: (context, snapshot) {
                        final currentPlaylists = snapshot.data ?? [];

                        return currentPlaylists.isEmpty
                            ? Center(
                                child: Text(
                                  'No playlists found. Create one!',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white54, fontSize: 16),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: currentPlaylists.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                  color: Colors.white12,
                                  height: 1,
                                  thickness: 1,
                                ),
                                itemBuilder: (context, index) {
                                  final playlist = currentPlaylists[index];
                                  return Container(
                                    color: const Color(0xFF1E1E1E),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 4),
                                      leading: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.queue_music,
                                            color: Color(0xFFCE93D8), size: 30),
                                      ),
                                      title: Text(
                                        playlist.name,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '${playlist.songIds.length} song${playlist.songIds.length != 1 ? 's' : ''}',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white54,
                                            fontSize: 14),
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert,
                                            color: Colors.white54),
                                        onSelected: (value) {
                                          if (value == 'share') {
                                            _sharePlaylist(playlist);
                                          } else if (value == 'delete') {
                                            _deletePlaylist(playlist);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          PopupMenuItem(
                                            value: 'share',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.share,
                                                    color: Colors.white),
                                                const SizedBox(width: 8),
                                                Text('Share',
                                                    style: GoogleFonts.poppins(
                                                        color: Colors.white)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.delete,
                                                    color: Colors.red),
                                                const SizedBox(width: 8),
                                                Text('Delete',
                                                    style: GoogleFonts.poppins(
                                                        color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                        color: const Color(0xFF1E1E1E),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PlaylistDetailsPage(
                                              playlist: playlist,
                                              userSongs: userSongs,
                                              currentUser: currentUser!,
                                              onUpdate: _refreshData,
                                              updateUserSongs: _updateUserSongs,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavBarTapped,
        backgroundColor: const Color(0xFF000000),
        selectedItemColor: const Color(0xFFCE93D8),
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue_music),
            label: 'Playlists',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(),
      ),
    );
  }
}

class PlaylistDetailsPage extends StatefulWidget {
  final Playlist playlist;
  final List<Homepagesong> userSongs;
  final User currentUser;
  final VoidCallback onUpdate;
  final Function(List<Homepagesong>) updateUserSongs;

  const PlaylistDetailsPage({
    super.key,
    required this.playlist,
    required this.userSongs,
    required this.currentUser,
    required this.onUpdate,
    required this.updateUserSongs,
  });

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  bool isLoading = false;
  final Map<int, String?> _coverCache = {};

  @override
  void initState() {
    super.initState();
    _loadCoverImages();
  }

  Future<void> _loadCoverImages() async {
    final userSongs = _getUserSongsOnly();
    for (final song in userSongs) {
      if (!_coverCache.containsKey(song.id)) {
        final coverPath = await _getSongCoverPath(song);
        setState(() {
          _coverCache[song.id] = coverPath;
        });
      }
    }
  }

  Future<String?> _getSongCoverPath(Homepagesong song) async {
    if (song.coverPath != null) {
      final file = File(song.coverPath!);
      if (await file.exists()) {
        return song.coverPath;
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final possibleCoverNames = [
      '${song.title}-cover.jpg',
      'cover_${song.title}.jpg',
      if (song.coverPath != null) song.coverPath!,
    ];

    for (final coverName in possibleCoverNames) {
      final coverFile = File('${dir.path}/$coverName');
      if (await coverFile.exists()) {
        return coverFile.path;
      }
    }

    return null;
  }

  List<Homepagesong> _getUserSongsOnly() {
    return widget.userSongs
        .where((song) => song.uploaderEmail == widget.currentUser.email)
        .toList();
  }

  List<Homepagesong> _getPlaylistUserSongs() {
    final userSongs = _getUserSongsOnly();
    return userSongs
        .where((song) => widget.playlist.songIds.contains(song.id))
        .toList();
  }

  Future<void> _addSongToPlaylist() async {
    final availableSongs = widget.userSongs
        .where((song) => !widget.playlist.songIds.contains(song.id))
        .toList();

    print(
        'Available songs for playlist: ${availableSongs.map((s) => s.title).toList()}');

    if (availableSongs.isEmpty) {
      _showMessage('No songs available to add', error: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Song to ${widget.playlist.name}',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: availableSongs.length,
            itemBuilder: (context, index) {
              final song = availableSongs[index];
              return ListTile(
                title: Text(
                  song.title,
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                subtitle: Text(
                  song.artist,
                  style: GoogleFonts.poppins(color: Colors.white54),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _addSongToPlaylistRequest(song);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFFCE93D8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSongToPlaylistRequest(Homepagesong song) async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'add_music_to_playlist',
        data: {
          'email': widget.currentUser.email,
          'playlist_name': widget.playlist.name,
          'music_name': song.title,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      print('Sending add_music_to_playlist request: ${request.toJson()}');
      final response = await socketService.send(request);
      print('Add music to playlist response: ${response.toJson()}');
      socketService.close();

      if (response.isSuccess) {
        _showMessage('Song added to playlist');
        if (mounted) {
          setState(() {
            widget.playlist.songIds.add(song.id);
          });
        }
        widget.onUpdate();
      } else {
        _showMessage('Failed to add song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error adding song: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _removeSongFromPlaylist(String musicName) async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final userSongs = _getUserSongsOnly();
      final song = userSongs.firstWhere(
        (song) => song.title == musicName,
        orElse: () => Homepagesong(
          id: 0,
          title: '',
          artist: '',
          filePath: '',
          uploaderEmail: '',
          isFromServer: false,
          addedAt: DateTime.now(),
          localPath: null,
          coverPath: null,
        ),
      );

      if (song.id == 0) {
        _showMessage('Song not found in your library', error: true);
        if (mounted) {
          setState(() => isLoading = false);
        }
        return;
      }

      final socketService = SocketService();
      final request = SocketRequest(
        action: 'remove_music_from_playlist',
        data: {
          'email': widget.currentUser.email,
          'playlist_name': widget.playlist.name,
          'music_name': musicName,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      print('Sending remove_music_from_playlist request: ${request.toJson()}');
      final response = await socketService.send(request);
      print('Remove music from playlist response: ${response.toJson()}');
      socketService.close();

      if (response.isSuccess) {
        _showMessage('Song removed from playlist');
        if (mounted) {
          setState(() {
            widget.playlist.songIds.remove(song.id);
            _coverCache.remove(song.id);
          });
        }
        widget.onUpdate();
      } else {
        _showMessage('Failed to remove song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error removing song: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _playSong(Homepagesong song, List<Homepagesong> playlistSongs, int index) async {
    try {
      if (song.localPath == null && song.isFromServer) {
        if (mounted) {
          setState(() => isLoading = true);
        }

        final socketService = SocketService();
        final request = SocketRequest(
          action: 'download_music',
          data: {'name': song.title, 'email': widget.currentUser.email},
          requestId: DateTime.now().millisecondsSinceEpoch.toString(),
        );

        print('Sending download_music request: ${request.toJson()}');
        final response = await socketService.send(request);
        print('Download music response: ${response.toJson()}');
        socketService.close();

        if (response.isSuccess && response.data != null) {
          final String base64File = response.data['file'] as String;
          final bytes = base64Decode(base64File);
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/${song.title}.mp3');
          await file.writeAsBytes(bytes);

          final updatedSongs = List<Homepagesong>.from(widget.userSongs);
          final songIndex = updatedSongs.indexWhere((s) => s.id == song.id);

          if (songIndex != -1) {
            updatedSongs[songIndex] = Homepagesong(
              id: song.id,
              title: song.title,
              artist: song.artist,
              filePath: song.filePath,
              localPath: file.path,
              uploaderEmail: song.uploaderEmail,
              isFromServer: song.isFromServer,
              addedAt: song.addedAt,
              coverPath: song.coverPath,
            );

            widget.updateUserSongs(updatedSongs);
          }
        } else {
          _showMessage('Failed to download song: ${response.message}', error: true);
          if (mounted) {
            setState(() => isLoading = false);
          }
          return;
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MusicPlayerPage(
            song: Music(
              id: song.id,
              title: song.title,
              artist: song.artist,
              filePath: song.localPath ?? song.filePath,
              coverPath: song.coverPath,
            ),
            songs: playlistSongs
                .map((s) => Music(
              id: s.id,
              title: s.title,
              artist: s.artist,
              filePath: s.localPath ?? s.filePath,
                      coverPath: s.coverPath,
                    ))
                .toList(),
            currentIndex: index,
          ),
        ),
      );
    } catch (e) {
      _showMessage('Error playing song: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        backgroundColor: error ? Colors.redAccent : const Color(0xFFCE93D8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        duration: const Duration(seconds: 3),
        elevation: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userSongs = _getUserSongsOnly();
    final playlistSongs = userSongs
        .where((song) => widget.playlist.songIds.contains(song.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: isLoading
            ? const Center(child: SpinKitThreeBounce(color: Color(0xFFCE93D8), size: 24))
            : Column(
          children: [
            Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFFCE93D8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.playlist.name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFFCE93D8)),
                    onPressed: _addSongToPlaylist,
                  ),
                ],
              ),
            ),
            Expanded(
              child: playlistSongs.isEmpty
                  ? Center(
                child: Text(
                  'No songs in this playlist. Add some!',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                ),
              )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: playlistSongs.length,
                            separatorBuilder: (context, index) => const Divider(
                              color: Colors.white12,
                              height: 1,
                              thickness: 1,
                            ),
                            itemBuilder: (context, index) {
                  final song = playlistSongs[index];
                              return FutureBuilder<String?>(
                                future: _getSongCoverPath(song),
                                builder: (context, snapshot) {
                                  final coverPath = snapshot.data;
                                  return Container(
                                    color: const Color(0xFF1E1E1E),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 4),
                                      leading: coverPath != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(coverPath),
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Container(
                                                  width: 50,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF1E1E1E),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: const Icon(
                                                      Icons.music_note,
                                                      color: Color(0xFFCE93D8),
                                                      size: 30),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E1E1E),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                  Icons.music_note,
                                                  color: Color(0xFFCE93D8),
                                                  size: 30),
                                            ),
                                      title: Text(
                                        song.title,
                                        style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        song.artist,
                                        style: GoogleFonts.poppins(
                                            color: Colors.white54),
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert,
                                            color: Colors.white54),
                                        onSelected: (value) {
                                          if (value == 'delete') {
                                            _removeSongFromPlaylist(song.title);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.delete,
                                                    color: Colors.red),
                                                const SizedBox(width: 8),
                                                Text('Delete',
                                                    style: GoogleFonts.poppins(
                                                        color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                        color: const Color(0xFF1E1E1E),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onTap: () =>
                                          _playSong(song, playlistSongs, index),
                                    ),
                                  );
                                },
                              );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}