import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:projectap/Song.dart';
import 'package:projectap/User.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/appstorage.dart';

AppStorage storage = AppStorage();


String sanitizeFileName(String name) {
  return name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
}


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
  } catch (e) {
    print('extractCoverFromFile error: $e');
  }
  return null;
}

class MusicPlayerPage extends StatefulWidget {
  final Music song;
  final List<Music> songs;
  final int currentIndex;

  const MusicPlayerPage({
    super.key,
    required this.song,
    required this.songs,
    required this.currentIndex,
  });

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  final AudioPlayer _player = AudioPlayer();
  final SocketService _socketService = SocketService();
  bool _isPlaying = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isLiked = false;
  int _currentIndex = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  User? _currentUser;
  List<String> _likedSongTitles = [];
  String? _currentCoverPath;
  Uint8List? _currentCoverBytes;
  bool _needsRefresh = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _loadCurrentUser().then((_) {
      _checkIfDownloaded();
      _loadLikedSongs();
      _initPlayer();
    });
    _setupPlayerListeners();
    _setupAutoNext();
  }

  @override
  void dispose() {
    _player.dispose();
    try {
      _socket_service_close();
    } catch (_) {}
    Navigator.pop(context, _needsRefresh);
    super.dispose();
  }

  void _socket_service_close() {
    try {
      _socketService.close();
    } catch (e) {
      print('Error closing socket service: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await storage.loadCurrentUser();
    if (user == null) {
      print('No user logged in');
      _showMessage('Please log in to access features', error: true);
      return;
    }
    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _checkIfDownloaded() async {
    final song = widget.songs[_currentIndex];
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = sanitizeFileName(song.title);
    final localFile = File('${dir.path}/$safeTitle.mp3');
    final exists = await localFile.exists();

    Uint8List? coverBytes;
    if (exists) {
      coverBytes = await extractCoverFromFile(localFile);
    }

    String? coverPath;
    final possibleCoverNames = [
      '${safeTitle}-cover.jpg',
      'cover_${safeTitle}.jpg',
      '${song.title}-cover.jpg',
      'cover_${song.title}.jpg',
    ];

    if (coverBytes == null) {
      for (final name in possibleCoverNames) {
        final f = File('${dir.path}/$name');
        if (await f.exists()) {
          coverPath = f.path;
          try {
            coverBytes = await f.readAsBytes();
          } catch (e) {
            print('Error reading cover file $name: $e');
          }
          break;
        }
      }
    } else {
      try {
        final coverFile = File('${dir.path}/${safeTitle}-cover.jpg');
        if (!coverFile.existsSync()) {
          await coverFile.writeAsBytes(coverBytes);
        }
        coverPath = coverFile.path;
      } catch (e) {
        print('Error writing extracted cover to file: $e');
      }
    }

    setState(() {
      _isDownloaded = exists;
      _currentCoverBytes = coverBytes;
      _currentCoverPath = coverPath;
    });
  }

  Future<void> _loadLikedSongs() async {
    if (_currentUser == null) return;
    try {
      final request = SocketRequest(
        action: 'list_liked_music',
        data: {'email': _currentUser!.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      print('Sending list_liked_music request: ${request.toJson()}');
      final response = await _socketService.send(request);
      print('Response for list_liked_music: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        setState(() {
          _likedSongTitles = (response.data as List<dynamic>)
              .where((json) => json['title'] != null && json['title'] is String)
              .map((json) => (json['title'] as String).trim())
              .toList();
          _isLiked = _likedSongTitles.contains(widget.songs[_currentIndex].title.trim());
        });
        print('Loaded liked songs: $_likedSongTitles');
      } else {
        _showMessage('Failed to load liked songs: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error loading liked songs: $e');
      _showMessage('Error loading liked songs: $e', error: true);
    }
  }

  Future<void> _initPlayer() async {
    try {
      final song = widget.songs[_currentIndex];
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = sanitizeFileName(song.title);
      final localFile = File('${dir.path}/$safeTitle.mp3');

      if (await localFile.exists()) {
        await _player.setFilePath(localFile.path);
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
          _isPlaying = _player.playing;
        });

        Uint8List? coverBytes = await extractCoverFromFile(localFile);
        String? coverPath;
        if (coverBytes != null) {
          try {
            final coverFile = File('${dir.path}/${safeTitle}-cover.jpg');
            if (!coverFile.existsSync()) {
              await coverFile.writeAsBytes(coverBytes);
            }
            coverPath = coverFile.path;
          } catch (e) {
            print('Error writing cover file: $e');
          }
        } else {
          final possible = ['${safeTitle}-cover.jpg', 'cover_${safeTitle}.jpg'];
          for (final name in possible) {
            final f = File('${dir.path}/$name');
            if (await f.exists()) {
              try {
                coverPath = f.path;
                coverBytes = await f.readAsBytes();
                break;
              } catch (e) {
                print('Error reading cover fallback $name: $e');
              }
            }
          }
        }

        setState(() {
          _currentCoverBytes = coverBytes;
          _currentCoverPath = coverPath;
        });
      } else {
        setState(() => _isDownloading = true);
        final request = SocketRequest(
          action: 'download_music',
          data: {'name': song.title, 'email': _currentUser?.email},
          requestId: DateTime.now().millisecondsSinceEpoch.toString(),
        );
        print('Sending download_music request: ${request.toJson()}');
        final response = await _socketService.send(request);
        print('Response for download_music: ${response.toJson()}');

        if (response.isSuccess && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final musicData = base64Decode(data['file'] as String);
          await localFile.writeAsBytes(musicData);
          await _player.setFilePath(localFile.path);

          Uint8List? coverBytes;
          String? coverPath;
          if (data.containsKey('cover') && data['cover'].toString().isNotEmpty) {
            try {
              coverBytes = base64Decode(data['cover'] as String);
              final coverFile = File('${dir.path}/${safeTitle}-cover.jpg');
              await coverFile.writeAsBytes(coverBytes);
              coverPath = coverFile.path;
            } catch (e) {
              print('Error decoding/writing server cover: $e');
            }
          }
          if (coverBytes == null) {
            coverBytes = await extractCoverFromFile(localFile);
            if (coverBytes != null) {
              try {
                final coverFile = File('${dir.path}/${safeTitle}-cover.jpg');
                if (!coverFile.existsSync()) {
                  await coverFile.writeAsBytes(coverBytes);
                }
                coverPath = coverFile.path;
              } catch (e) {
                print('Error writing extracted cover to file: $e');
              }
            }
          }

          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
            _isPlaying = _player.playing;
            _currentCoverBytes = coverBytes;
            _currentCoverPath = coverPath;
            _needsRefresh = true;
          });
        } else {
          setState(() => _isDownloading = false);
          _showMessage('Failed to download song: ${response.message}', error: true);
        }
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      print('Error initializing player: $e');
      _showMessage('Error initializing player: $e', error: true);
    }
  }

  Future<List<Map<String, String>>> _loadUsers() async {
    if (_currentUser == null) {
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
      print('Sending list_users request: ${request.toJson()}');
      final response = await _socket_service_send(request);
      print('Response for list_users: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        final users = (response.data as List<dynamic>)
            .where((json) => json['email'] != null && json['email'] is String && json['email'] != _currentUser!.email)
            .map((json) => {
          'email': json['email'] as String,
          'username': json['username'] as String? ?? 'Unknown',
        })
            .toList();
        print('Loaded users: $users');
        if (users.isEmpty) {
          _showMessage('No users available for sharing');
        }
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

  Future<dynamic> _socket_service_send(SocketRequest request) async {
    return await _socketService.send(request);
  }

  Future<void> _shareSong() async {
    if (_currentUser == null) {
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
          'Share Song: ${widget.songs[_currentIndex].title}',
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
                  final song = widget.songs[_currentIndex];
                  try {
                    final request = SocketRequest(
                      action: 'share_music',
                      data: {
                        'email': _currentUser!.email,
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
                      setState(() {
                        _needsRefresh = true;
                      });
                    } else {
                      _showMessage('Failed to share song: ${response.message}', error: true);
                    }
                  } catch (e) {
                    print('Error sharing song: $e');
                    _showMessage('Error sharing song: $e', error: true);
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

  Future<void> _toggleLike() async {
    if (_currentUser == null) {
      print('No user logged in');
      _showMessage('Please log in to like songs', error: true);
      return;
    }

    final song = widget.songs[_currentIndex];
    final isCurrentlyLiked = _isLiked;
    setState(() {
      _isLiked = !isCurrentlyLiked;
      _needsRefresh = true;
    });

    try {
      final request = SocketRequest(
        action: isCurrentlyLiked ? 'unlike_music' : 'like_music',
        data: {
          'email': _currentUser!.email,
          'music_name': song.title,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      print('Sending ${isCurrentlyLiked ? 'unlike' : 'like'} request: ${request.toJson()}');
      final response = await _socketService.send(request);
      print('Response for ${isCurrentlyLiked ? 'unlike' : 'like'}: ${response.toJson()}');
      if (response.isSuccess) {
        await _loadLikedSongs();
        _showMessage(isCurrentlyLiked ? 'Song unliked' : 'Song liked');
      } else {
        setState(() {
          _isLiked = isCurrentlyLiked;
          _needsRefresh = true;
        });
        _showMessage('Failed to ${isCurrentlyLiked ? 'unlike' : 'like'} song: ${response.message}', error: true);
      }
    } catch (e) {
      setState(() {
        _isLiked = isCurrentlyLiked;
        _needsRefresh = true;
      });
      print('Error toggling like: $e');
      _showMessage('Error toggling like: $e', error: true);
    }
  }

  void _setupPlayerListeners() {
    _player.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _player.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });

    _player.playingStream.listen((playing) {
      setState(() {
        _isPlaying = playing;
      });
    });
  }

  void _setupAutoNext() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });
  }

  void _playNext() {
    if (_currentIndex < widget.songs.length - 1) {
      setState(() {
        _currentIndex++;
        _isLiked = _likedSongTitles.contains(widget.songs[_currentIndex].title.trim());
      });
      _initPlayer();
      _checkIfDownloaded();
      _loadLikedSongs();
    } else {
      setState(() {
        _currentIndex = 0;
        _isLiked = _likedSongTitles.contains(widget.songs[_currentIndex].title.trim());
      });
      _initPlayer();
      _checkIfDownloaded();
      _loadLikedSongs();
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isLiked = _likedSongTitles.contains(widget.songs[_currentIndex].title.trim());
      });
      _initPlayer();
      _checkIfDownloaded();
      _loadLikedSongs();
    } else {
      setState(() {
        _currentIndex = widget.songs.length - 1;
        _isLiked = _likedSongTitles.contains(widget.songs[_currentIndex].title.trim());
      });
      _initPlayer();
      _checkIfDownloaded();
      _loadLikedSongs();
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

  Widget _buildSongCover(Music song) {
    final dirFuture = getApplicationDocumentsDirectory();

    if (_currentCoverBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          _currentCoverBytes!,
          width: 250,
          height: 250,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultCover(song);
          },
        ),
      );
    }

    if (_currentCoverPath != null) {
      final coverFile = File(_currentCoverPath!);
      if (coverFile.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            coverFile,
            width: 250,
            height: 250,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultCover(song);
            },
          ),
        );
      }
    }

    return FutureBuilder<Directory>(
      future: dirFuture,
      builder: (context, snap) {
        if (!snap.hasData) return _buildDefaultCover(song);
        final dir = snap.data!;
        final safeTitle = sanitizeFileName(song.title);
        final localPaths = [
          '${dir.path}/$safeTitle.mp3',
          '${dir.path}/${song.title}.mp3',
        ];
        for (final p in localPaths) {
          final f = File(p);
          if (f.existsSync()) {
            return FutureBuilder<Uint8List?>(
              future: extractCoverFromFile(f),
              builder: (c, s2) {
                if (s2.connectionState == ConnectionState.done && s2.data != null) {
                  // cache it for future renders
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _currentCoverBytes = s2.data;
                    });
                  });
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      s2.data!,
                      width: 250,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultCover(song);
                      },
                    ),
                  );
                }
                final possibleCoverFiles = [
                  '${dir.path}/${safeTitle}-cover.jpg',
                  '${dir.path}/cover_${safeTitle}.jpg',
                  '${dir.path}/${song.title}-cover.jpg',
                ];
                for (final cp in possibleCoverFiles) {
                  final cf = File(cp);
                  if (cf.existsSync()) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(cf, width: 250, height: 250, fit: BoxFit.cover),
                    );
                  }
                }
                return _buildDefaultCover(song);
              },
            );
          }
        }
        return _buildDefaultCover(song);
      },
    );
  }

  Widget _buildDefaultCover(Music song) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        song.filePath.contains(_currentUser?.email ?? '') ? Icons.phone_android : Icons.cloud,
        color: const Color(0xFFCE93D8),
        size: 60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.songs[_currentIndex];
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context, _needsRefresh);
          },
        ),
        title: Text(
          'Now Playing',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            _playPrevious();
          } else if (details.primaryVelocity! < 0) {
            _playNext();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSongCover(song),
              const SizedBox(height: 24),
              Text(
                song.title,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                song.artist,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white54,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              if (_isDownloading)
                const SpinKitThreeBounce(color: Color(0xFFCE93D8), size: 24)
              else
                Column(
                  children: [
                    Slider(
                      value: _position.inSeconds.toDouble(),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        _player.seek(Duration(seconds: value.toInt()));
                      },
                      activeColor: const Color(0xFFCE93D8),
                      inactiveColor: Colors.grey[700],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPlayerControls(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? Colors.red : Colors.white, size: 30),
                          onPressed: _toggleLike,
                        ),
                        const SizedBox(width: 40),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white, size: 30),
                          onPressed: _shareSong,
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 40), onPressed: _playPrevious),
        const SizedBox(width: 20),
        Container(
          decoration: BoxDecoration(color: const Color(0xFFCE93D8), borderRadius: BorderRadius.circular(30)),
          child: IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
            onPressed: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.play();
              }
            },
          ),
        ),
        const SizedBox(width: 20),
        IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 40), onPressed: _playNext),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}