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
  runApp(const XrayUltraApp());
}

class XrayUltraApp extends StatelessWidget {
  const XrayUltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xray Ultra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1B1D29), // گرانیت تیره
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6), // بنفش
          secondary: Color(0xFF00A86B), // سبز یاقوتی
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
      body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
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

  // آدرس هاست و API شما
  static const String apiBase = "https://socialmedia-ad.ir/api.php";

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final val = value.trim().toLowerCase();
      return val == 'true' || val == '1';
    }
    return false;
  }

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
      final res = await http.get(Uri.parse("$apiBase?action=get_users"));
      if (res.statusCode == 200 && res.body != 'null') {
        final dynamic decodedData = json.decode(res.body);
        String? foundUserId;
        Map<String, dynamic>? rawUserData;

        if (decodedData is List) {
          for (int i = 0; i < decodedData.length; i++) {
            final item = decodedData[i];
            if (item != null && item is Map) {
              if (item['username']?.toString().trim() == username &&
                  item['password']?.toString().trim() == password) {
                foundUserId = item['id']?.toString() ?? i.toString();
                rawUserData = Map<String, dynamic>.from(item);
                break;
              }
            }
          }
        } else if (decodedData is Map) {
          decodedData.forEach((key, value) {
            if (value != null && value is Map) {
              if (value['username']?.toString().trim() == username &&
                  value['password']?.toString().trim() == password) {
                foundUserId = key.toString();
                rawUserData = Map<String, dynamic>.from(value);
              }
            }
          });
        }

        if (foundUserId != null && rawUserData != null) {
          final Map<String, dynamic> currentUserData = Map<String, dynamic>.from(rawUserData);

          if (!_isTruthy(currentUserData['active'])) {
            _showError('حساب کاربری شما غیرفعال شده است.');
            setState(() => _isLoading = false);
            return;
          }

          final String deviceId = await _getDeviceId();
          final int maxDevices = int.tryParse(currentUserData['max_devices']?.toString() ?? '1') ?? 1;

          Map<String, dynamic> activeSessions = {};
          if (currentUserData['active_sessions'] != null && currentUserData['active_sessions'] is Map) {
            activeSessions = Map<String, dynamic>.from(currentUserData['active_sessions']);
          }

          if (!activeSessions.containsKey(deviceId) && activeSessions.length >= maxDevices) {
            _showError('محدودیت تعداد کاربر آنلاین! این اکانت در دستگاه دیگری فعال است.');
            setState(() => _isLoading = false);
            return;
          }

          final nowIso = DateTime.now().toIso8601String();
          activeSessions[deviceId] = {
            "login_at": activeSessions[deviceId]?['login_at'] ?? nowIso,
            "last_seen": nowIso,
          };
          currentUserData['active_sessions'] = activeSessions;

          await http.post(
            Uri.parse("$apiBase?action=save_user"),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(currentUserData),
          );

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', foundUserId);
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
              const Icon(Icons.bolt_rounded, size: 80, color: Color(0xFF00A86B)),
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
                    backgroundColor: const Color(0xFF8B5CF6),
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

class ConfigModel {
  final String id;
  final String name;
  final String configUrl;
  int ping;
  bool isPingLoading;

  ConfigModel({
    required this.id,
    required this.name,
    required this.configUrl,
    this.ping = -1,
    this.isPingLoading = false,
  });
}

class ServerListScreen extends StatefulWidget {
  final String userId;
  const ServerListScreen({super.key, required this.userId});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> with WidgetsBindingObserver {
  static const String apiBase = "https://socialmedia-ad.ir/api.php";

  late FlutterV2ray flutterV2ray;
  List<ConfigModel> _configs = [];
  bool _isLoading = true;
  bool _isTestingAllPings = false;
  bool _isConnectingProcess = false;
  String? _selectedConfigUrl;
  bool _isConnected = false;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _announcementData;

  int _lastSessionUpload = 0;
  int _lastSessionDownload = 0;
  int _accumulatedUsedBytes = 0;
  String _remainingTimeText = '...';

  Timer? _userCheckTimer;
  String? _deviceId;

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final val = value.trim().toLowerCase();
      return val == 'true' || val == '1';
    }
    return false;
  }

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
      final res = await http.get(Uri.parse("$apiBase?action=get_announcement"));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = json.decode(res.body);
        if (mounted) setState(() => _announcementData = data);
      }
    } catch (_) {}
  }

  Future<void> _fetchUserDataAndCheck() async {
    try {
      final res = await http.get(Uri.parse("$apiBase?action=get_user&id=${widget.userId}"));
      if (res.statusCode == 200 && res.body != 'null') {
        final dynamic data = json.decode(res.body);
        if (data == null || data is! Map) return;

        if (!_isTruthy(data['active'])) {
          _logoutUser('حساب کاربری شما غیرفعال شده است.');
          return;
        }

        _userData = Map<String, dynamic>.from(data);
        _accumulatedUsedBytes = int.tryParse(data['used_bytes']?.toString() ?? '0') ?? 0;

        if (data['expire_at'] != null && data['expire_at'].toString().isNotEmpty) {
          try {
            final expireDate = DateTime.parse(data['expire_at'].toString());
            final diff = expireDate.difference(DateTime.now());
            if (diff.isNegative) {
              _logoutUser('اعتبار زمانی حساب شما به پایان رسیده است.');
              return;
            } else {
              if (diff.inDays > 0) {
                _remainingTimeText = '${diff.inDays} روز باقی‌مانده';
              } else {
                _remainingTimeText = '${diff.inHours} ساعت باقی‌مانده';
              }
            }
          } catch (_) {}
        } else {
          _remainingTimeText = 'نامحدود';
        }

        double maxGb = double.tryParse(data['max_volume_gb']?.toString() ?? '0') ?? 0.0;
        if (maxGb > 0 && (_accumulatedUsedBytes / (1024 * 1024 * 1024)) >= maxGb) {
          _logoutUser('حجم مصرفی حساب شما به پایان رسیده است.');
          return;
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
        await http.post(
          Uri.parse("$apiBase?action=save_user"),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(_userData),
        );
      } catch (_) {}
    }
  }

  void _logoutUser(String reason) async {
    _userCheckTimer?.cancel();
    try {
      await flutterV2ray.stopV2Ray();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('device_id');

    if (mounted) {
      if (reason.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason), backgroundColor: Colors.redAccent));
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  // پردازش هوشمند کانفیگ‌های دستی و لینک‌های اشتراک (Subscription)
  Future<void> _fetchConfigs() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse("$apiBase?action=get_configs"));
      if (response.statusCode == 200 && response.body != 'null') {
        final dynamic data = json.decode(response.body);
        List<ConfigModel> parsedList = [];

        List items = [];
        if (data is List) {
          items = data;
        } else if (data is Map) {
          data.forEach((key, value) => items.add(value));
        }

        for (var item in items) {
          if (item == null || item is! Map) continue;
          if (!_isTruthy(item['active'])) continue;

          String rawContent = (item['config'] ?? '').toString().trim();
          String baseName = item['name']?.toString() ?? 'سرور Xray';
          String configId = item['id']?.toString() ?? baseName;

          // بررسی اینکه آیا لینک اشتراک (Subscription URL) است یا مستقیم
          if (rawContent.startsWith('http://') || rawContent.startsWith('https://')) {
            try {
              final subRes = await http.get(Uri.parse(rawContent));
              if (subRes.statusCode == 200) {
                String subBody = subRes.body.trim();
                String decodedString = subBody;
                try {
                  // دیکود کردن محتوای Base64 ساب‌سکریپشن
                  decodedString = utf8.decode(base64.decode(subBody.replaceAll(RegExp(r'\s+'), '')));
                } catch (_) {}

                List<String> lines = decodedString.split('\n');
                int subIndex = 1;
                for (var line in lines) {
                  line = line.trim();
                  if (line.isNotEmpty && (line.startsWith('vless://') || line.startsWith('vmess://') || line.startsWith('trojan://') || line.startsWith('ss://'))) {
                    try {
                      V2RayURL parser = FlutterV2ray.parseFromURL(line);
                      parsedList.add(ConfigModel(
                        id: '${configId}_$subIndex',
                        name: parser.remark.isNotEmpty ? parser.remark : '$baseName ($subIndex)',
                        configUrl: line,
                      ));
                    } catch (_) {
                      parsedList.add(ConfigModel(
                        id: '${configId}_$subIndex',
                        name: '$baseName ($subIndex)',
                        configUrl: line,
                      ));
                    }
                    subIndex++;
                  }
                }
              }
            } catch (_) {}
          } else if (rawContent.isNotEmpty) {
            // کانفیگ مستقیم دستی
            try {
              V2RayURL parser = FlutterV2ray.parseFromURL(rawContent);
              parsedList.add(ConfigModel(
                id: configId,
                name: parser.remark.isNotEmpty ? parser.remark : baseName,
                configUrl: rawContent,
              ));
            } catch (_) {
              parsedList.add(ConfigModel(
                id: configId,
                name: baseName,
                configUrl: rawContent,
              ));
            }
          }
        }

        setState(() {
          _configs = parsedList;
          if (_configs.isNotEmpty && _selectedConfigUrl == null) {
            _selectedConfigUrl = _configs[0].configUrl;
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

  // سیستم تست پینگ حرفه‌ای Real Delay مشابه V2RayNG با آدرس استاندارد generate_204
  Future<void> _testAllPings() async {
    if (_isTestingAllPings) return;
    setState(() => _isTestingAllPings = true);

    for (int i = 0; i < _configs.length; i++) {
      await _testSingleConfigPing(i);
    }

    if (mounted) {
      _configs.sort((a, b) {
        int pA = a.ping > 0 ? a.ping : 999999;
        int pB = b.ping > 0 ? b.ping : 999999;
        return pA.compareTo(pB);
      });
      setState(() => _isTestingAllPings = false);
    }
  }

  Future<void> _testSingleConfigPing(int index) async {
    if (mounted) setState(() => _configs[index].isPingLoading = true);

    int delay = -1;
    try {
      V2RayURL parser = FlutterV2ray.parseFromURL(_configs[index].configUrl);
      // استفاده دقیق از متد Real Delay با آدرس استاندارد تست پینگ V2RayNG
      delay = await flutterV2ray.getServerDelay(
        config: parser.getFullConfiguration(),
        url: 'https://www.gstatic.com/generate_204',
      ).timeout(const Duration(seconds: 5), onTimeout: () => -1);
    } catch (_) {
      delay = -1;
    }

    if (mounted) {
      setState(() {
        _configs[index].ping = delay;
        _configs[index].isPingLoading = false;
      });
    }
  }

  Future<void> _toggleMainConnection() async {
    if (_isConnectingProcess || _selectedConfigUrl == null) return;

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

    final selectedConfigItem = _configs.firstWhere(
      (c) => c.configUrl == _selectedConfigUrl,
      orElse: () => _configs.first,
    );

    setState(() => _isConnectingProcess = true);

    try {
      final bool hasPermission = await flutterV2ray.requestPermission();
      if (hasPermission) {
        V2RayURL parser = FlutterV2ray.parseFromURL(selectedConfigItem.configUrl);
        await flutterV2ray.startV2Ray(
          remark: selectedConfigItem.name,
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
    if (_announcementData == null || !_isTruthy(_announcementData!['enabled'])) {
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
                child: Image.network(imageUrl, width: double.infinity, height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            if (imageUrl.isNotEmpty && text.isNotEmpty) const SizedBox(height: 8),
            if (text.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.campaign, color: Color(0xFFA78BFA), size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
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
    double maxGb = double.tryParse(_userData?['max_volume_gb']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xray Ultra', style: TextStyle(fontSize: 18, color: Colors.white70)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _logoutUser(''),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAnnouncementBanner(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: _configs.length,
                    itemBuilder: (context, index) {
                      final item = _configs[index];
                      final bool isSelected = (_selectedConfigUrl == item.configUrl);
                      final String protocol = _getProtocolType(item.configUrl);

                      return GestureDetector(
                        onTap: () {
                          if (_isConnected) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('لطفاً ابتدا اتصال فعلی را قطع کنید.'), backgroundColor: Colors.orangeAccent),
                            );
                            return;
                          }
                          setState(() => _selectedConfigUrl = item.configUrl);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2A3045) : const Color(0xFF232738),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: const Color(0xFF8B5CF6), width: 1.5) : null,
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  decoration: const BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                                  ),
                                  alignment: Alignment.center,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Text(protocol, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _testSingleConfigPing(index),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: item.isPingLoading
                                            ? Colors.white10
                                            : (item.ping > 0 ? const Color(0xFF00A86B).withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.isPingLoading ? '...' : (item.ping > 0 ? '${item.ping}ms' : '-1ms'),
                                        style: TextStyle(
                                          color: item.isPingLoading
                                              ? Colors.white54
                                              : (item.ping > 0 ? const Color(0xFF00A86B) : Colors.redAccent),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
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
                Icon(Icons.circle, size: 12, color: _isConnected ? const Color(0xFF00A86B) : Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(child: Text(_isConnected ? 'CONNECTED' : 'DISCONNECTED', style: const TextStyle(color: Colors.white70, fontSize: 12))),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 45.0),
        child: FloatingActionButton(
          backgroundColor: _isConnected ? const Color(0xFF00A86B) : const Color(0xFFB0BEC5),
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
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text('اعتبار: $_remainingTimeText', style: const TextStyle(color: Colors.white54, fontSize: 10)),
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
