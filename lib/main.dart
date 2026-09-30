import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xray Ultra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212), // رنگ گرانیتی مشکی
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8E24AA), // بنفش
          secondary: Color(0xFF00E676), // سبز یاقوتی
        ),
      ),
      home: const FirebaseInitScreen(),
    );
  }
}

class FirebaseInitScreen extends StatefulWidget {
  const FirebaseInitScreen({super.key});

  @override
  State<FirebaseInitScreen> createState() => _FirebaseInitScreenState();
}

class _FirebaseInitScreenState extends State<FirebaseInitScreen> {
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupFirebase();
  }

  Future<void> _setupFirebase() async {
    setState(() {
      _errorMessage = null;
    });
    try {
      // مقداردهی مستقیم FirebaseOptions بدون نیاز به google-services.json
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDummyKeyForFirebaseToInitialize12345",
          appId: "1:1234567890:android:abcdef123456",
          messagingSenderId: "1234567890",
          projectId: "pane-dcc9a",
          databaseURL: "https://pane-dcc9a-default-rtdb.firebaseio.com",
        ),
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized) {
      // بعد از اتصال موفق، وارد صفحه اصلی برنامه می‌شود
      return const HomeScreen(); 
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 70),
                const SizedBox(height: 16),
                const Text(
                  'خطا در اتصال به Firebase',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _setupFirebase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E24AA),
                  ),
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xray Ultra'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: const Center(
        child: Text(
          'خوش آمدید! اتصال به فایربیس با موفقیت انجام شد.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
