import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:convert';
import 'package:projectap/appstorage.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/User.dart';
import 'package:projectap/Playlist.dart';
import 'package:projectap/Song.dart';

AppStorage storage = AppStorage();

class Homepagesong {
  final int id;
  final String title;
  final String artist;
  final String filePath;
  final DateTime uploadDate;
  final bool isFromServer;

  Homepagesong({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    required this.uploadDate,
    this.isFromServer = false,
  });

  factory Homepagesong.fromJson(Map<String, dynamic> json) {
    return Homepagesong(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      filePath: json['filePath'],
      uploadDate: DateTime.parse(json['uploadDate']),
      isFromServer: json['isFromServer'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'filePath': filePath,
    'uploadDate': uploadDate.toIso8601String(),
    'isFromServer': isFromServer,
  };
}

enum SortType { name, date }

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({Key? key, this.themeMode}) : super(key: key);
  final ThemeMode? themeMode;

  @override
  _MusicHomePageState createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  List<Homepagesong> serverSongs = [];
  List<Playlist> userPlaylists = [];
  TextEditingController searchController = TextEditingController();
  TextEditingController shareEmailController = TextEditingController();
  SortType currentSort = SortType.date;
  bool isAscending = true;
  bool isLoading = false;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    loadServerSongs();
    loadUserPlaylists();
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
  }

  void _onSearchChanged() {
    if (searchController.text.isEmpty) {
      loadServerSongs();
    } else {
      searchSongs(searchController.text.trim());
    }
  }

  Future<void> loadServerSongs() async {
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'list_music',
        data: {},
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        setState(() {
          serverSongs = (response.data as List<dynamic>)
              .map((json) => Homepagesong.fromJson(json))
              .toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load songs: ${response.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> searchSongs(String keyword) async {
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'search_music',
        data: {'keyword': keyword},
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        setState(() {
          serverSongs = (response.data as List<dynamic>)
              .map((json) => Homepagesong.fromJson(json))
              .toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to search songs: ${response.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
      if (response.isSuccess) {
        setState(() {
          userPlaylists = (response.data as List<dynamic>)
              .map((json) => Playlist.fromJson({
            'id': json['id'],
            'name': json['name'],
            'creatorEmail': json['creatorEmail'],
            'songIds': json['musics'].map((m) => m['id']).toList(),
            'createdAt': DateTime.now().toIso8601String(),
          }))
              .toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load playlists: ${response.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void sortSongs() {
    setState(() {
      if (currentSort == SortType.name) {
        serverSongs.sort((a, b) => isAscending
            ? a.title.compareTo(b.title)
            : b.title.compareTo(a.title));
      } else {
        serverSongs.sort((a, b) => isAscending
            ? a.uploadDate.compareTo(b.uploadDate)
            : b.uploadDate.compareTo(a.uploadDate));
      }
    });
  }

  Future<void> addLocalSong() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && currentUser != null) {
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
            'file': base64Data,
          },
        );
        final response = await SocketService().send(request);
        if (response.isSuccess) {
          await loadServerSongs();
          sortSongs();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Song uploaded successfully'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload song: ${response.message}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            ) as SnackBar
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> addServerSong(Homepagesong song) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to add songs')),
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
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Song added to your collection'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add song: ${response.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> shareSong(Homepagesong song) async {
    if (currentUser == null || shareEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a target email')),
      );
      return;
    }
    try {
      final request = SocketRequest(
        action: 'add_music_to_playlist',
        data: {
          'playlist_name': 'Shared_Songs_' + shareEmailController.text.trim(),
          'music_name': song.title,
        },
      );
      final response = await SocketService().send(request);
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Song shared'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share song: ${response.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void showShareDialog(Homepagesong song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Text('Share Song', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: shareEmailController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter target email',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              shareSong(song);
              Navigator.pop(context);
            },
            child: Text('Share', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  void showServerSongs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Server Songs',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: serverSongs.length,
                itemBuilder: (context, index) {
                  Homepagesong song = serverSongs[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 15),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: Color(0xFF3A3A3A),
                            child: Icon(
                              Icons.music_note,
                              color: Colors.white54,
                              size: 30,
                            ),
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                song.artist,
                                style: TextStyle(
                                  color: Colors.grey[400],
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
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size(0, 0),
                          ),
                          child: Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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

  void showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort By',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.sort_by_alpha, color: Colors.white),
              title: Text('Name', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() {
                  currentSort = SortType.name;
                  sortSongs();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.access_time, color: Colors.white),
              title: Text('Date Added', style: TextStyle(color: Colors.white)),
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
                style: TextStyle(color: Colors.white),
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

  void navigateToPlayer(Homepagesong song, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MusicPlayerPage(
          song: song,
          songs: serverSongs,
          currentIndex: index,
          themeMode: widget.themeMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextField(
                        controller: searchController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.menu, color: Colors.white),
                      onPressed: showFilterMenu,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: addLocalSong,
                      icon: Icon(Icons.add, color: Colors.white),
                      label: Text('Add from Device', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: showServerSongs,
                      icon: Icon(Icons.cloud_download, color: Colors.white),
                      label: Text('Server Songs', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
                  : serverSongs.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No songs found',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: serverSongs.length,
                itemBuilder: (context, index) {
                  Homepagesong song = serverSongs[index];
                  return GestureDetector(
                    onTap: () => navigateToPlayer(song, index),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 15),
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 60,
                              height: 60,
                              color: Color(0xFF3A3A3A),
                              child: Icon(
                                Icons.music_note,
                                color: Colors.white54,
                                size: 30,
                              ),
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  song.artist,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.share, color: Colors.greenAccent),
                            onPressed: () => showShareDialog(song),
                          ),
                          Icon(
                            Icons.play_arrow,
                            color: Colors.white54,
                            size: 30,
                          ),
                        ],
                      ),
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

class MusicPlayerPage extends StatefulWidget {
  final Homepagesong song;
  final List<Homepagesong> songs;
  final int currentIndex;
  final ThemeMode? themeMode;

  const MusicPlayerPage({
    Key? key,
    required this.song,
    required this.songs,
    required this.currentIndex,
    this.themeMode,
  }) : super(key: key);

  @override
  _MusicPlayerPageState createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  int _currentIndex;

  _MusicPlayerPageState() : _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setFilePath(widget.songs[_currentIndex].filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading audio: $e')),
      );
    }
  }

  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      await _initPlayer();
      if (_isPlaying) await _player.play();
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex < widget.songs.length - 1) {
      setState(() => _currentIndex++);
      await _initPlayer();
      if (_isPlaying) await _player.play();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Homepagesong currentSong = widget.songs[_currentIndex];
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, widget.themeMode),
        ),
        title: Text(
          'Now Playing',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 200,
                height: 200,
                color: Color(0xFF3A3A3A),
                child: Icon(
                  Icons.music_note,
                  color: Colors.white54,
                  size: 80,
                ),
              ),
            ),
            SizedBox(height: 30),
            Text(
              currentSong.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              currentSong.artist,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous, color: Colors.white, size: 40),
                  onPressed: _playPrevious,
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 60,
                  ),
                  onPressed: () async {
                    if (_isPlaying) {
                      await _player.pause();
                    } else {
                      await _player.play();
                    }
                    setState(() => _isPlaying = !_isPlaying);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.skip_next, color: Colors.white, size: 40),
                  onPressed: _playNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}