import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/Homepage.dart';
import 'package:projectap/Signup.dart';
import 'package:projectap/User.dart';

AppStorage storage = AppStorage();

class Screen1 extends StatefulWidget {
  const Screen1({super.key});

  @override
  State<Screen1> createState() => _Screen1State();
}

class _Screen1State extends State<Screen1> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool obscurePassword = true;
  bool isLoading = false;
  final SocketService _socketService = SocketService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _socketService.close();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Please enter email and password", error: true);
      setState(() => isLoading = false);
      return;
    }

    try {
      await storage.init();
      final request = SocketRequest(
        action: "login",
        data: {
          "email": email,
          "password": password,
        },
      );

      final response = await _socketService.send(request);
      print('Login response: ${response.toJson()}');

      if (response.isSuccess && response.data != null) {
        _showMessage("Login successful");
        final userData = response.data as Map<String, dynamic>;
        final user = User.fromJson(userData);
        await storage.saveCurrentUser(user);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MusicHomePage()),
          );
        }
      } else {
        _showMessage(response.data == null ? "No user data received" : response.message, error: true);
      }
    } on SocketException catch (e) {
      _showMessage("Connection error: ${e.message}", error: true);
      print('SocketException: $e');
    } on TimeoutException {
      _showMessage("Request timed out", error: true);
      print('TimeoutException');
    } catch (e) {
      _showMessage("Login failed: ${e.toString()}", error: true);
      print('Login error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
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

  Widget _buildInputField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFFCE93D8)),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFFCE93D8),
            ),
            onPressed: onToggle,
          )
              : null,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFCE93D8), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.login,
                size: 80,
                color: Color(0xFFCE93D8),
              ),
              const SizedBox(height: 20),
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
                'Sign in to your account',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),
              _buildInputField(
                hint: "Email",
                icon: Icons.email_outlined,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildInputField(
                hint: "Password",
                icon: Icons.lock_outline,
                controller: _passwordController,
                obscureText: !obscurePassword,
                isPassword: true,
                onToggle: () => setState(() => obscurePassword = !obscurePassword),
              ),
              const SizedBox(height: 24),
              Container(
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
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: isLoading
                      ? const SpinKitThreeBounce(
                    color: Colors.white,
                    size: 24,
                  )
                      : Text(
                    'Sign In',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Screen2()),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFCE93D8),
                        fontWeight: FontWeight.bold,
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
}