import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:projectap/Song.dart';
import 'package:projectap/User.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/appstorage.dart';

AppStorage storage = AppStorage();

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
  bool _isPlaying = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  bool _isLiked = false;
  int _currentIndex = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final TextEditingController _shareEmailController = TextEditingController();
  final SocketService _socketService = SocketService();
  User? _currentUser;
  List<String> _likedSongTitles = [];

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
  }

  @override
  void dispose() {
    _player.dispose();
    _shareEmailController.dispose();
    _socketService.close();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await storage.loadCurrentUser();
    if (user == null) {
      _showMessage('No user logged in', error: true);
      return;
    }
    setState(() {
      _currentUser = user;
    });
  }

  Future<void> _checkIfDownloaded() async {
    final song = widget.songs[_currentIndex];
    final localFile = File('${(await getApplicationDocumentsDirectory()).path}/${song.title}.mp3');
    final exists = await localFile.exists();
    setState(() {
      _isDownloaded = exists;
    });
  }

  Future<void> _loadLikedSongs() async {
    if (_currentUser == null) return;
    try {
      final request = SocketRequest(
        action: 'list_liked_music',
        data: {'email': _currentUser!.email},
      );
      final response = await _socketService.send(request);
      if (response.isSuccess && response.data != null) {
        setState(() {
          _likedSongTitles = (response.data as List<dynamic>).map((json) => json['title'] as String).toList();
          _isLiked = _likedSongTitles.contains(widget.songs[_currentIndex].title);
        });
      } else {
        _showMessage('Failed to load liked songs: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error loading liked songs: $e', error: true);
    }
  }

  Future<void> _initPlayer() async {
    try {
      final song = widget.songs[_currentIndex];
      final localFile = File('${(await getApplicationDocumentsDirectory()).path}/${song.title}.mp3');
      if (await localFile.exists()) {
        await _player.setFilePath(localFile.path);
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
          _isPlaying = _player.playing;
        });
      } else {
        setState(() => _isDownloading = true);
        final request = SocketRequest(
          action: 'download_music',
          data: {'name': song.title},
        );
        final response = await _socketService.send(request);
        if (response.isSuccess && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final String base64File = data['file'] as String;
          final bytes = base64Decode(base64File);
          await localFile.writeAsBytes(bytes);
          await _player.setFilePath(localFile.path);
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
            _isPlaying = _player.playing;
          });
        } else {
          setState(() {
            _isDownloading = false;
            _isPlaying = false;
          });
          _showMessage('Failed to download song: ${response.message}', error: true);
          return;
        }
      }
      await _player.play();
      setState(() => _isPlaying = true);
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _isPlaying = false;
      });
      _showMessage('Error initializing player: $e', error: true);
    }
  }

  void _setupPlayerListeners() {
    _player.positionStream.listen((position) {
      setState(() => _position = position);
    });
    _player.durationStream.listen((duration) {
      setState(() => _duration = duration ?? Duration.zero);
    });
    _player.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _playNext();
        }
      });
    });
  }

  void _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
      setState(() => _isPlaying = _player.playing);
    } catch (e) {
      _showMessage('Error toggling play/pause: $e', error: true);
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isPlaying = false;
        _isDownloaded = false;
        _isDownloading = false;
        _isLiked = _likedSongTitles.contains(widget.songs[_currentIndex].title);
      });
      _checkIfDownloaded();
      _initPlayer();
    }
  }

  void _playNext() {
    if (_currentIndex < widget.songs.length - 1) {
      setState(() {
        _currentIndex++;
        _isPlaying = false;
        _isDownloaded = false;
        _isDownloading = false;
        _isLiked = _likedSongTitles.contains(widget.songs[_currentIndex].title);
      });
      _checkIfDownloaded();
      _initPlayer();
    }
  }

  Future<void> _toggleLike() async {
    if (_currentUser == null) {
      _showMessage('No user logged in', error: true);
      return;
    }
    try {
      final song = widget.songs[_currentIndex];
      final bool wasLiked = _isLiked;
      // بهینه‌سازی خوش‌بینانه: تغییر فوری UI
      setState(() {
        _isLiked = !wasLiked;
        if (_isLiked) {
          _likedSongTitles.add(song.title);
        } else {
          _likedSongTitles.remove(song.title);
        }
      });
      final request = SocketRequest(
        action: wasLiked ? 'unlike_music' : 'like_music',
        data: {
          'email': _currentUser!.email,
          'music_name': song.title,
        },
      );
      final response = await _socketService.send(request);
      if (!response.isSuccess) {
        // بازگشت به حالت قبلی در صورت خطا
        setState(() {
          _isLiked = wasLiked;
          if (wasLiked) {
            _likedSongTitles.add(song.title);
          } else {
            _likedSongTitles.remove(song.title);
          }
        });
        if (response.message.contains("already liked")) {
          _showMessage('Song is already liked', error: true);
        } else if (response.message.contains("not liked")) {
          _showMessage('Song is not liked', error: true);
        } else {
          _showMessage('Failed to ${wasLiked ? 'unlike' : 'like'} song: ${response.message}', error: true);
        }
      }
    } catch (e) {
      // بازگشت به حالت قبلی در صورت خطا
      setState(() {
        _isLiked = !_isLiked;
        if (_isLiked) {
          _likedSongTitles.add(widget.songs[_currentIndex].title);
        } else {
          _likedSongTitles.remove(widget.songs[_currentIndex].title);
        }
      });
      _showMessage('Error ${_isLiked ? 'unliking' : 'liking'} song: $e', error: true);
    }
  }

  Future<void> _shareSong() async {
    if (_currentUser == null) {
      _showMessage('No user logged in', error: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Share Song',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: _shareEmailController,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter email to share with',
            hintStyle: GoogleFonts.poppins(color: Colors.white54),
            prefixIcon: const Icon(Icons.email, color: Color(0xFFCE93D8)),
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
              final email = _shareEmailController.text.trim();
              if (email.isEmpty) {
                _showMessage('Please enter an email', error: true);
                return;
              }
              Navigator.pop(context);
              try {
                final request = SocketRequest(
                  action: 'share_music',
                  data: {
                    'email': _currentUser!.email,
                    'target_email': email,
                    'music_name': widget.songs[_currentIndex].title,
                  },
                );
                final response = await _socketService.send(request);
                if (response.isSuccess) {
                  _showMessage('Song shared successfully');
                } else {
                  _showMessage('Failed to share song: ${response.message}', error: true);
                }
              } catch (e) {
                _showMessage('Error sharing song: $e', error: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCE93D8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Share',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
    final song = widget.songs[_currentIndex];
    final isFirstSong = _currentIndex == 0;
    final isLastSong = _currentIndex == widget.songs.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: _isDownloading
            ? const Center(child: SpinKitThreeBounce(color: Color(0xFFCE93D8), size: 24))
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFFCE93D8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Now Playing',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    song.filePath.contains(_currentUser?.email ?? '') ? Icons.phone_android : Icons.cloud,
                    color: const Color(0xFFCE93D8),
                    size: 120,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    song.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: _position.inSeconds.toDouble(),
                    max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                    activeColor: const Color(0xFFCE93D8),
                    inactiveColor: Colors.white24,
                    onChanged: _duration.inSeconds > 0
                        ? (value) {
                      _player.seek(Duration(seconds: value.toInt()));
                    }
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: GoogleFonts.poppins(color: Colors.white54),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: GoogleFonts.poppins(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.skip_previous,
                          color: isFirstSong ? Colors.white24 : const Color(0xFFCE93D8),
                          size: 40,
                        ),
                        onPressed: isFirstSong ? null : _playPrevious,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFCE93D8), Color(0xFF8E24AA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 60,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.skip_next,
                          color: isLastSong ? Colors.white24 : const Color(0xFFCE93D8),
                          size: 40,
                        ),
                        onPressed: isLastSong ? null : _playNext,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFCE93D8), Color(0xFF8E24AA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _toggleLike,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: Colors.white,
                          ),
                          label: Text(
                            _isLiked ? 'Unlike' : 'Like',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFCE93D8), Color(0xFF8E24AA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _shareSong,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: Text(
                            'Share',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}