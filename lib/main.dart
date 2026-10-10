import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
        child: CircularProgressIndicator(color: Color(0xFF8B9BB4)),
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
        final model =
            info.model.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
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
        const SnackBar(
          content: Text('لطفاً نام کاربری و رمز عبور را وارد کنید.'),
        ),
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
              ? (data['message']?.toString() ??
                  'نام کاربری یا رمز عبور اشتباه است.')
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.vpn_key_rounded,
                size: 80,
                color: Color(0xFF8B9BB4),
              ),
              const SizedBox(height: 12),
              const Text(
                'HUSKY VPN',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'نام کاربری',
                  filled: true,
                  fillColor: const Color(0xFF222536),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _isLoading ? null : _login(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B4261),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ورود',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
          final model =
              info.model.replaceAll(RegExp(r'[^\w\s-]'), '').trim();

          _deviceId =
              model.isNotEmpty ? model : 'ANDROID_${info.id}';
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
        final maxGb =
            double.tryParse(data['max_volume_gb']?.toString() ?? '0') ?? 0;
        final usedBytes =
            int.tryParse(data['used_bytes']?.toString() ?? '0') ?? 0;
        final maxBytes = maxGb > 0
            ? maxGb * 1024 * 1024 * 1024
            : 0.0;

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

      final serverUsedBytes =
          int.tryParse(data['used_bytes']?.toString() ?? '0') ?? 0;

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

      final maxGb =
          double.tryParse(data['max_volume_gb']?.toString() ?? '0') ?? 0;

      if (maxGb > 0) {
        final usedGb =
            _accumulatedUsedBytes / (1024 * 1024 * 1024);

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

    final maxGb =
        double.tryParse(_userData!['max_volume_gb']?.toString() ?? '0') ?? 0;

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

    final maxGb =
        double.tryParse(_userData!['max_volume_gb']?.toString() ?? '0') ?? 0;

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
          _pendingTrafficBytes =
              (_pendingTrafficBytes - batch).clamp(0, 1 << 62);

          final serverUsedBytes =
              int.tryParse(result['used_bytes']?.toString() ?? '') ??
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
        SnackBar(
          content: Text(reason),
          backgroundColor: Colors.redAccent,
        ),
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
        result[Uri.decodeComponent(rawKey)] =
            Uri.decodeComponent(rawValue);
      } catch (_) {
        result[rawKey] = rawValue;
      }
    }

    return result;
  }

  String _firstQueryValue(
    Map<String, String> query,
    List<String> keys,
  ) {
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

  void _patchVlessAdvancedSettings(
    Map<String, dynamic> config,
    Map<String, String> rawQuery,
  ) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) return;

    for (final item in outbounds) {
      if (item is! Map) continue;

      if (item['protocol']?.toString().toLowerCase() != 'vless') {
        continue;
      }

      final streamValue = item['streamSettings'];
      if (streamValue is! Map) continue;

      final stream = Map<String, dynamic>.from(streamValue);
      item['streamSettings'] = stream;

      final rawNetwork = _firstQueryValue(rawQuery, ['type', 'network']);
      if (rawNetwork.isNotEmpty) {
        stream['network'] =
            rawNetwork.toLowerCase() == 'splithttp' ? 'xhttp' : rawNetwork;
      }

      final security = _firstQueryValue(
        rawQuery,
        ['security'],
      ).toLowerCase();

      if (security == 'tls') {
        final oldTls = stream['tlsSettings'];
        final tls = oldTls is Map
            ? Map<String, dynamic>.from(oldTls)
            : <String, dynamic>{};

        final sni = _firstQueryValue(rawQuery, ['sni', 'serverName']);
        final fingerprint =
            _firstQueryValue(rawQuery, ['fp', 'fingerprint']);
        final alpn = _firstQueryValue(rawQuery, ['alpn']);

        if (sni.isNotEmpty) tls['serverName'] = sni;
        if (fingerprint.isNotEmpty) tls['fingerprint'] = fingerprint;

        if (alpn.isNotEmpty) {
          tls['alpn'] = _splitCsv(alpn);
        }

        final ech = _firstQueryValue(
          rawQuery,
          ['echConfigList', 'ech'],
        );
        if (ech.isNotEmpty) tls['echConfigList'] = ech;

        final vcn = _firstQueryValue(
          rawQuery,
          ['vcn', 'verifyPeerCertByName'],
        );
        if (vcn.isNotEmpty) {
          tls['verifyPeerCertByName'] = vcn;
        }

        final pcs = _firstQueryValue(
          rawQuery,
          ['pcs', 'pinnedPeerCertSha256'],
        );

        if (pcs.isNotEmpty) tls['pinnedPeerCertSha256'] = pcs;

        tls.remove('allowInsecure');

        stream['security'] = 'tls';
        stream['tlsSettings'] = tls;
        stream.remove('realitySettings');
      } else if (security == 'reality') {
        final oldReality = stream['realitySettings'];
        final reality = oldReality is Map
            ? Map<String, dynamic>.from(oldReality)
            : <String, dynamic>{};

        final sni = _firstQueryValue(rawQuery, ['sni', 'serverName']);
        final fingerprint =
            _firstQueryValue(rawQuery, ['fp', 'fingerprint']);
        final publicKey =
            _firstQueryValue(rawQuery, ['pbk', 'publicKey']);
        final shortId = _firstQueryValue(rawQuery, ['sid', 'shortId']);
        final spiderX = _firstQueryValue(rawQuery, ['spx', 'spiderX']);
        final mldsa = _firstQueryValue(
          rawQuery,
          ['pqv', 'mldsa65Verify'],
        );

        reality['show'] = false;

        if (sni.isNotEmpty) reality['serverName'] = sni;
        if (fingerprint.isNotEmpty) reality['fingerprint'] = fingerprint;
        if (publicKey.isNotEmpty) reality['publicKey'] = publicKey;
        if (shortId.isNotEmpty) reality['shortId'] = shortId;
        if (spiderX.isNotEmpty) reality['spiderX'] = spiderX;
        if (mldsa.isNotEmpty) reality['mldsa65Verify'] = mldsa;

        stream['security'] = 'reality';
        stream['realitySettings'] = reality;
        stream.remove('tlsSettings');
      }
    }
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

  String _parseConfigToJson(String rawUrl) {
    var configUrl = _cleanUrl(rawUrl);

    if (configUrl.isEmpty) {
      throw const FormatException('Config is empty');
    }

    try {
      final decodedJson = json.decode(configUrl);
      if (decodedJson is Map || decodedJson is List) {
        return json.encode(decodedJson);
      }
    } catch (_) {}

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
              lower.startsWith('vless://') ||
              lower.startsWith('vmess://') ||
              lower.startsWith('trojan://') ||
              lower.startsWith('ss://') ||
              lower.startsWith('shadowsocks://') ||
              lower.startsWith('socks://') ||
              lower.startsWith('hysteria://') ||
              lower.startsWith('hysteria2://') ||
              lower.startsWith('hy2://') ||
              lower.startsWith('tuic://') ||
              lower.startsWith('wireguard://') ||
              lower.startsWith('anytls://')) {
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
      // استفاده از Uri.encodeFull برای پشتیبانی از ایموجی و حروف فارسی در بخش Fragment
      uri = Uri.parse(Uri.encodeFull(configUrl));
    } catch (_) {
      try {
        uri = Uri.parse(configUrl);
      } catch (_) {
        return V2ray.parseFromURL(configUrl).getFullConfiguration();
      }
    }

    final scheme = uri.scheme.toLowerCase();
    final query = _rawQueryParametersPreservePlus(uri);
    final network = _firstQueryValue(query, ['type', 'network']).toLowerCase();
    final security = _firstQueryValue(query, ['security']).toLowerCase();

    if ((network == 'ws' || network == 'websocket') &&
        (scheme == 'trojan' || scheme == 'vless' || scheme == 'vmess')) {
      final server = uri.host;
      final port = uri.hasPort ? uri.port : 443;
      final credential = Uri.decodeComponent(uri.userInfo);
      if (server.isEmpty || credential.isEmpty || port < 1 || port > 65535) {
        throw const FormatException('Invalid WS config: missing server, port, or credential');
      }

      final transportHost = _firstQueryValue(query, ['host', 'authority']);
      final path = _firstQueryValue(query, ['path']);
      final sni = _firstQueryValue(query, ['sni', 'serverName']);
      final fingerprint = _firstQueryValue(query, ['fp', 'fingerprint']);
      final alpn = _firstQueryValue(query, ['alpn']);
      final outbound = <String, dynamic>{
        'protocol': scheme == 'trojan' ? 'trojan' : (scheme == 'vmess' ? 'vmess' : 'vless'),
        'settings': <String, dynamic>{},
        'streamSettings': <String, dynamic>{
          'network': 'ws',
          'security': security.isEmpty ? 'none' : security,
          'wsSettings': <String, dynamic>{
            'path': path.isEmpty ? '/' : path,
            if (transportHost.isNotEmpty)
              'headers': <String, dynamic>{'Host': transportHost},
          },
        },
      };

      final settings = outbound['settings'] as Map<String, dynamic>;
      if (scheme == 'trojan') {
        settings['servers'] = [
          {'address': server, 'port': port, 'password': credential},
        ];
      } else if (scheme == 'vmess') {
        settings['vnext'] = [
          {
            'address': server,
            'port': port,
            'users': [
              {
                'id': credential,
                'alterId': int.tryParse(query['aid'] ?? '0') ?? 0,
                'security': query['scy'] ?? 'auto',
              },
            ],
          },
        ];
      } else {
        settings['vnext'] = [
          {
            'address': server,
            'port': port,
            'users': [
              {
                'id': credential,
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
        final tls = <String, dynamic>{
          'serverName': sni.isNotEmpty
              ? sni
              : (transportHost.isNotEmpty ? transportHost : server),
        };
        if (fingerprint.isNotEmpty) tls['fingerprint'] = fingerprint;
        if (alpn.isNotEmpty) tls['alpn'] = _splitCsv(alpn);

        final ech = _firstQueryValue(query, ['echConfigList', 'ech']);
        if (ech.isNotEmpty &&
            !ech.contains('://') &&
            !ech.contains('+') &&
            RegExp(r'^[A-Za-z0-9_+/=-]+$').hasMatch(ech)) {
          tls['echConfigList'] = ech;
        }
        final vcn = _firstQueryValue(query, ['vcn', 'verifyPeerCertByName']);
        final pcs = _firstQueryValue(query, ['pcs', 'pinnedPeerCertSha256']);
        if (vcn.isNotEmpty) tls['verifyPeerCertByName'] = vcn;
        if (pcs.isNotEmpty) tls['pinnedPeerCertSha256'] = _splitCsv(pcs);

        stream['tlsSettings'] = tls;
      } else if (security == 'reality') {
        final reality = <String, dynamic>{
          'show': false,
          'serverName': sni.isNotEmpty
              ? sni
              : (transportHost.isNotEmpty ? transportHost : server),
          'fingerprint': fingerprint.isNotEmpty ? fingerprint : 'chrome',
        };
        final pbk = _firstQueryValue(query, ['pbk', 'publicKey']);
        final sid = _firstQueryValue(query, ['sid', 'shortId']);
        final spx = _firstQueryValue(query, ['spx', 'spiderX']);
        final pqv = _firstQueryValue(query, ['pqv', 'mldsa65Verify']);
        if (pbk.isNotEmpty) reality['publicKey'] = pbk;
        if (sid.isNotEmpty) reality['shortId'] = sid;
        if (spx.isNotEmpty) reality['spiderX'] = spx;
        if (pqv.isNotEmpty) reality['mldsa65Verify'] = pqv;
        stream['realitySettings'] = reality;
      }

      return json.encode(_baseConfig(outbound));
    }

    if (network == 'xhttp' || network == 'splithttp') {
      final protocol = scheme == 'vmess'
          ? 'vmess'
          : scheme == 'trojan'
              ? 'trojan'
              : 'vless';

      final host = uri.host;
      final port = uri.hasPort ? uri.port : 443;
      final userInfo = Uri.decodeComponent(uri.userInfo);

      if (host.isEmpty || userInfo.isEmpty) {
        throw const FormatException('XHTTP config has no server or ID');
      }

      final transportHost =
          _firstQueryValue(query, ['host', 'authority']).isNotEmpty
              ? _firstQueryValue(query, ['host', 'authority'])
              : host;

      final pathValue = _firstQueryValue(query, ['path']);
      final path = pathValue.isNotEmpty ? pathValue : '/';

      final modeValue = _firstQueryValue(query, ['mode']);
      final mode = modeValue.isNotEmpty ? modeValue : 'auto';

      final outbound = <String, dynamic>{
        'protocol': protocol,
        'settings': <String, dynamic>{},
        'streamSettings': <String, dynamic>{
          'network': 'xhttp',
          'security': security.isEmpty ? 'none' : security,
          'xhttpSettings': <String, dynamic>{
            'path': path,
            'host': transportHost,
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
                'alterId': int.tryParse(query['aid'] ?? '0') ?? 0,
                'security': query['scy'] ?? 'auto',
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
                'encryption': query['encryption'] ?? 'none',
                if ((query['flow'] ?? '').isNotEmpty) 'flow': query['flow'],
              }
            ],
          }
        ];
      }

      final stream =
          outbound['streamSettings'] as Map<String, dynamic>;
      final xhttp =
          stream['xhttpSettings'] as Map<String, dynamic>;

      final extra = query['extra'];
      if (extra != null && extra.trim().isNotEmpty) {
        try {
          xhttp['extra'] = json.decode(extra);
        } catch (_) {}
      }

      if (security == 'tls') {
        final tls = <String, dynamic>{};

        final sni = _firstQueryValue(query, ['sni', 'serverName']);
        final fingerprint =
            _firstQueryValue(query, ['fp', 'fingerprint']);
        final alpn = _firstQueryValue(query, ['alpn']);
        final ech = _firstQueryValue(query, ['echConfigList', 'ech']);
        final vcn = _firstQueryValue(
          query,
          ['vcn', 'verifyPeerCertByName'],
        );
        final pcs = _firstQueryValue(
          query,
          ['pcs', 'pinnedPeerCertSha256'],
        );

        tls['serverName'] = sni.isNotEmpty ? sni : transportHost;

        if (fingerprint.isNotEmpty) {
          tls['fingerprint'] = fingerprint;
        }

        if (alpn.isNotEmpty) tls['alpn'] = _splitCsv(alpn);
        if (ech.isNotEmpty) tls['echConfigList'] = ech;
        if (vcn.isNotEmpty) tls['verifyPeerCertByName'] = vcn;
        if (pcs.isNotEmpty) tls['pinnedPeerCertSha256'] = pcs;

        stream['tlsSettings'] = tls;
      } else if (security == 'reality') {
        final reality = <String, dynamic>{
          'show': false,
          'serverName': _firstQueryValue(query, ['sni', 'serverName'])
                  .isNotEmpty
              ? _firstQueryValue(query, ['sni', 'serverName'])
              : transportHost,
          'fingerprint':
              _firstQueryValue(query, ['fp', 'fingerprint']).isNotEmpty
                  ? _firstQueryValue(query, ['fp', 'fingerprint'])
                  : 'chrome',
        };

        final publicKey =
            _firstQueryValue(query, ['pbk', 'publicKey']);
        final shortId = _firstQueryValue(query, ['sid', 'shortId']);
        final spiderX = _firstQueryValue(query, ['spx', 'spiderX']);
        final mldsa =
            _firstQueryValue(query, ['pqv', 'mldsa65Verify']);

        if (publicKey.isNotEmpty) reality['publicKey'] = publicKey;
        if (shortId.isNotEmpty) reality['shortId'] = shortId;
        if (spiderX.isNotEmpty) reality['spiderX'] = spiderX;
        if (mldsa.isNotEmpty) reality['mldsa65Verify'] = mldsa;

        stream['realitySettings'] = reality;
      }

      return json.encode(_baseConfig(outbound));
    }

    final parser = V2ray.parseFromURL(configUrl);
    final generated = parser.getFullConfiguration();

    try {
      final decoded = json.decode(generated);

      if (decoded is Map) {
        final config = Map<String, dynamic>.from(decoded);

        if (scheme == 'vless') {
          _patchVlessAdvancedSettings(config, query);
        }

        return json.encode(config);
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
    if (value.startsWith('ss://') ||
        value.startsWith('shadowsocks://')) {
      return 'SS';
    }
    if (value.startsWith('socks://')) return 'SOCKS';
    if (value.startsWith('hysteria2://') ||
        value.startsWith('hy2://')) {
      return 'HY2';
    }
    if (value.startsWith('hysteria://')) return 'HYSTERIA';
    if (value.startsWith('tuic://')) return 'TUIC';
    if (value.startsWith('wireguard://')) return 'WG';
    if (value.startsWith('anytls://')) return 'ANYTLS';

    return 'XRAY';
  }

  Widget _buildAnnouncementBanner() {
    if (_announcementData == null ||
        !_isTruthy(_announcementData!['enabled'])) {
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
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
          }
        } catch (_) {}
      },
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2E354F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.5),
          ),
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
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (imageUrl.isNotEmpty && text.isNotEmpty)
              const SizedBox(height: 8),
            if (text.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.campaign,
                    color: Color(0xFFA78BFA),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (targetUrl.isNotEmpty)
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white38,
                      size: 14,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxGb =
        double.tryParse(_userData?['max_volume_gb']?.toString() ?? '0') ?? 0;

    final usedGb = maxGb > 0
        ? _accumulatedUsedBytes / (1024 * 1024 * 1024)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'HUSKY VPN',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            Text(
              'Core: $_coreVersion',
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: const Color(0xFF222536),
                  title: const Text('خروج از حساب'),
                  content: const Text(
                    'آیا می‌خواهید از حساب کاربری خود خارج شوید؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('انصراف'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _logoutUser('');
                      },
                      child: const Text(
                        'خروج',
                        style: TextStyle(color: Colors.redAccent),
                      ),
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
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B9BB4),
                    ),
                  )
                : _configs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              size: 42,
                              color: Colors.white38,
                            ),
                            const SizedBox(height: 12),
                            const Text('سروری دریافت نشد.'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _fetchConfigs,
                              child: const Text('تلاش دوباره'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        itemCount: _configs.length,
                        itemBuilder: (context, index) {
                          final item = _configs[index];
                          final configId = _configId(item);
                          final configUrl =
                              (item['config'] ?? '').toString();
                          final protocol = _getProtocolType(configUrl);
                          final isSelected =
                              _selectedConfigId == configId;
                          final ping = _pings[configId] ?? -1;
                          final pingLoading =
                              _pingLoading[configId] ?? false;

                          return GestureDetector(
                            onTap: () {
                              if (_isConnected) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'لطفاً ابتدا اتصال فعلی را قطع کنید.',
                                    ),
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
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2A3045)
                                    : const Color(0xFF232738),
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF7A93D1),
                                        width: 1.5,
                                      )
                                    : null,
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
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        child: Text(
                                          (item['name'] ?? 'سرور Xray')
                                              .toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pingLoading
                                              ? Colors.white10
                                              : ping > 0
                                                  ? const Color(0xFF2E5A3C)
                                                  : const Color(0xFF613137),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          pingLoading
                                              ? '...'
                                              : ping > 0
                                                  ? '${ping}ms'
                                                  : '-1ms',
                                          style: TextStyle(
                                            color: pingLoading
                                                ? Colors.white54
                                                : ping > 0
                                                    ? const Color(0xFF81C784)
                                                    : const Color(0xFFE57373),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: _isConnected
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isConnected ? 'CONNECTED' : 'DISCONNECTED',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 45),
        child: FloatingActionButton(
          backgroundColor: _isConnected
              ? const Color(0xFF4CAF50)
              : const Color(0xFFB0BEC5),
          onPressed: _toggleMainConnection,
          child: _isConnectingProcess
              ? const CircularProgressIndicator(color: Colors.white)
              : Icon(
                  Icons.power_settings_new,
                  color: _isConnected
                      ? Colors.white
                      : const Color(0xFF1B1D29),
                  size: 30,
                ),
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
                  Icon(
                    Icons.file_download_outlined,
                    color: Colors.white54,
                    size: 20,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Get Config',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  maxGb > 0
                      ? 'حجم: ${usedGb.toStringAsFixed(2)} / '
                          '${maxGb.toStringAsFixed(1)} GB'
                      : 'حجم: نامحدود',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.87),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'اعتبار: $_remainingTimeText',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: _isTestingAllPings ? null : _testAllPings,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bolt,
                    color: _isTestingAllPings
                        ? Colors.amber
                        : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isTestingAllPings ? 'Testing...' : 'Test',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
