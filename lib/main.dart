import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() {
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
        scaffoldBackgroundColor: const Color(0xFF1B1D29),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B9BB4),
          surface: Color(0xFF222536),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B1D29),
          elevation: 0,
        ),
      ),
      home: const AuthCheckScreen(),
    );
  }
}

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
      body: Center(child: CircularProgressIndicator(color: Color(0xFF8B9BB4))),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // استخراج شناسه یکتا و نام دستگاه جهت هماهنگی با پنل مدیریت
  Future<String> _getDeviceId() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        String model = androidInfo.model.replaceAll(RegExp(r'[^\w\s-]'), '');
        return model.isNotEmpty ? model : 'ANDROID_${androidInfo.id}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.model;
      }
    } catch (_) {}
    return 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
  }

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
          if (value != null && value['username'] == username && value['password'] == password) {
            foundUserId = key;
            userData = Map<String, dynamic>.from(value);
          }
        });

        if (foundUserId != null && userData != null) {
          if (userData!['active'] != true) {
            _showError('حساب کاربری شما غیرفعال شده است.');
            setState(() => _isLoading = false);
            return;
          }

          final String deviceId = await _getDeviceId();
          final int maxDevices = (userData!['max_devices'] ?? 1);
          
          Map<String, dynamic> activeSessions = {};
          if (userData!['active_sessions'] != null && userData!['active_sessions'] is Map) {
            activeSessions = Map<String, dynamic>.from(userData!['active_sessions']);
          }

          // بررسی محدودیت تعداد دستگاه آنلاین
          if (!activeSessions.containsKey(deviceId) && activeSessions.length >= maxDevices) {
            _showError('محدودیت تعداد کاربر آنلاین! این اکانت در دستگاه دیگری فعال است.');
            setState(() => _isLoading = false);
            return;
          }

          // ثبت مشخصات ورود دستگاه در فایربیس
          final nowIso = DateTime.now().toIso8601String();
          final sessionData = {
            "login_at": activeSessions[deviceId]?['login_at'] ?? nowIso,
            "last_seen": nowIso,
          };

          await http.put(
            Uri.parse("https://pane-dcc9a-default-rtdb.firebaseio.com/users/$foundUserId/active_sessions/$deviceId.json"),
            body: json.encode(sessionData),
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', foundUserId!);
          await prefs.setString('device_id', deviceId);

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
              const Icon(Icons.vpn_key_rounded, size: 80, color: Color(0xFF8B9BB4)),
              const SizedBox(height: 12),
              const Text('XRAY ULTRA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'نام کاربری',
                  filled: true,
                  fillColor: const Color(0xFF222536),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'رمز عبور',
                  filled: true,
                  fillColor: const Color(0xFF222536),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B4261),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('ورود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServerListScreen extends StatefulWidget {
  final String userId;
  const ServerListScreen({super.key, required this.userId});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> with WidgetsBindingObserver {
  final String firebaseUrl = "https://pane-dcc9a-default-rtdb.firebaseio.com/";

  late FlutterV2ray flutterV2ray;
  List<dynamic> _configs = [];
  final Map<String, int> _pings = {};
  final Map<String, bool> _pingLoading = {};

  bool _isLoading = true;
  bool _isTestingAllPings = false;
  bool _isConnectingProcess = false;
  String? _selectedConfigId;
  bool _isConnected = false;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _announcementData;

  int _lastSessionUpload = 0;
  int _lastSessionDownload = 0;
  int _accumulatedUsedBytes = 0;
  String _remainingTimeText = '...';

  Timer? _userCheckTimer;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeviceIdAndStart();
    _initV2Ray();
    _fetchConfigs();
    _fetchAnnouncement();
  }

  Future<void> _initDeviceIdAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');

    if (_deviceId == null) {
      try {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          String model = androidInfo.model.replaceAll(RegExp(r'[^\w\s-]'), '');
          _deviceId = model.isNotEmpty ? model : 'ANDROID_${androidInfo.id}';
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          _deviceId = iosInfo.model;
        }
      } catch (_) {
        _deviceId = 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
      }
      await prefs.setString('device_id', _deviceId!);
    }

    _fetchUserDataAndCheck();
    _userCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchUserDataAndCheck();
      _fetchAnnouncement();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUserDataAndCheck();
      _fetchAnnouncement();
    }
  }

  void _initV2Ray() async {
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        final stateUpper = status.state.toUpperCase();

        if (stateUpper == 'CONNECTED') {
          if (!_isConnected) {
            setState(() {
              _isConnected = true;
              _isConnectingProcess = false;
            });
          }
          _calculateAndSaveTraffic(status.upload, status.download);
        } else if (stateUpper == 'DISCONNECTED' || stateUpper == 'STOPPED' || stateUpper == 'IDLE') {
          if (_isConnected) {
            setState(() {
              _isConnected = false;
              _isConnectingProcess = false;
              _lastSessionUpload = 0;
              _lastSessionDownload = 0;
            });
          }
        }
      },
    );

    await flutterV2ray.initializeV2Ray();
  }

  Future<void> _fetchAnnouncement() async {
    try {
      final res = await http.get(Uri.parse("${firebaseUrl}announcement.json"));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = json.decode(res.body);
        if (mounted) setState(() => _announcementData = data);
      }
    } catch (_) {}
  }

  Future<void> _fetchUserDataAndCheck() async {
    try {
      final res = await http.get(Uri.parse("${firebaseUrl}users/${widget.userId}.json"));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = json.decode(res.body);

        if (data == null) {
          _logoutUser('حساب کاربری شما حذف شده است.');
          return;
        }

        if (data['active'] != true) {
          _logoutUser('حساب کاربری شما غیرفعال شده است.');
          return;
        }

        // بررسی اخراج دستگاه از پنل مدیریت
        if (_deviceId != null) {
          Map<String, dynamic> activeSessions = {};
          if (data['active_sessions'] != null && data['active_sessions'] is Map) {
            activeSessions = Map<String, dynamic>.from(data['active_sessions']);
          }

          // اگر دستگاه از لیست active_sessions حذف شده باشد، کاربر اخراج می‌شود
          if (!activeSessions.containsKey(_deviceId)) {
            _logoutUser('دستگاه شما توسط ادمین از حساب خارج شد.');
            return;
          } else {
            // بروزرسانی زمان آخرین اتصال
            http.patch(
              Uri.parse("${firebaseUrl}users/${widget.userId}/active_sessions/$_deviceId.json"),
              body: json.encode({"last_seen": DateTime.now().toIso8601String()}),
            );
          }
        }

        _userData = Map<String, dynamic>.from(data);
        _accumulatedUsedBytes = (data['used_bytes'] ?? 0);

        if (data['expire_at'] != null) {
          final expireDate = DateTime.parse(data['expire_at']);
          final now = DateTime.now();
          final diff = expireDate.difference(now);

          if (diff.isNegative) {
            _logoutUser('اعتبار زمانی حساب شما به پایان رسیده است.');
            return;
          } else {
            if (diff.inDays > 0) {
              _remainingTimeText = '${diff.inDays} روز باقی‌مانده';
            } else if (diff.inHours > 0) {
              _remainingTimeText = '${diff.inHours} ساعت باقی‌مانده';
            } else {
              _remainingTimeText = '${diff.inMinutes} دقیقه باقی‌مانده';
            }
          }
        } else {
          _remainingTimeText = 'نامحدود';
        }

        double maxGb = (data['max_volume_gb'] ?? 0).toDouble();
        if (maxGb > 0) {
          double usedGb = _accumulatedUsedBytes / (1024 * 1024 * 1024);
          if (usedGb >= maxGb) {
            _logoutUser('حجم مصرفی حساب شما به پایان رسیده است.');
            return;
          }
        }

        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  void _calculateAndSaveTraffic(int currentUpload, int currentDownload) async {
    if (!_isConnected || _userData == null) return;

    int uploadDelta = 0;
    int downloadDelta = 0;

    if (_lastSessionUpload > 0 && currentUpload >= _lastSessionUpload) {
      uploadDelta = currentUpload - _lastSessionUpload;
    }
    if (_lastSessionDownload > 0 && currentDownload >= _lastSessionDownload) {
      downloadDelta = currentDownload - _lastSessionDownload;
    }

    _lastSessionUpload = currentUpload;
    _lastSessionDownload = currentDownload;

    int totalDelta = uploadDelta + downloadDelta;

    if (totalDelta > 0) {
      _accumulatedUsedBytes += totalDelta;
      _userData!['used_bytes'] = _accumulatedUsedBytes;

      if (mounted) setState(() {});

      try {
        await http.patch(
          Uri.parse("${firebaseUrl}users/${widget.userId}.json"),
          body: json.encode({"used_bytes": _accumulatedUsedBytes}),
        );
      } catch (_) {}

      double maxGb = (_userData!['max_volume_gb'] ?? 0).toDouble();
      if (maxGb > 0 && (_accumulatedUsedBytes / (1024 * 1024 * 1024)) >= maxGb) {
        _logoutUser('حجم مجاز شما به پایان رسید.');
      }
    }
  }

  // متد کامل خروج کاربر و حذف نشست از فایربیس
  void _logoutUser(String reason) async {
    _userCheckTimer?.cancel();
    try {
      await flutterV2ray.stopV2Ray();
    } catch (_) {}

    // پاک کردن این دستگاه از گره active_sessions فایربیس
    if (_deviceId != null) {
      try {
        await http.delete(
          Uri.parse("${firebaseUrl}users/${widget.userId}/active_sessions/$_deviceId.json"),
        );
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('device_id');

    if (mounted) {
      if (reason.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reason), backgroundColor: Colors.redAccent),
        );
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

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
          if (_configs.isNotEmpty && _selectedConfigId == null) {
            _selectedConfigId = _configs[0]['id']?.toString() ?? _configs[0]['name'];
          }
          _isLoading = false;
        });

        _testAllPings();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _cleanUrl(String rawUrl) => rawUrl.trim();

  Future<void> _testAllPings() async {
    if (_isTestingAllPings) return;
    setState(() => _isTestingAllPings = true);

    for (var item in _configs) {
      await _testSinglePing(item);
    }

    if (mounted) {
      _configs.sort((a, b) {
        final String idA = a['id']?.toString() ?? a['name'];
        final String idB = b['id']?.toString() ?? b['name'];
        final int pingA = _pings[idA] ?? 999999;
        final int pingB = _pings[idB] ?? 999999;

        final int validPingA = pingA > 0 ? pingA : 999999;
        final int validPingB = pingB > 0 ? pingB : 999999;

        return validPingA.compareTo(validPingB);
      });

      setState(() => _isTestingAllPings = false);
    }
  }

  Future<void> _testSinglePing(Map<String, dynamic> item) async {
    final String rawUrl = (item['config'] ?? '').toString();
    final String configId = item['id']?.toString() ?? item['name'];

    if (rawUrl.isEmpty) return;

    if (mounted) setState(() => _pingLoading[configId] = true);

    try {
      final configUrl = _cleanUrl(rawUrl);
      V2RayURL parser = FlutterV2ray.parseFromURL(configUrl);

      int delay = await flutterV2ray.getServerDelay(
        config: parser.getFullConfiguration(),
        url: 'http://www.gstatic.com/generate_204',
      ).timeout(const Duration(seconds: 3), onTimeout: () => -1);

      if (delay <= 0) {
        final stopwatch = Stopwatch()..start();
        final int targetPort = int.tryParse(parser.port.toString()) ?? 443;
        try {
          final socket = await Socket.connect(
            parser.address,
            targetPort,
            timeout: const Duration(seconds: 2),
          );
          stopwatch.stop();
          delay = stopwatch.elapsedMilliseconds;
          await socket.close();
        } catch (_) {
          delay = -1;
        }
      }

      if (mounted) {
        setState(() {
          _pings[configId] = delay;
          _pingLoading[configId] = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pings[configId] = -1;
          _pingLoading[configId] = false;
        });
      }
    }
  }

  Future<void> _toggleMainConnection() async {
    if (_isConnectingProcess || _selectedConfigId == null) return;

    if (_isConnected) {
      setState(() => _isConnectingProcess = true);
      try {
        await flutterV2ray.stopV2Ray();
      } catch (_) {}
      setState(() {
        _isConnected = false;
        _isConnectingProcess = false;
      });
      return;
    }

    final selectedConfig = _configs.firstWhere(
      (c) => (c['id']?.toString() ?? c['name']) == _selectedConfigId,
      orElse: () => null,
    );

    if (selectedConfig == null) return;

    final String rawUrl = (selectedConfig['config'] ?? '').toString();
    setState(() => _isConnectingProcess = true);

    try {
      final bool hasPermission = await flutterV2ray.requestPermission();
      if (hasPermission) {
        final configUrl = _cleanUrl(rawUrl);
        V2RayURL parser = FlutterV2ray.parseFromURL(configUrl);

        await flutterV2ray.startV2Ray(
          remark: selectedConfig['name'] ?? parser.remark,
          config: parser.getFullConfiguration(),
          proxyOnly: false,
        );
      } else {
        setState(() => _isConnectingProcess = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در اتصال: $e'), backgroundColor: Colors.redAccent),
      );
      setState(() => _isConnectingProcess = false);
    }
  }

  String _getProtocolType(String url) {
    if (url.startsWith('vless://')) return 'VLESS';
    if (url.startsWith('vmess://')) return 'VMESS';
    if (url.startsWith('trojan://')) return 'TROJAN';
    if (url.startsWith('shadowsocks://') || url.startsWith('ss://')) return 'SS';
    return 'XRAY';
  }

  Widget _buildAnnouncementBanner() {
    if (_announcementData == null || _announcementData!['enabled'] != true) {
      return const SizedBox.shrink();
    }

    final String text = _announcementData!['text'] ?? '';
    final String imageUrl = _announcementData!['image_url'] ?? '';
    final String targetUrl = _announcementData!['target_url'] ?? '';

    return GestureDetector(
      onTap: () async {
        if (targetUrl.isNotEmpty) {
          final uri = Uri.parse(targetUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2E354F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            if (imageUrl.isNotEmpty && text.isNotEmpty) const SizedBox(height: 8),
            if (text.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.campaign, color: Color(0xFFA78BFA), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (targetUrl.isNotEmpty)
                    const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double usedGb = _accumulatedUsedBytes / (1024 * 1024 * 1024);
    double maxGb = (_userData?['max_volume_gb'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xray Ultra', style: TextStyle(fontSize: 18, color: Colors.white70)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF222536),
                  title: const Text('خروج از حساب'),
                  content: const Text('آیا می‌خواهید از حساب کاربری خود خارج شوید؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _logoutUser('');
                      },
                      child: const Text('خروج', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAnnouncementBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B9BB4)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: _configs.length,
                    itemBuilder: (context, index) {
                      final item = _configs[index];
                      final String configId = item['id']?.toString() ?? item['name'];
                      final String configUrl = (item['config'] ?? '').toString();
                      final String protocol = _getProtocolType(configUrl);
                      final bool isSelected = (_selectedConfigId == configId);
                      final int ping = _pings[configId] ?? 0;
                      final bool isPingLoading = _pingLoading[configId] ?? false;

                      return GestureDetector(
                        onTap: () {
                          if (_isConnected) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('لطفاً ابتدا اتصال فعلی را قطع کنید.'),
                                backgroundColor: Colors.orangeAccent,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _selectedConfigId = configId;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2A3045) : const Color(0xFF232738),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: const Color(0xFF7A93D1), width: 1.5) : null,
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  decoration: const BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Text(
                                      protocol,
                                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Text(
                                      item['name'] ?? 'سرور Xray',
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPingLoading
                                              ? Colors.white10
                                              : (ping > 0 ? const Color(0xFF2E5A3C) : const Color(0xFF613137)),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          isPingLoading ? '...' : (ping > 0 ? '${ping}ms' : '-1ms'),
                                          style: TextStyle(
                                            color: isPingLoading
                                                ? Colors.white54
                                                : (ping > 0 ? const Color(0xFF81C784) : const Color(0xFFE57373)),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
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
                      );
                    },
                  ),
          ),
          Container(
            color: const Color(0xFF28314A),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: _isConnected ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isConnected ? 'CONNECTED' : 'DISCONNECTED',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 45.0),
        child: FloatingActionButton(
          backgroundColor: _isConnected ? const Color(0xFF4CAF50) : const Color(0xFFB0BEC5),
          onPressed: _toggleMainConnection,
          child: _isConnectingProcess
              ? const CircularProgressIndicator(color: Colors.white)
              : Icon(Icons.power_settings_new, color: _isConnected ? Colors.white : const Color(0xFF1B1D29), size: 30),
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF151821),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _fetchConfigs,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download_outlined, color: Colors.white54, size: 20),
                  SizedBox(height: 2),
                  Text('Get Config', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'حجم: ${usedGb.toStringAsFixed(2)} / ${maxGb > 0 ? maxGb.toStringAsFixed(1) : "∞"} GB',
                  style: TextStyle(color: Colors.white.withOpacity(0.87), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'اعتبار: $_remainingTimeText',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
            InkWell(
              onTap: _isTestingAllPings ? null : _testAllPings,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, color: _isTestingAllPings ? Colors.amber : Colors.white54, size: 20),
                  const SizedBox(height: 2),
                  Text(_isTestingAllPings ? 'Testing...' : 'Test', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
