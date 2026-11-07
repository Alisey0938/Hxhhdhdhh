import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:installed_apps/installed_apps.dart';
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
        scaffoldBackgroundColor: const Color(0xFF0A0C14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F0FF),
          secondary: Color(0xFFFF007F),
          surface: Color(0xFF131722),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0C14),
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
        child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
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

  Widget _buildLoginAnnouncements() {
    if (_loginAnnouncements.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _loginAnnouncements.map((announcement) {
        final text = (announcement['text'] ?? '').toString();
        final imageUrl = (announcement['image_url'] ?? '').toString();
        final targetUrl = (announcement['target_url'] ?? '').toString();
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
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF181D2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (text.isNotEmpty) ...[
                  if (imageUrl.isNotEmpty) const SizedBox(height: 8),
                  Text(text, textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white, height: 1.5)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00F0FF).withOpacity(0.1),
                  border: Border.all(color: const Color(0xFF00F0FF), width: 2),
                ),
                child: const Icon(Icons.bolt, size: 50, color: Color(0xFF00F0FF)),
              ),
              const SizedBox(height: 16),
              const Text(
                'HUSKY VPN',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              _buildLoginAnnouncements(),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'نام کاربری',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF131722),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'رمز عبور',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: const Color(0xFF131722),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
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
                    backgroundColor: const Color(0xFF00F0FF),
                    foregroundColor: const Color(0xFF0A0C14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: const Color(0xFF00F0FF).withOpacity(0.4),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Color(0xFF0A0C14), strokeWidth: 2.5),
                        )
                      : const Text(
                          'ورود به سیستم',
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

class SplitTunnelingScreen extends StatefulWidget {
  const SplitTunnelingScreen({super.key});

  @override
  State<SplitTunnelingScreen> createState() => _SplitTunnelingScreenState();
}

class _SplitTunnelingScreenState extends State<SplitTunnelingScreen> {
  static const Color _background = Color(0xFF0A0C14);
  static const Color _surface = Color(0xFF131722);
  static const Color _accent = Color(0xFF00F0FF);

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
      final selected =
          prefs.getStringList('split_tunneling_selected')?.toSet() ?? <String>{};
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دریافت برنامه‌های نصب‌شده: $e')),
      );
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('split_tunneling_enabled', _enabled);
    await prefs.setStringList(
      'split_tunneling_selected',
      _selectedPackages.toList(),
    );
  }

  Future<void> _toggleApp(String packageName, bool selected) async {
    setState(() {
      if (selected) {
        _selectedPackages.add(packageName);
      } else {
        _selectedPackages.remove(packageName);
      }
    });
    await _save();
  }

  Future<void> _toggleFeature(bool value) async {
    setState(() => _enabled = value);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _apps.where((app) {
      final q = _search.trim().toLowerCase();
      return q.isEmpty ||
          app.name.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          title: const Text('عبور انتخابی برنامه‌ها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accent.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: _accent),
                            SizedBox(width: 8),
                            Text('راهنمای برنامه‌های مستثنا', textAlign: TextAlign.right,
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'برنامه‌هایی که انتخاب می‌کنید از تونل VPN عبور نکرده و با اینترنت عادی کار خواهند کرد (مناسب برای همراه‌بانک‌ها و خدمات داخلی).',
                          textAlign: TextAlign.right,
                          style: TextStyle(height: 1.5, color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SwitchListTile(
                      value: _enabled,
                      activeColor: _accent,
                      title: const Text('فعال‌سازی استثناهای VPN'),
                      subtitle: Text(
                        _enabled ? 'مستثنی‌سازی فعال است' : 'همه برنامه‌ها از VPN استفاده می‌کنند',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      onChanged: _toggleFeature,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        hintText: 'جست‌وجوی برنامه...',
                        hintTextDirection: TextDirection.rtl,
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: _surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filteredApps.isEmpty
                        ? const Center(child: Text('برنامه‌ای پیدا نشد.', style: TextStyle(color: Colors.white54)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: filteredApps.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final app = filteredApps[index];
                              final selected = _selectedPackages.contains(app.packageName);
                              return Container(
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected ? _accent.withOpacity(0.5) : Colors.transparent,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  value: selected,
                                  activeColor: _accent,
                                  checkColor: _background,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  onChanged: _enabled
                                      ? (value) => _toggleApp(app.packageName, value ?? false)
                                      : null,
                                  secondary: app.icon != null
                                      ? Image.memory(app.icon!, width: 34, height: 34,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.android, size: 30))
                                      : const Icon(Icons.android, size: 30),
                                  title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  subtitle: Text(app.packageName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: _background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تنظیمات ذخیره شد؛ برای اعمال تغییرات اتصال VPN را بازنشانی کنید.')),
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('ذخیره و بازگشت', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const String apiBase = 'https://socialmedia-ad.ir/index.php';

  late V2ray flutterV2ray;
  late AnimationController _pulseController;

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
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

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
    _userCheckTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (!mounted || _logoutInProgress) return;
      _fetchUserDataAndCheck();
      _fetchAnnouncement();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userCheckTimer?.cancel();
    _pulseController.dispose();
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
        } else if (state == 'DISCONNECTED' || state == 'STOPPED' || state == 'IDLE') {
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
          activeSessions = Map<String, dynamic>.from(data['active_sessions'] as Map);
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
                'active_sessions': {currentDeviceId: activeSessions[currentDeviceId]},
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

      if (mounted) setState(() {});
      if (_pendingTrafficBytes > 0) _flushPendingTraffic();
    } catch (_) {}
  }

  Future<void> _calculateAndSaveTraffic(int currentUpload, int currentDownload) async {
    if (_userData == null) return;
    final maxGb = double.tryParse(_userData!['max_volume_gb']?.toString() ?? '0') ?? 0;
    if (maxGb <= 0) return;

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
      await _flushPendingTraffic();
    }
  }

  Future<void> _flushPendingTraffic() async {
    if (_trafficUpdateInProgress || _pendingTrafficBytes <= 0) return;
    if (_userData == null) return;

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
    } catch (_) {
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
    } catch (_) {
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
    return value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }

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
    }
  }

  Map<String, dynamic> _baseConfig(Map<String, dynamic> outbound) {
    if (outbound is Map && !outbound.containsKey('tag')) {
      outbound['tag'] = 'proxy';
    }

    return {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'listen': '127.0.0.1',
          'port': 10808,
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true},
          'sniffing': {'enabled': true, 'destOverride': ['http', 'tls', 'quic']},
        }
      ],
      'outbounds': [
        outbound,
        {'protocol': 'freedom', 'tag': 'direct'}
      ],
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': [
          {'type': 'field', 'domain': ['full:socialmedia-ad.ir'], 'outboundTag': 'direct'}
        ]
      },
      'mux': {'enabled': true, 'concurrency': 8},
    };
  }

  Map<String, dynamic> _applyApiDirectRouting(Map<String, dynamic> source) {
    final config = Map<String, dynamic>.from(source);
    final rawOutbounds = config['outbounds'];
    final outbounds = rawOutbounds is List
        ? rawOutbounds.whereType().map((item) => Map<String, dynamic>.from(item)).toList()
        : >[];

    String? directTag;
    for (final outbound in outbounds) {
      if (outbound['protocol'] == 'freedom' && outbound['tag'] == 'direct') {
        directTag = 'direct';
        break;
      }
    }

    directTag ??= 'api-direct';
    if (!outbounds.any((item) => item['tag'] == directTag)) {
      outbounds.add({'protocol': 'freedom', 'tag': directTag});
    }
    config['outbounds'] = outbounds;

    final rawRouting = config['routing'];
    final routing = rawRouting is Map ? Map<String, dynamic>.from(rawRouting) : <String, dynamic>{};
    final rawRules = routing['rules'];
    final rules = rawRules is List
        ? rawRules.whereType().map((item) => Map<String, dynamic>.from(item)).toList()
        : >[];

    rules.removeWhere((rule) {
      final domains = rule['domain'];
      return rule['type'] == 'field' && domains is List && domains.contains('full:socialmedia-ad.ir');
    });
    rules.insert(0, {
      'type': 'field',
      'domain': ['full:socialmedia-ad.ir'],
      'outboundTag': directTag,
    });

    routing['domainStrategy'] ??= 'AsIs';
    routing['rules'] = rules;
    config['routing'] = routing;
    return config;
  }

  String _parseConfigToJson(String rawUrl) {
    var configUrl = _cleanUrl(rawUrl);
