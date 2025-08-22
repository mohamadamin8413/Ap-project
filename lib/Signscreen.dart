import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:projectap/Homepage.dart';
import 'package:projectap/Signup.dart';
import 'package:projectap/User.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/apiservice.dart';

AppStorage storage = AppStorage();

class Screen1 extends StatefulWidget {
  const Screen1({super.key});

  @override
  State<Screen1> createState() => _Screen1State();
}

class _Screen1State extends State<Screen1> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLoading = false;
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _checkLoggedInUser();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _socketService.close();
    super.dispose();
  }

  Future<void> _checkLoggedInUser() async {
    final user = await storage.loadCurrentUser();
    if (user != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MusicHomePage()),
      );
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter both email and password', error: true);
      return;
    }

    setState(() => isLoading = true);
    try {
      final request = SocketRequest(
        action: 'login',
        data: {
          'email': email,
          'password': password,
        },
        requestId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      print('Sending login request: ${request.toJson()}');
      final response = await _socketService.send(request);
      print('Response for login: ${response.toJson()}');
      if (response.isSuccess && response.data != null) {
        final user = User.fromJson(response.data as Map<String, dynamic>);
        await storage.saveCurrentUser(user);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MusicHomePage()),
          );
        }
        _showMessage('Login successful');
      } else {
        _showMessage('Login failed: ${response.message}', error: true);
      }
    } catch (e) {
      print('Error during login: $e');
      _showMessage('Error during login: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (mounted) {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  hintText: 'Email',
                  hintStyle: GoogleFonts.poppins(color: Colors.white54),
                  prefixIcon: const Icon(Icons.email, color: Color(0xFFCE93D8)),
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
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: GoogleFonts.poppins(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  hintText: 'Password',
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
              const SizedBox(height: 24),
              GestureDetector(
                onTap: isLoading ? null : _login,
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
                      'Sign In',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFCE93D8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
}