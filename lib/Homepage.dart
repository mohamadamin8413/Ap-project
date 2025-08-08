import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:projectap/Song.dart';
import 'package:projectap/User.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/playermusicpage.dart';
import 'package:projectap/ProfilePage.dart';
import 'package:projectap/PlaylistPage.dart';
import 'package:id3/id3.dart';

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

  Homepagesong({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    this.localPath,
    this.uploaderEmail,
    this.isFromServer = false,
    required this.addedAt,
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
      isFromServer: json['uploaderEmail'] == null || json['uploaderEmail'] == '',
      addedAt: addedAt,
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
}

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  List<Homepagesong> userSongs = [];
  List<Music> serverSongs = [];
  final TextEditingController searchController = TextEditingController();
  SortType currentSort = SortType.date;
  bool isAscending = true;
  bool isLoading = false;
  User? currentUser;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
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
        _loadUserSongs(),
        _loadServerSongs(),
      ]);
    } catch (e) {
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
      );
      final response = await SocketService().send(request);
      if (response.isSuccess && response.data != null) {
        setState(() {
          userSongs = (response.data as List<dynamic>)
              .map((json) {
            String? localPath;
            if (json['uploaderEmail'] == currentUser!.email) {
              localPath = '${appDir.path}/${json['title']}.mp3';
              if (!File(localPath).existsSync()) {
                localPath = null; // فایل محلی وجود ندارد، دانلود لازم است
              }
            }
            return Homepagesong.fromJson({
              'id': json['id'],
              'title': json['title'],
              'artist': json['artist'] ?? 'Unknown',
              'filePath': json['filePath'],
              'uploaderEmail': json['uploaderEmail'],
              'isFromServer': json['uploaderEmail'] == null || json['uploaderEmail'] == '',
              'addedAt': json['addedAt'] ?? DateTime.now().toIso8601String(),
              'localPath': localPath,
            });
          })
              .toList();
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
      );
      final response = await SocketService().send(request);
      if (response.isSuccess && response.data != null) {
        setState(() {
          serverSongs = (response.data as List<dynamic>)
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

  Future<void> _addLocalSong() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final base64File = base64Encode(bytes);
        final mp3 = MP3Instance(file.readAsBytesSync());
        String title = mp3.getMetaTags()?['Title'] ?? result.files.single.name.replaceAll('.mp3', '');
        String artist = mp3.getMetaTags()?['Artist'] ?? 'Unknown';
        if (userSongs.any((song) => song.title == title)) {
          _showMessage('This song already exists in your library', error: true);
          return;
        }

        final dir = await getApplicationDocumentsDirectory();
        final localFile = File('${dir.path}/$title.mp3');
        await localFile.writeAsBytes(bytes);

        setState(() => isLoading = true);
        final request = SocketRequest(
          action: 'add_local_music',
          data: {
            'email': currentUser!.email,
            'title': title,
            'artist': artist,
            'file': base64File,
          },
        );
        final response = await SocketService().send(request);
        if (response.isSuccess) {
          _showMessage('Song added to your library');
          setState(() {
            userSongs.add(Homepagesong(
              id: response.data != null && response.data['id'] != null ? response.data['id'] : userSongs.length + 1,
              title: title,
              artist: artist,
              filePath: '$title.mp3',
              localPath: localFile.path,
              uploaderEmail: currentUser!.email,
              isFromServer: false,
              addedAt: DateTime.now(),
            ));
            _sortSongs();
          });
        } else {
          _showMessage('Failed to add song: ${response.message}', error: true);
          await localFile.delete();
        }
      } else {
        _showMessage('No file selected', error: true);
      }
    } catch (e) {
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
                    );
                    final response = await SocketService().send(request);
                    if (response.isSuccess) {
                      _showMessage('Server song added successfully');
                      final downloadRequest = SocketRequest(
                        action: 'download_music',
                        data: {
                          'name': song.title,
                          'email': currentUser!.email,
                        },
                      );
                      final downloadResponse = await SocketService().send(downloadRequest);
                      if (downloadResponse.isSuccess && downloadResponse.data != null) {
                        final data = downloadResponse.data as Map<String, dynamic>;
                        final String base64File = data['file'] as String;
                        final bytes = base64Decode(base64File);
                        final dir = await getApplicationDocumentsDirectory();
                        final localFile = File('${dir.path}/${song.title}.mp3');
                        await localFile.writeAsBytes(bytes);
                        setState(() {
                          userSongs.add(Homepagesong(
                            id: response.data != null && response.data['id'] != null
                                ? response.data['id']
                                : userSongs.length + 1,
                            title: song.title,
                            artist: song.artist,
                            filePath: song.filePath,
                            localPath: localFile.path,
                            uploaderEmail: null,
                            isFromServer: true,
                            addedAt: DateTime.now(),
                          ));
                          _sortSongs();
                        });
                      } else {
                        _showMessage('Failed to download song: ${downloadResponse.message}', error: true);
                      }
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
      ),
    );
  }

  Future<void> _removeSong(String title) async {
    if (currentUser == null || title == null) return;
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'remove_user_music',
        data: {
          'email': currentUser!.email,
          'music_name': title,
        },
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        _showMessage('Song removed successfully');
        setState(() {
          userSongs.removeWhere((song) => song.title == title);
          _sortSongs();
        });
      } else {
        _showMessage('Failed to remove song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error removing song: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _downloadSong(Homepagesong song) async {
    if (song.localPath != null && File(song.localPath!).existsSync()) {
      _showMessage('Song already downloaded');
      return;
    }
    if (currentUser == null) {
      _showMessage('User not logged in', error: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'download_music',
        data: {
          'name': song.title,
          'email': currentUser!.email,
        },
      );
      final response = await SocketService().send(request);
      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final String base64File = data['file'] as String;
        final bytes = base64Decode(base64File);
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/${song.title}.mp3');
        await file.writeAsBytes(bytes);
        setState(() {
          userSongs[userSongs.indexWhere((s) => s.id == song.id)] = Homepagesong(
            id: song.id,
            title: song.title,
            artist: song.artist,
            filePath: song.filePath,
            localPath: file.path,
            uploaderEmail: song.uploaderEmail,
            isFromServer: song.isFromServer,
            addedAt: song.addedAt,
          );
        });
        _showMessage('Song downloaded successfully');
      } else {
        _showMessage('Failed to download song: ${response.message}', error: true);
      }
    } catch (e) {
      _showMessage('Error downloading song: $e', error: true);
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

  void _onNavBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PlaylistPage()),
      ).then((_) => _refreshData());
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      ).then((_) => _refreshData());
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Music',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      DropdownButton<SortType>(
                        value: currentSort,
                        icon: const Icon(Icons.sort, color: Color(0xFFCE93D8)),
                        dropdownColor: const Color(0xFF1E1E1E),
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
            const SizedBox(height: 8),
            Expanded(
              child: userSongs.isEmpty
                  ? Center(
                child: Text(
                  'No songs found. Add some!',
                  style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                ),
              )
                  : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: userSongs.length,
                separatorBuilder: (context, index) => const Divider(
                  color: Colors.white12,
                  height: 1,
                  thickness: 1,
                ),
                itemBuilder: (context, index) {
                  final song = userSongs[index];
                  return Container(
                    color: const Color(0xFF1E1E1E),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Icon(
                        song.isFromServer ? Icons.cloud : Icons.phone_android,
                        color: const Color(0xFFCE93D8),
                      ),
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
                          if (song.localPath == null || !File(song.localPath!).existsSync())
                            IconButton(
                              icon: const Icon(Icons.download, color: Color(0xFFCE93D8)),
                              onPressed: () => _downloadSong(song),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _removeSong(song.title),
                          ),
                        ],
                      ),
                      onTap: () {
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
                              songs: userSongs
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
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            backgroundColor: const Color(0xFFCE93D8),
            child: const Icon(Icons.upload_file, color: Colors.white),
            onPressed: _addLocalSong,
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            backgroundColor: const Color(0xFFCE93D8),
            child: const Icon(Icons.cloud_download, color: Colors.white),
            onPressed: _addServerSong,
          ),
        ],
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