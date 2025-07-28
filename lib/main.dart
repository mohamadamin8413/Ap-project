import 'package:flutter/material.dart';
import 'package:projectap/ProfilePage.dart';
import 'package:projectap/apiservice.dart';
import 'package:projectap/Signup.dart';
import 'package:projectap/Homepage.dart';
import 'package:projectap/appstorage.dart';

AppStorage storage = AppStorage();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await storage.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = true;
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _loadInitialScreen();
  }

  Future<void> _loadInitialScreen() async {
    try {
      final user = await storage.loadCurrentUser();
      setState(() {
        _initialScreen = user != null ? MusicHomePage() : const Screen2();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user: $e');
      setState(() {
        _initialScreen = const Screen2();
        _isLoading = false;
      });
    }
  }

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: _initialScreen,
    );
  }
}