import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:projectap/Homepage.dart' hide Homepagesong;
import 'package:projectap/Playlist.dart';
import 'package:projectap/ProfilePage.dart';
import 'package:projectap/Song.dart';
import 'package:projectap/User.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/playermusicpage.dart';

AppStorage storage = AppStorage();

Future<Uint8List?> extractCoverFromFile(File file) async {
  try {
    if (!await file.exists()) return null;
    final dynamic maybeMeta = readMetadata(file, getImage: true);
    final metadata = maybeMeta is Future ? await maybeMeta : maybeMeta;
    if (metadata != null && metadata.pictures.isNotEmpty) {
      final p = metadata.pictures.first.bytes;
      if (p is Uint8List) return p;
      if (p != null) return Uint8List.fromList(p);
    }
    final parent = file.parent.path;
    final baseName = file.uri.pathSegments.last.replaceAll('.mp3', '');
    final coverFile1 = File('$parent/${baseName}-cover.jpg');
    if (await coverFile1.exists()) return await coverFile1.readAsBytes();
    final coverFile2 = File('$parent/cover_${baseName}.jpg');
    if (await coverFile2.exists()) return await coverFile2.readAsBytes();
  } catch (e) {
    print('Error extracting cover: $e');
  }
  return null;
}

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

  final StreamController<List<Playlist>> _playlistStreamController =
  StreamController<List<Playlist>>.broadcast();
  final StreamController<List<Homepagesong>> _songStreamController =
  StreamController<List<Homepagesong>>.broadcast();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
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
    if (!_playlistStreamController.isClosed) _playlistStreamController.close();
    if (!_songStreamController.isClosed) _songStreamController.close();
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

  void _updateUserSongs(List<Homepagesong> updatedSongs) {
    if (mounted) {
      setState(() {
        userSongs = updatedSongs;
      });
    }
    if (!_songStreamController.isClosed) _songStreamController.add(updatedSongs);
  }

  Future<void> _refreshData() async {
    if (mounted) setState(() => isLoading = true);
    try {
      await Future.wait([
        _loadUserPlaylists(),
        _loadUserSongs(),
      ]);
      final updatedSongs = List<Homepagesong>.from(userSongs);
      for (final playlist in playlists) {
        for (final songId in playlist.songIds) {
          if (!updatedSongs.any((song) => song.id == songId)) {
            await _loadSingleSong(songId);
          }
        }
      }
      _updateUserSongs(List<Homepagesong>.from(userSongs));
    } catch (e) {
      _showMessage('Error refreshing data: $e', error: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
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
      final response = await socketService.send(request);
      socketService.close();
      final serverPlaylists = <Playlist>[];
      if (response.isSuccess && response.data != null) {
        final appDir = await getApplicationDocumentsDirectory();
        for (var json in response.data as List<dynamic>) {
          if (json['id'] != null && json['name'] != null && json['name'].toString().isNotEmpty) {
            final musics = (json['musics'] as List<dynamic>?) ?? [];
            final songIds = <int>[];
            for (var musicJson in musics) {
              if (musicJson['id'] != null) {
                final songId = musicJson['id'] as int;
                songIds.add(songId);
                final songTitle = musicJson['title'] as String;
                final expectedPath = '${appDir.path}/${songTitle}.mp3';
                if (!File(expectedPath).existsSync()) {
                  await _downloadSongIfMissing(musicJson);
                }
              }
            }
            final playlist = Playlist.fromJson({
              'id': json['id'],
              'name': json['name'],
              'creatorEmail': json['creatorEmail'] ?? currentUser!.email,
              'songIds': songIds,
            });
            serverPlaylists.add(playlist);
          }
        }
      }
      if (!_playlistStreamController.isClosed) _playlistStreamController.add(serverPlaylists);
    } catch (e) {
      _showMessage('Error loading playlists: $e', error: true);
    }
  }

  Future<void> _downloadSongIfMissing(Map<String, dynamic> musicJson) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final title = musicJson['title'] as String? ?? 'unknown';
      final expectedPath = '${appDir.path}/$title.mp3';
      if (File(expectedPath).existsSync()) return;
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'download_music',
        data: {
          'name': musicJson['title'],
          'email': currentUser!.email,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await socketService.send(request);
      socketService.close();
      if (response.isSuccess && response.data != null && response.data['file'] != null) {
        final String base64File = response.data['file'] as String;
        final bytes = base64Decode(base64File);
        final file = File(expectedPath);
        await file.writeAsBytes(bytes);
        try {
          final coverBytes = await extractCoverFromFile(file);
          if (coverBytes != null) {
            final coverFile = File('${appDir.path}/$title-cover.jpg');
            if (!coverFile.existsSync()) {
              await coverFile.writeAsBytes(coverBytes);
            }
          }
        } catch (e) {
          print('Error downloading cover: $e');
        }
      }
    } catch (e) {
      print('Error downloading song: $e');
    }
  }

  Future<void> _ensurePlaylistSongsLoaded(Playlist playlist) async {
    final missingIds = playlist.songIds.where((id) => !userSongs.any((s) => s.id == id)).toList();
    print('Missing song IDs for ${playlist.name}: $missingIds'); // دیباگ
    if (missingIds.isEmpty) return;
    for (final id in missingIds) {
      await _loadSingleSong(id);
    }
    _updateUserSongs(List<Homepagesong>.from(userSongs));
  }

  Future<void> _loadSingleSong(int songId) async {
    try {
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'get_music_by_id',
        data: {'id': songId, 'email': currentUser!.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await socketService.send(request);
      socketService.close();
      print('Load single song response for ID $songId: ${response.toJson()}'); // دیباگ
      if (response.isSuccess && response.data != null) {
        final json = response.data as Map<String, dynamic>;
        final appDir = await getApplicationDocumentsDirectory();
        final titleRaw = (json['title'] as String? ?? 'unknown');
        final expectedPath = '${appDir.path}/$titleRaw.mp3';
        String? localPath;
        if (File(expectedPath).existsSync()) {
          localPath = expectedPath;
        } else {
          final downloadReq = SocketRequest(
            action: 'download_music',
            data: {'name': json['title'], 'email': currentUser!.email},
            requestId: DateTime.now().millisecondsSinceEpoch.toString(),
          );
          final dlResp = await SocketService().send(downloadReq);
          if (dlResp.isSuccess && dlResp.data != null && dlResp.data['file'] != null) {
            final String base64File = dlResp.data['file'] as String;
            final bytes = base64Decode(base64File);
            final file = File(expectedPath);
            await file.writeAsBytes(bytes);
            localPath = expectedPath;
            try {
              if (dlResp.data['cover'] != null && dlResp.data['cover'].toString().isNotEmpty) {
                final coverBytes = base64Decode(dlResp.data['cover'] as String);
                final coverFile = File('${appDir.path}/$titleRaw-cover.jpg');
                if (!coverFile.existsSync()) await coverFile.writeAsBytes(coverBytes);
              } else {
                final coverBytes = await extractCoverFromFile(File(expectedPath));
                if (coverBytes != null) {
                  final coverFile = File('${appDir.path}/$titleRaw-cover.jpg');
                  if (!coverFile.existsSync()) await coverFile.writeAsBytes(coverBytes);
                }
              }
            } catch (e) {
              print('Cover write error: $e');
            }
          }
        }
        String title = titleRaw;
        String artist = json['artist'] as String? ?? 'Unknown';
        Uint8List? coverBytes;
        if (localPath != null) {
          try {
            final extracted = await extractCoverFromFile(File(localPath));
            if (extracted != null) coverBytes = extracted;
            final metadata = await (readMetadata(File(localPath), getImage: true) is Future
                ? await readMetadata(File(localPath), getImage: true)
                : readMetadata(File(localPath), getImage: true));
            if (metadata != null) {
              title = metadata.title?.trim() ?? title;
              artist = metadata.artist?.trim() ?? artist;
            }
          } catch (e) {
            print('Metadata read error: $e');
          }
        }
        final song = Homepagesong(
          id: json['id'] as int,
          title: title,
          artist: artist,
          filePath: json['filePath'],
          localPath: localPath,
          uploaderEmail: json['uploaderEmail'] ?? currentUser!.email,
          isFromServer: json['uploaderEmail'] != null && json['uploaderEmail'] != currentUser!.email,
          addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
          coverBytes: coverBytes,
        );
        final updatedSongs = List<Homepagesong>.from(userSongs);
        if (!updatedSongs.any((s) => s.id == song.id)) {
          updatedSongs.add(song);
          _updateUserSongs(updatedSongs);
        }
      } else {
        _showMessage('Failed to load song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error loading song: $e', error: true);
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
      final response = await socketService.send(request);
      socketService.close();
      print('Load user songs response: ${response.toJson()}'); // دیباگ
      if (response.isSuccess && response.data != null && response.data is List<dynamic>) {
        final appDir = await getApplicationDocumentsDirectory();
        final futures = (response.data as List<dynamic>)
            .where((json) => json['id'] != null && json['title'] != null && json['filePath'] != null)
            .map((json) async {
          final title = json['title'] as String? ?? 'unknown';
          String? localPath;
          final expectedPath = '${appDir.path}/$title.mp3';
          if (File(expectedPath).existsSync()) {
            localPath = expectedPath;
          }
          String titleOut = json['title'] as String? ?? 'Unknown';
          String artist = json['artist'] as String? ?? 'Unknown';
          Uint8List? coverBytes;
          if (localPath != null) {
            try {
              final extracted = await extractCoverFromFile(File(localPath));
              if (extracted != null) {
                coverBytes = extracted;
                final coverFile = File('${appDir.path}/$title-cover.jpg');
                if (!coverFile.existsSync()) {
                  await coverFile.writeAsBytes(coverBytes);
                }
              }
              final metadata = await (readMetadata(File(localPath), getImage: true) is Future
                  ? await readMetadata(File(localPath), getImage: true)
                  : readMetadata(File(localPath), getImage: true));
              if (metadata != null) {
                titleOut = metadata.title?.trim() ?? titleOut;
                artist = metadata.artist?.trim() ?? artist;
              }
            } catch (e) {
              print('Metadata read error for $localPath: $e');
            }
          }
          return Homepagesong(
            id: json['id'] as int,
            title: titleOut.trim(),
            artist: artist,
            filePath: json['filePath'],
            localPath: localPath,
            uploaderEmail: json['uploaderEmail'] ?? currentUser!.email,
            isFromServer: json['uploaderEmail'] != null && json['uploaderEmail'] != currentUser!.email,
            addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
            coverBytes: coverBytes,
          );
        }).toList();
        final resolvedSongs = await Future.wait(futures);
        if (mounted) {
          setState(() {
            userSongs = resolvedSongs;
          });
        }
        if (!_songStreamController.isClosed) _songStreamController.add(resolvedSongs);
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
      final response = await socketService.send(request);
      socketService.close();
      if (response.isSuccess && response.data != null) {
        final users = (response.data as List<dynamic>)
            .where((json) => json['email'] != null && json['email'] is String && json['email'] != currentUser!.email)
            .map((json) => {'email': json['email'] as String, 'username': json['username'] as String? ?? 'Unknown'})
            .toList();
        return users;
      } else {
        _showMessage('No users available: ${response.message}', error: true);
        return [];
      }
    } catch (e) {
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
                final response = await socketService.send(request);
                socketService.close();
                if (response.isSuccess) {
                  _showMessage('Playlist created successfully');
                  await _refreshData();
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
      final response = await socketService.send(request);
      socketService.close();
      if (response.isSuccess) {
        _showMessage('Playlist deleted successfully');
        final updatedPlaylists = playlists.where((p) => p.id != playlist.id).toList();
        if (!_playlistStreamController.isClosed) _playlistStreamController.add(updatedPlaylists);
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
                      requestId: DateTime.now().millisecondsSinceEpoch.toString(),
                    );
                    final response = await socketService.send(request);
                    if (response.isSuccess) {
                      _showMessage('Playlist shared successfully with ${user['username']}');
                    } else {
                      _showMessage('Failed to share playlist: ${response.message}', error: true);
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
      Navigator.push(
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

  Widget _buildSongCover(Homepagesong song) {
    if (song.coverBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          song.coverBytes!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _buildDefaultCover(song),
        ),
      );
    }
    if (song.localPath != null && File(song.localPath!).existsSync()) {
      return FutureBuilder<Uint8List?>(
        future: extractCoverFromFile(File(song.localPath!)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final idx = userSongs.indexWhere((s) => s.id == song.id);
              if (idx != -1 && userSongs[idx].coverBytes == null) {
                setState(() {
                  userSongs[idx] = userSongs[idx].copyWith(coverBytes: snapshot.data);
                });
              }
            });
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                snapshot.data!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _buildDefaultCover(song),
              ),
            );
          }
          return _buildDefaultCover(song);
        },
      );
    }
    return _buildDefaultCover(song);
  }

  Widget _buildDefaultCover(Homepagesong song) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCE93D8), Color(0xFF1E1E1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          song.title.isNotEmpty ? song.title[0].toUpperCase() : '',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  ? const Center(child: SpinKitThreeBounce(color: Color(0xFFCE93D8), size: 24))
                  : StreamBuilder<List<Playlist>>(
                stream: _playlistStreamController.stream,
                initialData: playlists,
                builder: (context, snapshot) {
                  final currentPlaylists = snapshot.data ?? [];
                  return currentPlaylists.isEmpty
                      ? Center(
                    child: Text(
                      'No playlists found. Create one!',
                      style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentPlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = currentPlaylists[index];
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            playlist.name,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text(
                            '${playlist.songIds.length} songs',
                            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white54),
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
                                    const Icon(Icons.share, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text('Share', style: GoogleFonts.poppins(color: Colors.white)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            color: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onTap: () async {
                            await _ensurePlaylistSongsLoaded(playlist);
                            if (currentUser == null) {
                              _showMessage('Please log in', error: true);
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlaylistDetailsPage(
                                  playlist: playlist,
                                  userSongs: userSongs,
                                  currentUser: currentUser!,
                                  onUpdate: _refreshData,
                                  updateUserSongs: _updateUserSongs,
                                  songStream: _songStreamController.stream,
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
  final Stream<List<Homepagesong>>? songStream;

  const PlaylistDetailsPage({
    super.key,
    required this.playlist,
    required this.userSongs,
    required this.currentUser,
    required this.onUpdate,
    required this.updateUserSongs,
    this.songStream,
  });

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  bool isLoading = false;
  late List<Homepagesong> currentUserSongs;
  StreamSubscription<List<Homepagesong>>? _songsSubscription;

  @override
  void initState() {
    super.initState();
    currentUserSongs = List<Homepagesong>.from(widget.userSongs);
    if (widget.songStream != null) {
      _songsSubscription = widget.songStream!.listen((songs) {
        if (!mounted) return;
        setState(() {
          currentUserSongs = List<Homepagesong>.from(songs);
        });
      }, onError: (e) {
        print('songStream error: $e');
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePlaylistSongsLoaded();
    });
  }

  @override
  void dispose() {
    _songsSubscription?.cancel();
    super.dispose();
  }

  List<Homepagesong> _getUserSongsOnly() {
    return List<Homepagesong>.from(currentUserSongs);
  }

  Widget _buildSongCover(Homepagesong song) {
    if (song.coverBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          song.coverBytes!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error painting cover memory: $error');
            return _buildDefaultCover(song);
          },
        ),
      );
    }
    if (song.localPath != null && File(song.localPath!).existsSync()) {
      return FutureBuilder<Uint8List?>(
        future: extractCoverFromFile(File(song.localPath!)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final idx = currentUserSongs.indexWhere((s) => s.id == song.id);
              if (idx != -1 && currentUserSongs[idx].coverBytes == null) {
                setState(() {
                  currentUserSongs[idx] = currentUserSongs[idx].copyWith(coverBytes: snapshot.data);
                });
                widget.updateUserSongs(List<Homepagesong>.from(currentUserSongs));
              }
            });
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                snapshot.data!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultCover(song),
              ),
            );
          }
          return _buildDefaultCover(song);
        },
      );
    }
    return _buildDefaultCover(song);
  }

  Widget _buildDefaultCover(Homepagesong song) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          song.title.isNotEmpty ? song.title[0].toUpperCase() : '',
          style: GoogleFonts.poppins(
            color: const Color(0xFFCE93D8),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _ensurePlaylistSongsLoaded() async {
    final missingIds = widget.playlist.songIds.where((id) => !currentUserSongs.any((s) => s.id == id)).toList();
    print('Missing song IDs in details: $missingIds');
    if (missingIds.isEmpty) return;
    if (mounted) setState(() {
      isLoading = true;
    });
    try {
      for (final id in missingIds) {
        await _loadSingleSong(id);
      }
    } catch (e) {
      _showMessage('Error ensuring songs loaded: $e', error: true);
    } finally {
      if (mounted) setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadSingleSong(int songId) async {
    try {
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'get_music_by_id',
        data: {'id': songId, 'email': widget.currentUser.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await socketService.send(request);
      socketService.close();
      print('Load single song response in details for ID $songId: ${response.toJson()}'); // دیباگ
      if (response.isSuccess && response.data != null) {
        final json = response.data as Map<String, dynamic>;
        final appDir = await getApplicationDocumentsDirectory();
        final titleRaw = (json['title'] as String? ?? 'unknown');
        final expectedPath = '${appDir.path}/$titleRaw.mp3';
        String? localPath;
        if (File(expectedPath).existsSync()) {
          localPath = expectedPath;
        } else {
          final downloadReq = SocketRequest(
            action: 'download_music',
            data: {'name': json['title'], 'email': widget.currentUser.email},
            requestId: DateTime.now().millisecondsSinceEpoch.toString(),
          );
          final dlResp = await SocketService().send(downloadReq);
          if (dlResp.isSuccess && dlResp.data != null && dlResp.data['file'] != null) {
            final String base64File = dlResp.data['file'] as String;
            final bytes = base64Decode(base64File);
            final file = File(expectedPath);
            await file.writeAsBytes(bytes);
            localPath = expectedPath;
            try {
              if (dlResp.data['cover'] != null && dlResp.data['cover'].toString().isNotEmpty) {
                final coverBytes = base64Decode(dlResp.data['cover'] as String);
                final coverFile = File('${appDir.path}/$titleRaw-cover.jpg');
                if (!coverFile.existsSync()) await coverFile.writeAsBytes(coverBytes);
              } else {
                final coverBytes = await extractCoverFromFile(File(expectedPath));
                if (coverBytes != null) {
                  final coverFile = File('${appDir.path}/$titleRaw-cover.jpg');
                  if (!coverFile.existsSync()) await coverFile.writeAsBytes(coverBytes);
                }
              }
            } catch (e) {
              print('Cover write error in details: $e');
            }
          }
        }
        String title = titleRaw;
        String artist = json['artist'] as String? ?? 'Unknown';
        Uint8List? coverBytes;
        if (localPath != null) {
          try {
            final extracted = await extractCoverFromFile(File(localPath));
            if (extracted != null) coverBytes = extracted;
            final metadata = await (readMetadata(File(localPath), getImage: true) is Future
                ? await readMetadata(File(localPath), getImage: true)
                : readMetadata(File(localPath), getImage: true));
            if (metadata != null) {
              title = metadata.title?.trim() ?? title;
              artist = metadata.artist?.trim() ?? artist;
            }
          } catch (e) {
            print('Metadata read error for $localPath in details: $e');
          }
        }
        final song = Homepagesong(
          id: json['id'] as int,
          title: title,
          artist: artist,
          filePath: json['filePath'],
          localPath: localPath,
          uploaderEmail: json['uploaderEmail'] ?? widget.currentUser.email,
          isFromServer: json['uploaderEmail'] != null && json['uploaderEmail'] != widget.currentUser.email,
          addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
          coverBytes: coverBytes,
        );
        final updated = List<Homepagesong>.from(currentUserSongs);
        if (!updated.any((s) => s.id == song.id)) {
          updated.add(song);
          setState(() {
            currentUserSongs = updated;
          });
          widget.updateUserSongs(List<Homepagesong>.from(currentUserSongs));
        }
      } else {
        _showMessage('Failed to load song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error loading song in details: $e', error: true);
    }
  }

  Future<void> _addSongToPlaylist() async {
    final availableSongs = _getUserSongsOnly()
        .where((song) => !widget.playlist.songIds.contains(song.id))
        .toList();
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
          height: 360,
          child: ListView.builder(
            itemCount: availableSongs.length,
            itemBuilder: (context, index) {
              final song = availableSongs[index];
              return ListTile(
                leading: _buildSongCover(song),
                title: Text(song.title, style: GoogleFonts.poppins(color: Colors.white)),
                subtitle: Text(song.artist, style: GoogleFonts.poppins(color: Colors.white54)),
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
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFFCE93D8))),
          ),
        ],
      ),
    );
  }

  Future<void> _addSongToPlaylistRequest(Homepagesong song) async {
    if (mounted) setState(() => isLoading = true);
    try {
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'add_music_to_playlist',
        data: {
          'email': widget.currentUser.email,
          'playlist_name': widget.playlist.name,
          'music_id': song.id,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await socketService.send(request);
      socketService.close();
      print('Add song to playlist response: ${response.toJson()}');
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
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _removeSongFromPlaylist(int songId) async {
    if (mounted) setState(() => isLoading = true);
    try {
      final song = currentUserSongs.firstWhere(
            (s) => s.id == songId,
        orElse: () => Homepagesong(
          id: 0,
          title: '',
          artist: '',
          filePath: '',
          localPath: null,
          uploaderEmail: '',
          isFromServer: false,
          addedAt: DateTime.now(),
        ),
      );
      if (song.id == 0) {
        _showMessage('Song not found in your library', error: true);
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final socketService = SocketService();
      final request = SocketRequest(
        action: 'remove_music_from_playlist',
        data: {
          'email': widget.currentUser.email,
          'playlist_name': widget.playlist.name,
          'music_id': songId,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await socketService.send(request);
      socketService.close();
      print('Remove song from playlist response: ${response.toJson()}');
      if (response.isSuccess) {
        _showMessage('Song removed from playlist');
        if (mounted) {
          setState(() {
            widget.playlist.songIds.remove(songId);
          });
        }
        widget.onUpdate();
      } else {
        _showMessage('Failed to remove song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error removing song: $e', error: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _playSong(Homepagesong song, List<Homepagesong> playlistSongs, int index) async {
    try {
      if (song.localPath == null && song.isFromServer) {
        if (mounted) setState(() => isLoading = true);
        final socketService = SocketService();
        final request = SocketRequest(
          action: 'download_music',
          data: {'name': song.title, 'email': widget.currentUser.email},
          requestId: DateTime.now().millisecondsSinceEpoch.toString(),
        );
        final response = await socketService.send(request);
        socketService.close();
        if (response.isSuccess && response.data != null) {
          final String base64File = response.data['file'] as String;
          final bytes = base64Decode(base64File);
          final dir = await getApplicationDocumentsDirectory();
          final safeTitle = song.title;
          final file = File('${dir.path}/$safeTitle.mp3');
          await file.writeAsBytes(bytes);
          final metadataCover = await extractCoverFromFile(file);
          Uint8List? cover;
          String title = song.title;
          String artist = song.artist;
          if (metadataCover != null) {
            cover = metadataCover;
            try {
              final m = await readMetadata(file, getImage: true);
              if (m != null) {
                title = m.title?.trim() ?? title;
                artist = m.artist?.trim() ?? artist;
              }
            } catch (_) {}
            final coverFile = File('${dir.path}/$safeTitle-cover.jpg');
            if (!coverFile.existsSync()) {
              await coverFile.writeAsBytes(cover);
            }
          }
          final updated = List<Homepagesong>.from(currentUserSongs);
          final idx = updated.indexWhere((s) => s.id == song.id);
          if (idx != -1) {
            updated[idx] = updated[idx].copyWith(localPath: file.path, title: title, artist: artist, coverBytes: cover);
          } else {
            updated.add(Homepagesong(
              id: song.id,
              title: title,
              artist: artist,
              filePath: song.filePath,
              localPath: file.path,
              uploaderEmail: song.uploaderEmail,
              isFromServer: song.isFromServer,
              addedAt: song.addedAt,
              coverBytes: cover,
            ));
          }
          setState(() {
            currentUserSongs = updated;
          });
          widget.updateUserSongs(List<Homepagesong>.from(currentUserSongs));
        } else {
          _showMessage('Failed to download song: ${response.message}', error: true);
          if (mounted) setState(() => isLoading = false);
          return;
        }
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MusicPlayerPage(
            song: Music(id: song.id, title: song.title, artist: song.artist, filePath: song.localPath ?? song.filePath),
            songs: playlistSongs
                .map((s) => Music(id: s.id, title: s.title, artist: s.artist, filePath: s.localPath ?? s.filePath))
                .toList(),
            currentIndex: index,
          ),
        ),
      );
    } catch (e) {
      _showMessage('Error playing song: $e', error: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white), textAlign: TextAlign.center),
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
    final playlistSongs = currentUserSongs.where((song) => widget.playlist.songIds.contains(song.id)).toList();
    print('Playlist ${widget.playlist.name} songs count: ${playlistSongs.length}, songIds: ${widget.playlist.songIds}'); // دیباگ
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: isLoading
            ? const Center(child: SpinKitThreeBounce(color: Color(0xFFCE93D8), size: 24))
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: playlistSongs.length,
                itemBuilder: (context, index) {
                  final song = playlistSongs[index];
                  return Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: ListTile(
                      leading: _buildSongCover(song),
                      title: Text(
                        song.title,
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: GoogleFonts.poppins(color: Colors.white54),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                        onPressed: () => _removeSongFromPlaylist(song.id),
                      ),
                      onTap: () => _playSong(song, playlistSongs, index),
                    ),
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