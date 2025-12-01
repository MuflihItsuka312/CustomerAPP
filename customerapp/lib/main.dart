import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (with error handling)
  try {
    await Firebase.initializeApp();
    print('[FIREBASE] Initialized successfully');
    
    // Initialize Notification Service only if Firebase initialized
    await NotificationService().initialize();
    print('[NOTIFICATION] Service initialized');
  } catch (e) {
    print('[FIREBASE] Initialization failed: $e');
    print('[NOTIFICATION] Skipping notification service initialization');
    // Continue without Firebase - app will work without notifications
  }
  
  runApp(const SmartLockerApp());
}

class SmartLockerApp extends StatelessWidget {
  const SmartLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Customer Revisi 3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
      ),
      home: const _RootDecider(),
    );
  }
}

class _RootDecider extends StatefulWidget {
  const _RootDecider();

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final token = await ApiClient.getToken();
    setState(() {
      _loggedIn = token != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _loggedIn ? const MainTabPage() : const LoginPage();
  }
}
