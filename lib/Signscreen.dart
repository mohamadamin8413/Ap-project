import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
      final request = SocketRequest(
        action: "login",
        data: {
          "email": email,
          "password": password,
        },
      );

      final response = await _socketService.send(request);

      if (response.isSuccess) {
        _showMessage("Login successful ✅");
        final user = User(
          id: 0,
          username: email,
          password: password,
          email: email,
        );
        await storage.saveCurrentUser(user);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) =>  MusicHomePage()),
        );
      } else {
        _showMessage(response.message, error: true);
      }
    } on SocketException catch (e) {
      _showMessage("Connection error: ${e.message}", error: true);
    } on TimeoutException {
      _showMessage("Request timed out", error: true);
    } catch (e) {
      _showMessage("Login failed: ${e.toString()}", error: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    bool isPassword = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.green.shade600),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.greenAccent),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.greenAccent,
            ),
            onPressed: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
          )
              : null,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_rounded,
                  size: 100, color: Colors.greenAccent),
              const SizedBox(height: 20),
              _buildInputField(
                controller: _emailController,
                hint: "Email",
                icon: Icons.email_outlined,
                obscure: false,
              ),
              _buildInputField(
                controller: _passwordController,
                hint: "Password",
                icon: Icons.lock_outline,
                obscure: obscurePassword,
                isPassword: true,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.greenAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 12,
                  ),
                  child: isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                      : const Text("Sign In",
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?",
                      style: TextStyle(color: Colors.white70)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Screen2()),
                      );
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                          color: Colors.greenAccent, fontWeight: FontWeight.bold),
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