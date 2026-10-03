import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

const String FIREBASE_URL = "https://pane-dcc9a-default-rtdb.firebaseio.com/";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XRAY ULTRA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090B10),
        cardColor: const Color(0xFF131722),
        primaryColor: const Color(0xFF8B5CF6),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('username');
    final savedPass = prefs.getString('password');

    if (savedUser != null && savedPass != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainScreen(username: savedUser, password: savedPass),
          ),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id;
  }

  Future<void> _login() async {
    final username = _userController.text.trim();
    final password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً نام کاربری و رمز عبور را وارد کنید.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await http.get(Uri.parse('${FIREBASE_URL}users.json'));
      if (res.statusCode == 200 && res.body != 'null') {
        final Map<String, dynamic> users = jsonDecode(res.body);
        String? foundUserId;
        Map<String, dynamic>? userData;

        users.forEach((key, value) {
          if (value['username'] == username && value['password'] == password) {
            foundUserId = key;
            userData = Map<String, dynamic>.from(value);
          }
        });

        if (userData != null && foundUserId != null) {
          // بررسی فعال بودن کاربر
          if (userData!['active'] != true) {
            _showError('حساب کاربری شما غیرفعال شده است.');
            return;
          }

          // بررسی اعتبار زمانی
          final createdAt = DateTime.parse(userData!['created_at']);
          final maxDays = userData!['max_days'] ?? 30;
          if (DateTime.now().difference(createdAt).inDays > maxDays) {
            _showError('اعتبار زمانی حساب شما به پایان رسیده است.');
            return;
          }

          // بررسی حجم مصرفی
          final maxGb = (userData!['max_volume_gb'] ?? 0).toDouble();
          final usedBytes = (userData!['used_bytes'] ?? 0).toDouble();
          final usedGb = usedBytes / (1024 * 1024 * 1024);
          if (maxGb > 0 && usedGb >= maxGb) {
            _showError('حجم مصرفی حساب شما به پایان رسیده است.');
            return;
          }

          // بررسی تعداد دستگاه‌های فعال همزمان
          final deviceId = await _getDeviceId();
          final maxDevices = userData!['max_devices'] ?? 1;
          final Map activeDevices = userData!['active_devices'] ?? {};

          if (!activeDevices.containsKey(deviceId) && activeDevices.length >= maxDevices) {
            _showError('تعداد دستگاه‌های متصل به این حساب به سقف مجاز ($maxDevices) رسیده است.');
            return;
          }

          // ثبت دستگاه جدید در فایربیس
          await http.put(
            Uri.parse('${FIREBASE_URL}users/$foundUserId/active_devices/$deviceId.json'),
            body: jsonEncode(DateTime.now().toIso8601String()),
          );

          // ذخیره ورود
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', username);
          await prefs.setString('password', password);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MainScreen(username: username, password: password),
              ),
            );
          }
        } else {
          _showError('نام کاربری یا رمز عبور اشتباه است.');
        }
      } else {
        _showError('خطا در برقراری ارتباط با سرور.');
      }
    } catch (e) {
      _showError('خطا: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 80, color: Color(0xFF8B5CF6)),
              const SizedBox(height: 16),
              const Text(
                'XRAY ULTRA',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _userController,
                decoration: InputDecoration(
                  labelText: 'نام کاربری',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'رمز عبور',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ورود به حساب', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String username;
  final String password;

  const MainScreen({super.key, required this.username, required this.password});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late FlutterV2ray _v2ray;
  bool _isConnected = false;
  List<dynamic> _configs = [];
  int _selectedConfigIndex = 0;
  bool _isLoadingConfigs = true;
  String _statusText = "آماده اتصال";

  @override
  void initState() {
    super.initState();
    _initV2Ray();
    _fetchConfigs();
  }

  void _initV2Ray() {
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (mounted) {
          setState(() {
            _isConnected = status.state == 'CONNECTED';
            _statusText = status.state;
          });
        }
      },
    );
    _v2ray.initializeV2Ray();
  }

  Future<void> _fetchConfigs() async {
    try {
      final res = await http.get(Uri.parse('${FIREBASE_URL}configs.json'));
      if (res.statusCode == 200 && res.body != 'null') {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final List<dynamic> loaded = [];

        data.forEach((key, value) {
          if (value['active'] == true) {
            loaded.add(value);
          }
        });

        setState(() {
          _configs = loaded;
          _isLoadingConfigs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingConfigs = false);
      }
    }
  }

  Future<void> _toggleConnection() async {
    if (_configs.isEmpty) return;

    if (_isConnected) {
      await _v2ray.stopV2Ray();
      setState(() {
        _isConnected = false;
        _statusText = "قطع شد";
      });
    } else {
      final configStr = _configs[_selectedConfigIndex]['config'];

      if (await _v2ray.requestPermission()) {
        try {
          final V2RayURL parser = FlutterV2ray.parseFromURL(configStr);
          await _v2ray.startV2Ray(
            remark: parser.remark,
            config: parser.fullConfiguration,
            blockedApps: null,
            bypassSubnets: null,
            proxyOnly: false,
          );
          setState(() {
            _isConnected = true;
            _statusText = "متصل شد";
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در اجرای کانفیگ: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مجوز VPN داده نشد.')),
        );
      }
    }
  }

  Future<void> _logout() async {
    if (_isConnected) {
      await _v2ray.stopV2Ray();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('کاربر: ${widget.username}'),
        backgroundColor: const Color(0xFF131722),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoadingConfigs
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // دکمه بزرگ اتصال
                  GestureDetector(
                    onTap: _toggleConnection,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected ? Colors.green.shade700 : const Color(0xFF8B5CF6),
                        boxShadow: [
                          BoxShadow(
                            color: (_isConnected ? Colors.green : const Color(0xFF8B5CF6)).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isConnected ? Icons.power_settings_new : Icons.play_arrow,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? Colors.green : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // لیست کانفیگ‌ها جهت انتخاب
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('انتخاب سرور:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _configs.isEmpty
                        ? const Center(child: Text('هیچ کانفیگ فعالی یافت نشد.'))
                        : ListView.builder(
                            itemCount: _configs.length,
                            itemBuilder: (context, index) {
                              final item = _configs[index];
                              final isSelected = _selectedConfigIndex == index;
                              return Card(
                                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF131722),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Text(item['flag'] ?? '🌐', style: const TextStyle(fontSize: 24)),
                                  title: Text(item['name'] ?? 'سرور', style: const TextStyle(color: Colors.white)),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: Color(0xFF8B5CF6))
                                      : null,
                                  onTap: () {
                                    if (!_isConnected) {
                                      setState(() => _selectedConfigIndex = index);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
