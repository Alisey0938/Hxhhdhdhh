import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Xray Ultra',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurple,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return HomeScreen(
            userId: args['userId'],
            v2rayClient: args['v2rayClient'],
          );
        },
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final FlutterV2ray _v2rayClient = FlutterV2ray(
    onStatusChanged: (status) {},
  );
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _v2rayClient.initializeV2Ray();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً نام کاربری را وارد کنید')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ref = FirebaseDatabase.instance.ref('users/$username');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final bool isActive = data['isActive'] ?? true;

        if (isActive) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/home',
            arguments: {
              'userId': username,
              'v2rayClient': _v2rayClient,
            },
          );
        } else {
          _showError('حساب کاربری شما غیرفعال است.');
        }
      } else {
        _showError('کاربری با این مشخصات یافت نشد.');
      }
    } catch (e) {
      _showError('خطا در برقراری ارتباط با سرور.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 80, color: Colors.deepPurpleAccent),
              const SizedBox(height: 20),
              const Text('Xray Ultra', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'نام کاربری',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ورود به برنامه', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String userId;
  final FlutterV2ray v2rayClient;

  const HomeScreen({
    Key? key,
    required this.userId,
    required this.v2rayClient,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    AuthService.startUserListener(context, widget.userId, widget.v2rayClient);
  }

  @override
  void dispose() {
    AuthService.stopUserListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xray Ultra'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          tooltip: 'خروج از حساب',
          onPressed: () => _showLogoutDialog(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'خوش آمدید (${widget.userId})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            IconButton(
              iconSize: 100,
              icon: Icon(
                Icons.power_settings_new_rounded,
                color: _isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
              onPressed: () {
                setState(() {
                  _isConnected = !_isConnected;
                });
              },
            ),
            const SizedBox(height: 10),
            Text(_isConnected ? 'متصل شد' : 'قطع می‌باشد'),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خروج از حساب'),
        content: const Text('آیا می‌خواهید از حساب کاربری خود خارج شوید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthService.logoutManual(context, widget.v2rayClient);
            },
            child: const Text('خروج', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
