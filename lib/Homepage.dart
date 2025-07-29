import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:projectap/Signup.dart';
import 'package:projectap/ProfilePage.dart';
import 'package:projectap/User.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/playlistpage.dart';
import 'package:projectap/Playlist.dart';

AppStorage storage = AppStorage();

class Homepagesong {
  final int id;
  final String title;
  final String artist;
  final String filePath;
  final String? localPath;
  final String? uploaderEmail;
  final bool isFromServer;

  Homepagesong({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    this.localPath,
    this.uploaderEmail,
    this.isFromServer = false,
  });

  factory Homepagesong.fromJson(Map<String, dynamic> json) {
    return Homepagesong(
      id: json['id'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      filePath: json['filePath'] as String,
      localPath: json['localPath'] as String?,
      uploaderEmail: json['uploaderEmail'] as String?,
      isFromServer: json['isFromServer'] as bool? ?? false,
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
  };
}

enum SortType { name, date }

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key, this.themeMode});

  final ThemeMode? themeMode;

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  List<Homepagesong> userSongs = [];
  List<Homepagesong> serverSongsList = [];
  List<Playlist> userPlaylists = [];
  final TextEditingController searchController = TextEditingController();
  final TextEditingController shareEmailController = TextEditingController();
  SortType currentSort = SortType.date;
  bool isAscending = true;
  bool isLoading = false;
  User? currentUser;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    userSongs = [];
    serverSongsList = [];
    _loadCurrentUser();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    shareEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await storage.loadCurrentUser();
    setState(() {
      currentUser = user;
    });
    if (user != null) {
      await loadUserSongs();
      await loadUserPlaylists();
    } else {
      setState(() {
        userSongs = [];
        userPlaylists = [];
      });
    }
  }

  void _onSearchChanged() {
    if (currentUser == null) return;
    if (searchController.text.isEmpty) {
      loadUserSongs();
    } else {
      searchSongs(searchController.text.trim());
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
      print('Request sent for list_user_music: $request');
      if (response.isSuccess && response.data != null) {
        print('User songs response: ${response.data}');
        setState(() {
          userSongs = (response.data as List<dynamic>)
              .map((json) {
            try {
              return Homepagesong.fromJson(json);
            } catch (e) {
              print('Error parsing user song JSON: $json, Error: $e');
              return null;
            }
          })
              .where((song) => song != null)
              .cast<Homepagesong>()
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
      print('Error in loadUserSongs: $e');
      setState(() => userSongs = []);
    } finally {
      setState(() => isLoading = false);
    }
  }


  Future<void> searchSongs(String keyword) async {
    if (currentUser == null) return;
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'search_music',
        data: {'keyword': keyword},
      );
      final response = await SocketService().send(request);
      print('Request sent for search_music: $request');
      if (response.isSuccess && response.data != null) {
        print('Search songs response: ${response.data}');
        setState(() {
          userSongs = (response.data as List<dynamic>)
              .map((json) {
            try {
              return Homepagesong.fromJson(json);
            } catch (e) {
              print('Error parsing search song JSON: $json, Error: $e');
              return null;
            }
          })
              .where((song) => song != null)
              .cast<Homepagesong>()
              .toList();
          sortSongs();
        });
      } else {
        _showMessage(
          response.data == null
              ? 'No search results'
              : 'Failed to search songs: ${response.message}',
          error: true,
        );
        setState(() => userSongs = []);
      }
    } catch (e) {
      _showMessage('Error searching songs: $e', error: true);
      print('Error in searchSongs: $e');
      setState(() => userSongs = []);
    } finally {
      setState(() => isLoading = false);
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
      print('Request sent for list_user_playlists: $request');
      if (response.isSuccess && response.data != null) {
        print('User playlists response: ${response.data}');
        setState(() {
          userPlaylists = (response.data as List<dynamic>)
              .map((json) {
            try {
              return Playlist.fromJson({
                'id': json['id'],
                'name': json['name'],
                'creatorEmail': json['creatorEmail'],
                'songIds': json['musics'].map((m) => m['id']).toList(),
                'createdAt': DateTime.now().toIso8601String(),
              });
            } catch (e) {
              print('Error parsing playlist JSON: $json, Error: $e');
              return null;
            }
          })
              .where((playlist) => playlist != null)
              .cast<Playlist>()
              .toList();
        });
      } else {
        _showMessage(
          response.data == null
              ? 'No playlists data received'
              : 'Failed to load playlists: ${response.message}',
          error: true,
        );
        setState(() => userPlaylists = []);
      }
    } catch (e) {
      _showMessage('Error loading playlists: $e', error: true);
      print('Error in loadUserPlaylists: $e');
      setState(() => userPlaylists = []);
    } finally {
      setState(() => isLoading = false);
    }
  }


  void sortSongs() {
    setState(() {
      if (currentSort == SortType.name) {
        userSongs.sort((a, b) =>
        isAscending ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
      } else {
        userSongs.sort((a, b) =>
        isAscending ? a.id.compareTo(b.id) : b.id.compareTo(a.id));
      }
    });
  }


  Future<void> addLocalSong() async {
    if (currentUser == null) {
      _showMessage('Please log in to upload songs', error: true);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Screen2()),
      );
      return;
    }
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(type: FileType.audio, allowMultiple: false);

    if (result != null) {
      setState(() => isLoading = true);
      try {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        String base64Data = base64Encode(await file.readAsBytes());
        final request = SocketRequest(
          action: 'upload_music',
          data: {
            'name': fileName.split('.').first,
            'artist': 'Unknown Artist',
            'email': currentUser!.email,
            'file': base64Data,
          },
        );
        final response = await SocketService().send(request);
        print('Request sent for upload_music: $request');
        if (response.isSuccess) {
          print('Upload music response: ${response.data}');
          await loadUserSongs();
          setState(() {
            userSongs = userSongs.map((song) {
              if (song.title == fileName.split('.').first) {
                return Homepagesong(
                  id: song.id,
                  title: song.title,
                  artist: song.artist,
                  filePath: song.filePath,
                  localPath: file.path,
                  uploaderEmail: currentUser!.email,
                  isFromServer: song.isFromServer,
                );
              }
              return song;
            }).toList();
            sortSongs();
          });
          _showMessage('Song uploaded successfully', error: false);
        } else {
          _showMessage('Failed to upload song: ${response.message}', error: true);
          print('Upload music error: ${response.message}');
        }
      } catch (e) {
        _showMessage('Error uploading song: $e', error: true);
        print('Error in addLocalSong: $e');
      } finally {
        setState(() => isLoading = false);
      }
    }
  }


  Future<void> addServerSong(Homepagesong song) async {
    if (currentUser == null) {
      _showMessage('Please log in to add songs', error: true);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Screen2()),
      );
      return;
    }
    try {
      final request = SocketRequest(
        action: 'like_music',
        data: {
          'email': currentUser!.email,
          'music_name': song.title,
        },
      );
      final response = await SocketService().send(request);
      print('Request sent for like_music: $request');
      if (response.isSuccess) {
        print('Like music response: ${response.data}');
        await loadUserSongs();
        _showMessage('Song added to your collection', error: false);
      } else {
        _showMessage('Failed to add song: ${response.message}', error: true);
        print('Like music error: ${response.message}');
      }
    } catch (e) {
      _showMessage('Error adding song: $e', error: true);
      print('Error in addServerSong: $e');
    }
  }


  Future<void> deleteSong(Homepagesong song) async {
    if (currentUser == null) {
      _showMessage('Please log in to delete songs', error: true);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Screen2()),
      );
      return;
    }
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
                'Delete Song',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to delete "${song.title}"?',
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
        action: 'delete_music',
        data: {'name': song.title},
      );
      final response = await SocketService().send(request);
      print('Request sent for delete_music: $request');
      if (response.isSuccess) {
        print('Delete music response: ${response.data}');
        setState(() {
          userSongs.removeWhere((s) => s.id == song.id);
        });
        _showMessage('Song deleted successfully', error: false);
      } else {
        _showMessage('Failed to delete song: ${response.message}', error: true);
        print('Delete music error: ${response.message}');
      }
    } catch (e) {
      _showMessage('Error deleting song: $e', error: true);
      print('Error in deleteSong: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> shareSong(Homepagesong song) async {
    if (currentUser == null || shareEmailController.text.trim().isEmpty) {
      _showMessage(
        currentUser == null
            ? 'Please log in to share songs'
            : 'Please enter a target email',
        error: true,
      );
      if (currentUser == null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Screen2()),
        );
      }
      return;
    }
    try {
      final request = SocketRequest(
        action: 'add_music_to_playlist',
        data: {
          'playlist_name': 'Shared_Songs_${shareEmailController.text.trim()}',
          'music_name': song.title,
        },
      );
      final response = await SocketService().send(request);
      print('Request sent for add_music_to_playlist: $request');
      if (response.isSuccess) {
        print('Share song response: ${response.data}');
        _showMessage('Song shared successfully', error: false);
      } else {
        _showMessage('Failed to share song: ${response.message}', error: true);
        print('Share song error: ${response.message}');
      }
    } catch (e) {
      _showMessage('Error sharing song: $e', error: true);
      print('Error in shareSong: $e');
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

  void showShareDialog(Homepagesong song) {
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
                'Share Song',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: shareEmailController,
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
                      shareSong(song);
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

  Future<List<Homepagesong>> _fetchServerSongs() async {
    try {
      final request = SocketRequest(action: 'list_music', data: {});
      print('Request sent for list_music: $request');
      final response = await SocketService().send(request);
      if (response.isSuccess && response.data != null) {
        print('Server songs response: ${response.data}');
        final songs = (response.data as List<dynamic>)
            .map((json) {
          try {
            return Homepagesong.fromJson(json);
          } catch (e) {
            print('Error parsing server song JSON: $json, Error: $e');
            return null;
          }
        })
            .where((song) => song != null)
            .cast<Homepagesong>()
            .toList();
        if (songs.isEmpty) {
          _showMessage('No server songs available', error: true);
        }
        return songs;
      } else {
        _showMessage(
          response.data == null
              ? 'No server songs data received'
              : 'Failed to load server songs: ${response.message}',
          error: true,
        );
        print('Server response error: ${response.message}, Data: ${response.data}');
        return [];
      }
    } catch (e) {
      _showMessage('Error fetching server songs: $e', error: true);
      print('Error in _fetchServerSongs: $e');
      return [];
    }
  }

  void showServerSongs() {
    if (currentUser == null) {
      _showMessage('Please log in to view server songs', error: true);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const Screen2()),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Server Songs',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Homepagesong>>(
                future: _fetchServerSongs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SpinKitFadingCircle(
                        color: Color(0xFF1DB954),
                        size: 50,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading server songs: ${snapshot.error}',
                        textAlign:TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        'No server songs found',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }
                  final serverSongsList = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: serverSongsList.length,
                    itemBuilder: (context, index) {
                      Homepagesong song = serverSongsList[index];
                      return FadeInUp(
                        duration: Duration(milliseconds: 300 + (index * 100)),
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
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: const Color(0xFF3A3A3A),
                                  child: const Icon(
                                    Icons.cloud,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      song.artist,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  addServerSong(song);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1DB954),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Add',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
        break;
      case 1:
        if (currentUser == null) {
          _showMessage('Please log in to view playlists', error: true);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Screen2()),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlaylistPage()),
        );
        break;
      case 2:
        if (currentUser == null) {
          _showMessage('Please log in to view profile', error: true);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Screen2()),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfilePage()),
        );
        break;
    }
  }

  void navigateToPlayer(Homepagesong song, int index) {
    if (userSongs.isEmpty) {
      _showMessage('No songs available to play', error: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MusicPlayerPage(
          song: song,
          songs: userSongs,
          currentIndex: index,
          themeMode: widget.themeMode,
          onSongDownloaded: (updatedSong) {
            setState(() {
              userSongs = userSongs.map((s) {
                if (s.id == updatedSong.id) {
                  return updatedSong;
                }
                return s;
              }).toList();
            });
          },
        ),
      ),
    );
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
          child: isLoading
              ? Center(
            child: SpinKitFadingCircle(
              color: const Color(0xFF1DB954),
              size: 50,
            ),
          )
              : currentUser == null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Please log in to view your songs',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 18,
                    textStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Screen2()),
                      );
                    },
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
                      'Login',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        textStyle: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
              : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: FadeInDown(
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
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
                          child: TextField(
                            controller: searchController,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              textStyle: Theme.of(context).textTheme.bodyLarge,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search your songs...',
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.white54,
                                textStyle:
                                Theme.of(context).textTheme.bodyMedium,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF1DB954),
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => _onSearchChanged(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: Container(
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
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: showFilterMenu,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: FadeInUp(
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
                          child: ElevatedButton.icon(
                            onPressed: addLocalSong,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: Text(
                              'Add from Device',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                textStyle:
                                Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FadeInUp(
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
                          child: ElevatedButton.icon(
                            onPressed: showServerSongs,
                            icon: const Icon(
                              Icons.cloud_download,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Server Songs',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                textStyle:
                                Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: userSongs.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.music_note,
                        size: 80,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No songs found',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 18,
                          textStyle:
                          Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: userSongs.length,
                  itemBuilder: (context, index) {
                    Homepagesong song = userSongs[index];
                    return FadeInUp(
                      duration:
                      Duration(milliseconds: 300 + (index * 100)),
                      child: GestureDetector(
                        onTap: () => navigateToPlayer(song, index),
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
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: const Color(0xFF3A3A3A),
                                  child: Icon(
                                    song.localPath != null &&
                                        File(song.localPath!)
                                            .existsSync()
                                        ? Icons.phone_android
                                        : Icons.cloud,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      song.artist,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white54,
                                        fontSize: 14,
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.share,
                                  color: Color(0xFF1DB954),
                                ),
                                onPressed: () => showShareDialog(song),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => deleteSong(song),
                              ),
                              const Icon(
                                Icons.play_arrow,
                                color: Colors.white54,
                                size: 30,
                              ),
                            ],
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

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({
    super.key,
    required this.song,
    required this.songs,
    required this.currentIndex,
    this.themeMode,
    this.onSongDownloaded,
  });

  final Homepagesong song;
  final List<Homepagesong> songs;
  final int currentIndex;
  final ThemeMode? themeMode;
  final Function(Homepagesong)? onSongDownloaded;

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isDownloading = false;
  int _currentIndex = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _initPlayer();
    _setupPlayerListeners();
  }

  // مقداردهی اولیه پلیر
  Future<void> _initPlayer() async {
    try {
      final song = widget.songs[_currentIndex];
      if (song.localPath != null && await File(song.localPath!).exists()) {
        await _player.setFilePath(song.localPath!);
      } else {
        final request = SocketRequest(
          action: 'download_music',
          data: {'name': song.title},
        );
        final response = await SocketService().send(request);
        print('Request sent for download_music: $request');
        if (response.isSuccess && response.data != null) {
          print('Download music response: ${response.data}');
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
          print('Download music error: ${response.message}');
          return;
        }
      }
      if (_isPlaying) {
        await _player.play();
        _animationController.forward();
      }
    } catch (e) {
      _showMessage('Error loading audio: $e', error: true);
      print('Error in _initPlayer: $e');
    }
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

  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _isPlaying = false;
      await _player.stop();
      await _initPlayer();
      await _player.play();
      setState(() => _isPlaying = true);
      _animationController.forward();
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex < widget.songs.length - 1) {
      setState(() => _currentIndex++);
      _isPlaying = false;
      await _player.stop();
      await _initPlayer();
      await _player.play();
      setState(() => _isPlaying = true);
      _animationController.forward();
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
      print('Request sent for download_music: $request');
      if (response.isSuccess && response.data != null) {
        print('Download music response: ${response.data}');
        final data = response.data as Map<String, dynamic>;
        final String base64File = data['file'] as String;
        final bytes = base64Decode(base64File);

        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/${song.title}.mp3';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        final updatedSong = Homepagesong(
          id: song.id,
          title: song.title,
          artist: song.artist,
          filePath: song.filePath,
          localPath: filePath,
          uploaderEmail: song.uploaderEmail,
          isFromServer: song.isFromServer,
        );

        if (widget.onSongDownloaded != null) {
          widget.onSongDownloaded!(updatedSong);
        }

        if (_isPlaying && widget.songs[_currentIndex].id == song.id) {
          await _player.stop();
          await _initPlayer();
          await _player.play();
        }

        _showMessage('Song downloaded successfully', error: false);
      } else {
        _showMessage('Failed to download song: ${response.message}', error: true);
        print('Download music error: ${response.message}');
      }
    } catch (e) {
      _showMessage('Error downloading song: $e', error: true);
      print('Error in _downloadSong: $e');
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
    Homepagesong currentSong = widget.songs[_currentIndex];
    final isFirstSong = _currentIndex == 0;
    final isLastSong = _currentIndex == widget.songs.length - 1;
    final isDownloaded =
        currentSong.localPath != null && File(currentSong.localPath!).existsSync();

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
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context, widget.themeMode),
                ),
                title: Text(
                  'Now Playing',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  color: const Color(0xFF3A3A3A),
                                  child: Icon(
                                    isDownloaded ? Icons.phone_android : Icons.cloud,
                                    color: Colors.white54,
                                    size: 100,
                                  ),
                                ),
                                if (_isPlaying)
                                  FadeIn(
                                    duration: const Duration(milliseconds: 600),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF1DB954),
                                          width: 2,
                                        ),
                                      ),
                                      child: const SizedBox(
                                        width: 220,
                                        height: 220,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Text(
                          currentSong.title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            textStyle: Theme.of(context).textTheme.headlineSmall,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Text(
                          currentSong.artist,
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 18,
                            textStyle: Theme.of(context).textTheme.bodyLarge,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SliderTheme(
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
                        ),
                      ),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: GoogleFonts.poppins(
                                  color: Colors.white54,
                                  fontSize: 14,
                                  textStyle: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: GoogleFonts.poppins(
                                  color: Colors.white54,
                                  fontSize: 14,
                                  textStyle: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: _isDownloading
                            ? const SpinKitFadingCircle(
                          color: Color(0xFF1DB954),
                          size: 30,
                        )
                            : IconButton(
                          icon: Icon(
                            isDownloaded ? Icons.cloud_done : Icons.cloud_download,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: isDownloaded ? null : () => _downloadSong(currentSong),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.skip_previous,
                                color: isFirstSong ? Colors.white24 : Colors.white,
                                size: 40,
                              ),
                              onPressed: isFirstSong ? null : _playPrevious,
                            ),
                            ScaleTransition(
                              scale: Tween(begin: 0.9, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1DB954), Color(0xFF17A14A)],
                                  ),
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
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.skip_next,
                                color: isLastSong ? Colors.white24 : Colors.white,
                                size: 40,
                              ),
                              onPressed: isLastSong ? null : _playNext,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}