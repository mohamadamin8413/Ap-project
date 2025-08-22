import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:projectap/Homepage.dart';
import 'package:projectap/PlaylistPage.dart';
import 'package:projectap/Signscreen.dart';
import 'package:projectap/User.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/apiservice.dart';

AppStorage storage = AppStorage();

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? currentUser;
  bool isLoading = false;
  bool allowSharing = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  int _selectedIndex = 2;
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _socketService.close();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await storage.loadCurrentUser();
    setState(() {
      currentUser = user;
      if (user != null) {
        _usernameController.text = user.username;
      }
    });
    if (user != null) {
      await _loadSharingSettings();
    }
  }

  Future<void> _loadSharingSettings() async {
    try {
      final request = SocketRequest(
        action: 'get_user',
        data: {'email': currentUser!.email},
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      print('Sending get_user request: ${request.toJson()}');
      final response = await _socketService.send(request);
      print('Response for get_user: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        setState(() {
          allowSharing = response.data['allowSharing'] ?? true;
        });
      } else {
        _showMessage('Failed to load sharing settings: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error loading sharing settings: $e');
      _showMessage('Error loading sharing settings: $e', error: true);
    }
  }

  Future<void> _updateProfile() async {
    if (currentUser == null || _usernameController.text.trim().isEmpty) {
      _showMessage('Please enter a username', error: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'update_user',
        data: {
          'email': currentUser!.email,
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim().isEmpty
              ? currentUser!.password
              : _passwordController.text.trim(),
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      print('Sending update_user request: ${request.toJson()}');
      final response = await _socketService.send(request);
      print('Response for update_user: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        final updatedUser = User.fromJson(response.data as Map<String, dynamic>);
        await storage.saveCurrentUser(updatedUser);
        setState(() {
          currentUser = updatedUser;
          _usernameController.text = updatedUser.username;
        });
        _passwordController.clear();
        _showMessage('Profile updated successfully');
      } else {
        _showMessage('Failed to update profile: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error updating profile: $e');
      _showMessage('Error updating profile: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleSharing() async {
    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'toggle_sharing',
        data: {
          'email': currentUser!.email,
          'allow_sharing': !allowSharing,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      print('Sending toggle_sharing request: ${request.toJson()}');
      final response = await _socketService.send(request);
      print('Response for toggle_sharing: ${response.toJson()}');
      if (response.isSuccess) {
        setState(() {
          allowSharing = !allowSharing;
        });
        _showMessage('Sharing settings updated');
      } else {
        _showMessage('Failed to update sharing settings: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error updating sharing settings: $e');
      _showMessage('Error updating sharing settings: $e', error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to logout?',
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
              backgroundColor: const Color(0xFFCE93D8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await storage.resetCurrentUser();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Screen1()),
      );
    }
  }

  Future<void> _deleteAccount() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Account',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
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
    if (confirm == true) {
      setState(() => isLoading = true);
      try {
        final request = SocketRequest(
          action: 'delete_user',
          data: {'email': currentUser!.email},
          requestId: DateTime.now().millisecondsSinceEpoch.toString(),
        );
        print('Sending delete_user request: ${request.toJson()}');
        final response = await _socketService.send(request);
        print('Response for delete_user: ${response.toJson()}');
        if (response.isSuccess) {
          await storage.resetCurrentUser();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Screen1()),
          );
          _showMessage('Account deleted successfully');
        } else {
          _showMessage('Failed to delete account: ${response.message}', error: true);
        }
      } catch (e) {
        print('Error deleting account: $e');
        _showMessage('Error deleting account: $e', error: true);
      } finally {
        setState(() => isLoading = false);
      }
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
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MusicHomePage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PlaylistPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: SpinKitWaveSpinner(
            color: Color(0xFFCE93D8),
            size: 50,
            waveColor: Color(0xFF8E24AA),
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFCE93D8), Color(0xFF8E24AA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFF1E1E1E),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.username ?? 'User',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            currentUser?.email ?? 'No email',
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Profile',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          hintText: 'Username',
                          hintStyle: GoogleFonts.poppins(color: Colors.white54),
                          prefixIcon: const Icon(Icons.person, color: Color(0xFFCE93D8)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        obscureText: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          hintText: 'New Password (leave blank to keep current)',
                          hintStyle: GoogleFonts.poppins(color: Colors.white54),
                          prefixIcon: const Icon(Icons.lock, color: Color(0xFFCE93D8)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: isLoading ? null : _updateProfile,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Update Profile',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Allow others to share',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Switch(
                        value: allowSharing,
                        activeColor: const Color(0xFFCE93D8),
                        activeTrackColor: const Color(0xFF8E24AA).withOpacity(0.5),
                        onChanged: isLoading ? null : (value) => _toggleSharing(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: isLoading ? null : _logout,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: isLoading ? null : _deleteAccount,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Color(0xFFD32F2F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Delete Account',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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