import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class HudColors {
  static const Color bg = Color(0xFF07090E);
  static const Color surface = Color(0xFF101520);
  static const Color surfaceAlt = Color(0xFF171F30);
  static const Color standbyPrimary = Color(0xFFFF2A54);
  static const Color standbySecondary = Color(0xFFFF6B00);
  static const Color activePrimary = Color(0xFF00F0FF);
  static const Color activeSecondary = Color(0xFF00FF9D);
  static const Color borderIdle = Color(0xFF1E283C);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUSKY VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: HudColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: HudColors.activePrimary,
          surface: HudColors.surface,
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
      backgroundColor: HudColors.bg,
      body: Center(
        child: CircularProgressIndicator(color: HudColors.activePrimary),
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
  List> _loginAnnouncements = [];

  @override
  void initState() {
    super.initState();
    _fetchLoginAnnouncements();
  }

  Future<void> _fetchLoginAnnouncements() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBase?action=get_login_announcements'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;
      final dynamic data = json.decode(response.body);
      if (!mounted) return;
      setState(() {
        _loginAnnouncements = data is List
            ? data
                .whereType()
                .map((item) => Map<String, dynamic>.from(item))
                .where((item) =>
                    item['enabled'] == 1 ||
                    item['enabled'] == true ||
                    item['enabled']?.toString() == '1')
                .toList()
            : [];
      });
    } catch (_) {}
  }

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
        _showError('نام کاربری یا رمز عبور اشتباه است.');
        return;
      }

      final userData = data['user'];
      if (userData is! Map || userData['id'] == null) {
        _showError('اطلاعات کاربر دریافت نشد.');
        return;
      }

      final userId = userData['id'].toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('device_id', deviceId);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ServerListScreen(userId: userId)),
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
      SnackBar(content: Text(message), backgroundColor: HudColors.standbyPrimary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HudColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HudColors.surface,
                  border: Border.all(color: HudColors.activePrimary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: HudColors.activePrimary.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt, size: 44, color: HudColors.activePrimary),
              ),
              const SizedBox(height: 18),
              const Text(
                'HUSKY VPN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.5, color: Colors.white),
              ),
              const Text(
                'TACTICAL HUD ACCESS',
                style: TextStyle(fontSize: 10, letterSpacing: 2.0, color: HudColors.activePrimary),
              ),
              const SizedBox(height: 28),
              Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'نام کاربری',
                    prefixIcon: const Icon(Icons.person_outline, color: HudColors.activePrimary),
                    filled: true,
                    fillColor: HudColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'رمز عبور',
                    prefixIcon: const Icon(Icons.lock_outline, color: HudColors.activePrimary),
                    filled: true,
                    fillColor: HudColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HudColors.activePrimary,
                    foregroundColor: HudColors.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: HudColors.bg)
                      : const Text('ورود به سیستم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SplitTunnelingScreen extends StatefulWidget {
  const SplitTunnelingScreen({super.key});

  @override
  State<SplitTunnelingScreen> createState() => _SplitTunnelingScreenState();
}

class _SplitTunnelingScreenState extends State<SplitTunnelingScreen> {
  bool _loading = true;
  bool _enabled = false;
  String _search = '';
  List<AppInfo> _apps = [];
  Set<String> _selectedPackages = <String>{};

  @override
  void initState() {
    super.initState();
    _loadSettingsAndApps();
  }

