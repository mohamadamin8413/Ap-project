import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:projectap/appstorage.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/Signscreen.dart';
import 'package:projectap/Homepage.dart';
import 'package:projectap/User.dart';

AppStorage storage = AppStorage();

class Screen2 extends StatefulWidget {
  const Screen2({super.key});

  @override
  State<Screen2> createState() => _Screen2State();
}

class _Screen2State extends State<Screen2> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool showPassword = false;
  bool showConfirmPassword = false;
  bool isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? passwordValidator(String? value) {
    final email = _emailController.text.trim();
    if (value == null || value.isEmpty) return 'Password cannot be empty';
    if (value.length < 8) return 'At least 8 characters required';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Include one uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Include one lowercase letter';
    if (!RegExp(r'\d').hasMatch(value)) return 'Include one number';
    if (email.isNotEmpty && value.contains(email)) return 'Password must not contain email';
    return null;
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
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

  Future<void> _register() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (_formKey.currentState!.validate()) {
      try {
        await storage.init();
        final request = SocketRequest(
          action: "register",
          data: {
            "email": email,
            "username": username,
            "password": password,
          },
        );

        final response = await SocketService().send(request);
        print('Register response: ${response.toJson()}');

        if (response.isSuccess && response.data != null) {
          _showMessage("Registration successful!");
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
        _showMessage("Registration failed: ${e.toString()}", error: true);
        print('Register error: $e');
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  Widget _buildInputField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF1DB954)),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF1DB954),
              ),
              onPressed: onToggle,
            )
                : null,
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(16),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF1DB954), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.redAccent),
              borderRadius: BorderRadius.circular(16),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
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
            colors: [
              Color(0xFF121212),
              Color(0xFF1DB954),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 800),
                        child: Icon(
                          Icons.person_add_alt_1,
                          size: 120,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInDown(
                        duration: const Duration(milliseconds: 600),
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildInputField(
                        hint: "Email",
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email cannot be empty';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      _buildInputField(
                        hint: "Username",
                        icon: Icons.person,
                        controller: _usernameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Username cannot be empty';
                          if (value.length < 3) return 'Username must be at least 3 characters';
                          return null;
                        },
                      ),
                      _buildInputField(
                        hint: "Password",
                        icon: Icons.lock_outline,
                        controller: _passwordController,
                        obscureText: !showPassword,
                        onToggle: () => setState(() => showPassword = !showPassword),
                        isPassword: true,
                        validator: passwordValidator,
                      ),
                      _buildInputField(
                        hint: "Confirm Password",
                        icon: Icons.lock_reset_outlined,
                        controller: _confirmPasswordController,
                        obscureText: !showConfirmPassword,
                        onToggle: () => setState(() => showConfirmPassword = !showConfirmPassword),
                        isPassword: true,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Confirm your password';
                          if (val != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      FadeInUp(
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
                            onPressed: isLoading
                                ? null
                                : () {
                              if (_formKey.currentState!.validate()) {
                                _register();
                              }
                            },
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
                              'Sign Up',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const Screen1()),
                                );
                              },
                              child: Text(
                                'Sign In',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF1DB954),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}