import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:projectap/Homepage.dart';
import 'package:projectap/ProfilePage.dart';
import 'package:projectap/Song.dart';
import 'package:projectap/User.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/Playlist.dart';
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
  final TextEditingController _shareEmailController = TextEditingController();
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    _shareEmailController.dispose();
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

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _loadUserPlaylists(),
        _loadUserSongs(),
      ]);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadUserPlaylists() async {
    if (currentUser == null) return;
    setState(() => playlists = []);
    try {
      final request = SocketRequest(
        action: 'list_user_playlists',
        data: {'email': currentUser!.email},
      );
      final response = await SocketService().send(request);
      print('Playlists response: $response');
      if (response.isSuccess && response.data != null) {
        final uniquePlaylists = <String, Playlist>{};
        for (var json in response.data as List<dynamic>) {
          if (json['id'] != null && json['name'] != null && json['name'].toString().isNotEmpty) {
            final musics = (json['musics'] as List<dynamic>?) ?? [];
            final playlistSongs = musics
                .where((m) => m['id'] != null && m['title'] != null && m['filePath'] != null)
                .map((m) => Homepagesong.fromJson({
              'id': m['id'],
              'title': m['title'],
              'artist': m['artist'] ?? 'Unknown',
              'filePath': m['filePath'],
              'uploaderEmail': m['uploaderEmail'] ?? '',
              'isFromServer': m['uploaderEmail'] != currentUser!.email,
              'addedAt': DateTime.now().toIso8601String(),
              'localPath': null,
            }))
                .toList();
            final songIds = playlistSongs.map((s) => s.id).toList();
            final playlist = Playlist.fromJson({
              'id': json['id'],
              'name': json['name'],
              'creatorEmail': json['creatorEmail'] ?? currentUser!.email,
              'songIds': songIds,
            });
            uniquePlaylists[playlist.id.toString()] = playlist;
            for (var song in playlistSongs) {
              if (!userSongs.any((s) => s.id == song.id)) {
                userSongs.add(song);
              }
            }
          }
        }
        setState(() {
          playlists = uniquePlaylists.values.toList();
          print('Loaded playlists: ${playlists.length}'); // لاگ برای دیباگ
        });
      } else {
        _showMessage('Failed to load playlists: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error loading playlists: $e', error: true);
    }
  }

  Future<void> _loadUserSongs() async {
    if (currentUser == null) return;
    try {
      final request = SocketRequest(
        action: 'list_user_musics',
        data: {'email': currentUser!.email},
      );
      final response = await SocketService().send(request);
      print('Songs response: $response'); // لاگ برای دیباگ
      if (response.isSuccess && response.data != null) {
        setState(() {
          userSongs = (response.data as List<dynamic>)
              .where((json) => json['id'] != null && json['title'] != null && json['filePath'] != null)
              .map((json) => Homepagesong.fromJson({
            'id': json['id'],
            'title': json['title'],
            'artist': json['artist'] ?? 'Unknown',
            'filePath': json['filePath'],
            'uploaderEmail': json['uploaderEmail'] ?? '',
            'isFromServer': json['uploaderEmail'] != currentUser!.email,
            'addedAt': DateTime.now().toIso8601String(),
            'localPath': null,
          }))
              .toList();
          print('Loaded songs: ${userSongs.length}'); // لاگ برای دیباگ
        });
      } else {
        _showMessage('Failed to load user songs: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error loading songs: $e', error: true);
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
              setState(() => isLoading = true);
              try {
                final request = SocketRequest(
                  action: 'create_playlist',
                  data: {
                    'email': currentUser!.email,
                    'name': name,
                  },
                );
                final response = await SocketService().send(request);
                if (response.isSuccess) {
                  _showMessage('Playlist created successfully');
                  await _refreshData();
                } else {
                  _showMessage('Failed to create playlist: ${response.message}', error: true);
                }
              } catch (e) {
                _showMessage('Error creating playlist: $e', error: true);
              } finally {
                setState(() => isLoading = false);
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

    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'delete_playlist',
        data: {
          'email': currentUser!.email,
          'playlist_name': playlist.name,
        },
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        _showMessage('Playlist deleted successfully');
        await _refreshData();
      } else {
        _showMessage('Failed to delete playlist: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error deleting playlist: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _sharePlaylist(Playlist playlist) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Share Playlist',
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
              setState(() => isLoading = true);
              try {
                final request = SocketRequest(
                  action: 'share_playlist',
                  data: {
                    'email': currentUser!.email,
                    'target_email': email,
                    'playlist_name': playlist.name,
                  },
                );
                final response = await SocketService().send(request);
                if (response.isSuccess) {
                  _showMessage('Playlist shared successfully');
                } else {
                  _showMessage('Failed to share playlist: ${response.message}', error: true);
                }
              } catch (e) {
                _showMessage('Error sharing playlist: $e', error: true);
              } finally {
                setState(() => isLoading = false);
                _shareEmailController.clear();
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    }
  }

  void _showPlaylistDetails(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailsPage(
          playlist: playlist,
          userSongs: userSongs,
          currentUser: currentUser!,
          onUpdate: _refreshData,
          updateUserSongs: (updatedSongs) {
            setState(() {
              userSongs = updatedSongs;
            });
          },
        ),
      ),
    ).then((_) => _refreshData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: isLoading
            ? const Center(child: SpinKitThreeBounce(color: Color(0xFFCE93D8), size: 24))
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Playlists',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFFCE93D8)),
                    onPressed: _createPlaylist,
                  ),
                ],
              ),
            ),
            Expanded(
              child: playlists.isEmpty
                  ? Center(
                child: Text(
                  'No playlists found. Create one!',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  final songCount = playlist.songIds.length;
                  return Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        playlist.name,
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '$songCount songs',
                        style: GoogleFonts.poppins(color: Colors.white54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share, color: Color(0xFFCE93D8)),
                            onPressed: () => _sharePlaylist(playlist),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _deletePlaylist(playlist),
                          ),
                        ],
                      ),
                      onTap: () => _showPlaylistDetails(playlist),
                    ),
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
        backgroundColor: const Color(0xFF1E1E1E),
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

  Future<void> _addSongToPlaylist() async {
    final availableSongs = widget.userSongs
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
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableSongs.length,
            itemBuilder: (context, index) {
              final song = availableSongs[index];
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
                    if (!widget.userSongs.any((s) => s.id == song.id)) {
                      final ensureRequest = SocketRequest(
                        action: 'add_server_music',
                        data: {
                          'email': widget.currentUser.email,
                          'music_name': song.title,
                        },
                      );
                      final ensureResponse = await SocketService().send(ensureRequest);
                      if (!ensureResponse.isSuccess) {
                        _showMessage('Failed to ensure song in user music: ${ensureResponse.message}', error: true);
                        setState(() => isLoading = false);
                        return;
                      }
                      final updatedSongs = List<Homepagesong>.from(widget.userSongs)..add(song);
                      widget.updateUserSongs(updatedSongs);
                    }

                    final request = SocketRequest(
                      action: 'add_music_to_playlist',
                      data: {
                        'email': widget.currentUser.email,
                        'playlist_name': widget.playlist.name,
                        'music_name': song.title,
                      },
                    );
                    final response = await SocketService().send(request);
                    if (response.isSuccess) {
                      _showMessage('Song added to playlist');
                      // به‌روزرسانی فوری پلی‌لیست در کلاینت
                      setState(() {
                        widget.playlist.songIds.add(song.id);
                      });
                      widget.onUpdate();
                    } else {
                      _showMessage('Failed to add song: ${response.message}', error: true);
                    }
                  } catch (e) {
                    _showMessage('Error adding song: $e', error: true);
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

  Future<void> _removeSongFromPlaylist(String musicName) async {
    setState(() => isLoading = true);
    try {
      final song = widget.userSongs.firstWhere(
            (song) => song.title == musicName,
        orElse: () => Homepagesong(id: 0, title: '', artist: '', filePath: '', uploaderEmail: '', isFromServer: false, addedAt: DateTime.now()),
      );
      if (song.id == 0) {
        _showMessage('Song not found', error: true);
        setState(() => isLoading = false);
        return;
      }

      final request = SocketRequest(
        action: 'remove_music_from_playlist',
        data: {
          'email': widget.currentUser.email,
          'playlist_name': widget.playlist.name,
          'music_name': musicName,
        },
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        _showMessage('Song removed from playlist');
        setState(() {
          widget.playlist.songIds.remove(song.id);
        });
        widget.onUpdate();
      } else {
        _showMessage('Failed to remove song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error removing song: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _playSong(Homepagesong song, List<Homepagesong> playlistSongs, int index) async {
    try {
      if (song.localPath == null && song.isFromServer) {
        setState(() => isLoading = true);
        final request = SocketRequest(
          action: 'download_music',
          data: {'name': song.title},
        );
        final response = await SocketService().send(request);
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
            );
            widget.updateUserSongs(updatedSongs);
          }
        } else {
          _showMessage('Failed to download song: ${response.message}', error: true);
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
            ),
            songs: playlistSongs
                .map((s) => Music(
              id: s.id,
              title: s.title,
              artist: s.artist,
              filePath: s.localPath ?? s.filePath,
            ))
                .toList(),
            currentIndex: index,
          ),
        ),
      );
    } catch (e) {
      _showMessage('Error playing song: $e', error: true);
    } finally {
      setState(() => isLoading = false);
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
    final playlistSongs = widget.userSongs
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: playlistSongs.length,
                itemBuilder: (context, index) {
                  final song = playlistSongs[index];
                  return Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Icon(
                        song.isFromServer ? Icons.cloud : Icons.phone_android,
                        color: const Color(0xFFCE93D8),
                      ),
                      title: Text(
                        song.title,
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: GoogleFonts.poppins(color: Colors.white54),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Color(0xFFCE93D8)),
                        onPressed: () => _removeSongFromPlaylist(song.title),
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