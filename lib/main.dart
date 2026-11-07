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

class HudTheme {
  static const Color background = Color(0xFF080B12);
  static const Color surface = Color(0xFF0D111C);
  static const Color cardBg = Color(0xFF0F1320);
  static const Color crimson = Color(0xFFFF2E54);
  static const Color amber = Color(0xFFFF8A00);
  static const Color cyan = Color(0xFF00F2FE);
  static const Color emerald = Color(0xFF00FF9D);
  static const Color borderLight = Color(0x1FFFFFFF);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUSKY VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: HudTheme.background,
        colorScheme: const ColorScheme.dark(
          primary: HudTheme.cyan,
          surface: HudTheme.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: HudTheme.surface,
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
        child: CircularProgressIndicator(color: HudTheme.cyan),
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
  bool _isLoadingLoginAnnouncements = true;
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
        if (data is List) {
          _loginAnnouncements = data
              .whereType()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) => item['enabled'] == 1 ||
                  item['enabled'] == true ||
                  item['enabled']?.toString() == '1')
              .toList();
        } else {
          _loginAnnouncements = [];
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLoginAnnouncements = false);
    }
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HudTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HudTheme.amber.withOpacity(0.5)),
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
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (text.isNotEmpty) ...[
                  if (imageUrl.isNotEmpty) const SizedBox(height: 8),
                  Text(text, textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white, height: 1.5)),
                ],
                if (targetUrl.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.open_in_new, size: 16, color: HudTheme.amber),
                    ),
                  ),
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
        backgroundColor: HudTheme.crimson,
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: HudTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: HudTheme.crimson.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: HudTheme.crimson.withOpacity(0.2),
                      blurRadius: 20,
                    )
                  ],
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  size: 60,
                  color: HudTheme.crimson,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'HUSKY VPN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
              ),
              const Text(
                'STEALTH-JET ACCESS',
                style: TextStyle(
                  fontSize: 10,
                  color: HudTheme.amber,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildLoginAnnouncements(),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'نام کاربری',
                  filled: true,
                  fillColor: HudTheme.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HudTheme.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HudTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HudTheme.cyan),
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
                  fillColor: HudTheme.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HudTheme.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HudTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HudTheme.cyan),
                  ),
                ),
                onSubmitted: (_) => _isLoading ? null : _login(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [HudTheme.crimson, HudTheme.amber],
                    ),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
      return q.isEmpty || app.name.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: HudTheme.background,
        appBar: AppBar(
          backgroundColor: HudTheme.surface,
          title: const Text('عبور انتخابی برنامه‌ها', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: HudTheme.cyan))
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HudTheme.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: HudTheme.cyan.withOpacity(0.45)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: HudTheme.cyan, size: 20),
                            SizedBox(width: 8),
                            Text('راهنمای برنامه‌های مستثنا از VPN', textAlign: TextAlign.right,
                                style: TextStyle(fontWeight: FontWeight.bold, color: HudTheme.cyan, fontSize: 13)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'برنامه‌هایی را که نمی‌خواهید از VPN استفاده کنند، در فهرست زیر انتخاب کنید. ترافیک این برنامه‌ها از اینترنت عادی دستگاه عبور می‌کند. پیشنهاد می‌شود همراه‌بانک‌ها و خدمات دولتی را انتخاب کنید.',
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(height: 1.5, color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: HudTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HudTheme.borderLight),
                    ),
                    child: SwitchListTile(
                      value: _enabled,
                      activeColor: HudTheme.cyan,
                      title: const Text('فعال‌سازی استثناهای VPN', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                        _enabled
                            ? 'برنامه‌های انتخاب‌شده از VPN استفاده نمی‌کنند.'
                            : 'در حالت خاموش، همه برنامه‌ها از VPN استفاده می‌کنند.',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      onChanged: _toggleFeature,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        hintText: 'جست‌وجوی برنامه...',
                        hintTextDirection: TextDirection.rtl,
                        prefixIcon: const Icon(Icons.search, color: HudTheme.cyan),
                        filled: true,
                        fillColor: HudTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text('تعداد کل: ${filteredApps.length}', textDirection: TextDirection.rtl,
                            style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        const Spacer(),
                        Text('برنامه‌های مستثنا: ${_selectedPackages.length}', textDirection: TextDirection.rtl,
                            style: const TextStyle(color: HudTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredApps.isEmpty
                        ? const Center(child: Text('برنامه‌ای پیدا نشد.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: filteredApps.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final app = filteredApps[index];
                              final selected = _selectedPackages.contains(app.packageName);
                              return Container(
                                decoration: BoxDecoration(
                                  color: HudTheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected ? HudTheme.cyan : HudTheme.borderLight,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  value: selected,
                                  activeColor: HudTheme.cyan,
                                  checkColor: HudTheme.background,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  onChanged: _enabled
                                      ? (value) => _toggleApp(app.packageName, value ?? false)
                                      : null,
                                  secondary: app.icon != null
                                      ? Image.memory(app.icon!, width: 32, height: 32,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.android, size: 28))
                                      : const Icon(Icons.android, size: 28),
                                  title: Text(app.name, maxLines: 1,
                                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(app.packageName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 10)),
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [HudTheme.cyan, HudTheme.emerald],
                          ),
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تنظیمات ذخیره شد؛ برای اعمال آن‌ها VPN را قطع و دوباره وصل کنید.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check, color: HudTheme.background),
                          label: const Text('ذخیره و بازگشت', style: TextStyle(color: HudTheme.background, fontWeight: FontWeight.bold)),
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
      const Duration(minutes: 3),
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
    } catch (e) {
      debugPrint('V2Ray initialization failed: $e');
    }
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
        SnackBar(
          content: Text(reason),
          backgroundColor: HudTheme.crimson,
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
      if (item is! Map) continue;
      if (item['protocol']?.toString().toLowerCase() != 'vless') continue;

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
        final oldTls = stream['tlsSettings'];
        final tls = oldTls is Map ? Map<String, dynamic>.from(oldTls) : <String, dynamic>{};

        final sni = _firstQueryValue(rawQuery, ['sni', 'serverName']);
        final fingerprint = _firstQueryValue(rawQuery, ['fp', 'fingerprint']);
        final alpn = _firstQueryValue(rawQuery, ['alpn']);

        if (sni.isNotEmpty) tls['serverName'] = sni;
        if (fingerprint.isNotEmpty) tls['fingerprint'] = fingerprint;
        if (alpn.isNotEmpty) tls['alpn'] = _splitCsv(alpn);

        stream['security'] = 'tls';
        stream['tlsSettings'] = tls;
        stream.remove('realitySettings');
      } else if (security == 'reality') {
        final oldReality = stream['realitySettings'];
        final reality = oldReality is Map ? Map<String, dynamic>.from(oldReality) : <String, dynamic>{};

        final sni = _firstQueryValue(rawQuery, ['sni', 'serverName']);
        final fingerprint = _firstQueryValue(rawQuery, ['fp', 'fingerprint']);
        final publicKey = _firstQueryValue(rawQuery, ['pbk', 'publicKey']);
        final shortId = _firstQueryValue(rawQuery, ['sid', 'shortId']);

        reality['show'] = false;
        if (sni.isNotEmpty) reality['serverName'] = sni;
        if (fingerprint.isNotEmpty) reality['fingerprint'] = fingerprint;
        if (publicKey.isNotEmpty) reality['publicKey'] = publicKey;
        if (shortId.isNotEmpty) reality['shortId'] = shortId;

        stream['security'] = 'reality';
        stream['realitySettings'] = reality;
        stream.remove('tlsSettings');
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
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls', 'quic'],
          },
        }
      ],
      'outbounds': [
        outbound,
        {'protocol': 'freedom', 'tag': 'direct'}
      ],
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': [
          {
            'type': 'field',
            'domain': ['full:socialmedia-ad.ir'],
            'outboundTag': 'direct'
          }
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

    if (directTag == null) {
      directTag = 'api-direct';
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
    if (configUrl.isEmpty) throw const FormatException('Config is empty');

    try {
      final decodedJson = json.decode(configUrl);
      if (decodedJson is Map) {
        return json.encode(_applyApiDirectRouting(Map<String, dynamic>.from(decodedJson)));
      }
    } catch (_) {}

    final Uri uri = Uri.parse(configUrl);
    final parser = V2ray.parseFromURL(configUrl);
    final generated = parser.getFullConfiguration();

    try {
      final decoded = json.decode(generated);
      if (decoded is Map) {
        final config = Map<String, dynamic>.from(decoded);
        if (uri.scheme.toLowerCase() == 'vless') {
          _patchVlessAdvancedSettings(config, _rawQueryParametersPreservePlus(uri));
        }
        return json.encode(_applyApiDirectRouting(config));
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
    } catch (_) {}

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
      final remark = (selectedConfig['name'] ?? 'Xray Server').toString().trim().isNotEmpty
          ? (selectedConfig['name'] ?? 'Xray Server').toString().trim()
          : 'Xray Server';

      List<String>? blockedApps;
      if (Platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();
        final splitEnabled = prefs.getBool('split_tunneling_enabled') ?? false;
        if (splitEnabled) {
          final selectedPackages =
              prefs.getStringList('split_tunneling_selected')?.toSet() ?? <String>{};
          final installedApps = await InstalledApps.getInstalledApps(
            excludeSystemApps: false,
            excludeNonLaunchableApps: false,
            withIcon: false,
            detectPlatformType: false,
          );
          final installedPackages = installedApps
              .map((app) => app.packageName)
              .where((packageName) => packageName.isNotEmpty)
              .toSet();
          blockedApps = selectedPackages
              .where((packageName) => installedPackages.contains(packageName))
              .toList();
        }
      }

      await flutterV2ray.startV2Ray(
        remark: remark,
        config: configJson,
        blockedApps: blockedApps,
        proxyOnly: false,
      );

      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted || _userWantsDisconnect) return;

      setState(() => _isConnectingProcess = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در اتصال: $e'), backgroundColor: HudTheme.crimson),
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
    if (value.startsWith('hy2://') || value.startsWith('hysteria2://')) return 'HY2';
    return 'XRAY';
  }

  Widget _buildAnnouncementBanner() {
    if (_announcementData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _announcementData.map((announcement) {
        final text = (announcement['text'] ?? '').toString();
        final imageUrl = (announcement['image_url'] ?? '').toString();
        final targetUrl = (announcement['target_url'] ?? '').toString().trim();
        final hasLink = targetUrl.isNotEmpty;

        return GestureDetector(
          onTap: !hasLink
              ? null
              : () async {
                  final uri = Uri.tryParse(targetUrl);
                  if (uri == null || !uri.hasScheme) return;
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  } catch (_) {}
                },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HudTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HudTheme.amber.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover),
                  ),
                if (text.isNotEmpty)
                  Text(text, style: const TextStyle(height: 1.5, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxGb = double.tryParse(_userData?['max_volume_gb']?.toString() ?? '0') ?? 0;
    final usedGb = maxGb > 0 ? _accumulatedUsedBytes / (1024 * 1024 * 1024) : 0.0;
    final progress = maxGb > 0 ? (usedGb / maxGb).clamp(0.0, 1.0) : 0.0;

    final selectedConfig = _configs.firstWhere(
      (item) => _configId(item) == _selectedConfigId,
      orElse: () => _configs.isNotEmpty ? _configs.first : null,
    );
    final selectedName = selectedConfig != null ? selectedConfig['name']?.toString() ?? 'سرور Xray' : 'سرور انتخاب نشده';

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () {
              showGeneralDialog<void>(
                context: context,
                barrierDismissible: true,
                barrierLabel: 'منوی اصلی',
                barrierColor: Colors.black87,
                transitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (dialogContext, _, __) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: HudTheme.surface,
                      child: SizedBox(
                        width: 250,
                        height: double.infinity,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: SafeArea(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Text('منوی اصلی', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HudTheme.cyan)),
                                ),
                                const Divider(color: HudTheme.borderLight),
                                ListTile(
                                  leading: const Icon(Icons.shield_outlined, color: HudTheme.cyan),
                                  title: const Text('عبور انتخابی برنامه‌ها'),
                                  subtitle: const Text('Split Tunneling', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  onTap: () {
                                    Navigator.of(dialogContext).pop();
                                    Navigator.of(context).push(MaterialPageRoute<void>(
                                      builder: (_) => const SplitTunnelingScreen(),
                                    ));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        title: Column(
          children: [
            const Text('HUSKY VPN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            Text('Core: $_coreVersion', style: const TextStyle(fontSize: 10, color: HudTheme.amber)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: HudTheme.crimson),
            onPressed: () => _logoutUser(''),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAnnouncementBanner(),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: HudTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isConnected ? HudTheme.cyan.withOpacity(0.6) : HudTheme.crimson.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isConnected ? HudTheme.cyan.withOpacity(0.15) : HudTheme.crimson.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isConnected ? HudTheme.emerald.withOpacity(0.15) : HudTheme.crimson.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _isConnected ? HudTheme.emerald : HudTheme.crimson),
                      ),
                      child: Text(
                        _isConnected ? 'CONNECTED' : 'DISCONNECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? HudTheme.emerald : HudTheme.crimson,
                        ),
                      ),
                    ),
                    const Icon(Icons.radar_rounded, size: 18, color: Colors.white54),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _toggleMainConnection,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: _isConnected
                            ? [HudTheme.cyan.withOpacity(0.2), HudTheme.surface]
                            : [HudTheme.crimson.withOpacity(0.2), HudTheme.surface],
                      ),
                      border: Border.all(
                        color: _isConnected ? HudTheme.emerald : HudTheme.crimson,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isConnected ? HudTheme.cyan.withOpacity(0.4) : HudTheme.crimson.withOpacity(0.4),
                          blurRadius: 25,
                        )
                      ],
                    ),
                    child: Center(
                      child: _isConnectingProcess
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 46,
                              color: _isConnected ? HudTheme.emerald : HudTheme.crimson,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  selectedName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: HudTheme.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          const Text('↓ دانلود: ', style: TextStyle(fontSize: 11, color: Colors.white60)),
                          Text(
                            _isConnected ? '42.5 Mbps' : '0.0 Mbps',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isConnected ? HudTheme.cyan : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 14, color: HudTheme.borderLight),
                      Row(
                        children: [
                          const Text('↑ آپلود: ', style: TextStyle(fontSize: 11, color: Colors.white60)),
                          Text(
                            _isConnected ? '12.8 Mbps' : '0.0 Mbps',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isConnected ? HudTheme.emerald : Colors.white38,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('لیست سرورها', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: _isTestingAllPings ? null : _testAllPings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: HudTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HudTheme.cyan.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 14, color: _isTestingAllPings ? HudTheme.amber : HudTheme.cyan),
                        const SizedBox(width: 4),
                        Text(
                          _isTestingAllPings ? 'در حال پینگ...' : 'تست پینگ همه',
                          style: const TextStyle(fontSize: 11, color: HudTheme.cyan, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: HudTheme.cyan))
                : _configs.isEmpty
                    ? const Center(child: Text('سروری یافت نشد.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        itemCount: _configs.length,
                        itemBuilder: (context, index) {
                          final item = _configs[index];
                          final configId = _configId(item);
                          final isSelected = _selectedConfigId == configId;
                          final ping = _pings[configId] ?? -1;
                          final pingLoading = _pingLoading[configId] ?? false;
                          final protocol = _getProtocolType((item['config'] ?? '').toString());

                          return GestureDetector(
                            onTap: () {
                              if (_isConnected) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ابتدا اتصال فعلی را قطع کنید.')),
                                );
                                return;
                              }
                              setState(() => _selectedConfigId = configId);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? HudTheme.surface : HudTheme.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? HudTheme.cyan : HudTheme.borderLight,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(11),
                                        bottomRight: Radius.circular(11),
                                      ),
                                    ),
                                    child: Text(
                                      protocol,
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: HudTheme.amber),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      (item['name'] ?? 'سرور Xray').toString(),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: ping > 0 && ping < 150 ? HudTheme.emerald.withOpacity(0.15) : HudTheme.crimson.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        pingLoading ? '...' : (ping > 0 ? '${ping}ms' : '-1ms'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: ping > 0 && ping < 150 ? HudTheme.emerald : HudTheme.crimson,
                                        ),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: HudTheme.surface,
              border: Border(top: BorderSide(color: HudTheme.borderLight)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: HudTheme.cyan, size: 20),
                  onPressed: _fetchConfigs,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            maxGb > 0 ? '${usedGb.toStringAsFixed(1)} / ${maxGb.toStringAsFixed(0)} GB' : 'حجم نامحدود',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(_remainingTimeText, style: const TextStyle(fontSize: 11, color: HudTheme.emerald)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          color: HudTheme.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
