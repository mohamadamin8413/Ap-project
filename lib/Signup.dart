import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
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
        final request = SocketRequest(
          action: "register",
          data: {
            "email": email,
            "username": username,
            "password": password,
          },
        );

        final response = await SocketService().send(request);

        if (response.isSuccess) {
          _showMessage("Registration successful!");
          final user = User(
            id: 0, // Placeholder ID, updated by backend
            username: username,
            password: password,
            email: email,
          );
          await storage.saveCurrentUser(user);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) =>  MusicHomePage()),
            );
          }
        } else {
          _showMessage(response.message, error: true);
        }
      } on SocketException catch (e) {
        _showMessage("Connection error: ${e.message}", error: true);
      } on TimeoutException {
        _showMessage("Request timed out", error: true);
      } catch (e) {
        _showMessage("Registration failed: ${e.toString()}", error: true);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.greenAccent),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.greenAccent,
            ),
            onPressed: onToggle,
          )
              : null,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white10,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.greenAccent),
            borderRadius: BorderRadius.circular(30),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.greenAccent, width: 2),
            borderRadius: BorderRadius.circular(30),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.redAccent),
            borderRadius: BorderRadius.circular(30),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E2E2E),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          height: MediaQuery.of(context).size.height,
          alignment: Alignment.center,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_alt, size: 100, color: Colors.greenAccent),
                const SizedBox(height: 20),
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
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () {
                      if (_formKey.currentState!.validate()) {
                        _register();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.greenAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 10,
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "Sign Up",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? ",
                        style: TextStyle(color: Colors.white70)),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const Screen1()),
                        );
                      },
                      child: const Text(
                        "Sign In",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}