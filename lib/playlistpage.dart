import 'package:flutter/material.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/Playlist.dart';
import 'package:projectap/Homepage.dart';
import 'package:projectap/User.dart';
import 'package:projectap/Song.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({Key? key}) : super(key: key);

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  List<Playlist> playlists = [];
  List<Music> serverSongs = [];
  bool isLoading = false;
  User? currentUser;
  final TextEditingController _playlistNameController = TextEditingController();
  final TextEditingController _shareEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    loadPlaylists();
    loadServerSongs();
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    _shareEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AppStorage().loadCurrentUser();
    setState(() {
      currentUser = user;
    });
  }

  Future<void> loadPlaylists() async {
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
          playlists = (response.data as List<dynamic>)
              .map((json) => Playlist(
            id: json['id'],
            name: json['name'],
            creatorEmail: json['creatorEmail'],
            songIds: (json['musics'] as List<dynamic>).map((m) => m['id'] as int).toList(),
            createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
          ))
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
              .map((json) => Music.fromJson(json))
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

  Future<void> createPlaylist() async {
    if (currentUser == null || _playlistNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a playlist name')),
      );
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
        await loadPlaylists();
        _playlistNameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist created'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create playlist: ${response.message}')),
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

  Future<void> deletePlaylist(int playlistId, String name) async {
    if (currentUser == null) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist deleted'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete playlist: ${response.message}')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Song added to playlist'), backgroundColor: Colors.green),
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
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> sharePlaylist(int playlistId, String name) async {
    if (currentUser == null || _shareEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a target email')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist shared'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share playlist: ${response.message}')),
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

  void showAddSongDialog(int playlistId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Add Song to Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: serverSongs.length,
                itemBuilder: (context, index) {
                  Music song = serverSongs[index];
                  return ListTile(
                    leading: Icon(Icons.music_note, color: Colors.white),
                    title: Text(song.title, style: TextStyle(color: Colors.white)),
                    subtitle: Text(song.artist, style: TextStyle(color: Colors.grey[400])),
                    onTap: () {
                      addSongToPlaylist(playlistId, song.id, song.title);
                      Navigator.pop(context);
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

  void showShareDialog(int playlistId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Text('Share Playlist', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _shareEmailController,
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
              sharePlaylist(playlistId, name);
              Navigator.pop(context);
            },
            child: Text('Share', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Playlists', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.greenAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _playlistNameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'New Playlist Name',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: createPlaylist,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                : playlists.isEmpty
                ? Center(
              child: Text(
                'No playlists found',
                style: TextStyle(color: Colors.grey[400], fontSize: 18),
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                Playlist playlist = playlists[index];
                return ListTile(
                  leading: Icon(Icons.queue_music, color: Colors.white),
                  title: Text(playlist.name, style: TextStyle(color: Colors.white)),
                  subtitle: Text('${playlist.songIds.length} songs', style: TextStyle(color: Colors.grey[400])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.share, color: Colors.greenAccent),
                        onPressed: () => showShareDialog(playlist.id, playlist.name),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => deletePlaylist(playlist.id, playlist.name),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.greenAccent),
                        onPressed: () => showAddSongDialog(playlist.id),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaylistDetailsPage(playlist: playlist, songs: serverSongs),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PlaylistDetailsPage extends StatelessWidget {
  final Playlist playlist;
  final List<Music> songs;

  const PlaylistDetailsPage({Key? key, required this.playlist, required this.songs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Music> playlistSongs = songs.where((song) => playlist.songIds.contains(song.id)).toList();

    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(playlist.name, style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.greenAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: playlistSongs.isEmpty
          ? Center(
        child: Text(
          'No songs in this playlist',
          style: TextStyle(color: Colors.grey[400], fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20),
        itemCount: playlistSongs.length,
        itemBuilder: (context, index) {
          Music song = playlistSongs[index];
          return ListTile(
            leading: Icon(Icons.music_note, color: Colors.white),
            title: Text(song.title, style: TextStyle(color: Colors.white)),
            subtitle: Text(song.artist, style: TextStyle(color: Colors.grey[400])),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MusicPlayerPage(
                    song: Homepagesong(
                      id: song.id,
                      title: song.title,
                      artist: song.artist,
                      filePath: song.filePath,
                      uploadDate: song.uploadDate,
                      isFromServer: true,
                    ),
                    songs: playlistSongs
                        .map((s) => Homepagesong(
                      id: s.id,
                      title: s.title,
                      artist: s.artist,
                      filePath: s.filePath,
                      uploadDate: s.uploadDate,
                      isFromServer: true,
                    ))
                        .toList(),
                    currentIndex: index,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}