  Future<void> _loadSettingsAndApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('split_tunneling_enabled') ?? false;
      final selected = prefs.getStringList('split_tunneling_selected')?.toSet() ?? <String>{};
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: true,
        withIcon: true,
        detectPlatformType: false,
      );
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _selectedPackages = selected;
        _apps = apps;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('split_tunneling_enabled', _enabled);
    await prefs.setStringList('split_tunneling_selected', _selectedPackages.toList());
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _apps.where((app) {
      final q = _search.trim().toLowerCase();
      return q.isEmpty || app.name.toLowerCase().contains(q) || app.packageName.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: HudColors.bg,
        appBar: AppBar(
          backgroundColor: HudColors.bg,
          title: const Text('عبور انتخابی برنامه‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: HudColors.activePrimary))
            : Column(
                children: [
                  SwitchListTile(
                    value: _enabled,
                    activeColor: HudColors.activePrimary,
                    title: const Text('فعال‌سازی استثناهای VPN'),
                    onChanged: (val) async {
                      setState(() => _enabled = val);
                      await _save();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      onChanged: (val) => setState(() => _search = val),
                      decoration: InputDecoration(
                        hintText: 'جست‌وجوی برنامه...',
                        filled: true,
                        fillColor: HudColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = filteredApps[index];
                        final selected = _selectedPackages.contains(app.packageName);
                        return CheckboxListTile(
                          value: selected,
                          activeColor: HudColors.activePrimary,
                          onChanged: _enabled
                              ? (val) async {
                                  setState(() {
                                    if (val == true) {
                                      _selectedPackages.add(app.packageName);
                                    } else {
                                      _selectedPackages.remove(app.packageName);
                                    }
                                  });
                                  await _save();
                                }
                              : null,
                          secondary: app.icon != null ? Image.memory(app.icon!, width: 32, height: 32) : null,
                          title: Text(app.name),
                          subtitle: Text(app.packageName, style: const TextStyle(fontSize: 10, color: Colors.white38)),
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

class ServerListScreen extends StatefulWidget {
  final String userId;
  const ServerListScreen({super.key, required this.userId});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const String apiBase = 'https://socialmedia-ad.ir/index.php';

  late V2ray flutterV2ray;
  late AnimationController _shockwaveController;
  late Animation<double> _shockwaveScale;
  late Animation<double> _shockwaveOpacity;

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
  List> _announcementData = [];

  int _lastSessionUpload = 0;
  int _lastSessionDownload = 0;
  int _accumulatedUsedBytes = 0;
  int _pendingTrafficBytes = 0;

  String _currentUploadSpeed = '0 KB/s';
  String _currentDownloadSpeed = '0 KB/s';
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
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _shockwaveScale = Tween<double>(begin: 1.0, end: 1.9).animate(
      CurvedAnimation(parent: _shockwaveController, curve: Curves.easeOut),
    );
    _shockwaveOpacity = Tween<double>(begin: 0.75, end: 0.0).animate(
      CurvedAnimation(parent: _shockwaveController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addObserver(this);
    _initDeviceIdAndStart();
    _initV2Ray();
    _fetchConfigs();
    _fetchAnnouncement();
  }

  void _triggerShockwave() {
    _shockwaveController.forward(from: 0.0);
  }

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec <= 0) return '0 KB/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  Future<void> _initDeviceIdAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', _deviceId!);
    }
    if (!mounted) return;
    await _fetchUserDataAndCheck();
    _userCheckTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (!mounted || _logoutInProgress) return;
      _fetchUserDataAndCheck();
      _fetchAnnouncement();
    });
  }

  @override
  void dispose() {
    _shockwaveController.dispose();
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
            final wasDisconnected = !_isConnected;
            setState(() {
              _isConnected = true;
              _isConnectingProcess = false;
              _currentUploadSpeed = _formatSpeed(status.uploadSpeed);
              _currentDownloadSpeed = _formatSpeed(status.downloadSpeed);
            });
            if (wasDisconnected) _triggerShockwave();
            _calculateAndSaveTraffic(status.upload, status.download);
          }
        } else if (state == 'DISCONNECTED' || state == 'STOPPED' || state == 'IDLE') {
          if (_trafficBaselineInitialized) {
            _calculateAndSaveTraffic(status.upload, status.download);
          }
          setState(() {
            _isConnected = false;
            _isConnectingProcess = false;
            _lastSessionUpload = 0;
            _lastSessionDownload = 0;
            _currentUploadSpeed = '0 KB/s';
            _currentDownloadSpeed = '0 KB/s';
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
    } catch (_) {}
  }

  Future<void> _fetchAnnouncement() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBase?action=get_app_announcements'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.body.trim() == 'null') return;
      final dynamic data = json.decode(response.body);
      if (mounted && data is List) {
        setState(() {
          _announcementData = data
              .whereType()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) => _isTruthy(item['enabled']))
              .toList();
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
      if (response.statusCode != 200 || response.body.trim() == 'null') return;
      final dynamic decoded = json.decode(response.body);
      if (decoded is! Map) return;

      final data = Map<String, dynamic>.from(decoded);
      if (!_isTruthy(data['active'])) {
        await _logoutUser('حساب کاربری شما غیرفعال شده است.');
        return;
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
          } else {
            _remainingTimeText = '${diff.inHours} ساعت باقی‌مانده';
          }
        } catch (_) {
          _remainingTimeText = 'نامشخص';
        }
      } else {
        _remainingTimeText = 'نامحدود';
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _calculateAndSaveTraffic(int currentUpload, int currentDownload) async {
    if (_userData == null) return;
    if (!_trafficBaselineInitialized) {
      _lastSessionUpload = currentUpload;
      _lastSessionDownload = currentDownload;
      _trafficBaselineInitialized = true;
      return;
    }
    if (currentDownload < _lastSessionDownload || currentUpload < _lastSessionUpload) {
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
    if (_trafficUpdateInProgress || _pendingTrafficBytes <= 0 || _userData == null) return;
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
          _accumulatedUsedBytes = int.tryParse(result['used_bytes']?.toString() ?? '') ?? (_accumulatedUsedBytes + batch);
          if (mounted) setState(() {});
        }
      }
    } catch (_) {
    } finally {
      _trafficUpdateInProgress = false;
    }
  }

  Future<void> _logoutUser(String reason) async {
    if (_logoutInProgress) return;
    _logoutInProgress = true;
    _userCheckTimer?.cancel();
    try {
      await flutterV2ray.stopV2Ray();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('device_id');
    if (!mounted) return;
    if (reason.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: HudColors.standbyPrimary),
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
      }
      if (!mounted) return;
      setState(() {
        _configs = loadedConfigs;
        if (_configs.isNotEmpty && (_selectedConfigId == null || !_configs.any((i) => _configId(i) == _selectedConfigId))) {
          _selectedConfigId = _configId(_configs.first);
        }
        _isLoading = false;
      });
      _testAllPings();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _configId(dynamic item) => item is Map ? (item['id'] ?? item['name'] ?? '').toString() : '';

  String _cleanUrl(String rawUrl) => rawUrl.trim().replaceFirst('\uFEFF', '').trim();

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

  List<String> _splitCsv(String value) => value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  void _patchVlessAdvancedSettings(Map<String, dynamic> config, Map<String, String> rawQuery) {
    final outbounds = config['outbounds'];
    if (outbounds is! List) return;
    for (final item in outbounds) {
      if (item is! Map || item['protocol']?.toString().toLowerCase() != 'vless') continue;
      final streamValue = item['streamSettings'];
      if (streamValue is! Map) continue;
      final stream = Map<String, dynamic>.from(streamValue);
      item['streamSettings'] = stream;
      final rawNetwork = _firstQueryValue(rawQuery, ['type', 'network']);
      if (rawNetwork.isNotEmpty) {
        stream['network'] = rawNetwork.toLowerCase() == 'splithttp' ? 'xhttp' : rawNetwork;
      }
      final security = _firstQueryValue(rawQuery, ['security']).toLowerCase();
      if (security == 'tls') {
        final tls = stream['tlsSettings'] is Map ? Map<String, dynamic>.from(stream['tlsSettings']) : <String, dynamic>{};
        final sni = _firstQueryValue(rawQuery, ['sni', 'serverName']);
        final fp = _firstQueryValue(rawQuery, ['fp', 'fingerprint']);
        final alpn = _firstQueryValue(rawQuery, ['alpn']);
        if (sni.isNotEmpty) tls['serverName'] = sni;
        if (fp.isNotEmpty) tls['fingerprint'] = fp;
        if (alpn.isNotEmpty) tls['alpn'] = _splitCsv(alpn);
        stream['security'] = 'tls';
        stream['tlsSettings'] = tls;
      }
    }
  }

  Map<String, dynamic> _baseConfig(Map<String, dynamic> outbound) {
    if (!outbound.containsKey('tag')) outbound['tag'] = 'proxy';
    return {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {'listen': '127.0.0.1', 'port': 10808, 'protocol': 'socks', 'settings': {'auth': 'noauth', 'udp': true}}
      ],
      'outbounds': [outbound, {'protocol': 'freedom', 'tag': 'direct'}],
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': [{'type': 'field', 'domain': ['full:socialmedia-ad.ir'], 'outboundTag': 'direct'}]
      },
    };
  }

  String _parseConfigToJson(String rawUrl) {
    var configUrl = _cleanUrl(rawUrl);
    try {
      final decodedJson = json.decode(configUrl);
      if (decodedJson is Map) return json.encode(decodedJson);
      if (decodedJson is List) return json.encode(decodedJson);
    } catch (_) {}

    try {
      final uri = Uri.parse(configUrl);
      final scheme = uri.scheme.toLowerCase();
      final query = _rawQueryParametersPreservePlus(uri);
      final network = _firstQueryValue(query, ['type', 'network']).toLowerCase();
      final security = _firstQueryValue(query, ['security']).toLowerCase();

      if (network == 'ws' && (scheme == 'vless' || scheme == 'vmess' || scheme == 'trojan')) {
        final host = uri.host;
        final port = uri.hasPort ? uri.port : 443;
        final userInfo = Uri.decodeComponent(uri.userInfo);
        final path = _firstQueryValue(query, ['path']).isNotEmpty ? _firstQueryValue(query, ['path']) : '/';

        final outbound = <String, dynamic>{
          'protocol': scheme,
          'settings': {
            scheme == 'trojan'
                ? 'servers'
                : 'vnext': [
                    {
                      'address': host,
                      'port': port,
                      scheme == 'trojan' ? 'password' : 'users': scheme == 'trojan' ? userInfo : [{'id': userInfo}]
                    }
                  ]
          },
          'streamSettings': {
            'network': 'ws',
            'security': security.isEmpty ? 'none' : security,
            'wsSettings': {'path': path, 'host': host}
          }
        };
        return json.encode(_baseConfig(outbound));
      }
    } catch (_) {}

    try {
      return V2ray.parseFromURL(configUrl).getFullConfiguration();
    } catch (_) {
      return configUrl;
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
        final pa = _pings[_configId(a)] ?? -1;
        final pb = _pings[_configId(b)] ?? -1;
        return (pa > 0 ? pa : 1 << 30).compareTo(pb > 0 ? pb : 1 << 30);
      });
      _isTestingAllPings = false;
    });
  }

  Future<void> _testServerDelay(dynamic item) async {
    if (item is! Map) return;
    final rawUrl = (item['config'] ?? '').toString().trim();
    final configId = _configId(item);
    if (rawUrl.isEmpty || configId.isEmpty) return;

    var delay = -1;
    try {
      final configJson = _parseConfigToJson(rawUrl);
      delay = await flutterV2ray.getServerDelay(config: configJson).timeout(const Duration(seconds: 15));
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _pings[configId] = delay > 0 ? delay : -1;
      _pingLoading[configId] = false;
    });
  }

  Future<void> _toggleMainConnection() async {
    if (_isConnectingProcess) return;
    _triggerShockwave();

    if (_isConnected) {
      setState(() {
        _userWantsDisconnect = true;
        _isConnected = false;
        _isConnectingProcess = true;
        _currentUploadSpeed = '0 KB/s';
        _currentDownloadSpeed = '0 KB/s';
      });
      try {
        await flutterV2ray.stopV2Ray();
      } catch (_) {}
      await _flushPendingTraffic();
      if (mounted) {
        setState(() {
          _isConnectingProcess = false;
          _trafficBaselineInitialized = false;
        });
      }
      return;
    }

    if (_configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هیچ سروری موجود نیست.')));
      return;
    }

    _selectedConfigId ??= _configId(_configs.first);
    final selectedConfig = _configs.firstWhere(
      (i) => _configId(i) == _selectedConfigId,
      orElse: () => _configs.first,
    );

    final rawUrl = (selectedConfig['config'] ?? '').toString().trim();
    if (rawUrl.isEmpty) return;

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
      final remark = (selectedConfig['name'] ?? 'Xray Server').toString();

      await flutterV2ray.startV2Ray(
        remark: remark,
        config: configJson,
        proxyOnly: false,
      );

      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted || _userWantsDisconnect) return;
      setState(() => _isConnectingProcess = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در اتصال: $e'), backgroundColor: HudColors.standbyPrimary),
      );
      setState(() {
        _isConnectingProcess = false;
        _isConnected = false;
      });
    }
  }

  String _getProtocolType(String url) {
    final v = url.trim().toLowerCase();
    if (v.startsWith('vless://')) return 'VLESS';
    if (v.startsWith('vmess://')) return 'VMESS';
    if (v.startsWith('trojan://')) return 'TROJAN';
    if (v.startsWith('ss://')) return 'SS';
    return 'XRAY';
  }

  @override
  Widget build(BuildContext context) {
    final maxGb = double.tryParse(_userData?['max_volume_gb']?.toString() ?? '0') ?? 0;
    final usedGb = maxGb > 0 ? _accumulatedUsedBytes / (1024 * 1024 * 1024) : 0.0;
    final accentColor = _isConnected ? HudColors.activePrimary : HudColors.standbyPrimary;

    return Scaffold(
      backgroundColor: HudColors.bg,
      appBar: AppBar(
        backgroundColor: HudColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white70),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitTunnelingScreen()));
          },
        ),
        title: Column(
          children: [
            const Text('HUSKY VPN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
            Text('CORE // $_coreVersion', style: TextStyle(fontSize: 9, color: accentColor)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: HudColors.standbyPrimary),
            onPressed: () => _logoutUser(''),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HudColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 20)],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleMainConnection,
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _shockwaveController,
                          builder: (context, _) {
                            if (_shockwaveController.isDismissed) return const SizedBox.shrink();
                            return Transform.scale(
                              scale: _shockwaveScale.value,
                              child: Opacity(
                                opacity: _shockwaveOpacity.value,
                                child: Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: accentColor, width: 2.5),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isConnected ? accentColor.withOpacity(0.2) : HudColors.surfaceAlt,
                            border: Border.all(color: accentColor, width: 2),
                          ),
                          child: _isConnectingProcess
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: accentColor),
                                )
                              : Icon(Icons.power_settings_new_rounded, color: accentColor, size: 32),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor)),
                          const SizedBox(width: 8),
                          Text(
                            _isConnectingProcess ? 'CONNECTING...' : _isConnected ? 'CONNECTED // SECURE' : 'STANDBY // READY',
                            style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: HudColors.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: HudColors.borderIdle),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_downward_rounded, size: 13, color: HudColors.activeSecondary),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(_currentDownloadSpeed, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: HudColors.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: HudColors.borderIdle),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_upward_rounded, size: 13, color: HudColors.activePrimary),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(_currentUploadSpeed, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_announcementData.isNotEmpty)
            ..._announcementData.map((a) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HudColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HudColors.activePrimary.withOpacity(0.3)),
                  ),
                  child: Text(a['text']?.toString() ?? '', style: const TextStyle(fontSize: 12, height: 1.4), textAlign: TextAlign.right),
                )),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: HudColors.activePrimary))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _configs.length,
                    itemBuilder: (context, index) {
                      final item = _configs[index];
                      final configId = _configId(item);
                      final protocol = _getProtocolType(item['config']?.toString() ?? '');
                      final isSelected = _selectedConfigId == configId;
                      final ping = _pings[configId] ?? -1;
                      final pingLoading = _pingLoading[configId] ?? false;

                      return GestureDetector(
                        onTap: () {
                          if (_isConnected) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('لطفاً ابتدا اتصال را قطع کنید.')),
                            );
                            return;
                          }
                          setState(() => _selectedConfigId = configId);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? HudColors.surfaceAlt : HudColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? accentColor : HudColors.borderIdle,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  decoration: BoxDecoration(
                                    color: isSelected ? accentColor.withOpacity(0.2) : Colors.black26,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(9),
                                      bottomLeft: Radius.circular(9),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Text(
                                      protocol,
                                      style: TextStyle(
                                        color: isSelected ? accentColor : Colors.white38,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      (item['name'] ?? 'سرور Xray').toString(),
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: pingLoading
                                          ? Colors.white10
                                          : ping > 0
                                              ? HudColors.activeSecondary.withOpacity(0.15)
                                              : HudColors.standbyPrimary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      pingLoading ? '...' : ping > 0 ? '${ping}ms' : '-1ms',
                                      style: TextStyle(
                                        color: ping > 0 ? HudColors.activeSecondary : HudColors.standbyPrimary,
                                        fontSize: 10,
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
        ],
      ),
      bottomNavigationBar: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: HudColors.surface,
          border: Border(top: BorderSide(color: HudColors.borderIdle)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _fetchConfigs,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_download_outlined, color: HudColors.activePrimary, size: 18),
                  Text('Get Config', style: TextStyle(fontSize: 9, color: Colors.white70)),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  maxGb > 0 ? 'حجم: ${usedGb.toStringAsFixed(2)} / ${maxGb.toStringAsFixed(1)} GB' : 'حجم: نامحدود',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text('اعتبار: $_remainingTimeText', style: const TextStyle(fontSize: 9, color: Colors.white54)),
              ],
            ),
            InkWell(
              onTap: _isTestingAllPings ? null : _testAllPings,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, color: _isTestingAllPings ? HudColors.standbySecondary : HudColors.activeSecondary, size: 18),
                  Text(_isTestingAllPings ? 'Testing...' : 'Test', style: const TextStyle(fontSize: 9, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}