import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:projectap/Homepage.dart';
import 'package:projectap/ProfilePage.dart';
import 'package:projectap/User.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/Playlist.dart';

AppStorage storage = AppStorage();

enum SortType { name, date }

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
  SortType currentSort = SortType.date;
  bool isAscending = true;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    userSongs = [];
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
      await loadUserPlaylists();
      await loadUserSongs();
    }
  }

  Future<void> loadUserPlaylists() async {
    if (currentUser == null) return;
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'list_user_playlists',
        data: {'email': currentUser!.email},
      );
      final response = await SocketService().send(request);
      if (response.isSuccess && response.data != null) {
        setState(() {
          playlists = (response.data as List<dynamic>)
              .map((json) => Playlist.fromJson({
            'id': json['id'],
            'name': json['name'],
            'creatorEmail': json['creatorEmail'],
            'songIds': json['musics'].map((m) => m['id']).toList(),
            'createdAt': DateTime.now().toIso8601String(),
          }))
              .toList();
          sortPlaylists();
        });
      } else {
        _showMessage(
          response.data == null
              ? 'No playlists data received'
              : 'Failed to load playlists: ${response.message}',
          error: true,
        );
        setState(() => playlists = []);
      }
    } catch (e) {
      _showMessage('Error loading playlists: $e', error: true);
      setState(() => playlists = []);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadUserSongs() async {
    if (currentUser == null) return;
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'list_user_music',
        data: {'email': currentUser!.email},
      );
      final response = await SocketService().send(request);
      if (response.isSuccess && response.data != null) {
        setState(() {
          userSongs = (response.data as List<dynamic>)
              .map((json) => Homepagesong.fromJson(json))
              .toList();
          sortSongs();
        });
      } else {
        _showMessage(
          response.data == null
              ? 'No songs data received'
              : 'Failed to load user songs: ${response.message}',
          error: true,
        );
        setState(() => userSongs = []);
      }
    } catch (e) {
      _showMessage('Error loading songs: $e', error: true);
      setState(() => userSongs = []);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> createPlaylist() async {
    if (currentUser == null || _playlistNameController.text.trim().isEmpty) {
      _showMessage('Please enter a playlist name', error: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'add_playlist',
        data: {
          'name': _playlistNameController.text.trim(),
          'email': currentUser!.email,
        },
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        await loadUserPlaylists();
        _playlistNameController.clear();
        _showMessage('Playlist created successfully', error: false);
      } else {
        _showMessage('Failed to create playlist: ${response.message}',
            error: true);
      }
    } catch (e) {
      _showMessage('Error creating playlist: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> deletePlaylist(int playlistId, String name) async {
    if (currentUser == null) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Delete Playlist',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to delete "$name"?',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'delete_playlist',
        data: {'name': name},
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        setState(() {
          playlists.removeWhere((p) => p.id == playlistId);
        });
        _showMessage('Playlist deleted successfully', error: false);
      } else {
        _showMessage('Failed to delete playlist: ${response.message}',
            error: true);
      }
    } catch (e) {
      _showMessage('Error deleting playlist: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> addSongToPlaylist(int playlistId, int songId, String songTitle) async {
    if (currentUser == null) return;
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'add_music_to_playlist',
        data: {
          'playlist_name': playlists.firstWhere((p) => p.id == playlistId).name,
          'music_name': songTitle,
        },
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        setState(() {
          final playlist = playlists.firstWhere((p) => p.id == playlistId);
          if (!playlist.songIds.contains(songId)) {
            playlist.songIds.add(songId);
          }
        });
        _showMessage('Song added to playlist', error: false);
      } else {
        _showMessage('Failed to add song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error adding song to playlist: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> sharePlaylist(int playlistId, String name) async {
    if (currentUser == null || _shareEmailController.text.trim().isEmpty) {
      _showMessage('Please enter a target email', error: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'share_playlist',
        data: {
          'email': currentUser!.email,
          'target_email': _shareEmailController.text.trim(),
          'playlist_name': name,
        },
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        _shareEmailController.clear();
        _showMessage('Playlist shared successfully', error: false);
      } else {
        _showMessage('Failed to share playlist: ${response.message}',
            error: true);
      }
    } catch (e) {
      _showMessage('Error sharing playlist: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            textStyle: Theme.of(context).textTheme.bodyMedium,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: error ? Colors.redAccent : const Color(0xFF1DB954),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        duration: const Duration(seconds: 3),
        elevation: 10,
      ),
    );
  }

  void showAddSongDialog(int playlistId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Add Song to Playlist',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: userSongs.length,
                itemBuilder: (context, index) {
                  Homepagesong song = userSongs[index];
                  return FadeInUp(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    child: ListTile(
                      leading: Icon(
                        song.localPath != null && File(song.localPath!).existsSync()
                            ? Icons.phone_android
                            : Icons.cloud,
                        color: Color(0xFF1DB954),
                      ),
                      title: Text(
                        song.title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          textStyle: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 14,
                          textStyle: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      onTap: () {
                        addSongToPlaylist(playlistId, song.id, song.title);
                        Navigator.pop(context);
                      },
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

  void showShareDialog(int playlistId, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Playlist',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _shareEmailController,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter target email',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.white54,
                    textStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      sharePlaylist(playlistId, name);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Share',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void sortPlaylists() {
    setState(() {
      if (currentSort == SortType.name) {
        playlists.sort((a, b) => isAscending ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
      } else {
        playlists.sort((a, b) => isAscending ? a.id.compareTo(b.id) : b.id.compareTo(a.id));
      }
    });
  }

  void sortSongs() {
    setState(() {
      if (currentSort == SortType.name) {
        userSongs.sort((a, b) => isAscending ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
      } else {
        userSongs.sort((a, b) => isAscending ? a.id.compareTo(b.id) : b.id.compareTo(a.id));
      }
    });
  }

  void showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort By',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha, color: Colors.white),
              title: Text(
                'Name',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  textStyle: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              onTap: () {
                setState(() {
                  currentSort = SortType.name;
                  sortPlaylists();
                  sortSongs();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.white),
              title: Text(
                'Date Added',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  textStyle: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              onTap: () {
                setState(() {
                  currentSort = SortType.date;
                  sortPlaylists();
                  sortSongs();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white,
              ),
              title: Text(
                isAscending ? 'Ascending' : 'Descending',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  textStyle: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              onTap: () {
                setState(() {
                  isAscending = !isAscending;
                  sortPlaylists();
                  sortSongs();
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onNavBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MusicHomePage()),
        );
        break;
      case 1:
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121212), Color(0xFF1DB954)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'Playlists',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF1DB954),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: showFilterMenu,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: FadeInDown(
                        duration: const Duration(milliseconds: 600),
                        child: TextField(
                          controller: _playlistNameController,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            textStyle: Theme.of(context).textTheme.bodyLarge,
                          ),
                          decoration: InputDecoration(
                            hintText: 'New Playlist Name',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.white54,
                              textStyle: Theme.of(context).textTheme.bodyMedium,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1DB954), Color(0xFF17A14A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: createPlaylist,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          child: Text(
                            'Add',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? Center(
                  child: SpinKitFadingCircle(
                    color: const Color(0xFF1DB954),
                    size: 50,
                  ),
                )
                    : playlists.isEmpty
                    ? Center(
                  child: Text(
                    'No playlists found',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 18,
                      textStyle: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    Playlist playlist = playlists[index];
                    return FadeInUp(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlaylistDetailsPage(
                                playlist: playlist,
                                songs: userSongs,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.queue_music,
                              color: Color(0xFF1DB954),
                            ),
                            title: Text(
                              playlist.name,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                textStyle: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            subtitle: Text(
                              '${playlist.songIds.length} songs',
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 14,
                                textStyle: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.share,
                                    color: Color(0xFF1DB954),
                                  ),
                                  onPressed: () => showShareDialog(playlist.id, playlist.name),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => deletePlaylist(playlist.id, playlist.name),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Color(0xFF1DB954),
                                  ),
                                  onPressed: () => showAddSongDialog(playlist.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavBarTapped,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: const Color(0xFF1DB954),
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
  const PlaylistDetailsPage({
    super.key,
    required this.playlist,
    required this.songs,
  });

  final Playlist playlist;
  final List<Homepagesong> songs;

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> with SingleTickerProviderStateMixin {
  bool isLoading = false;
  bool _isDownloading = false;
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  int _currentIndex = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late AnimationController _animationController;
  List<Homepagesong> userSongs=[];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _setupPlayerListeners();
  }


  void _setupPlayerListeners() {
    _player.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _playNext();
        }
      });
      if (_isPlaying) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
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
  }


  Future<void> _playSong(Homepagesong song, int index) async {
    setState(() {
      _currentIndex = index;
      isLoading = true;
    });
    try {
      if (song.localPath != null && await File(song.localPath!).exists()) {
        await _player.setFilePath(song.localPath!);
      } else {
        final request = SocketRequest(
          action: 'download_music',
          data: {'name': song.title},
        );
        final response = await SocketService().send(request);
        if (response.isSuccess && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final String base64File = data['file'] as String;
          final bytes = base64Decode(base64File);

          final dir = await getTemporaryDirectory();
          final tempFilePath = '${dir.path}/${song.title}_temp.mp3';
          final tempFile = File(tempFilePath);
          await tempFile.writeAsBytes(bytes);

          await _player.setFilePath(tempFilePath);
        } else {
          _showMessage('Failed to load song: ${response.message}', error: true);
          return;
        }
      }
      await _player.play();
      setState(() => _isPlaying = true);
      _animationController.forward();
    } catch (e) {
      _showMessage('Error loading audio: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }


  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _isPlaying = false;
      await _player.stop();
      await _playSong(widget.songs[_currentIndex], _currentIndex);
    }
  }


  Future<void> _playNext() async {
    if (_currentIndex < widget.songs.length - 1) {
      setState(() => _currentIndex++);
      _isPlaying = false;
      await _player.stop();
      await _playSong(widget.songs[_currentIndex], _currentIndex);
    }
  }


  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
      _animationController.reverse();
    } else {
      await _player.play();
      _animationController.forward();
    }
    setState(() => _isPlaying = !_isPlaying);
  }


  Future<void> _downloadSong(Homepagesong song) async {
    if (_isDownloading || (song.localPath != null && File(song.localPath!).existsSync())) {
      _showMessage(
        song.localPath != null ? 'Song already downloaded' : 'Download in progress',
        error: true,
      );
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final request = SocketRequest(
        action: 'download_music',
        data: {'name': song.title},
      );
      final response = await SocketService().send(request);
      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final String base64File = data['file'] as String;
        final bytes = base64Decode(base64File);

        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/${song.title}.mp3';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        setState(() {
          userSongs = userSongs.map((s) {
            if (s.id == song.id) {
              return Homepagesong(
                id: s.id,
                title: s.title,
                artist: s.artist,
                filePath: s.filePath,
                localPath: filePath,
                uploaderEmail: s.uploaderEmail,
                isFromServer: s.isFromServer,
              );
            }
            return s;
          }).toList();
        });

        if (_isPlaying && widget.songs[_currentIndex].id == song.id) {
          await _player.stop();
          await _playSong(song, _currentIndex);
        }

        _showMessage('Song downloaded successfully', error: false);
      } else {
        _showMessage('Failed to download song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error downloading song: $e', error: true);
    } finally {
      setState(() => _isDownloading = false);
    }
  }


  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            textStyle: Theme.of(context).textTheme.bodyMedium,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: error ? Colors.redAccent : const Color(0xFF1DB954),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        duration: const Duration(seconds: 3),
        elevation: 10,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Homepagesong> playlistSongs =
    widget.songs.where((song) => widget.playlist.songIds.contains(song.id)).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121212), Color(0xFF1DB954)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  widget.playlist.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF1DB954),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              if (_isPlaying)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      Text(
                        playlistSongs[_currentIndex].title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          textStyle: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbColor: const Color(0xFF1DB954),
                          activeTrackColor: const Color(0xFF1DB954),
                          inactiveTrackColor: Colors.white24,
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayColor: const Color(0xFF1DB954).withOpacity(0.2),
                        ),
                        child: Slider(
                          value: _position.inSeconds.toDouble(),
                          max: _duration.inSeconds.toDouble() > 0
                              ? _duration.inSeconds.toDouble()
                              : 1.0,
                          onChanged: (value) async {
                            await _player.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 12,
                              textStyle: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 12,
                              textStyle: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.skip_previous,
                              color: _currentIndex == 0 ? Colors.white24 : Colors.white,
                              size: 30,
                            ),
                            onPressed: _currentIndex == 0 ? null : _playPrevious,
                          ),
                          ScaleTransition(
                            scale: Tween(begin: 0.9, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Curves.easeInOut,
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 40,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.skip_next,
                              color: _currentIndex == playlistSongs.length - 1
                                  ? Colors.white24
                                  : Colors.white,
                              size: 30,
                            ),
                            onPressed: _currentIndex == playlistSongs.length - 1 ? null : _playNext,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: isLoading
                    ? Center(
                  child: SpinKitFadingCircle(
                    color: const Color(0xFF1DB954),
                    size: 50,
                  ),
                )
                    : playlistSongs.isEmpty
                    ? Center(
                  child: Text(
                    'No songs in this playlist',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 18,
                      textStyle: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: playlistSongs.length,
                  itemBuilder: (context, index) {
                    Homepagesong song = playlistSongs[index];
                    bool isDownloaded =
                        song.localPath != null && File(song.localPath!).existsSync();
                    return FadeInUp(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      child: GestureDetector(
                        onTap: () => _playSong(song, index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: Icon(
                              isDownloaded ? Icons.phone_android : Icons.cloud,
                              color: Color(0xFF1DB954),
                            ),
                            title: Text(
                              song.title,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                textStyle: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            subtitle: Text(
                              song.artist,
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 14,
                                textStyle: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            trailing: _isDownloading && _currentIndex == index
                                ? const SpinKitFadingCircle(
                              color: Color(0xFF1DB954),
                              size: 20,
                            )
                                : IconButton(
                              icon: Icon(
                                isDownloaded ? Icons.cloud_done : Icons.cloud_download,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: isDownloaded ? null : () => _downloadSong(song),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}