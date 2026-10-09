import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
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

  static const String apiBase = "https://socialmedia-ad.ir/index.php";

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
      final deviceId = await _getDeviceId();
      final res = await http.post(
        Uri.parse("$apiBase?action=user_login"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "username": username,
          "password": password,
          "device_id": deviceId,
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success') {
          final userData = data['user'];
          final String userId = userData['id'].toString();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', userId);
          await prefs.setString('device_id', deviceId);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => ServerListScreen(userId: userId)),
            );
          }
        } else {
          _showError(data['message'] ?? 'نام کاربری یا رمز عبور اشتباه است.');
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
  static const String apiBase = "https://socialmedia-ad.ir/index.php";

  late V2ray flutterV2ray;
  List<dynamic> _configs = [];
  final Map<String, int> _pings = {};
  final Map<String, bool> _pingLoading = {};

  bool _isLoading = true;
  bool _isTestingAllPings = false;
  bool _isConnectingProcess = false;
  String? _selectedConfigId;
  bool _isConnected = false;
  bool _userWantsDisconnect = false;

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _announcementData;

  int _lastSessionUpload = 0;
  int _lastSessionDownload = 0;
  int _accumulatedUsedBytes = 0;
  int _pendingTrafficBytes = 0;
  bool _trafficBaselineInitialized = false;
  bool _trafficUpdateInProgress = false;
  String _remainingTimeText = '...';
  String _coreVersion = '26.9.9';

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
    _userCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
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
    flutterV2ray = V2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        final stateUpper = status.state.toUpperCase();

        if (stateUpper == 'CONNECTED') {
          if (!_userWantsDisconnect) {
            setState(() {
              _isConnected = true;
              _isConnectingProcess = false;
            });
            _calculateAndSaveTraffic(status.upload, status.download);
          }
        } else if (stateUpper == 'DISCONNECTED' || stateUpper == 'STOPPED' || stateUpper == 'IDLE') {
          // آخرین مقدار ترافیک قبل از قطع را هم ثبت کن تا چند مگابایت
          // انتهایی به دلیل تغییر state از دست نرود.
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
        }
      },
    );

    await flutterV2ray.initialize(
      notificationIconResourceType: "mipmap",
      notificationIconResourceName: "ic_launcher",
    );
    
    try {
      String version = await flutterV2ray.getCoreVersion();
      if (mounted && version.isNotEmpty) {
        setState(() {
          _coreVersion = version;
        });
      }
    } catch (_) {}
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
          // اگر حساب به علت رسیدن به سقف حجم غیرفعال شده باشد، پیام مخصوص حجم را نشان بده.
          // در غیر این صورت غیرفعال‌سازی از سمت ادمین/پنل بوده است.
          final maxGb = double.tryParse(data['max_volume_gb']?.toString() ?? '0') ?? 0.0;
          final usedBytes = int.tryParse(data['used_bytes']?.toString() ?? '0') ?? 0;
          final maxBytes = maxGb > 0 ? (maxGb * 1024 * 1024 * 1024) : 0.0;

          if (maxGb > 0 && usedBytes >= maxBytes) {
            _logoutUser('حجم مصرفی مجاز شما به پایان رسید.');
          } else {
            _logoutUser('حساب کاربری شما غیرفعال شده است.');
          }
          return;
        }

        final currentDeviceId = _deviceId;
        if (currentDeviceId != null) {
          Map<String, dynamic> activeSessions = {};
          if (data['active_sessions'] != null && data['active_sessions'] is Map) {
            activeSessions = Map<String, dynamic>.from(data['active_sessions']);
          }

          if (!activeSessions.containsKey(currentDeviceId)) {
            _logoutUser('دستگاه شما توسط ادمین از حساب خارج شد.');
            return;
          } else {
            final session = activeSessions[currentDeviceId];
            activeSessions[currentDeviceId] = {
              if (session is Map) ...session,
              "last_seen": DateTime.now().toIso8601String(),
            };
            data['active_sessions'] = activeSessions;
            
            await http.post(
              Uri.parse("$apiBase?action=update_traffic"),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                "id": widget.userId,
                "device_id": currentDeviceId,
                "active_sessions": {
                  currentDeviceId: {
                    if (activeSessions[currentDeviceId] is Map)
                      ...Map<String, dynamic>.from(activeSessions[currentDeviceId]),
                    "last_seen": DateTime.now().toIso8601String(),
                  }
                },
              }),
            );
          }
        }

        _userData = Map<String, dynamic>.from(data);
        
        int serverUsedBytes = int.tryParse(data['used_bytes']?.toString() ?? '0') ?? 0;
        if (_accumulatedUsedBytes < serverUsedBytes) {
          _accumulatedUsedBytes = serverUsedBytes;
        }

        if (data['expire_at'] != null && data['expire_at'].toString().isNotEmpty) {
          try {
            final expireDate = DateTime.parse(data['expire_at'].toString());
            final now = DateTime.now();
            final diff = expireDate.difference(now);

            if (diff.isNegative) {
              _logoutUser('اعتبار زمانی حساب شما به پایان رسیده است.');
              return;
            } else {
              if (diff.inDays > 0) {
                _remainingTimeText = '${diff.inDays} روز باقی‌‌مانده';
              } else if (diff.inHours > 0) {
                _remainingTimeText = '${diff.inHours} ساعت باقی‌مانده';
              } else {
                _remainingTimeText = '${diff.inMinutes} دقیقه باقی‌مانده';
              }
            }
          } catch (_) {
            _remainingTimeText = 'نامشخص';
          }
        } else {
          _remainingTimeText = 'نامحدود';
        }

        double maxGb = double.tryParse(data['max_volume_gb']?.toString() ?? '0') ?? 0.0;
        if (maxGb > 0) {
          double usedGb = _accumulatedUsedBytes / (1024 * 1024 * 1024);
          if (usedGb >= maxGb) {
            _logoutUser('حجم مصرفی مجاز شما به پایان رسید.');
            return;
          }
        }

        if (mounted) setState(() {});
      } else {
        _logoutUser('حساب کاربری شما یافت نشد.');
      }
    } catch (_) {}
  }

  void _calculateAndSaveTraffic(int currentUpload, int currentDownload) async {
    if (_userData == null) return;

    final maxGb = double.tryParse(
          _userData!['max_volume_gb']?.toString() ?? '0',
        ) ??
        0.0;

    // حساب نامحدود: هیچ شمارش یا ارسال مصرفی در اپ انجام نمی‌شود.
    if (maxGb <= 0) return;

    // اولین status فقط baseline است تا بایت‌های قبل از شروع session
    // دوباره به عنوان مصرف جدید ثبت نشوند.
    if (!_trafficBaselineInitialized) {
      _lastSessionUpload = currentUpload;
      _lastSessionDownload = currentDownload;
      _trafficBaselineInitialized = true;
      return;
    }

    // reset شدن شمارنده‌های core را به عنوان شروع baseline جدید در نظر بگیر.
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
      _flushPendingTraffic();
    }
  }

  Future<void> _flushPendingTraffic() async {
    if (_trafficUpdateInProgress || _pendingTrafficBytes <= 0) return;
    if (_userData == null) return;

    final maxGb = double.tryParse(
          _userData!['max_volume_gb']?.toString() ?? '0',
        ) ??
        0.0;

    if (maxGb <= 0) {
      _pendingTrafficBytes = 0;
      return;
    }

    final batch = _pendingTrafficBytes;
    _trafficUpdateInProgress = true;

    try {
      final res = await http.post(
        Uri.parse("$apiBase?action=update_traffic"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "id": widget.userId,
          "device_id": _deviceId,
          "delta_bytes": batch,
        }),
      );

      if (res.statusCode == 200) {
        final response = json.decode(res.body);

        if (response is Map && response['status'] == 'success') {
          // فقط همان batch موفق را حذف کن؛ اگر حین درخواست batch جدیدی
          // جمع شده باشد، برای درخواست بعدی باقی می‌ماند.
          _pendingTrafficBytes =
              (_pendingTrafficBytes - batch).clamp(0, 1 << 62);

          final serverUsedBytes =
              int.tryParse(response['used_bytes']?.toString() ?? '') ??
                  (_accumulatedUsedBytes + batch);

          _accumulatedUsedBytes = serverUsedBytes;
          _userData!['used_bytes'] = serverUsedBytes;

          if (mounted) setState(() {});

          if (response['deactivated'] == true) {
            _logoutUser('حجم مصرفی مجاز شما به پایان رسید.');
          }
        }
      }
    } catch (_) {
      // batch باقی می‌ماند و callback بعدی آن را دوباره ارسال می‌کند.
    } finally {
      _trafficUpdateInProgress = false;

      // اگر حین درخواست مصرف جدیدی جمع شده، بلافاصله آن را ارسال کن.
      if (_pendingTrafficBytes > 0 && _isConnected) {
        _flushPendingTraffic();
      }
    }
  }

  void _logoutUser(String reason) async {
    _userCheckTimer?.cancel();
    try {
      await flutterV2ray.stopV2Ray();
    } catch (_) {}

    final currentDeviceId = _deviceId;
    if (currentDeviceId != null && _userData != null) {
      try {
        Map<String, dynamic> activeSessions = Map<String, dynamic>.from(_userData!['active_sessions'] ?? {});
        activeSessions.remove(currentDeviceId);
        
        await http.post(
          Uri.parse("$apiBase?action=update_traffic"),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            "id": widget.userId,
            "device_id": currentDeviceId,
            "remove_device": true,
          }),
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
      final response = await http.get(Uri.parse("$apiBase?action=get_configs"));
      if (response.statusCode == 200 && response.body != 'null') {
        final dynamic data = json.decode(response.body);
        List<dynamic> loadedConfigs = [];

        if (data is List) {
          for (var item in data) {
            if (item != null && item is Map && _isTruthy(item['active'])) {
              loadedConfigs.add(item);
            }
          }
        } else if (data is Map) {
          data.forEach((key, value) {
            if (value != null && value is Map && _isTruthy(value['active'])) {
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
        final key = Uri.decodeComponent(rawKey);
        final value = Uri.decodeComponent(rawValue);
        result[key] = value;
      } catch (_) {
        result[rawKey] = rawValue;
      }
    }

    return result;
  }

  void _patchVlessAdvancedSettings(
    Map<String, dynamic> config,
    Map<String, String> rawQuery,
  ) {
    final outbounds = config['outbounds'];
    if (outbounds is! List || outbounds.isEmpty) return;

    final outbound = outbounds.first;
    if (outbound is! Map) return;
    if (outbound['protocol']?.toString().toLowerCase() != 'vless') return;

    final stream = outbound['streamSettings'];
    if (stream is! Map) return;

    final security =
        (rawQuery['security'] ?? stream['security'] ?? '').trim().toLowerCase();

    if (rawQuery['type'] != null && rawQuery['type']!.isNotEmpty) {
      stream['network'] = rawQuery['type'];
    }

    if (security == 'tls') {
      final existing = stream['tlsSettings'];
      final tls = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};

      final sni = rawQuery['sni'] ?? '';
      final fp = rawQuery['fp'] ?? rawQuery['fingerprint'] ?? '';
      final alpn = rawQuery['alpn'] ?? '';

      if (sni.isNotEmpty) tls['serverName'] = sni;
      if (fp.isNotEmpty) tls['fingerprint'] = fp;

      if (alpn.isNotEmpty) {
        tls['alpn'] = alpn
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final ech = (rawQuery['echConfigList'] ?? rawQuery['ech'] ?? '').trim();
      if (ech.isNotEmpty) {
        tls['echConfigList'] = ech;
      }

      final vcn =
          (rawQuery['vcn'] ?? rawQuery['verifyPeerCertByName'] ?? '').trim();
      if (vcn.isNotEmpty) {
        tls['verifyPeerCertByName'] = vcn;
      }

      final pcs =
          (rawQuery['pcs'] ?? rawQuery['pinnedPeerCertSha256'] ?? '').trim();
      if (pcs.isNotEmpty) {
        tls['pinnedPeerCertSha256'] =
            pcs.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      tls.remove('allowInsecure');

      stream['security'] = 'tls';
      stream['tlsSettings'] = tls;
      stream.remove('realitySettings');
    } else if (security == 'reality') {
      final existing = stream['realitySettings'];
      final reality = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};

      final sni = rawQuery['sni'] ?? '';
      final fp = rawQuery['fp'] ?? rawQuery['fingerprint'] ?? '';
      final pbk = rawQuery['pbk'] ?? rawQuery['publicKey'] ?? '';
      final sid = rawQuery['sid'] ?? rawQuery['shortId'] ?? '';
      final spx = rawQuery['spx'] ?? rawQuery['spiderX'] ?? '';
      final pqv = rawQuery['pqv'] ?? rawQuery['mldsa65Verify'] ?? '';

      reality['show'] = false;
      if (sni.isNotEmpty) reality['serverName'] = sni;
      if (fp.isNotEmpty) reality['fingerprint'] = fp;
      if (pbk.isNotEmpty) reality['publicKey'] = pbk;
      if (sid.isNotEmpty) reality['shortId'] = sid;
      if (spx.isNotEmpty) reality['spiderX'] = spx;
      if (pqv.isNotEmpty) reality['mldsa65Verify'] = pqv;

      stream['security'] = 'reality';
      stream['realitySettings'] = reality;
      stream.remove('tlsSettings');
    }
  }

  String _parseConfigToJson(String rawUrl) {
    var configUrl = _cleanUrl(rawUrl).replaceFirst('\uFEFF', '').trim();

    // Some providers return a single share link encoded as base64.
    // Decode only when the result is recognizably a supported share URI or JSON,
    // so ordinary passwords/tokens are not accidentally rewritten.
    if (!configUrl.contains('://') &&
        !configUrl.startsWith('{') &&
        !configUrl.startsWith('[')) {
      final compact = configUrl.replaceAll(RegExp(r'\\s+'), '');
      if (compact.length >= 8 &&
          RegExp(r'^[A-Za-z0-9+/_=-]+$').hasMatch(compact)) {
        try {
          final normalized = compact.replaceAll('-', '+').replaceAll('_', '/');
          final decoded = utf8.decode(base64.decode(base64.normalize(normalized))).trim();
          final lowerDecoded = decoded.toLowerCase();
          if (decoded.startsWith('{') ||
              decoded.startsWith('[') ||
              lowerDecoded.startsWith('vless://') ||
              lowerDecoded.startsWith('vmess://') ||
              lowerDecoded.startsWith('trojan://') ||
              lowerDecoded.startsWith('ss://') ||
              lowerDecoded.startsWith('shadowsocks://') ||
              lowerDecoded.startsWith('socks://') ||
              lowerDecoded.startsWith('hysteria://') ||
              lowerDecoded.startsWith('hysteria2://') ||
              lowerDecoded.startsWith('hy2://')) {
            configUrl = decoded;
          }
        } catch (_) {}
      }
    }

    try {
      final decoded = json.decode(configUrl);
      if (decoded is Map || decoded is List) {
        return json.encode(decoded);
      }
    } catch (_) {}

    Uri uri;
    try {
      uri = Uri.parse(configUrl);
    } catch (_) {
      final parser = V2ray.parseFromURL(configUrl);
      return parser.getFullConfiguration();
    }

    final scheme = uri.scheme.toLowerCase();
    final network =
        (uri.queryParameters['type'] ?? uri.queryParameters['network'] ?? '')
            .toLowerCase();

    if (network == 'xhttp' || network == 'splithttp') {
      final q = _rawQueryParametersPreservePlus(uri);

      final protocol = scheme == 'vmess'
          ? 'vmess'
          : scheme == 'trojan'
              ? 'trojan'
              : 'vless';

      final host = uri.host;
      final port = uri.hasPort ? uri.port : 443;
      final userInfo = Uri.decodeComponent(uri.userInfo);

      if (host.isEmpty || userInfo.isEmpty) {
        throw const FormatException('XHTTP config has no server/ID');
      }

      final serverHost = q['host']?.isNotEmpty == true ? q['host']! : host;
      final path = q['path']?.isNotEmpty == true ? q['path']! : '/';
      final mode = q['mode']?.isNotEmpty == true ? q['mode']! : 'auto';
      final security = (q['security'] ?? 'none').toLowerCase();

      final outbound = <String, dynamic>{
        'protocol': protocol,
        'settings': <String, dynamic>{},
        'streamSettings': <String, dynamic>{
          'network': 'xhttp',
          'security': security,
          'xhttpSettings': <String, dynamic>{
            'path': path,
            'host': serverHost,
            'mode': mode,
          },
        },
      };

      final settings = outbound['settings'] as Map<String, dynamic>;

      if (protocol == 'trojan') {
        settings['servers'] = [
          {
            'address': host,
            'port': port,
            'password': userInfo,
          }
        ];
      } else if (protocol == 'vmess') {
        settings['vnext'] = [
          {
            'address': host,
            'port': port,
            'users': [
              {
                'id': userInfo,
                'alterId': int.tryParse(q['aid'] ?? '0') ?? 0,
                'security': q['scy'] ?? q['security'] ?? 'auto',
              }
            ],
          }
        ];
      } else {
        settings['vnext'] = [
          {
            'address': host,
            'port': port,
            'users': [
              {
                'id': userInfo,
                'encryption': q['encryption'] ?? 'none',
                if ((q['flow'] ?? '').isNotEmpty) 'flow': q['flow'],
              }
            ],
          }
        ];
      }

      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      final xhttp = stream['xhttpSettings'] as Map<String, dynamic>;

      final extra = q['extra'];
      if (extra != null) {
        try {
          xhttp['extra'] = json.decode(extra);
        } catch (_) {}
      }

      if (security == 'tls') {
        final tls = <String, dynamic>{
          'serverName': q['sni']?.isNotEmpty == true ? q['sni']! : serverHost,
        };

        final fp = q['fp'] ?? q['fingerprint'] ?? '';
        if (fp.isNotEmpty) tls['fingerprint'] = fp;

        final alpn = q['alpn'] ?? '';
        if (alpn.isNotEmpty) {
          tls['alpn'] = alpn
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }

        stream['tlsSettings'] = tls;
      } else if (security == 'reality') {
        final reality = <String, dynamic>{
          'show': false,
          'serverName': q['sni']?.isNotEmpty == true ? q['sni']! : serverHost,
          'fingerprint': q['fp'] ?? q['fingerprint'] ?? 'chrome',
        };

        final pbk = q['pbk'] ?? q['publicKey'] ?? '';
        final sid = q['sid'] ?? q['shortId'] ?? '';
        final spx = q['spx'] ?? q['spiderX'] ?? '';

        if (pbk.isNotEmpty) reality['publicKey'] = pbk;
        if (sid.isNotEmpty) reality['shortId'] = sid;
        if (spx.isNotEmpty) reality['spiderX'] = spx;

        stream['realitySettings'] = reality;
      }

      return json.encode({
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
      });
    }

    final parser = V2ray.parseFromURL(configUrl);
    final generated = parser.getFullConfiguration();

    try {
      final decoded = json.decode(generated);
      if (decoded is Map<String, dynamic>) {
        if (scheme == 'vless') {
          final rawQuery = _rawQueryParametersPreservePlus(uri);
          _patchVlessAdvancedSettings(decoded, rawQuery);
        }

        return json.encode(decoded);
      }
    } catch (_) {}

    return generated;
  }

  Future<void> _testAllPings() async {
    if (_isTestingAllPings || _configs.isEmpty) return;

    if (mounted) {
      setState(() {
        _isTestingAllPings = true;
        for (final item in _configs) {
          final id = item['id']?.toString() ?? item['name']?.toString() ?? '';
          if (id.isNotEmpty) {
            _pingLoading[id] = true;
            _pings[id] = -1;
          }
        }
      });
    }

    await Future.wait(_configs.map((item) async {
      if (!mounted) return;
      await _testServerDelay(item);
    }));

    if (!mounted) return;

    setState(() {
      _configs.sort((a, b) {
        final String idA = a['id']?.toString() ?? a['name']?.toString() ?? '';
        final String idB = b['id']?.toString() ?? b['name']?.toString() ?? '';

        final int pingA = _pings[idA] ?? -1;
        final int pingB = _pings[idB] ?? -1;

        final int validA = pingA > 0 ? pingA : 1 << 30;
        final int validB = pingB > 0 ? pingB : 1 << 30;

        return validA.compareTo(validB);
      });

      _isTestingAllPings = false;
    });
  }

  Future<void> _testServerDelay(Map<String, dynamic> item) async {
    final String rawUrl = (item['config'] ?? '').toString().trim();
    final String configId = item['id']?.toString() ?? item['name']?.toString() ?? '';

    if (rawUrl.isEmpty || configId.isEmpty) {
      if (mounted && configId.isNotEmpty) {
        setState(() {
          _pings[configId] = -1;
          _pingLoading[configId] = false;
        });
      }
      return;
    }

    int delay = -1;
    try {
      String finalConfigJson = _parseConfigToJson(rawUrl);
      delay = await flutterV2ray.getServerDelay(config: finalConfigJson);
    } catch (_) {
      delay = -1;
    }

    if (mounted) {
      setState(() {
        _pings[configId] = delay > 0 ? delay : -1;
        _pingLoading[configId] = false;
      });
    }
  }

  Future<void> _toggleMainConnection() async {
    if (_isConnectingProcess) return;

    if (_isConnected) {
      // هر دلتايی که تا این لحظه ثبت محلی شده را قبل از توقف core ارسال کن.
      await _flushPendingTraffic();

      setState(() {
        _userWantsDisconnect = true;
        _isConnected = false;
        _isConnectingProcess = true;
      });
      try {
        await flutterV2ray.stopV2Ray();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isConnectingProcess = false;
          _lastSessionUpload = 0;
          _lastSessionDownload = 0;
        });
      }
      return;
    }

    if (_configs.isEmpty) return;

    if (_selectedConfigId == null || !_configs.any((c) => (c['id']?.toString() ?? c['name']) == _selectedConfigId)) {
      _selectedConfigId = _configs[0]['id']?.toString() ?? _configs[0]['name'];
    }

    final selectedConfig = _configs.firstWhere(
      (c) => (c['id']?.toString() ?? c['name']) == _selectedConfigId,
      orElse: () => _configs[0],
    );

    final String rawUrl = (selectedConfig['config'] ?? '').toString();
    setState(() {
      _userWantsDisconnect = false;
      _isConnectingProcess = true;
    });

    try {
      final bool hasPermission = await flutterV2ray.requestPermission();
      if (hasPermission) {
        String finalConfigJson = _parseConfigToJson(rawUrl);
        String remark = selectedConfig['name'] ?? 'Xray Server';

        try {
          if (!rawUrl.contains('type=xhttp') && !rawUrl.contains('type=ws') && !rawUrl.contains('ws://')) {
            V2RayURL parser = V2ray.parseFromURL(_cleanUrl(rawUrl));
            if (parser.remark.isNotEmpty) {
              remark = parser.remark;
            }
          }
        } catch (_) {}

        await flutterV2ray.startV2Ray(
          remark: remark,
          config: finalConfigJson,
          proxyOnly: false,
        );

        if (mounted && !_userWantsDisconnect) {
          setState(() {
            _isConnected = true;
            _isConnectingProcess = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isConnectingProcess = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در اتصال: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() {
          _isConnectingProcess = false;
          _isConnected = false;
        });
      }
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
    final maxGb = double.tryParse(_userData?['max_volume_gb']?.toString() ?? '0') ?? 0.0;
    final usedGb = maxGb > 0
        ? _accumulatedUsedBytes / (1024 * 1024 * 1024)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Xray Ultra', style: TextStyle(fontSize: 18, color: Colors.white70)),
            Text('Core: $_coreVersion', style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
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
                  content: const Text('آیا می‌‌خواهید از حساب کاربری خود خارج شوید؟'),
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
                  maxGb > 0
                      ? 'حجم: ${usedGb.toStringAsFixed(2)} / ${maxGb.toStringAsFixed(1)} GB'
                      : 'حجم: نامحدود',
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
