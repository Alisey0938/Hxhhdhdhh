import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xray Ultra Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090B10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF131722),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF131722),
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const AuthCheckScreen(),
    );
  }
}

// بررسی وضعیت لاگین بودن کاربر
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  void _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString('user_id');

    if (userId != null && userId.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ServerListScreen(userId: userId)),
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
      body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
    );
  }
}

// ----------------------------------------------------
// صفحه ورود (LOGIN SCREEN)
// ----------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً نام کاربری و رمز عبور را وارد کنید.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await http.get(Uri.parse("https://pane-dcc9a-default-rtdb.firebaseio.com/users.json"));
      if (res.statusCode == 200 && res.body != 'null') {
        final Map<String, dynamic> users = json.decode(res.body);
        String? foundUserId;
        Map<String, dynamic>? userData;

        users.forEach((key, value) {
          if (value['username'] == username && value['password'] == password) {
            foundUserId = key;
            userData = value;
          }
        });

        if (foundUserId != null && userData != null) {
          // بررسی فعال بودن حساب
          if (userData!['active'] != true) {
            _showError('حساب کاربری شما غیرفعال شده است.');
            setState(() => _isLoading = false);
            return;
          }

          // ذخیره ورود
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', foundUserId!);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => ServerListScreen(userId: foundUserId!)),
            );
          }
        } else {
          _showError('نام کاربری یا رمز عبور اشتباه است.');
        }
      } else {
        _showError('خطا در ارتباط با سرور.');
      }
    } catch (e) {
      _showError('خطا در برقراری ارتباط: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, size: 80, color: Color(0xFF8B5CF6)),
              const SizedBox(height: 12),
              const Text(
                'XRAY ULTRA',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'نام کاربری',
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF8B5CF6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'رمز عبور',
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF8B5CF6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ورود به حساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// صفحه اصلی سرورها و مدیریت حجم/انقضا (SERVER LIST SCREEN)
// ----------------------------------------------------
class ServerListScreen extends StatefulWidget {
  final String userId;
  const ServerListScreen({super.key, required this.userId});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  final String firebaseUrl = "https://pane-dcc9a-default-rtdb.firebaseio.com/";

  late V2ray v2ray;
  List<dynamic> _configs = [];
  final Map<String, int> _pings = {};
  final Map<String, bool> _pingLoading = {};

  bool _isLoading = true;
  bool _isConnectingProcess = false;
  String? _connectedConfigId;
  bool _isConnected = false;
  String _statusText = "DISCONNECTED";

  Timer? _trafficTimer;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _initV2Ray();
    _fetchUserDataAndCheck();
    _fetchConfigs();
  }

  @override
  void dispose() {
    _trafficTimer?.cancel();
    super.dispose();
  }

  void _resetToDisconnected() {
    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _connectedConfigId = null;
      _isConnectingProcess = false;
      _statusText = "DISCONNECTED";
    });
  }

  // ۱. بررسی اعتبار حساب و میزان مصرف
  Future<void> _fetchUserDataAndCheck() async {
    try {
      final res = await http.get(Uri.parse("${firebaseUrl}users/${widget.userId}.json"));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = json.decode(res.body);
        _userData = data;

        // الف) بررسی انقضای روزانه
        if (data['created_at'] != null && data['max_days'] != null && data['max_days'] > 0) {
          final createdDate = DateTime.parse(data['created_at']);
          final expireDate = createdDate.add(Duration(days: data['max_days']));
          if (DateTime.now().isAfter(expireDate)) {
            _logoutUser('اعتبار زمانی حساب شما به پایان رسیده است.');
            return;
          }
        }

        // ب) بررسی انقضای حجمی (اگر 0 نباشد)
        double maxGb = (data['max_volume_gb'] ?? 0).toDouble();
        int usedBytes = (data['used_bytes'] ?? 0);
        if (maxGb > 0) {
          double usedGb = usedBytes / (1024 * 1024 * 1024);
          if (usedGb >= maxGb) {
            _logoutUser('حجم مصرفی حساب شما به پایان رسیده است.');
            return;
          }
        }

        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("خطا در به‌روزرسانی داده کاربر: $e");
    }
  }

  // خروج اجباری و قطع وی‌پی‌ان
  void _logoutUser(String reason) async {
    _trafficTimer?.cancel();
    try {
      await v2ray.stopV2Ray();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4)),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // محاسبه ترافيک مصرفی و ارسال به فایربیس
  void _startTrafficMonitoring() {
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isConnected || _userData == null) return;

      double maxGb = (_userData!['max_volume_gb'] ?? 0).toDouble();

      // گرفتن آمار دقیق هسته
      var status = await v2ray.getConnectedV2rayStatistics();
      int newBytes = status.upload + status.download;

      if (newBytes > 0) {
        int currentUsed = (_userData!['used_bytes'] ?? 0);
        int totalUsed = currentUsed + newBytes;

        // آپدیت سریع فایربیس
        await http.patch(
          Uri.parse("${firebaseUrl}users/${widget.userId}.json"),
          body: json.encode({"used_bytes": totalUsed}),
        );

        _userData!['used_bytes'] = totalUsed;

        // بررسی مجدد سقف حجم
        if (maxGb > 0 && (totalUsed / (1024 * 1024 * 1024)) >= maxGb) {
          _logoutUser('حجم مجاز شما تمام شد و از حساب خارج شدید.');
        }
      }
    });
  }

  // ۲. مقداردهی اولیه هسته Xray
  void _initV2Ray() async {
    v2ray = V2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        final stateUpper = status.state.toUpperCase();

        if (stateUpper == 'CONNECTED') {
          setState(() {
            _isConnected = true;
            _statusText = "CONNECTED";
            _isConnectingProcess = false;
          });
          _startTrafficMonitoring();
        } else if (stateUpper == 'DISCONNECTED' || stateUpper == 'STOPPED' || stateUpper == 'IDLE') {
          _trafficTimer?.cancel();
          _resetToDisconnected();
        } else {
          setState(() => _statusText = stateUpper);
        }
      },
    );

    await v2ray.initialize(
      notificationIconResourceType: "mipmap",
      notificationIconResourceName: "ic_launcher",
    );
  }

  // ۳. دریافت لیست سرورها
  Future<void> _fetchConfigs() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse("${firebaseUrl}configs.json"));
      if (response.statusCode == 200 && response.body != 'null') {
        final data = json.decode(response.body);
        List<dynamic> loadedConfigs = [];

        if (data is List) {
          loadedConfigs = data.where((item) => item != null && item['active'] == true).toList();
        } else if (data is Map) {
          data.forEach((key, value) {
            if (value != null && value['active'] == true) {
              loadedConfigs.add(value);
            }
          });
        }

        setState(() {
          _configs = loadedConfigs;
          _isLoading = false;
        });

        _testAllPings();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _testAllPings() async {
    for (var item in _configs) {
      _testSinglePing(item);
    }
  }

  Future<void> _testSinglePing(Map<String, dynamic> item) async {
    final String configUrl = (item['config'] ?? '').toString().trim();
    final String configId = item['id']?.toString() ?? item['name'];

    if (configUrl.isEmpty) return;

    if (mounted) setState(() => _pingLoading[configId] = true);

    try {
      V2RayURL parser = V2ray.parseFromURL(configUrl);
      int delay = await v2ray.getServerDelay(config: parser.getFullConfiguration(), url: 'https://1.1.1.1');

      if (delay <= 0) {
        final stopwatch = Stopwatch()..start();
        final int targetPort = int.tryParse(parser.port.toString()) ?? 443;
        final socket = await Socket.connect(parser.address, targetPort, timeout: const Duration(seconds: 3));
        stopwatch.stop();
        delay = stopwatch.elapsedMilliseconds;
        await socket.close();
      }

      if (mounted) {
        setState(() {
          _pings[configId] = delay;
          _pingLoading[configId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pings[configId] = -1;
          _pingLoading[configId] = false;
        });
      }
    }
  }

  Future<void> _toggleConnect(Map<String, dynamic> item) async {
    if (_isConnectingProcess) return;

    final String configUrl = (item['config'] ?? '').toString().trim();
    final String configId = item['id']?.toString() ?? item['name'];

    if (_isConnected && _connectedConfigId == configId) {
      _trafficTimer?.cancel();
      _resetToDisconnected();
      try {
        await v2ray.stopV2Ray();
      } catch (_) {}
      return;
    }

    setState(() {
      _isConnectingProcess = true;
      _connectedConfigId = configId;
    });

    try {
      if (_isConnected) await v2ray.stopV2Ray();

      if (await v2ray.requestPermission()) {
        V2RayURL parser = V2ray.parseFromURL(configUrl);

        await v2ray.startV2Ray(
          remark: item['name'] ?? parser.remark,
          config: parser.getFullConfiguration(),
          proxyOnly: false,
        );

        if (mounted) {
          setState(() {
            _isConnected = true;
            _statusText = "CONNECTED";
            _isConnectingProcess = false;
          });
        }
      } else {
        _resetToDisconnected();
      }
    } catch (e) {
      _resetToDisconnected();
    }
  }

  Color _getPingColor(int ping) {
    if (ping <= 0) return Colors.redAccent;
    if (ping < 300) return const Color(0xFF10B981);
    if (ping < 600) return Colors.amber;
    return Colors.redAccent;
  }

  String _getVolumeString() {
    if (_userData == null) return "در حال دریافت...";
    double maxGb = (_userData!['max_volume_gb'] ?? 0).toDouble();
    if (maxGb == 0) return "حجم نامحدود";

    int usedBytes = (_userData!['used_bytes'] ?? 0);
    double usedGb = usedBytes / (1024 * 1024 * 1024);
    return "${usedGb.toStringAsFixed(2)} GB / ${maxGb.toStringAsFixed(1)} GB";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XRAY ULTRA', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => _logoutUser('از حساب کاربری خارج شدید.'),
          ),
        ],
      ),
      body: Column(
        children: [
          // کارت نمایش وضعیت اتصال و حجم مصرفی
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isConnected
                    ? [const Color(0xFF064E3B), const Color(0xFF10B981)]
                    : [const Color(0xFF451225), const Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(_isConnected ? Icons.shield : Icons.shield_outlined, size: 30, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      _isConnected ? "اتصال ایمن برقرار است" : "قطع اتصال",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("مصرف حجم:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(_getVolumeString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          // لیست کانفیگ‌ها
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _configs.length,
                    itemBuilder: (context, index) {
                      final item = _configs[index];
                      final String configId = item['id']?.toString() ?? item['name'];
                      final bool isThisConnected = _isConnected && (_connectedConfigId == configId);
                      final int ping = _pings[configId] ?? 0;

                      return Card(
                        color: const Color(0xFF131722),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(item['name'] ?? 'سرور Xray', style: const TextStyle(color: Colors.white)),
                          subtitle: Text('$ping ms', style: TextStyle(color: _getPingColor(ping))),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isThisConnected ? Colors.redAccent : const Color(0xFF8B5CF6),
                            ),
                            onPressed: _isConnectingProcess ? null : () => _toggleConnect(item),
                            child: Text(isThisConnected ? 'قطع' : 'اتصال'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
