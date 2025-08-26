import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:projectap/PlaylistPage.dart';
import 'package:projectap/ProfilePage.dart';
import 'package:projectap/Song.dart';
import 'package:projectap/User.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/playermusicpage.dart';

AppStorage storage = AppStorage();

enum SortType { name, date }

class Homepagesong {
  final int id;
  final String title;
  final String artist;
  final String filePath;
  final String? localPath;
  final String? uploaderEmail;
  final bool isFromServer;
  final DateTime addedAt;
  final String? coverPath;

  Homepagesong({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    this.localPath,
    this.uploaderEmail,
    this.isFromServer = false,
    required this.addedAt,
    this.coverPath,
  });

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
      coverPath: json['coverPath'] as String?,
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
    'coverPath': coverPath,
  };
}

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  List<Homepagesong> userSongs = [];
  List<Music> serverSongs = [];
  List<String> _likedSongTitles = [];
  final StreamController<List<String>> _likedSongsStreamController = StreamController<List<String>>.broadcast();
  final TextEditingController searchController = TextEditingController();
  SortType currentSort = SortType.date;
  bool isAscending = true;
  bool isLoading = false;
  bool _isLoadingLikedSongs = false;
  User? currentUser;
  int _selectedIndex = 0;
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    searchController.addListener(_onSearchChanged);
    _likedSongsStreamController.stream.listen(
          (likedSongs) {
        print('Stream updated with liked songs: $likedSongs');
        setState(() {
          _likedSongTitles = likedSongs;
        });
      },
      onError: (error) {
        print('Stream error: $error');
        _showMessage('Stream error: $error', error: true);
      },
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _socketService.close();
    if (!_likedSongsStreamController.isClosed) {
      _likedSongsStreamController.close();
    }
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await storage.loadCurrentUser();
    setState(() {
      currentUser = user;
    });
    if (user != null) {
      await _refreshData();
    }
  }

  Future<void> _loadLikedSongs() async {
    if (currentUser == null || _isLoadingLikedSongs) {
      print('Skipping _loadLikedSongs: user is null or already loading');
      return;
    }
    _isLoadingLikedSongs = true;
    try {
      print('Loading liked songs for user: ${currentUser!.email}');
      final request = SocketRequest(
        action: 'list_liked_music',
        data: {'email': currentUser!.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await _socketService.send(request);
      print('Response for list_liked_music: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        final likedSongs = (response.data as List<dynamic>)
            .where((json) => json['title'] != null && json['title'] is String)
            .map((json) => (json['title'] as String).trim())
            .toList();
        if (!_likedSongsStreamController.isClosed) {
          _likedSongsStreamController.add(likedSongs);
        }
        print('Loaded liked songs: $likedSongs');
      } else {
        print('Failed to load liked songs: ${response.message}');
        _showMessage('Failed to load liked songs: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error loading liked songs: $e');
      _showMessage('Error loading liked songs: $e', error: true);
    } finally {
      _isLoadingLikedSongs = false;
    }
  }

  Future<void> _toggleLike(Homepagesong song) async {
    if (currentUser == null) {
      print('No user logged in');
      _showMessage('Please log in to like songs', error: true);
      return;
    }

    final isCurrentlyLiked = _likedSongTitles.contains(song.title.trim());
    final updatedLikedSongs = List<String>.from(_likedSongTitles);
    if (isCurrentlyLiked) {
      updatedLikedSongs.remove(song.title.trim());
    } else {
      updatedLikedSongs.add(song.title.trim());
    }
    print('Updating UI with liked songs: $updatedLikedSongs');
    if (!_likedSongsStreamController.isClosed) {
      _likedSongsStreamController.add(updatedLikedSongs);
    }

    try {
      final request = SocketRequest(
        action: isCurrentlyLiked ? 'unlike_music' : 'like_music',
        data: {
          'email': currentUser!.email,
          'music_name': song.title,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      print('Sending ${isCurrentlyLiked ? 'unlike' : 'like'} request: ${request.toJson()}');
      final response = await _socketService.send(request);
      print('Response for ${isCurrentlyLiked ? 'unlike' : 'like'}: ${response.toJson()}');
      if (response.isSuccess) {
        _showMessage(isCurrentlyLiked ? 'Song unliked' : 'Song liked');
        await _loadLikedSongs();
      } else {
        if (!_likedSongsStreamController.isClosed) {
          _likedSongsStreamController.add(_likedSongTitles);
        }
        _showMessage('Failed to ${isCurrentlyLiked ? 'unlike' : 'like'} song: ${response.message}', error: true);
      }
    } catch (e) {
      if (!_likedSongsStreamController.isClosed) {
        _likedSongsStreamController.add(_likedSongTitles);
      }
      print('Error toggling like: $e');
      _showMessage('Error toggling like: $e', error: true);
    }
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _loadUserSongs(),
        _loadServerSongs(),
      ]);
      for (final song in userSongs) {
        await _autoDownloadSong(song);
      }
      await _loadLikedSongs();
    } catch (e) {
      print('Error refreshing data: $e');
      _showMessage('Error refreshing data: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadUserSongs() async {
    if (currentUser == null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final request = SocketRequest(
        action: 'list_user_musics',
        data: {'email': currentUser!.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await _socketService.send(request);
      print('Response for list_user_musics: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        setState(() {
          userSongs = (response.data as List<dynamic>)
              .where((json) => json['id'] != null && json['title'] != null && json['filePath'] != null)
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
                print('Found cover for ${json['title']}: $coverPath');
                break;
              }
            }
            return Homepagesong.fromJson({
              'id': json['id'],
              'title': (json['title'] as String).trim(),
              'artist': json['artist'] ?? 'Unknown',
              'filePath': json['filePath'],
              'uploaderEmail': json['uploaderEmail'],
              'isFromServer': json['uploaderEmail'] != null && json['uploaderEmail'] != currentUser!.email,
              'addedAt': json['addedAt'] ?? DateTime.now().toIso8601String(),
              'localPath': localPath,
              'coverPath': coverPath,
            });
          })
              .toList();
          _sortSongs();
        });
      } else {
        print('Failed to load user songs: ${response.message}');
        _showMessage('Failed to load user songs: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error loading songs: $e');
      _showMessage('Error loading songs: $e', error: true);
    }
  }

  Future<void> _loadServerSongs() async {
    try {
      final request = SocketRequest(
        action: 'list_server_musics',
        data: {},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await _socketService.send(request);
      print('Response for list_server_musics: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        setState(() {
          serverSongs = (response.data as List<dynamic>)
              .where((json) => json['id'] != null && json['title'] != null && json['filePath'] != null)
              .map((json) => Music.fromJson(json))
              .toList();
        });
      } else {
        print('Failed to load server songs: ${response.message}');
        _showMessage('Failed to load server songs: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error loading server songs: $e');
      _showMessage('Error loading server songs: $e', error: true);
    }
  }

  Future<List<Map<String, String>>> _loadUsers() async {
    if (currentUser == null) {
      print('No user logged in for loading users');
      _showMessage('Please log in to load users', error: true);
      return [];
    }
    try {
      final request = SocketRequest(
        action: 'list_users',
        data: {},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await _socketService.send(request);
      print('Response for list_users: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        final users = (response.data as List<dynamic>)
            .where((json) => json['email'] != null && json['email'] is String && json['email'] != currentUser!.email)
            .map((json) => {
          'email': json['email'] as String,
          'username': json['username'] as String? ?? 'Unknown',
        })
            .toList();
        print('Loaded users: $users');
        if (users.isEmpty) {
          _showMessage('No users available for sharing', error: true);
        }
        return users;
      } else {
        print('Failed to load users: ${response.message}');
        _showMessage('Failed to load users: ${response.message}', error: true);
        return [];
      }
    } catch (e) {
      print('Error loading users: $e');
      _showMessage('Error loading users: $e', error: true);
      return [];
    }
  }

  Future<void> _autoDownloadSong(Homepagesong song) async {
    if (song.localPath != null && File(song.localPath!).existsSync()) {
      print('Song ${song.title} already exists locally at ${song.localPath}');
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/${song.title}.mp3');
      final request = SocketRequest(
        action: 'download_music',
        data: {'name': song.title, 'email': currentUser!.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await _socketService.send(request);
      print('Response for download_music: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        final String base64File = response.data['file'] as String;
        final bytes = base64Decode(base64File);
        await localFile.writeAsBytes(bytes);
        String? coverPath;
        if (response.data['cover'] != null && response.data['cover'].toString().isNotEmpty) {
          try {
            final String base64Cover = response.data['cover'] as String;
            final coverBytes = base64Decode(base64Cover);
            final coverFile = File('${dir.path}/${song.title}-cover.jpg');
            await coverFile.writeAsBytes(coverBytes);
            coverPath = coverFile.path;
            print('Cover saved for ${song.title} at $coverPath');
          } catch (e) {
            print('Error saving cover for ${song.title}: $e');
            _showMessage('Error saving cover for ${song.title}: $e', error: true);
          }
        } else {
          print('No cover provided for ${song.title}');
        }
        setState(() {
          final index = userSongs.indexWhere((s) => s.id == song.id);
          if (index != -1) {
            userSongs[index] = Homepagesong(
              id: song.id,
              title: song.title,
              artist: song.artist,
              filePath: song.filePath,
              localPath: localFile.path,
              uploaderEmail: song.uploaderEmail,
              isFromServer: song.isFromServer,
              addedAt: song.addedAt,
              coverPath: coverPath ?? song.coverPath,
            );
            print('Updated song ${song.title} with localPath: ${localFile.path}, coverPath: $coverPath');
          }
        });
      } else {
        print('Failed to download song ${song.title}: ${response.message}');
        _showMessage('Failed to download song: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error downloading song ${song.title}: $e');
      _showMessage('Error downloading song: $e', error: true);
    }
  }

  Future<void> _shareSong(Homepagesong song) async {
    if (currentUser == null) {
      print('No user logged in');
      _showMessage('Please log in to share songs', error: true);
      return;
    }
    final users = await _loadUsers();
    if (users.isEmpty) {
      print('No users available for sharing');
      _showMessage('No users available for sharing', error: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Share Song: ${song.title}',
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
                  setState(() => isLoading = true);
                  try {
                    final request = SocketRequest(
                      action: 'share_music',
                      data: {
                        'email': currentUser!.email,
                        'target_email': user['email'],
                        'music_name': song.title,
                      },
                      requestId: DateTime.now().millisecondsSinceEpoch.toString(),
                    );
                    print('Sending share_music request: ${request.toJson()}');
                    final response = await _socketService.send(request);
                    print('Response for share_music: ${response.toJson()}');
                    if (response.isSuccess) {
                      _showMessage('Song shared successfully with ${user['username']}');
                    } else {
                      _showMessage('Failed to share song: ${response.message}', error: true);
                    }
                  } catch (e) {
                    print('Error sharing song: $e');
                    _showMessage('Error sharing song: $e', error: true);
                  } finally {
                    setState(() => isLoading = false);
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

  Future<void> _addLocalSong() async {
    if (currentUser == null) {
      _showMessage('Please log in first', error: true);
      return;
    }

    try {
      setState(() => isLoading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result == null || result.files.single.path == null) {
        _showMessage('No file selected', error: true);
        return;
      }

      final file = File(result.files.single.path!);
      if (!await file.exists()) {
        _showMessage('Selected file does not exist', error: true);
        return;
      }

      // Get app directory early to be able to save cover locally (if present in metadata)
      final dir = await getApplicationDocumentsDirectory();

      // Make sure to request metadata with images: getImage: true
      final metadata = await readMetadata(file, getImage: true);
      final title = (metadata?.title?.trim().isNotEmpty ?? false)
          ? metadata!.title!.trim()
          : result.files.single.name.replaceAll('.mp3', '');
      final artist = (metadata?.artist?.trim().isNotEmpty ?? false) ? metadata!.artist!.trim() : 'Unknown Artist';

      if (userSongs.any((song) => song.title.trim() == title)) {
        _showMessage('This song already exists in your library', error: true);
        return;
      }

      String? coverBase64;
      String? localCoverPath;
      if (metadata != null && metadata.pictures.isNotEmpty) {
        try {
          coverBase64 = base64Encode(metadata.pictures.first.bytes);
          // Save cover locally immediately so UI can show it even before server responds
          try {
            final coverBytes = metadata.pictures.first.bytes;
            final coverFile = File('${dir.path}/${title}-cover.jpg');
            await coverFile.writeAsBytes(coverBytes);
            localCoverPath = coverFile.path;
            print('Saved local cover for $title at $localCoverPath');
          } catch (e) {
            print('Error writing local cover file for $title: $e');
          }
          print('Cover metadata found for $title');
        } catch (e) {
          print('Error encoding cover for $title: $e');
        }
      } else {
        print('No cover metadata found for $title');
      }

      final bytes = await file.readAsBytes();
      final fileBase64 = base64Encode(bytes);

      final request = SocketRequest(
        action: 'add_local_music',
        data: {
          'email': currentUser!.email,
          'title': title,
          'artist': artist,
          'file': fileBase64,
          'cover': coverBase64 ?? '',
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      final response = await _socketService.send(request);
      print('Response for add_local_music: ${response.toJson()}');

      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final localFile = File('${dir.path}/${data['filePath'] ?? '$title.mp3'}');
        await localFile.writeAsBytes(bytes);

        String? coverPath;
        // If server returned cover, prefer that (and overwrite local if necessary),
        // otherwise keep the cover we saved from metadata (localCoverPath).
        if (data.containsKey('cover') && data['cover'] != null && data['cover'].toString().isNotEmpty) {
          try {
            final coverBytes = base64Decode(data['cover'] as String);
            final coverFile = File('${dir.path}/${title}-cover.jpg');
            await coverFile.writeAsBytes(coverBytes);
            coverPath = coverFile.path;
            print('Cover saved for $title at $coverPath (from server)');
          } catch (e) {
            print('Error saving cover from server for $title: $e');
            _showMessage('Error saving cover: $e', error: true);
            // fallback to localCoverPath if writing server cover fails
            coverPath = localCoverPath;
          }
        } else {
          // No cover returned from server, use local one if available
          coverPath = localCoverPath;
          if (coverPath != null) {
            print('No cover returned from server for $title, using local cover at $coverPath');
          } else {
            print('No cover available for $title');
          }
        }

        _showMessage('Song added successfully');

        setState(() {
          userSongs.add(Homepagesong(
            id: data['id'] ?? userSongs.length + 1,
            title: title,
            artist: artist,
            filePath: data['filePath'] ?? '',
            localPath: localFile.path,
            uploaderEmail: currentUser!.email,
            isFromServer: false,
            addedAt: DateTime.now(),
            coverPath: coverPath,
          ));
          _sortSongs();
        });
      } else {
        _showMessage('Failed to add song: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error adding local song: $e');
      _showMessage('Error adding local song: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addServerSong() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Select Server Song',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: serverSongs.length,
            itemBuilder: (context, index) {
              final song = serverSongs[index];
              if (userSongs.any((userSong) => userSong.title == song.title)) {
                return const SizedBox.shrink();
              }
              return ListTile(
                title: Text(
                  song.title,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                ),
                subtitle: Text(
                  song.artist,
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => isLoading = true);
                  try {
                    final request = SocketRequest(
                      action: 'add_server_music',
                      data: {
                        'email': currentUser!.email,
                        'music_name': song.title,
                      },
                      requestId: DateTime.now().millisecondsSinceEpoch.toString(),
                    );
                    final response = await _socketService.send(request);
                    print('Response for add_server_music: ${response.toJson()}');
                    if (response.isSuccess) {
                      _showMessage('Server song added successfully');
                      await _refreshData();
                    } else {
                      _showMessage('Failed to add server song: ${response.message}', error: true);
                    }
                  } catch (e) {
                    print('Error adding server song: $e');
                    _showMessage('Error adding server song: $e', error: true);
                  } finally {
                    setState(() => isLoading = false);
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

  Future<void> _removeSong(String title) async {
    if (currentUser == null || title.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'remove_user_music',
        data: {
          'email': currentUser!.email,
          'music_name': title,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await _socketService.send(request);
      print('Response for remove_user_music: ${response.toJson()}');
      if (response.isSuccess) {
        _showMessage('Song removed successfully');
        await _refreshData();
      } else {
        _showMessage('Failed to remove song: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error removing song: $e');
      _showMessage('Error removing song: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _sortSongs();
    });
  }

  void _sortSongs() {
    final query = searchController.text.toLowerCase();
    List<Homepagesong> filteredSongs = userSongs.where((song) {
      return song.title.toLowerCase().contains(query) || song.artist.toLowerCase().contains(query);
    }).toList();
    if (currentSort == SortType.name) {
      filteredSongs.sort((a, b) => isAscending ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
    } else {
      filteredSongs.sort((a, b) => isAscending ? a.addedAt.compareTo(b.addedAt) : b.addedAt.compareTo(a.addedAt));
    }
    setState(() {
      userSongs = filteredSongs;
    });
  }

  void _onNavBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlaylistPage()),
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
        duration: const Duration(seconds: 2),
        elevation: 10,
      ),
    );
  }

  Widget _buildSongCover(Homepagesong song) {
    print('Building cover for song: ${song.title}, coverPath: ${song.coverPath}');
    if (song.coverPath != null) {
      final coverFile = File(song.coverPath!);
      if (coverFile.existsSync()) {
        print('Using existing cover at ${song.coverPath}');
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            coverFile,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading cover image for ${song.title}: $error');
              return _buildDefaultCover(song);
            },
          ),
        );
      } else {
        print('Cover file not found at ${song.coverPath}');
      }
    }

    return FutureBuilder<Directory>(
      future: getApplicationDocumentsDirectory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          print('Waiting for application directory for ${song.title}');
          return _buildDefaultCover(song);
        }
        if (snapshot.hasError) {
          print('Error accessing application directory: ${snapshot.error}');
          return _buildDefaultCover(song);
        }
        final dir = snapshot.data!;
        final possibleCoverNames = [
          '${song.title}-cover.jpg',
          'cover_${song.title}.jpg',
        ];
        for (final coverName in possibleCoverNames) {
          final coverFile = File('${dir.path}/$coverName');
          if (coverFile.existsSync()) {
            print('Found alternative cover for ${song.title} at ${coverFile.path}');
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                coverFile,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading alternative cover for ${song.title}: $error');
                  return _buildDefaultCover(song);
                },
              ),
            );
          }
        }
        print('No cover found for ${song.title}, using default');
        return _buildDefaultCover(song);
      },
    );
  }

  Widget _buildDefaultCover(Homepagesong song) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, color: Color(0xFFCE93D8), size: 30),
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
                    'Your Music',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      DropdownButton<SortType>(
                        dropdownColor: const Color(0xFF1E1E1E),
                        value: currentSort,
                        items: const [
                          DropdownMenuItem(
                            value: SortType.name,
                            child: Text('Name', style: TextStyle(color: Colors.white)),
                          ),
                          DropdownMenuItem(
                            value: SortType.date,
                            child: Text('Date', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            currentSort = value!;
                            _sortSongs();
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          color: const Color(0xFFCE93D8),
                        ),
                        onPressed: () {
                          setState(() {
                            isAscending = !isAscending;
                            _sortSongs();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchController,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search songs...',
                  hintStyle: GoogleFonts.poppins(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFCE93D8)),
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton.icon(
                        onPressed: _addLocalSong,
                        icon: const Icon(Icons.upload_file, color: Colors.white),
                        label: Text(
                          'Add Local',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCE93D8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFFCE93D8).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton.icon(
                        onPressed: _addServerSong,
                        icon: const Icon(Icons.cloud_download, color: Colors.white),
                        label: Text(
                          'Add Server',
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCE93D8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFFCE93D8).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isLoading
                  ? const Center(
                child: SpinKitFadingCircle(
                  color: Color(0xFFCE93D8),
                  size: 50,
                ),
              )
                  : userSongs.isEmpty
                  ? Center(
                child: Text(
                  'No songs found. Add some!',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                ),
              )
                  : StreamBuilder<List<String>>(
                stream: _likedSongsStreamController.stream,
                initialData: _likedSongTitles,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('StreamBuilder error: ${snapshot.error}');
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16),
                      ),
                    );
                  }
                  final likedSongs = snapshot.data ?? _likedSongTitles;
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: userSongs.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Colors.white12,
                      height: 1,
                      thickness: 1,
                    ),
                    itemBuilder: (context, index) {
                      final song = userSongs[index];
                      final isLiked = likedSongs.contains(song.title.trim());
                      return Container(
                        color: const Color(0xFF1E1E1E),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: _buildSongCover(song),
                          title: Text(
                            song.title,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            song.artist,
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.red : Colors.white54,
                                  size: 24,
                                ),
                                onPressed: () => _toggleLike(song),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white54),
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _removeSong(song.title);
                                  } else if (value == 'share') {
                                    _shareSong(song);
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            final result = await Navigator.push(
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
                                  songs: userSongs
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
                            if (result == true) {
                              await _refreshData();
                            }
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