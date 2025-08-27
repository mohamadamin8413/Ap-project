import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  final Uint8List? coverBytes;

  Homepagesong({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    this.localPath,
    this.uploaderEmail,
    this.isFromServer = false,
    required this.addedAt,
    this.coverBytes,
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
      coverBytes: null,
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
  };

  Homepagesong copyWith({
    Uint8List? coverBytes,
    String? localPath,
    String? title,
    String? artist,
  }) {
    return Homepagesong(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      filePath: filePath,
      localPath: localPath ?? this.localPath,
      uploaderEmail: uploaderEmail,
      isFromServer: isFromServer,
      addedAt: addedAt,
      coverBytes: coverBytes ?? this.coverBytes,
    );
  }
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
        setState(() {
          _likedSongTitles = likedSongs;
        });
      },
      onError: (error) {
        _showMessage('Stream error: $error', error: true);
      },
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    try { _socket_service_close(); } catch (_) {}
    if (!_likedSongsStreamController.isClosed) {
      _likedSongsStreamController.close();
    }
    super.dispose();
  }

  void _socket_service_close() {
    try { _socketService.close(); } catch (e) {  }
  }

  Future<void> _loadCurrentUser() async {
    final user = await storage.loadCurrentUser();
    setState(() {
      currentUser = user;
    });
    if (user != null) {
      await _initialDataLoad();
    }
  }

  Future<void> _initialDataLoad() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _loadUserSongs(),
        _loadServerSongs(),
        _loadLikedSongs(),
      ]);
    } catch (e) {
      _showMessage('Error loading initial data: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _loadUserSongs(),
        _loadServerSongs(),
        _loadLikedSongs(),
      ]);
    } catch (e) {
      _showMessage('Error refreshing data: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<Uint8List?> _extractCoverBytesFromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final metadata = await readMetadata(file, getImage: true);
      if (metadata != null && metadata.pictures.isNotEmpty) {
        final bytes = metadata.pictures.first.bytes;
        if (bytes is Uint8List) return bytes;
        if (bytes != null) return Uint8List.fromList(bytes);
      }
      final coverFile = File('${file.parent.path}/${file.uri.pathSegments.last.replaceAll('.mp3','')}-cover.jpg');
      if (await coverFile.exists()) {
        return await coverFile.readAsBytes();
      }
    } catch (e) {

    }
    return null;
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
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultCover(song);
          },
        ),
      );
    }

    if (song.localPath != null && File(song.localPath!).existsSync()) {
      return FutureBuilder<Uint8List?>(
        future: _extractCoverBytesFromFile(song.localPath!),
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
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          song.title.isNotEmpty ? song.title[0].toUpperCase() : '',
          style: GoogleFonts.poppins(
            color: const Color(0xFFCE93D8),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultCoverForTitle(String title) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '',
          style: GoogleFonts.poppins(
            color: const Color(0xFFCE93D8),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildServerSongLeading(Music song) {
    return FutureBuilder<Uint8List?>(
      future: () async {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final safeMp3Path = '${appDir.path}/${song.title}.mp3';
          final mp3File = File(safeMp3Path);
          if (await mp3File.exists()) {
            // try embedded cover
            try {
              final meta = await readMetadata(mp3File, getImage: true);
              if (meta != null && meta.pictures.isNotEmpty) {
                final p = meta.pictures.first.bytes;
                if (p is Uint8List) return p;
                if (p != null) return Uint8List.fromList(p);
              }
            } catch (e) {
              print('Error reading metadata for server-song ${song.title}: $e');
            }
            final coverFile1 = File('${appDir.path}/${song.title}-cover.jpg');
            if (await coverFile1.exists()) return await coverFile1.readAsBytes();
            final coverFile2 = File('${appDir.path}/cover_${song.title}.jpg');
            if (await coverFile2.exists()) return await coverFile2.readAsBytes();
          } else {
            final coverFile1 = File('${appDir.path}/${song.title}-cover.jpg');
            if (await coverFile1.exists()) return await coverFile1.readAsBytes();
            final coverFile2 = File('${appDir.path}/cover_${song.title}.jpg');
            if (await coverFile2.exists()) return await coverFile2.readAsBytes();
          }
        } catch (e) {
          print('Error in _buildServerSongLeading future: $e');
        }
        return null;
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              snapshot.data!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _buildDefaultCoverForTitle(song.title),
            ),
          );
        }
        return _buildDefaultCoverForTitle(song.title);
      },
    );
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
      final response = await _socket_service_send(request);
      if (response.isSuccess && response.data != null && response.data is List<dynamic>) {
        final futures = (response.data as List<dynamic>).map((json) async {
          String? localPath;
          final expectedPath = '${appDir.path}/${json['title']}.mp3';
          if (File(expectedPath).existsSync()) {
            localPath = expectedPath;
          }
          String title = json['title'] as String? ?? 'Unknown';
          String artist = json['artist'] as String? ?? 'Unknown';
          Uint8List? coverBytes;
          if (localPath != null) {
            final metadata = await readMetadata(File(localPath), getImage: true);
            if (metadata != null) {
              title = metadata.title?.trim() ?? title;
              artist = metadata.artist?.trim() ?? artist;
              if (metadata.pictures.isNotEmpty) {
                final p = metadata.pictures.first.bytes;
                if (p is Uint8List) coverBytes = p;
                else if (p != null) coverBytes = Uint8List.fromList(p);
              }
            }
          }
          return Homepagesong(
            id: json['id'] as int? ?? 0,
            title: title.trim(),
            artist: artist,
            filePath: json['filePath'] as String? ?? '',
            localPath: localPath,
            uploaderEmail: json['uploaderEmail'] as String?,
            isFromServer: json['uploaderEmail'] != null && json['uploaderEmail'] != '',
            addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
            coverBytes: coverBytes,
          );
        }).toList();

        final resolved = await Future.wait(futures);
        setState(() {
          userSongs = resolved;
          _sortSongs();
        });
      } else {
        _showMessage('Failed to load user songs: ${response.message}', error: true);
      }
    } catch (e) {

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
      final response = await _socket_service_send(request);
      if (response.isSuccess && response.data != null && response.data is List<dynamic>) {
        setState(() {
          serverSongs = (response.data as List<dynamic>)
              .where((json) => json['id'] != null && json['title'] != null && json['filePath'] != null)
              .map((json) => Music.fromJson(json))
              .toList();
        });
      } else {
        _showMessage('Failed to load server songs: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error loading server songs: $e', error: true);
    }
  }

  Future<dynamic> _socket_service_send(SocketRequest request) async {
    return await _socketService.send(request);
  }

  Future<void> _loadLikedSongs() async {
    if (currentUser == null || _isLoadingLikedSongs) return;
    _isLoadingLikedSongs = true;
    try {
      final request = SocketRequest(
        action: 'list_liked_music',
        data: {'email': currentUser!.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await _socket_service_send(request);
      if (response.isSuccess && response.data != null && response.data is List<dynamic>) {
        final liked = (response.data as List<dynamic>).map((json) => (json['title'] as String).trim()).toList();
        if (!_likedSongsStreamController.isClosed) _likedSongsStreamController.add(liked);
      } else {
        _showMessage('Failed to load liked songs: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error loading liked songs: $e', error: true);
    } finally {
      _isLoadingLikedSongs = false;
    }
  }

  Future<void> _toggleLike(Homepagesong song) async {
    if (currentUser == null) {
      _showMessage('Please log in to like songs', error: true);
      return;
    }
    final isCurrentlyLiked = _likedSongTitles.contains(song.title.trim());
    final updatedLikedSongs = List<String>.from(_likedSongTitles);
    if (isCurrentlyLiked) updatedLikedSongs.remove(song.title.trim()); else updatedLikedSongs.add(song.title.trim());
    if (!_likedSongsStreamController.isClosed) _likedSongsStreamController.add(updatedLikedSongs);

    try {
      final request = SocketRequest(
        action: isCurrentlyLiked ? 'unlike_music' : 'like_music',
        data: {
          'email': currentUser!.email,
          'music_name': song.title,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await _socket_service_send(request);
      if (response.isSuccess) {
        _showMessage(isCurrentlyLiked ? 'Song unliked' : 'Song liked');
        await _loadLikedSongs();
      } else {
        if (!_likedSongsStreamController.isClosed) _likedSongsStreamController.add(_likedSongTitles);
        _showMessage('Failed to ${isCurrentlyLiked ? 'unlike' : 'like'} song: ${response.message}', error: true);
      }
    } catch (e) {
      if (!_likedSongsStreamController.isClosed) _likedSongsStreamController.add(_likedSongTitles);
      _showMessage('Error toggling like: $e', error: true);
    }
  }

  Future<void> _autoDownloadSong(Homepagesong song) async {
    if (song.localPath != null && File(song.localPath!).existsSync()) {
      if (song.coverBytes == null) {
        final bytes = await _extractCoverBytesFromFile(song.localPath!);
        if (bytes != null) {
          setState(() {
            final idx = userSongs.indexWhere((s) => s.id == song.id);
            if (idx != -1) userSongs[idx] = userSongs[idx].copyWith(coverBytes: bytes);
          });
        }
      }
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
      final response = await _socket_service_send(request);
      if (response.isSuccess && response.data != null) {
        final String base64File = response.data['file'] as String;
        final bytes = base64Decode(base64File);
        await localFile.writeAsBytes(bytes);

        Uint8List? coverBytes;
        if (response.data['cover'] != null && response.data['cover'].toString().isNotEmpty) {
          try {
            coverBytes = Uint8List.fromList(base64Decode(response.data['cover'] as String));
          } catch (e) {
            print('Error decoding server cover: $e');
          }
        }
        if (coverBytes == null) {
          final extracted = await _extractCoverBytesFromFile(localFile.path);
          if (extracted != null) coverBytes = extracted;
        }

        final metadata = await readMetadata(localFile, getImage: true);
        String title = song.title;
        String artist = song.artist;
        if (metadata != null) {
          title = metadata.title?.trim() ?? title;
          artist = metadata.artist?.trim() ?? artist;
        }

        setState(() {
          final index = userSongs.indexWhere((s) => s.id == song.id);
          if (index != -1) {
            userSongs[index] = userSongs[index].copyWith(localPath: localFile.path, coverBytes: coverBytes, title: title, artist: artist);
          } else {
            userSongs.add(Homepagesong(
              id: song.id,
              title: title,
              artist: artist,
              filePath: song.filePath,
              localPath: localFile.path,
              uploaderEmail: song.uploaderEmail,
              isFromServer: song.isFromServer,
              addedAt: song.addedAt,
              coverBytes: coverBytes,
            ));
          }
        });
      } else {
        _showMessage('Failed to download song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error downloading song: $e', error: true);
    }
  }

  Future<void> _shareSong(Homepagesong song) async {
    if (currentUser == null) {
      _showMessage('Please log in to share songs', error: true);
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
        title: Text('Share Song: ${song.title}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: double.maxFinite,
          height: 240,
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user['username']!, style: GoogleFonts.poppins(color: Colors.white)),
                subtitle: Text(user['email']!, style: GoogleFonts.poppins(color: Colors.white54)),
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
                    final response = await _socket_service_send(request);
                    if (response.isSuccess) {
                      _showMessage('Song shared with ${user['username']}');
                    } else {
                      _showMessage('Failed to share song: ${response.message}', error: true);
                    }
                  } catch (e) {
                    _showMessage('Error sharing song: $e', error: true);
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFFCE93D8))))],
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

      // read metadata incl. image
      final metadata = await readMetadata(file, getImage: true);
      final title = (metadata?.title?.trim().isNotEmpty ?? false) ? metadata!.title!.trim() : result.files.single.name.replaceAll('.mp3', '');
      final artist = (metadata?.artist?.trim().isNotEmpty ?? false) ? metadata!.artist!.trim() : 'Unknown Artist';

      if (userSongs.any((song) => song.title.trim() == title)) {
        _showMessage('This song already exists in your library', error: true);
        return;
      }

      Uint8List? coverBytes;
      if (metadata != null && metadata.pictures.isNotEmpty) {
        final p = metadata.pictures.first.bytes;
        if (p is Uint8List) coverBytes = p;
        else if (p != null) coverBytes = Uint8List.fromList(p);
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
          'cover': coverBytes != null ? base64Encode(coverBytes) : '',
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      final response = await _socket_service_send(request);
      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final dir = await getApplicationDocumentsDirectory();
        final localFile = File('${dir.path}/${title}.mp3');
        await localFile.writeAsBytes(bytes);

        Uint8List? finalCover = coverBytes;
        if (data.containsKey('cover') && data['cover'] != null && data['cover'].toString().isNotEmpty) {
          try {
            finalCover = Uint8List.fromList(base64Decode(data['cover'] as String));
          } catch (e) {
            print('Error decoding server cover: $e');
          }
        } else if (finalCover == null) {
          final extracted = await _extractCoverBytesFromFile(localFile.path);
          if (extracted != null) finalCover = extracted;
        }

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
            coverBytes: finalCover,
          ));
          _sortSongs();
        });

        _showMessage('Song added successfully');
      } else {
        _showMessage('Failed to add song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error adding local song: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _addServerSong() async {
    if (currentUser == null) {
      _showMessage('Please log in first', error: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Select Server Song', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
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
                title: Text(song.title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
                subtitle: Text(song.artist, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
                leading: _buildServerSongLeading(song), // <<--- show cover like main list
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
                    final response = await _socket_service_send(request);
                    if (response.isSuccess) {
                      final newSong = Homepagesong(
                        id: song.id,
                        title: song.title,
                        artist: song.artist,
                        filePath: song.filePath,
                        uploaderEmail: null,
                        isFromServer: true,
                        addedAt: DateTime.now(),
                        coverBytes: null,
                      );
                      setState(() {
                        userSongs.add(newSong);
                        _sortSongs();
                      });
                      await _autoDownloadSong(newSong);
                      _showMessage('Server song added successfully');
                    } else {
                      _showMessage('Failed to add server song: ${response.message}', error: true);
                    }
                  } catch (e) {
                    _showMessage('Error adding server song: $e', error: true);
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFFCE93D8))))],
      ),
    );
  }

  Future<void> _removeSong(String title) async {
    if (currentUser == null || title.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'remove_user_music',
        data: {'email': currentUser!.email, 'music_name': title},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final response = await _socket_service_send(request);
      if (response.isSuccess) {
        setState(() {
          userSongs.removeWhere((song) => song.title == title);
          _sortSongs();
        });
        _showMessage('Song removed successfully');
      } else {
        _showMessage('Failed to remove song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error removing song: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, String>>> _loadUsers() async {
    if (currentUser == null) {
      _showMessage('Please log in to load users', error: true);
      return [];
    }
    try {
      final request = SocketRequest(action: 'list_users', data: {}, requestId: DateTime.now().millisecondsSinceEpoch.toString());
      final response = await _socket_service_send(request);
      if (response.isSuccess && response.data != null && response.data is List<dynamic>) {
        final users = (response.data as List<dynamic>)
            .where((json) => json['email'] != null && json['email'] is String && json['email'] != currentUser!.email)
            .map((json) => {'email': json['email'] as String, 'username': json['username'] as String? ?? 'Unknown'})
            .toList();
        return users;
      } else {
        _showMessage('Failed to load users: ${response.message}', error: true);
        return [];
      }
    } catch (e) {
      _showMessage('Error loading users: $e', error: true);
      return [];
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
      Navigator.push(context, MaterialPageRoute(builder: (context) => const PlaylistPage()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: error ? Colors.redAccent : const Color(0xFFCE93D8),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // header row
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Music', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      DropdownButton<SortType>(
                        dropdownColor: const Color(0xFF1E1E1E),
                        value: currentSort,
                        items: const [
                          DropdownMenuItem(value: SortType.name, child: Text('Name', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: SortType.date, child: Text('Date', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (value) { setState(() { currentSort = value!; _sortSongs(); }); },
                      ),
                      IconButton(icon: Icon(isAscending ? Icons.arrow_upward : Icons.arrow_downward, color: const Color(0xFFCE93D8)),
                          onPressed: () { setState(() { isAscending = !isAscending; _sortSongs(); }); }),
                    ],
                  ),
                ],
              ),
            ),

            // search field
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 1)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 2)),
                ),
              ),
            ),

            // buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addLocalSong,
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      label: Text('Add Local', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCE93D8), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addServerSong,
                      icon: const Icon(Icons.cloud_download, color: Colors.white),
                      label: Text('Add Server', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCE93D8), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // list
            Expanded(
              child: isLoading
                  ? const Center(child: SpinKitFadingCircle(color: Color(0xFFCE93D8), size: 50))
                  : userSongs.isEmpty
                  ? Center(child: Text('No songs found. Add some!', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16)))
                  : StreamBuilder<List<String>>(
                stream: _likedSongsStreamController.stream,
                initialData: _likedSongTitles,
                builder: (context, snapshot) {
                  final likedSongs = snapshot.data ?? _likedSongTitles;
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: userSongs.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1, thickness: 1),
                    itemBuilder: (context, index) {
                      final song = userSongs[index];
                      final isLiked = likedSongs.contains(song.title.trim());
                      return Container(
                        color: const Color(0xFF1E1E1E),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: _buildSongCover(song),
                          title: Text(song.title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text(song.artist, style: GoogleFonts.poppins(color: Colors.white54)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.white54),
                                onPressed: () => _toggleLike(song),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white54),
                                onSelected: (value) {
                                  if (value == 'delete') _removeSong(song.title);
                                  else if (value == 'share') _shareSong(song);
                                },
                                itemBuilder: (BuildContext context) => [
                                  PopupMenuItem(value: 'share', child: Row(children: [const Icon(Icons.share, color: Colors.white), const SizedBox(width: 8), Text('Share', style: GoogleFonts.poppins(color: Colors.white))])),
                                  PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, color: Colors.red), const SizedBox(width: 8), Text('Delete', style: GoogleFonts.poppins(color: Colors.red))])),
                                ],
                              ),
                            ],
                          ),
                          onTap: () async {
                            if (song.localPath == null || !File(song.localPath!).existsSync()) {
                              await _autoDownloadSong(song);
                            }
                            final localPath = (song.localPath != null && File(song.localPath!).existsSync()) ? song.localPath! : song.filePath;
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => MusicPlayerPage(
                              song: Music(id: song.id, title: song.title, artist: song.artist, filePath: localPath),
                              songs: userSongs.map((s) => Music(id: s.id, title: s.title, artist: s.artist, filePath: s.localPath != null && File(s.localPath!).existsSync() ? s.localPath! : s.filePath)).toList(),
                              currentIndex: index,
                            )));
                            if (result == true) await _refreshData();
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
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: 'Playlists'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}