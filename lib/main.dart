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
  static const Color bg = Color(0xFF0B0E14);
  static const Color surface = Color(0xFF131822);
  static const Color surfaceAlt = Color(0xFF1A2130);
  static const Color standbyPrimary = Color(0xFFFF2A54);
  static const Color standbySecondary = Color(0xFFFF6B00);
  static const Color activePrimary = Color(0xFF00F0FF);
  static const Color activeSecondary = Color(0xFF00FF9D);
  static const Color borderIdle = Color(0xFF263044);
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
        appBarTheme: const AppBarTheme(
          backgroundColor: HudColors.bg,
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
  bool _isLoadingLoginAnnouncements = true;
  List<Map<String, dynamic>> _loginAnnouncements = [];

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
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where((item) =>
                    item['enabled'] == 1 ||
                    item['enabled'] == true ||
                    item['enabled']?.toString() == '1')
                .toList()
            : [];
      });
    } catch (_) {
      // Login must remain available even if announcements cannot be loaded.
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
              color: HudColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: HudColors.activePrimary.withOpacity(0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (text.isNotEmpty) ...[
                  if (imageUrl.isNotEmpty) const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, height: 1.5),
                  ),
                ],
                if (targetUrl.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: HudColors.activePrimary,
                      ),
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
        backgroundColor: HudColors.standbyPrimary,
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
      backgroundColor: HudColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HudColors.surface,
                  border: Border.all(
                    color: HudColors.activePrimary.withOpacity(0.7),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HudColors.activePrimary.withOpacity(0.22),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 46,
                  color: HudColors.activePrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'HUSKY VPN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'STEALTH TACTICAL ACCESS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.2,
                  color: HudColors.activePrimary.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 28),
              _buildLoginAnnouncements(),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'نام کاربری',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: HudColors.activePrimary,
                    ),
                    filled: true,
                    fillColor: HudColors.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: HudColors.borderIdle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: HudColors.activePrimary),
                    ),
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
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: HudColors.activePrimary,
                    ),
                    filled: true,
                    fillColor: HudColors.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: HudColors.borderIdle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: HudColors.activePrimary),
                    ),
                  ),
                  onSubmitted: (_) => _isLoading ? null : _login(),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HudColors.activePrimary,
                    foregroundColor: HudColors.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 6,
                    shadowColor: HudColors.activePrimary.withOpacity(0.4),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: HudColors.bg,
                          ),
                        )
                      : const Text(
                          'ورود به سیستم',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
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
          prefs.getStringList('split_tunneling_selected')?.toSet() ??
              <String>{};
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
        backgroundColor: HudColors.bg,
        appBar: AppBar(
          backgroundColor: HudColors.bg,
          title: const Text(
            'عبور انتخابی برنامه‌ها',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: HudColors.activePrimary),
              )
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HudColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: HudColors.activePrimary.withOpacity(0.4),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: HudColors.activePrimary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'راهنمای برنامه‌های مستثنا از VPN',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'برنامه‌هایی را که نمی‌خواهید از VPN استفاده کنند، در فهرست زیر انتخاب کنید. ترافیک این برنامه‌ها از اینترنت عادی دستگاه عبور می‌کند و سایر برنامه‌ها از VPN استفاده خواهند کرد. لطفاً برنامه‌های ایرانی و داخلی، به‌خصوص همراه‌بانک‌ها، اپلیکیشن‌های بانکی، پرداخت و خدمات دولتی را انتخاب کنید تا از VPN عبور نکنند.',
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(height: 1.6, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: HudColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: HudColors.borderIdle),
                    ),
                    child: SwitchListTile(
                      value: _enabled,
                      activeColor: HudColors.activePrimary,
                      title: const Text('فعال‌سازی استثناهای VPN'),
                      subtitle: Text(
                        _enabled
                            ? 'برنامه‌های انتخاب‌شده از VPN استفاده نمی‌کنند.'
                            : 'در حالت خاموش، همه برنامه‌ها از VPN استفاده می‌کنند.',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
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
                        prefixIcon: const Icon(
                          Icons.search,
                          color: HudColors.activePrimary,
                        ),
                        filled: true,
                        fillColor: HudColors.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: HudColors.borderIdle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: HudColors.activePrimary),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'تعداد برنامه‌ها: ${filteredApps.length}',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(color: Colors.white60),
                        ),
                        const Spacer(),
                        Text(
                          'برنامه‌های مستثنا: ${_selectedPackages.length}',
                          textDirection: TextDirection.rtl,
                          style:
                              const TextStyle(color: HudColors.activePrimary),
                        ),
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
                              final selected =
                                  _selectedPackages.contains(app.packageName);
                              return Container(
                                decoration: BoxDecoration(
                                  color: HudColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? HudColors.activePrimary
                                            .withOpacity(0.5)
                                        : HudColors.borderIdle,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  value: selected,
                                  activeColor: HudColors.activePrimary,
                                  checkColor: HudColors.bg,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: _enabled
                                      ? (value) => _toggleApp(
                                            app.packageName,
                                            value ?? false,
                                          )
                                      : null,
                                  secondary: app.icon != null
                                      ? Image.memory(
                                          app.icon!,
                                          width: 34,
                                          height: 34,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.android,
                                                  size: 30),
                                        )
                                      : const Icon(Icons.android, size: 30),
                                  title: Text(
                                    app.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    app.packageName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HudColors.activePrimary,
                            foregroundColor: HudColors.bg,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تنظیمات ذخیره شد؛ برای اعمال آن‌ها VPN را قطع و دوباره وصل کنید.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text(
                            'ذخیره و بازگشت',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
  List<Map<String, dynamic>> _announcementData = [];

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
    } catch (e) {
      debugPrint('V2Ray initialization failed: $e');
    }
  }

  Future<void> _fetchAnnouncement() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBase?action=get_app_announcements'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 || response.body.trim() == 'null') {
        return;
      }

      final dynamic data = json.decode(response.body);

      if (mounted && data is List) {
        setState(() {
          _announcementData = data
              .whereType<Map>()
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
          backgroundColor: HudColors.standbyPrimary,
        ),
      );
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String get _selectedConfigPreferenceKey =>
      'husky_selected_config_${widget.userId}';

  Future<String?> _loadSavedSelectedConfigId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedConfigPreferenceKey);
    } catch (e) {
      debugPrint('Selected config restore failed: $e');
      return null;
    }
  }

  Future<void> _saveSelectedConfigId(String configId) async {
    if (configId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedConfigPreferenceKey, configId);
    } catch (e) {
      debugPrint('Selected config save failed: $e');
    }
  }

  Future<void> _fetchConfigs() async {
    if (mounted) setState(() => _isLoading = true);

    // Restore the previous selection before the server list is populated.
    final savedSelectedConfigId = await _loadSavedSelectedConfigId();

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

        if (_configs.isNotEmpty) {
          final savedSelectionExists = savedSelectedConfigId != null &&
              _configs.any((item) => _configId(item) == savedSelectedConfigId);
          final currentSelectionExists = _selectedConfigId != null &&
              _configs.any((item) => _configId(item) == _selectedConfigId);

          if (!currentSelectionExists) {
            _selectedConfigId = savedSelectionExists
                ? savedSelectedConfigId
                : _configId(_configs.first);
          }
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
        final fingerprint = _firstQueryValue(rawQuery, ['fp', 'fingerprint']);
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
        final fingerprint = _firstQueryValue(rawQuery, ['fp', 'fingerprint']);
        final publicKey = _firstQueryValue(rawQuery, ['pbk', 'publicKey']);
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
    if (!outbound.containsKey('tag')) {
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
      'mux': {
        'enabled': true,
        'concurrency': 8,
      },
    };
  }

  Map<String, dynamic> _applyApiDirectRouting(Map<String, dynamic> source) {
    final config = Map<String, dynamic>.from(source);

    final rawOutbounds = config['outbounds'];
    final outbounds = rawOutbounds is List
        ? rawOutbounds
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    String? directTag;
    for (final outbound in outbounds) {
      if (outbound['protocol'] == 'freedom' && outbound['tag'] == 'direct') {
        directTag = 'direct';
        break;
      }
    }

    if (directTag == null) {
      for (final outbound in outbounds) {
        if (outbound['protocol'] == 'freedom' &&
            outbound['tag'] == 'api-direct') {
          directTag = 'api-direct';
          break;
        }
      }
    }

    if (directTag == null) {
      directTag = 'api-direct';
      var candidate = directTag;
      var suffix = 2;
      while (outbounds.any((item) => item['tag'] == candidate)) {
        candidate = 'api-direct-$suffix';
        suffix++;
      }
      directTag = candidate;
      outbounds.add({'protocol': 'freedom', 'tag': directTag});
    }
    config['outbounds'] = outbounds;

    final rawInbounds = config['inbounds'];
    if (rawInbounds is List) {
      config['inbounds'] = rawInbounds.whereType<Map>().map((item) {
        final inbound = Map<String, dynamic>.from(item);
        final rawSniffing = inbound['sniffing'];
        final sniffing = rawSniffing is Map
            ? Map<String, dynamic>.from(rawSniffing)
            : <String, dynamic>{};
        sniffing['enabled'] = true;
        final rawOverrides = sniffing['destOverride'];
        final overrides = rawOverrides is List
            ? rawOverrides.map((value) => value.toString()).toList()
            : <String>[];
        for (final protocol in const ['http', 'tls', 'quic']) {
          if (!overrides.contains(protocol)) overrides.add(protocol);
        }
        sniffing['destOverride'] = overrides;
        inbound['sniffing'] = sniffing;
        return inbound;
      }).toList();
    }

    final rawRouting = config['routing'];
    final routing = rawRouting is Map
        ? Map<String, dynamic>.from(rawRouting)
        : <String, dynamic>{};
    final rawRules = routing['rules'];
    final rules = rawRules is List
        ? rawRules
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    rules.removeWhere((rule) {
      final domains = rule['domain'];
      return rule['type'] == 'field' &&
          domains is List &&
          domains.contains('full:socialmedia-ad.ir');
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

    if (configUrl.isEmpty) {
      throw const FormatException('Config is empty');
    }

    try {
      final decodedJson = json.decode(configUrl);
      if (decodedJson is Map) {
        return json.encode(
          _applyApiDirectRouting(Map<String, dynamic>.from(decodedJson)),
        );
      }
      if (decodedJson is List) {
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
      if (decodedJson is Map) {
        return json.encode(
          _applyApiDirectRouting(Map<String, dynamic>.from(decodedJson)),
        );
      }
      if (decodedJson is List) {
        return json.encode(decodedJson);
      }
    } catch (_) {}

    final Uri uri;

    try {
      uri = Uri.parse(configUrl);
    } catch (_) {
      return V2ray.parseFromURL(configUrl).getFullConfiguration();
    }

    final scheme = uri.scheme.toLowerCase();
    final query = _rawQueryParametersPreservePlus(uri);
    final network = _firstQueryValue(query, ['type', 'network']).toLowerCase();
    final security = _firstQueryValue(query, ['security']).toLowerCase();

    if (network == 'ws' &&
        (scheme == 'vless' || scheme == 'vmess' || scheme == 'trojan')) {
      final serverHost = uri.host;
      final port = uri.hasPort ? uri.port : 443;
      final userInfo = Uri.decodeComponent(uri.userInfo);

      if (serverHost.isEmpty || userInfo.isEmpty) {
        throw const FormatException('WebSocket config has no server or user ID');
      }

      final transportHostValue = _firstQueryValue(query, ['host', 'authority']);
      final transportHost =
          transportHostValue.isNotEmpty ? transportHostValue : serverHost;
      final pathValue = _firstQueryValue(query, ['path']);
      final path = pathValue.isNotEmpty ? pathValue : '/';
      final wsSecurity = security.isEmpty ? 'none' : security;

      final outbound = <String, dynamic>{
        'protocol': scheme,
        'settings': <String, dynamic>{},
        'streamSettings': <String, dynamic>{
          'network': 'ws',
          'security': wsSecurity,
          'wsSettings': <String, dynamic>{
            'path': path,
            'host': transportHost,
            'headers': <String, dynamic>{'Host': transportHost},
          },
        },
      };

      final settings = outbound['settings'] as Map<String, dynamic>;
      if (scheme == 'trojan') {
        settings['servers'] = [
          {'address': serverHost, 'port': port, 'password': userInfo},
        ];
      } else if (scheme == 'vmess') {
        settings['vnext'] = [
          {
            'address': serverHost,
            'port': port,
            'users': [
              {
                'id': userInfo,
                'alterId': int.tryParse(query['aid'] ?? '0') ?? 0,
                'security': _firstQueryValue(query, ['scy', 'securityMethod'])
                        .isNotEmpty
                    ? _firstQueryValue(query, ['scy', 'securityMethod'])
                    : 'auto',
              },
            ],
          },
        ];
      } else {
        settings['vnext'] = [
          {
            'address': serverHost,
            'port': port,
            'users': [
              {
                'id': userInfo,
                'encryption': _firstQueryValue(query, ['encryption']).isNotEmpty
                    ? _firstQueryValue(query, ['encryption'])
                    : 'none',
                if (_firstQueryValue(query, ['flow']).isNotEmpty)
                  'flow': _firstQueryValue(query, ['flow']),
              },
            ],
          },
        ];
      }

      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      if (wsSecurity == 'tls') {
        final tls = <String, dynamic>{};
        final sni = _firstQueryValue(query, ['sni', 'serverName']);
        final fingerprint = _firstQueryValue(query, ['fp', 'fingerprint']);
        final alpn = _firstQueryValue(query, ['alpn']);
        final ech = _firstQueryValue(query, ['echConfigList', 'ech']);
        final vcn = _firstQueryValue(query, ['vcn', 'verifyPeerCertByName']);
        final pcs = _firstQueryValue(query, ['pcs', 'pinnedPeerCertSha256']);

        tls['serverName'] = sni.isNotEmpty ? sni : transportHost;
        if (fingerprint.isNotEmpty) tls['fingerprint'] = fingerprint;
        if (alpn.isNotEmpty) tls['alpn'] = _splitCsv(alpn);
        if (ech.isNotEmpty) tls['echConfigList'] = ech;
        if (vcn.isNotEmpty) tls['verifyPeerCertByName'] = vcn;
        if (pcs.isNotEmpty) tls['pinnedPeerCertSha256'] = pcs;
        stream['tlsSettings'] = tls;
      } else if (wsSecurity == 'reality') {
        final sni = _firstQueryValue(query, ['sni', 'serverName']);
        final fingerprint = _firstQueryValue(query, ['fp', 'fingerprint']);
        final reality = <String, dynamic>{
          'show': false,
          'serverName': sni.isNotEmpty ? sni : transportHost,
          'fingerprint': fingerprint.isNotEmpty ? fingerprint : 'chrome',
        };
        final publicKey = _firstQueryValue(query, ['pbk', 'publicKey']);
        final shortId = _firstQueryValue(query, ['sid', 'shortId']);
        final spiderX = _firstQueryValue(query, ['spx', 'spiderX']);
        final mldsa = _firstQueryValue(query, ['pqv', 'mldsa65Verify']);
        if (publicKey.isNotEmpty) reality['publicKey'] = publicKey;
        if (shortId.isNotEmpty) reality['shortId'] = shortId;
        if (spiderX.isNotEmpty) reality['spiderX'] = spiderX;
        if (mldsa.isNotEmpty) reality['mldsa65Verify'] = mldsa;
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

      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      final xhttp = stream['xhttpSettings'] as Map<String, dynamic>;

      final extra = query['extra'];
      if (extra != null && extra.trim().isNotEmpty) {
        try {
          xhttp['extra'] = json.decode(extra);
        } catch (_) {}
      }

      if (security == 'tls') {
        final tls = <String, dynamic>{};

        final sni = _firstQueryValue(query, ['sni', 'serverName']);
        final fingerprint = _firstQueryValue(query, ['fp', 'fingerprint']);
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
          'serverName':
              _firstQueryValue(query, ['sni', 'serverName']).isNotEmpty
                  ? _firstQueryValue(query, ['sni', 'serverName'])
                  : transportHost,
          'fingerprint':
              _firstQueryValue(query, ['fp', 'fingerprint']).isNotEmpty
                  ? _firstQueryValue(query, ['fp', 'fingerprint'])
                  : 'chrome',
        };

        final publicKey = _firstQueryValue(query, ['pbk', 'publicKey']);
        final shortId = _firstQueryValue(query, ['sid', 'shortId']);
        final spiderX = _firstQueryValue(query, ['spx', 'spiderX']);
        final mldsa = _firstQueryValue(query, ['pqv', 'mldsa65Verify']);

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
        final idA = _configId(a);
        final idB = _configId(b);

        // Keep the selected server pinned at the top; sort the rest by ping.
        final selectedA = idA == _selectedConfigId;
        final selectedB = idB == _selectedConfigId;
        if (selectedA != selectedB) return selectedA ? -1 : 1;

        final pingA = _pings[idA] ?? -1;
        final pingB = _pings[idB] ?? -1;
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
    if (_selectedConfigId != null) {
      await _saveSelectedConfigId(_selectedConfigId!);
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

      final remark =
          (selectedConfig['name'] ?? 'Xray Server').toString().trim().isNotEmpty
              ? (selectedConfig['name'] ?? 'Xray Server').toString().trim()
              : 'Xray Server';

      List<String>? blockedApps;
      if (Platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();
        final splitEnabled = prefs.getBool('split_tunneling_enabled') ?? false;
        if (splitEnabled) {
          final selectedPackages =
              prefs.getStringList('split_tunneling_selected')?.toSet() ??
                  <String>{};
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

      if (!_isConnected) {
        setState(() => _isConnectingProcess = false);
        if (mounted && !_isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'هسته اتصال را تأیید نکرد. لاگ‌های [XRAY_CORE] را از Debug Console بررسی کنید.',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        }
      } else {
        setState(() => _isConnectingProcess = false);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در اتصال: $e'),
          backgroundColor: HudColors.standbyPrimary,
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
    if (value.startsWith('ss://') || value.startsWith('shadowsocks://')) {
      return 'SS';
    }
    if (value.startsWith('socks://')) return 'SOCKS';
    if (value.startsWith('hysteria2://') || value.startsWith('hy2://')) {
      return 'HY2';
    }
    if (value.startsWith('hysteria://')) return 'HYSTERIA';
    if (value.startsWith('tuic://')) return 'TUIC';
    if (value.startsWith('wireguard://')) return 'WG';
    if (value.startsWith('anytls://')) return 'ANYTLS';

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
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  } catch (_) {}
                },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 6,
              bottom: 4,
            ),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HudColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: HudColors.activePrimary.withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (text.isNotEmpty || hasLink) ...[
                  if (imageUrl.isNotEmpty) const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (text.isNotEmpty)
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                      if (hasLink) ...[
                        if (text.isNotEmpty) const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: HudColors.activePrimary.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                                color: HudColors.activePrimary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'مشاهده لینک',
                                style: TextStyle(
                                  color: HudColors.activePrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHudConnectReactor(Color accentColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HudColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.12),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _toggleMainConnection,
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _shockwaveController,
                        builder: (context, _) {
                          if (_shockwaveController.isDismissed) {
                            return const SizedBox.shrink();
                          }
                          return Transform.scale(
                            scale: _shockwaveScale.value,
                            child: Opacity(
                              opacity: _shockwaveOpacity.value,
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isConnected
                              ? accentColor.withOpacity(0.18)
                              : HudColors.surfaceAlt,
                          border: Border.all(color: accentColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.35),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: _isConnectingProcess
                            ? Padding(
                                padding: const EdgeInsets.all(15),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: accentColor,
                                ),
                              )
                            : Icon(
                                Icons.power_settings_new_rounded,
                                color: accentColor,
                                size: 30,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor,
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnectingProcess
                              ? 'CONNECTING...'
                              : _isConnected
                                  ? 'CONNECTED // SECURE'
                                  : 'STANDBY // READY',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: HudColors.bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: HudColors.borderIdle),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 14,
                                  color: _isConnected
                                      ? HudColors.activeSecondary
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _currentDownloadSpeed,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: HudColors.bg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: HudColors.borderIdle),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 14,
                                  color: _isConnected
                                      ? HudColors.activePrimary
                                      : Colors.white38,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _currentUploadSpeed,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxGb =
        double.tryParse(_userData?['max_volume_gb']?.toString() ?? '0') ?? 0;

    final usedGb =
        maxGb > 0 ? _accumulatedUsedBytes / (1024 * 1024 * 1024) : 0.0;

    final accentColor = _isConnected
        ? HudColors.activePrimary
        : HudColors.standbyPrimary;

    return Scaffold(
      backgroundColor: HudColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            automaticallyImplyLeading: false,
            leading: Builder(
              builder: (context) => IconButton(
                tooltip: 'منو',
                icon: const Icon(Icons.menu, color: Colors.white70),
                onPressed: () {
                  final screenWidth = MediaQuery.of(context).size.width;
                  showGeneralDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'منوی اصلی',
                    barrierColor: Colors.black54,
                    transitionDuration: const Duration(milliseconds: 220),
                    pageBuilder:
                        (dialogContext, animation, secondaryAnimation) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Material(
                          color: HudColors.surface,
                          elevation: 16,
                          child: SizedBox(
                            width: screenWidth * 0.58,
                            height: double.infinity,
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: SafeArea(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(18, 24, 18, 18),
                                      child: Text(
                                        'منوی اصلی',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: HudColors.borderIdle,
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.shield_outlined,
                                        color: HudColors.activePrimary,
                                      ),
                                      title: const Text(
                                        'عبور انتخابی برنامه‌ها',
                                        textAlign: TextAlign.right,
                                      ),
                                      subtitle: const Text(
                                        'مدیریت برنامه‌های خارج از VPN',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.of(dialogContext).pop();
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const SplitTunnelingScreen(),
                                          ),
                                        );
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
                    transitionBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final slide = Tween<Offset>(
                        begin: const Offset(-1, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      );
                      return SlideTransition(position: slide, child: child);
                    },
                  );
                },
              ),
            ),
            title: Column(
              children: [
                const Text(
                  'HUSKY VPN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'CORE // $_coreVersion',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: accentColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: HudColors.standbyPrimary),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: HudColors.surface,
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
                            style: TextStyle(color: HudColors.standbyPrimary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHudConnectReactor(accentColor),
          _buildAnnouncementBanner(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: accentColor),
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
                                    content: Text(
                                      'لطفاً ابتدا اتصال فعلی را قطع کنید.',
                                    ),
                                    backgroundColor: HudColors.standbySecondary,
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                _selectedConfigId = configId;
                              });
                              unawaited(_saveSelectedConfigId(configId));
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(bottom: 9),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? HudColors.surfaceAlt
                                    : HudColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor
                                      : HudColors.borderIdle,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accentColor.withOpacity(0.16)
                                            : Colors.black26,
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
                                            color: isSelected
                                                ? accentColor
                                                : Colors.white38,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
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
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
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
                                                  ? HudColors.activeSecondary
                                                      .withOpacity(0.15)
                                                  : HudColors.standbyPrimary
                                                      .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: pingLoading
                                                ? Colors.white24
                                                : ping > 0
                                                    ? HudColors.activeSecondary
                                                        .withOpacity(0.5)
                                                    : HudColors.standbyPrimary
                                                        .withOpacity(0.5),
                                          ),
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
                                                    ? HudColors.activeSecondary
                                                    : HudColors.standbyPrimary,
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
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: HudColors.surface,
          border: Border(
            top: BorderSide(color: HudColors.borderIdle, width: 1),
          ),
        ),
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
                    color: HudColors.activePrimary,
                    size: 20,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Get Config',
                    style: TextStyle(
                      color: Colors.white70,
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
                    color: Colors.white.withOpacity(0.9),
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
                        ? HudColors.standbySecondary
                        : HudColors.activeSecondary,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isTestingAllPings ? 'Testing...' : 'Test',
                    style: const TextStyle(
                      color: Colors.white70,
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
