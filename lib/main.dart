import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUSKY VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF0F172A),
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

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => userId != null && userId.isNotEmpty
            ? ServerListScreen(userId: userId)
            : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
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
  static const String apiBase = 'https://socialmedia-ad.ir/index.php';

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        final model = info.model.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        return model.isNotEmpty ? model : 'ANDROID_${info.id}';
      }

      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.model;
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
      final deviceId = await _getDeviceId();

      final response = await http
          .post(
            Uri.parse('$apiBase?action=user_login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'username': username,
              'password': password,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        _showError('خطا در ارتباط با سرور.');
        return;
      }

      final dynamic data = json.decode(response.body);

      if (data is! Map || data['status'] != 'success') {
        _showError(
          data is Map
              ? (data['message']?.toString() ?? 'نام کاربری یا رمز عبور اشتباه است.')
              : 'پاسخ سرور معتبر نیست.',
        );
        return;
      }

      final userData = data['user'];
      if (userData is! Map || userData['id'] == null) {
        _showError('اطلاعات حساب کاربری از سرور دریافت نشد.');
        return;
      }

      final userId = userData['id'].toString();
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('user_id', userId);
      await prefs.setString('device_id', deviceId);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ServerListScreen(userId: userId),
        ),
      );
    } catch (e) {
      _showError('خطا در برقراری ارتباط: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1E3A8A), Color(0xFF030712)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withOpacity(0.2),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 60,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'HUSKY VPN',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.black,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'نام کاربری',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF0F172A).withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'رمز عبور',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF0F172A).withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  onSubmitted: (_) => _isLoading ? null : _login(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF38BDF8).withOpacity(0.5),
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'ورود به حساب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
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

class _ServerListScreenState extends State<ServerListScreen>
    with WidgetsBindingObserver {
  static const String apiBase = 'https://socialmedia-ad.ir/index.php';

  late V2ray flutterV2ray;

  List<dynamic> _configs = [];

  final Map<String, int> _pings = {};
  final Map<String, bool> _pingLoading = {};

  bool _isLoading = true;
  bool _isTestingAllPings = false;
  bool _isConnectingProcess = false;
  bool _isConnected = false;
  bool _userWantsDisconnect = false;
  bool _trafficBaselineInitialized = false;
  bool _trafficUpdateInProgress = false;
  bool _logoutInProgress = false;

  String? _selectedConfigId;
  String? _deviceId;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _announcementData;

  int _lastSessionUpload = 0;
  int _lastSessionDownload = 0;
  int _accumulatedUsedBytes = 0;
  int _pendingTrafficBytes = 0;

  String _remainingTimeText = '...';
  String _coreVersion = '26.9.9';

  Timer? _userCheckTimer;

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;

    if (value is String) {
      final text = value.trim().toLowerCase();
      return text == 'true' || text == '1';
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

    if (_deviceId == null || _deviceId!.isEmpty) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final info = await deviceInfo.androidInfo;
          final model = info.model.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
          _deviceId = model.isNotEmpty ? model : 'ANDROID_${info.id}';
        } else if (Platform.isIOS) {
          final info = await deviceInfo.iosInfo;
          _deviceId = info.model;
        }
      } catch (_) {
        _deviceId = 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
      }

      _deviceId ??= 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', _deviceId!);
    }

    if (!mounted) return;

    await _fetchUserDataAndCheck();

    _userCheckTimer?.cancel();
    _userCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (!mounted || _logoutInProgress) return;
        _fetchUserDataAndCheck();
        _fetchAnnouncement();
      },
    );
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

  Future<void> _initV2Ray() async {
    flutterV2ray = V2ray(
      onStatusChanged: (status) {
        if (!mounted) return;

        final state = status.state.toUpperCase();

        if (state == 'CONNECTED') {
          if (!_userWantsDisconnect) {
            setState(() {
              _isConnected = true;
              _isConnectingProcess = false;
            });

            _calculateAndSaveTraffic(status.upload, status.download);
          }
        } else if (state == 'DISCONNECTED' ||
            state == 'STOPPED' ||
            state == 'IDLE') {
          if (_trafficBaselineInitialized) {
            _calculateAndSaveTraffic(status.upload, status.download);
          }

          setState(() {
            _isConnected = false;
            _isConnectingProcess = false;
            _lastSessionUpload = 0;
            _lastSessionDownload = 0;
            _trafficBaselineInitialized = false;
            _userWantsDisconnect = false;
          });

          _flushPendingTraffic();
        }
      },
    );

    try {
      await flutterV2ray.initialize(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );

      final version = await flutterV2ray.getCoreVersion();

      if (mounted && version.isNotEmpty) {
        setState(() => _coreVersion = version);
      }
    } catch (e) {
      debugPrint('V2Ray initialization failed: $e');
    }
  }

  Future<void> _fetchAnnouncement() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBase?action=get_announcement'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 || response.body.trim() == 'null') {
        return;
      }

      final dynamic data = json.decode(response.body);

      if (mounted && data is Map) {
        setState(() {
          _announcementData = Map<String, dynamic>.from(data);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchUserDataAndCheck() async {
    if (_logoutInProgress) return;

    try {
      final response = await http
          .get(Uri.parse('$apiBase?action=get_user&id=${widget.userId}'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 || response.body.trim() == 'null') {
        return;
      }

      final dynamic decoded = json.decode(response.body);
      if (decoded is! Map) return;

      final data = Map<String, dynamic>.from(decoded);

      if (!_isTruthy(data['active'])) {
        final maxGb = double.tryParse(data['max_volume_gb']?.toString() ?? '0') ?? 0;
        final usedBytes = int.tryParse(data['used_bytes']?.toString() ?? '0') ?? 0;
        final maxBytes = maxGb > 0 ? maxGb * 1024 * 1024 * 1024 : 0.0;

        if (maxGb > 0 && usedBytes >= maxBytes) {
          await _logoutUser('حجم مصرفی مجاز شما به پایان رسید.');
        } else {
          await _logoutUser('حساب کاربری شما غیرفعال شده است.');
        }
        return;
      }

      final currentDeviceId = _deviceId;

      if (currentDeviceId != null && currentDeviceId.isNotEmpty) {
        Map<String, dynamic> activeSessions = {};

        if (data['active_sessions'] is Map) {
          activeSessions = Map<String, dynamic>.from(
            data['active_sessions'] as Map,
          );
        }

        if (!activeSessions.containsKey(currentDeviceId)) {
          await _logoutUser('دستگاه شما از حساب خارج شد.');
          return;
        }

        final session = activeSessions[currentDeviceId];

        activeSessions[currentDeviceId] = {
          if (session is Map) ...Map<String, dynamic>.from(session),
          'last_seen': DateTime.now().toIso8601String(),
        };

        data['active_sessions'] = activeSessions;

        await http
            .post(
              Uri.parse('$apiBase?action=update_traffic'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'id': widget.userId,
                'device_id': currentDeviceId,
                'active_sessions': {
                  currentDeviceId: activeSessions[currentDeviceId],
                },
              }),
            )
            .timeout(const Duration(seconds: 15));
      }

      _userData = data;

      final serverUsedBytes = int.tryParse(data['used_bytes']?.toString() ?? '0') ?? 0;

      if (_accumulatedUsedBytes < serverUsedBytes) {
        _accumulatedUsedBytes = serverUsedBytes;
      }

      final expireAt = data['expire_at']?.toString() ?? '';

      if (expireAt.isNotEmpty) {
        try {
          final expireDate = DateTime.parse(expireAt);
          final diff = expireDate.difference(DateTime.now());

          if (diff.isNegative) {
            await _logoutUser('اعتبار زمانی حساب شما به پایان رسیده است.');
            return;
          } else if (diff.inDays > 0) {
            _remainingTimeText = '${diff.inDays} روز باقی‌مانده';
          } else if (diff.inHours > 0) {
            _remainingTimeText = '${diff.inHours} ساعت باقی‌مانده';
          } else {
            _remainingTimeText = '${diff.inMinutes} دقیقه باقی‌مانده';
          }
        } catch (_) {
          _remainingTimeText = 'نامشخص';
        }
      } else {
        _remainingTimeText = 'نامحدود';
      }

      final maxGb = double.tryParse(data['max_volume_gb']?.toString() ?? '0') ?? 0;

      if (maxGb > 0) {
        final usedGb = _accumulatedUsedBytes / (1024 * 1024 * 1024);

        if (usedGb >= maxGb) {
          await _logoutUser('حجم مصرفی مجاز شما به پایان رسید.');
          return;
        }
      }

      if (mounted) setState(() {});

      if (_pendingTrafficBytes > 0) {
        _flushPendingTraffic();
      }
    } catch (e) {
      debugPrint('User check failed: $e');
    }
  }

  Future<void> _calculateAndSaveTraffic(
    int currentUpload,
    int currentDownload,
  ) async {
    if (_userData == null) return;

    final maxGb = double.tryParse(_userData!['max_volume_gb']?.toString() ?? '0') ?? 0;

    if (maxGb <= 0) return;

    if (!_trafficBaselineInitialized) {
      _lastSessionUpload = currentUpload;
      _lastSessionDownload = currentDownload;
      _trafficBaselineInitialized = true;
      return;
    }

    if (currentDownload < _lastSessionDownload ||
        currentUpload < _lastSessionUpload) {
      _lastSessionDownload = currentDownload;
      _lastSessionUpload = currentUpload;
      return;
    }

    final uploadDelta = currentUpload - _lastSessionUpload;
    final downloadDelta = currentDownload - _lastSessionDownload;

    _lastSessionUpload = currentUpload;
    _lastSessionDownload = currentDownload;

    final totalDelta = uploadDelta + downloadDelta;

    if (totalDelta > 0) {
      _pendingTrafficBytes += totalDelta;
      await _flushPendingTraffic();
    }
  }

  Future<void> _flushPendingTraffic() async {
    if (_trafficUpdateInProgress || _pendingTrafficBytes <= 0) return;
    if (_userData == null) return;

    final maxGb = double.tryParse(_userData!['max_volume_gb']?.toString() ?? '0') ?? 0;

    if (maxGb <= 0) {
      _pendingTrafficBytes = 0;
      return;
    }

    final batch = _pendingTrafficBytes;
    _trafficUpdateInProgress = true;

    try {
      final response = await http
          .post(
            Uri.parse('$apiBase?action=update_traffic'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'id': widget.userId,
              'device_id': _deviceId,
              'delta_bytes': batch,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic result = json.decode(response.body);

        if (result is Map && result['status'] == 'success') {
          _pendingTrafficBytes = (_pendingTrafficBytes - batch).clamp(0, 1 << 62);

          final serverUsedBytes = int.tryParse(result['used_bytes']?.toString() ?? '') ??
              (_accumulatedUsedBytes + batch);

          _accumulatedUsedBytes = serverUsedBytes;
          _userData!['used_bytes'] = serverUsedBytes;

          if (mounted) setState(() {});

          if (_isTruthy(result['deactivated'])) {
            await _logoutUser('حجم مصرفی مجاز شما به پایان رسید.');
          }
        }
      }
    } catch (e) {
      debugPrint('Traffic update failed: $e');
    } finally {
      _trafficUpdateInProgress = false;

      if (_pendingTrafficBytes > 0 && _isConnected && !_logoutInProgress) {
        _flushPendingTraffic();
      }
    }
  }

  Future<void> _logoutUser(String reason) async {
    if (_logoutInProgress) return;
    _logoutInProgress = true;

    _userCheckTimer?.cancel();

    try {
      await flutterV2ray.stopV2Ray();
    } catch (_) {}

    final currentDeviceId = _deviceId;

    if (currentDeviceId != null && _userData != null) {
      try {
        await http
            .post(
              Uri.parse('$apiBase?action=update_traffic'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'id': widget.userId,
                'device_id': currentDeviceId,
                'remove_device': true,
              }),
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('device_id');

    if (!mounted) return;

    if (reason.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: Colors.redAccent),
      );
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _fetchConfigs() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final response = await http
          .get(Uri.parse('$apiBase?action=get_configs'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200 || response.body.trim() == 'null') {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final dynamic data = json.decode(response.body);
      final List<dynamic> loadedConfigs = [];

      if (data is List) {
        for (final item in data) {
          if (item is Map && _isTruthy(item['active'])) {
            loadedConfigs.add(Map<String, dynamic>.from(item));
          }
        }
      } else if (data is Map) {
        data.forEach((key, value) {
          if (value is Map && _isTruthy(value['active'])) {
            loadedConfigs.add(Map<String, dynamic>.from(value));
          }
        });
      }

      if (!mounted) return;

      setState(() {
        _configs = loadedConfigs;

        if (_configs.isNotEmpty &&
            (_selectedConfigId == null ||
                !_configs.any((item) => _configId(item) == _selectedConfigId))) {
          _selectedConfigId = _configId(_configs.first);
        }

        _isLoading = false;
      });

      _testAllPings();
    } catch (e) {
      debugPrint('Config fetch failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _configId(dynamic item) {
    if (item is! Map) return '';
    return (item['id'] ?? item['name'] ?? '').toString();
  }

  String _cleanUrl(String rawUrl) {
    return rawUrl.trim().replaceFirst('\uFEFF', '').trim();
  }

  Map<String, String> _rawQueryParametersPreservePlus(Uri uri) {
    final result = <String, String>{};
    final raw = uri.hasQuery ? uri.query : '';

    if (raw.isEmpty) return result;

    for (final part in raw.split('&')) {
      if (part.isEmpty) continue;

      final eq = part.indexOf('=');
      final rawKey = eq >= 0 ? part.substring(0, eq) : part;
      final rawValue = eq >= 0 ? part.substring(eq + 1) : '';

      try {
        result[Uri.decodeComponent(rawKey)] = Uri.decodeComponent(rawValue);
      } catch (_) {
        result[rawKey] = rawValue;
      }
    }

    return result;
  }

  String _firstQueryValue(Map<String, String> query, List<String> keys) {
    for (final key in keys) {
      final value = query[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  List<String> _splitCsv(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _baseConfig(Map<String, dynamic> outbound) {
    return {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'listen': '127.0.0.1',
          'port': 10808,
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true},
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls', 'quic'],
          },
        }
      ],
      'outbounds': [outbound],
    };
  }

  /// **موتور جامع و اصلاح‌شده برای پشتیبانی ۱۰۰٪ از تمام کانفیگ‌ها با هر متود و پارامتری**
  String _parseConfigToJson(String rawUrl) {
    var configUrl = _cleanUrl(rawUrl);

    if (configUrl.isEmpty) {
      throw const FormatException('Config is empty');
    }

    // بررسی فرمت JSON مستقیم
    try {
      final decodedJson = json.decode(configUrl);
      if (decodedJson is Map || decodedJson is List) {
        return json.encode(decodedJson);
      }
    } catch (_) {}

    // دیکد کردن Base64 لینک‌های اشتراک
    if (!configUrl.contains('://') &&
        !configUrl.startsWith('{') &&
        !configUrl.startsWith('[')) {
      final compact = configUrl.replaceAll(RegExp(r'\s+'), '');

      if (compact.length >= 8 &&
          RegExp(r'^[A-Za-z0-9+/_=-]+$').hasMatch(compact)) {
        try {
          final normalized = compact.replaceAll('-', '+').replaceAll('_', '/');
          final decoded = utf8
              .decode(base64.decode(base64.normalize(normalized)))
              .trim();

          final lower = decoded.toLowerCase();

          if (decoded.startsWith('{') ||
              decoded.startsWith('[') ||
              lower.contains('://')) {
            configUrl = decoded;
          }
        } catch (_) {}
      }
    }

    try {
      final decodedJson = json.decode(configUrl);
      if (decodedJson is Map || decodedJson is List) {
        return json.encode(decodedJson);
      }
    } catch (_) {}

    final Uri uri;
    try {
      uri = Uri.parse(configUrl);
    } catch (_) {
      try {
        return V2ray.parseFromURL(configUrl).getFullConfiguration();
      } catch (e) {
        throw FormatException('ناتوان در تجزیه لینک کانفیگ: $e');
      }
    }

    final scheme = uri.scheme.toLowerCase();
    final query = _rawQueryParametersPreservePlus(uri);
    final network = _firstQueryValue(query, ['type', 'network']).toLowerCase();
    final security = _firstQueryValue(query, ['security']).toLowerCase();

    final server = uri.host;
    final port = uri.hasPort ? uri.port : 443;
    final userInfo = Uri.decodeComponent(uri.userInfo);

    if (server.isEmpty || userInfo.isEmpty) {
      try {
        return V2ray.parseFromURL(configUrl).getFullConfiguration();
      } catch (_) {
        throw const FormatException('کانفیگ فاقد آدرس سرور یا شناسه کاربری است.');
      }
    }

    // مدیریت اختصاصی کانفیگ‌های وب‌سوکت (WS) جهت رفع خطای خالی بودن security
    if (network == 'ws' || network == 'websocket' || network.isEmpty) {
      final transportHost = _firstQueryValue(query, ['host', 'authority']);
      final path = _firstQueryValue(query, ['path']);
      final sni = _firstQueryValue(query, ['sni', 'serverName']);
      final fingerprint = _firstQueryValue(query, ['fp', 'fingerprint']);
      final alpn = _firstQueryValue(query, ['alpn']);

      final outbound = <String, dynamic>{
        'protocol': scheme == 'trojan' ? 'trojan' : (scheme == 'vmess' ? 'vmess' : 'vless'),
        'settings': <String, dynamic>{},
        'streamSettings': <String, dynamic>{
          'network': network.isEmpty ? 'tcp' : 'ws',
          'security': security.isEmpty ? 'none' : security,
        },
      };

      if (network == 'ws' || network == 'websocket') {
        (outbound['streamSettings'] as Map<String, dynamic>)['wsSettings'] = <String, dynamic>{
          'path': path.isEmpty ? '/' : path,
          if (transportHost.isNotEmpty) 'headers': <String, dynamic>{'Host': transportHost},
        };
      }

      final settings = outbound['settings'] as Map<String, dynamic>;
      if (scheme == 'trojan') {
        settings['servers'] = [
          {'address': server, 'port': port, 'password': userInfo},
        ];
      } else if (scheme == 'vmess') {
        settings['vnext'] = [
          {
            'address': server,
            'port': port,
            'users': [
              {
                'id': userInfo,
                'alterId': int.tryParse(query['aid'] ?? '0') ?? 0,
                'security': query['scy'] ?? 'auto',
              }
            ],
          }
        ];
      } else {
        settings['vnext'] = [
          {
            'address': server,
            'port': port,
            'users': [
              {
                'id': userInfo,
                'encryption': _firstQueryValue(query, ['encryption']).isEmpty
                    ? 'none'
                    : _firstQueryValue(query, ['encryption']),
                if (_firstQueryValue(query, ['flow']).isNotEmpty)
                  'flow': _firstQueryValue(query, ['flow']),
              },
            ],
          },
        ];
      }

      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      if (security == 'tls') {
        stream['tlsSettings'] = <String, dynamic>{
          'serverName': sni.isNotEmpty ? sni : (transportHost.isNotEmpty ? transportHost : server),
          if (fingerprint.isNotEmpty) 'fingerprint': fingerprint,
          if (alpn.isNotEmpty) 'alpn': _splitCsv(alpn),
        };
      } else if (security == 'reality') {
        stream['realitySettings'] = <String, dynamic>{
          'show': false,
          'serverName': sni.isNotEmpty ? sni : (transportHost.isNotEmpty ? transportHost : server),
          'fingerprint': fingerprint.isNotEmpty ? fingerprint : 'chrome',
          'publicKey': _firstQueryValue(query, ['pbk', 'publicKey']),
          'shortId': _firstQueryValue(query, ['sid', 'shortId']),
          'spiderX': _firstQueryValue(query, ['spx', 'spiderX']),
        };
      }

      return json.encode(_baseConfig(outbound));
    }

    // استفاده از پکیج رسمی برای بقیه پروتکل‌ها و متودها به عنوان پایگاه مطمئن
    try {
      final parser = V2ray.parseFromURL(configUrl);
      return parser.getFullConfiguration();
    } catch (_) {
      throw const FormatException('ساختار لینک کانفیگ پشتیبانی نمی‌شود.');
    }
  }

  Future<void> _testAllPings() async {
    if (_isTestingAllPings || _configs.isEmpty) return;

    if (mounted) {
      setState(() {
        _isTestingAllPings = true;
        for (final item in _configs) {
          final id = _configId(item);
          if (id.isNotEmpty) {
            _pingLoading[id] = true;
            _pings[id] = -1;
          }
        }
      });
    }

    await Future.wait(_configs.map(_testServerDelay));

    if (!mounted) return;

    setState(() {
      _configs.sort((a, b) {
        final pingA = _pings[_configId(a)] ?? -1;
        final pingB = _pings[_configId(b)] ?? -1;
        final validA = pingA > 0 ? pingA : 1 << 30;
        final validB = pingB > 0 ? pingB : 1 << 30;
        return validA.compareTo(validB);
      });
      _isTestingAllPings = false;
    });
  }

  Future<void> _testServerDelay(dynamic item) async {
    if (item is! Map) return;

    final rawUrl = (item['config'] ?? '').toString().trim();
    final configId = _configId(item);

    if (rawUrl.isEmpty || configId.isEmpty) {
      if (mounted && configId.isNotEmpty) {
        setState(() {
          _pings[configId] = -1;
          _pingLoading[configId] = false;
        });
      }
      return;
    }

    var delay = -1;

    try {
      final configJson = _parseConfigToJson(rawUrl);
      delay = await flutterV2ray
          .getServerDelay(config: configJson)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Ping failed for $configId: $e');
    }

    if (!mounted) return;

    setState(() {
      _pings[configId] = delay > 0 ? delay : -1;
      _pingLoading[configId] = false;
    });
  }

  Future<void> _toggleMainConnection() async {
    if (_isConnectingProcess) return;

    if (_isConnected) {
      setState(() {
        _userWantsDisconnect = true;
        _isConnected = false;
        _isConnectingProcess = true;
      });

      try {
        await flutterV2ray.stopV2Ray();
      } catch (_) {}

      await _flushPendingTraffic();

      if (mounted) {
        setState(() {
          _isConnectingProcess = false;
          _lastSessionUpload = 0;
          _lastSessionDownload = 0;
          _trafficBaselineInitialized = false;
        });
      }

      return;
    }

    if (_configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هیچ سروری در دسترس نیست.')),
      );
      return;
    }

    if (_selectedConfigId == null ||
        !_configs.any((item) => _configId(item) == _selectedConfigId)) {
      _selectedConfigId = _configId(_configs.first);
    }

    final selectedConfig = _configs.firstWhere(
      (item) => _configId(item) == _selectedConfigId,
      orElse: () => _configs.first,
    );

    final rawUrl = (selectedConfig['config'] ?? '').toString().trim();

    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('آدرس کانفیگ این سرور خالی است.')),
      );
      return;
    }

    setState(() {
      _userWantsDisconnect = false;
      _isConnectingProcess = true;
    });

    try {
      final hasPermission = await flutterV2ray.requestPermission();

      if (!hasPermission) {
        if (mounted) setState(() => _isConnectingProcess = false);
        return;
      }

      final configJson = _parseConfigToJson(rawUrl);

      var remark = (selectedConfig['name'] ?? 'Xray Server').toString();

      try {
        final parser = V2ray.parseFromURL(_cleanUrl(rawUrl));
        if (parser.remark.isNotEmpty) {
          remark = parser.remark;
        }
      } catch (_) {}

      await flutterV2ray.startV2Ray(
        remark: remark,
        config: configJson,
        proxyOnly: false,
      );

      if (mounted && !_userWantsDisconnect) {
        setState(() {
          _isConnected = true;
          _isConnectingProcess = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در اتصال: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );

      setState(() {
        _isConnectingProcess = false;
        _isConnected = false;
      });
    }
  }

  String _getProtocolType(String url) {
    final value = url.trim().toLowerCase();

    if (value.startsWith('vless://')) return 'VLESS';
    if (value.startsWith('vmess://')) return 'VMESS';
    if (value.startsWith('trojan://')) return 'TROJAN';
    if (value.startsWith('ss://') || value.startsWith('shadowsocks://')) return 'SS';
    if (value.startsWith('socks://')) return 'SOCKS';
    if (value.startsWith('hysteria2://') || value.startsWith('hy2://')) return 'HY2';
    if (value.startsWith('hysteria://')) return 'HYSTERIA';
    if (value.startsWith('tuic://')) return 'TUIC';
    if (value.startsWith('wireguard://')) return 'WG';
    if (value.startsWith('anytls://')) return 'ANYTLS';

    return 'XRAY';
  }

  Widget _buildAnnouncementBanner() {
    if (_announcementData == null || !_isTruthy(_announcementData!['enabled'])) {
      return const SizedBox.shrink();
    }

    final text = (_announcementData!['text'] ?? '').toString();
    final imageUrl = (_announcementData!['image_url'] ?? '').toString();
    final targetUrl = (_announcementData!['target_url'] ?? '').toString();

    return GestureDetector(
      onTap: () async {
        if (targetUrl.isEmpty) return;
        final uri = Uri.tryParse(targetUrl);
        if (uri == null) return;
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (imageUrl.isNotEmpty && text.isNotEmpty) const SizedBox(height: 8),
            if (text.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.campaign_rounded, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (targetUrl.isNotEmpty)
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 12),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxGb = double.tryParse(_userData?['max_volume_gb']?.toString() ?? '0') ?? 0;
    final usedGb = maxGb > 0 ? _accumulatedUsedBytes / (1024 * 1024 * 1024) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.3,
            colors: [Color(0xFF1E3A8A), Color(0xFF020617)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // هدر بالای صفحه (SkyVPN Style)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'HUSKY VPN',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.black, letterSpacing: 1.5, color: Colors.white),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                          ),
                          child: Text(
                            'Core: $_coreVersion',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                backgroundColor: const Color(0xFF0F172A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('خروج از حساب', style: TextStyle(color: Colors.white)),
                                content: const Text('آیا می‌خواهید از حساب کاربری خود خارج شوید؟', style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      _logoutUser('');
                                    },
                                    child: const Text('خروج', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // بنر اعلان
              _buildAnnouncementBanner(),

              // بخش دکمه مرکزی اتصال و وضعیت (SkyVPN Luxury Center)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                            boxShadow: [
                              BoxShadow(
                                color: (_isConnected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected ? 'CONNECTED' : 'DISCONNECTED',
                          style: TextStyle(
                            color: _isConnected ? Colors.greenAccent : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // دکمه پاور نئونی بزرگ
                    GestureDetector(
                      onTap: _toggleMainConnection,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isConnected
                                ? [const Color(0xFF059669), const Color(0xFF10B981)]
                                : [const Color(0xFF1E3A8A), const Color(0xFF0284C7)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isConnected ? const Color(0xFF10B981) : const Color(0xFF38BDF8)).withOpacity(0.5),
                              blurRadius: 35,
                              spreadRadius: 5,
                            ),
                          ],
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: Center(
                          child: _isConnectingProcess
                              ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : Icon(
                                  Icons.power_settings_new_rounded,
                                  size: 50,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // لیست سرورهای شیشه‌ای
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                    : _configs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.white38),
                                const SizedBox(height: 12),
                                const Text('سروری دریافت نشد.', style: TextStyle(color: Colors.white70)),
                                const SizedBox(height: 8),
                                TextButton(onPressed: _fetchConfigs, child: const Text('تلاش دوباره')),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            itemCount: _configs.length,
                            itemBuilder: (context, index) {
                              final item = _configs[index];
                              final configId = _configId(item);
                              final configUrl = (item['config'] ?? '').toString();
                              final protocol = _getProtocolType(configUrl);
                              final isSelected = _selectedConfigId == configId;
                              final ping = _pings[configId] ?? -1;
                              final pingLoading = _pingLoading[configId] ?? false;

                              return GestureDetector(
                                onTap: () {
                                  if (_isConnected) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('لطفاً ابتدا اتصال فعلی را قطع کنید.'),
                                        backgroundColor: Colors.orangeAccent,
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
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF1E3A8A).withOpacity(0.4)
                                        : const Color(0xFF0F172A).withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.08),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF38BDF8).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          protocol,
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          (item['name'] ?? 'سرور Xray').toString(),
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: pingLoading
                                              ? Colors.white10
                                              : (ping > 0 ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          pingLoading ? '...' : (ping > 0 ? '${ping}ms' : '-1ms'),
                                          style: TextStyle(
                                            color: pingLoading ? Colors.white54 : (ping > 0 ? Colors.greenAccent : Colors.redAccent),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              // نوار ناوبری پایین صفحه (Bottom Navigation Bar)
              Container(
                color: const Color(0xFF030712).withOpacity(0.95),
                height: 65,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _fetchConfigs,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.file_download_outlined, color: Color(0xFF38BDF8), size: 20),
                          SizedBox(height: 2),
                          Text('Get Config', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          maxGb > 0
                              ? 'حجم: ${usedGb.toStringAsFixed(2)} / ${maxGb.toStringAsFixed(1)} GB'
                              : 'حجم: نامحدود',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'اعتبار: $_remainingTimeText',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _isTestingAllPings ? null : _testAllPings,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, color: _isTestingAllPings ? Colors.amber : const Color(0xFF38BDF8), size: 20),
                          SizedBox(height: 2),
                          Text(_isTestingAllPings ? 'Testing...' : 'Test', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
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
  }
}
