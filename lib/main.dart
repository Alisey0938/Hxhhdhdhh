import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XrayUltraApp());
}

class XrayUltraApp extends StatelessWidget {
  const XrayUltraApp({super.key});

  static const Color background = Color(0xFF191A26);
  static const Color card = Color(0xFF232638);
  static const Color accent = Color(0xFF8299E8);
  static const Color green = Color(0xFF43A948);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xray Ultra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: green,
          surface: card,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const FirebaseInitScreen(),
    );
  }
}

DatabaseReference get databaseRoot => FirebaseDatabase.instance.ref();

class FirebaseInitScreen extends StatefulWidget {
  const FirebaseInitScreen({super.key});

  @override
  State<FirebaseInitScreen> createState() => _FirebaseInitScreenState();
}

class _FirebaseInitScreenState extends State<FirebaseInitScreen> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const LoginScreen();

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: Colors.redAccent, size: 54),
                const SizedBox(height: 14),
                const Text(
                  'اتصال به Firebase برقرار نشد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'تنظیمات Firebase را بررسی کنید.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => setState(() {
                    _error = null;
                    _ready = false;
                    _initialize();
                  }),
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _asBool(dynamic value, {bool fallback = true}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (value.toLowerCase() == 'false' || value == '0') return false;
      if (value.toLowerCase() == 'true' || value == '1') return true;
    }
    return fallback;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final username = _username.text.trim();
    final password = _password.text;

    try {
      final snapshot = await databaseRoot.child('users').child(username).get();
      if (!snapshot.exists || snapshot.value is! Map) {
        _message('نام کاربری یا رمز عبور صحیح نیست.');
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      if ((data['password']?.toString() ?? '') != password) {
        _message('نام کاربری یا رمز عبور صحیح نیست.');
        return;
      }
      if (!_asBool(data['active'])) {
        _message('حساب کاربری شما غیرفعال است.');
        return;
      }

      final expiry = accountExpiry(data);
      if (expiry != null && !expiry.isAfter(DateTime.now())) {
        _message('اعتبار حساب کاربری شما به پایان رسیده است.');
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(username: username, initialUserData: data),
        ),
      );
    } catch (e) {
      _message('خطا در دریافت اطلاعات حساب. اتصال اینترنت و دسترسی Firebase را بررسی کنید.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFB33A45)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF8299E8);
    const green = Color(0xFF43A948);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 88,
                      width: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: green, width: 2.5),
                      ),
                      child: const Icon(Icons.shield_outlined, size: 48, color: green),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'ورود به Xray Ultra',
                      style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'برای ادامه، وارد حساب کاربری خود شوید',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _username,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: _inputDecoration(
                        'نام کاربری',
                        Icons.person_outline,
                        purple,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'نام کاربری را وارد کنید' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      textDirection: TextDirection.ltr,
                      obscureText: _hidePassword,
                      onFieldSubmitted: (_) => _login(),
                      decoration: _inputDecoration(
                        'رمز عبور',
                        Icons.lock_outline,
                        purple,
                      ).copyWith(
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(
                            _hidePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'رمز عبور را وارد کنید' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'ورود',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, Color accent) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: accent),
      filled: true,
      fillColor: const Color(0xFF1E202D),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF45495C)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.7),
      ),
    );
  }
}

/// Reads supported expiry fields. Numeric timestamps may be seconds or milliseconds.
/// If no expiry timestamp exists, remainingDays is used as a display fallback only.
DateTime? accountExpiry(Map<String, dynamic> data) {
  final value = data['expiresAt'] ?? data['expireAt'] ?? data['expiryTimestamp'];
  if (value is num) {
    final raw = value.toInt();
    return DateTime.fromMillisecondsSinceEpoch(raw < 1000000000000 ? raw * 1000 : raw);
  }
  if (value is String && value.trim().isNotEmpty) {
    final numeric = num.tryParse(value.trim());
    if (numeric != null) {
      final raw = numeric.toInt();
      return DateTime.fromMillisecondsSinceEpoch(
        raw < 1000000000000 ? raw * 1000 : raw,
      );
    }
    return DateTime.tryParse(value.trim());
  }
  return null;
}

class HomeScreen extends StatefulWidget {
  final String username;
  final Map<String, dynamic> initialUserData;

  const HomeScreen({
    super.key,
    required this.username,
    required this.initialUserData,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _background = Color(0xFF191A26);
  static const Color _card = Color(0xFF232638);
  static const Color _accent = Color(0xFF8299E8);
  static const Color _green = Color(0xFF43A948);

  late final FlutterV2ray _v2ray;
  StreamSubscription<DatabaseEvent>? _userSubscription;

  bool _engineReady = false;
  bool _connected = false;
  bool _connecting = false;
  bool _loggingOut = false;
  String _status = 'DISCONNECTED';
  String? _engineError;

  List<Map<String, String>> _configs = [];
  int _selectedIndex = 0;
  final Map<int, String> _ping = {};

  int _lastUpload = 0;
  int _lastDownload = 0;
  double _usedTrafficMB = 0;
  double _totalTrafficGB = 20;
  int _fallbackRemainingDays = 30;
  DateTime? _expiry;
  bool _accountActive = true;

  DatabaseReference get _userRef =>
      databaseRoot.child('users').child(widget.username);

  @override
  void initState() {
    super.initState();
    _applyUserData(widget.initialUserData, notify: false);
    _initializeEngine();
    _loadConfigs();
    _watchUser();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _applyUserData(
    Map<String, dynamic> data, {
    bool notify = true,
  }) {
    double number(dynamic value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    final used = number(data['usedTrafficMB'], 0).clamp(0, double.infinity).toDouble();
    final total = number(data['totalTrafficGB'], 20).clamp(0, double.infinity).toDouble();
    final days = int.tryParse('${data['remainingDays'] ?? 30}') ?? 30;
    final expiry = accountExpiry(data);
    final active = data['active'] == null
        ? true
        : (data['active'] == true ||
            data['active'] == 1 ||
            data['active'].toString().toLowerCase() == 'true');

    void assign() {
      _usedTrafficMB = used;
      _totalTrafficGB = total;
      _fallbackRemainingDays = days;
      _expiry = expiry;
      _accountActive = active;
    }

    if (notify && mounted) {
      setState(assign);
    } else {
      assign();
    }
  }

  int get _remainingDays {
    if (_expiry != null) {
      final difference = _expiry!.difference(DateTime.now()).inSeconds;
      if (difference <= 0) return 0;
      return (difference / Duration.secondsPerDay).ceil();
    }
    return _fallbackRemainingDays < 0 ? 0 : _fallbackRemainingDays;
  }

  double get _totalMB => _totalTrafficGB * 1024;
  bool get _quotaExhausted => _totalTrafficGB <= 0 || _usedTrafficMB >= _totalMB;
  bool get _subscriptionExpired => _remainingDays <= 0;

  Future<void> _initializeEngine() async {
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;

        final int upload = status.upload;
        final int download = status.download;
        double deltaMB = 0;

        // Counters may reset when the tunnel restarts. Never write negative deltas.
        if (upload >= _lastUpload) deltaMB += (upload - _lastUpload) / (1024 * 1024);
        if (download >= _lastDownload) deltaMB += (download - _lastDownload) / (1024 * 1024);
        _lastUpload = upload;
        _lastDownload = download;

        setState(() {
          _status = status.state;
          _connected = status.state == 'CONNECTED';
        });

        if (deltaMB > 0) {
          _userRef.update({
            'usedTrafficMB': ServerValue.increment(deltaMB),
            'lastOnline': ServerValue.timestamp,
          }).catchError((_) {});
        }
      },
    );

    try {
      await _v2ray.initializeV2Ray();
      if (mounted) setState(() => _engineReady = true);
    } catch (e) {
      if (mounted) setState(() => _engineError = e.toString());
    }
  }

  void _watchUser() {
    _userSubscription = _userRef.onValue.listen(
      (event) {
        if (!event.snapshot.exists || event.snapshot.value is! Map) {
          _forceLogout('حساب کاربری حذف شده است.');
          return;
        }
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _applyUserData(data);
        final active = data['active'] == null ||
            data['active'] == true ||
            data['active'] == 1 ||
            data['active'].toString().toLowerCase() == 'true';
        final expiry = accountExpiry(data);
        final expired = expiry != null && !expiry.isAfter(DateTime.now());
        final used = double.tryParse('${data['usedTrafficMB'] ?? 0}') ?? 0;
        final total = double.tryParse('${data['totalTrafficGB'] ?? 20}') ?? 20;
        if (!active) {
          _forceLogout('حساب کاربری شما توسط ادمین غیرفعال شده است.');
        } else if (expired) {
          _stopForLimit('اعتبار اشتراک شما به پایان رسیده است.');
        } else if (total <= 0 || used >= total * 1024) {
          _stopForLimit('حجم مجاز حساب شما به پایان رسیده است.');
        }
      },
      onError: (_) => _message('خطا در دریافت تغییرات حساب کاربری.'),
    );
  }

  Future<void> _stopForLimit(String reason) async {
    if (_connected || _connecting) {
      try {
        await _v2ray.stopV2Ray();
      } catch (_) {}
    }
    if (mounted) _message(reason);
  }

  Future<void> _forceLogout(String reason) async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      if (_connected || _connecting) await _v2ray.stopV2Ray();
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason), backgroundColor: const Color(0xFFB33A45)),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _detectType(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.startsWith('vless://')) return 'VLESS';
    if (lower.startsWith('vmess://')) return 'VMESS';
    if (lower.startsWith('trojan://')) return 'TROJAN';
    if (lower.startsWith('ss://')) return 'SHADOWSOCKS';
    if (lower.startsWith('socks://') || lower.startsWith('socks5://')) return 'SOCKS';
    if (lower.startsWith('hysteria2://') || lower.startsWith('hy2://')) return 'HYSTERIA2';
    if (lower.startsWith('tuic://')) return 'TUIC';
    if (lower.startsWith('wireguard://')) return 'WIREGUARD';
    if (lower.startsWith('https://') || lower.startsWith('http://')) return 'SUBSCRIPTION';
    return 'UNKNOWN';
  }

  Future<void> _loadConfigs() async {
    try {
      final snapshot = await databaseRoot.child('configs').get();
      if (!snapshot.exists || snapshot.value == null) {
        if (mounted) setState(() => _configs = []);
        return;
      }

      final parsed = <Map<String, String>>[];

      void add(dynamic raw) {
        String url = '';
        String name = 'سرور اتصال';
        if (raw is String) {
          url = raw.trim();
        } else if (raw is Map) {
          url = (raw['url'] ?? raw['link'] ?? raw['config'] ?? '').toString().trim();
          name = (raw['name'] ?? raw['remark'] ?? name).toString().trim();
        }
        if (url.isEmpty) return;

        final hashIndex = url.indexOf('#');
        if (hashIndex >= 0 && hashIndex < url.length - 1) {
          try {
            final remark = Uri.decodeComponent(url.substring(hashIndex + 1));
            if (remark.isNotEmpty) name = remark;
          } catch (_) {}
        }
        parsed.add({
          'url': url,
          'name': name.isEmpty ? 'سرور اتصال' : name,
          'type': _detectType(url),
        });
      }

      final value = snapshot.value;
      if (value is Map) {
        for (final item in value.values) {
          add(item);
        }
      } else if (value is List) {
        for (final item in value) {
          if (item != null) add(item);
        }
      }

      if (!mounted) return;
      setState(() {
        _configs = parsed;
        if (_selectedIndex >= _configs.length) _selectedIndex = 0;
      });
    } catch (_) {
      _message('دریافت کانفیگ‌ها ناموفق بود. دسترسی Firebase را بررسی کنید.');
    }
  }

  Future<void> _toggleConnection() async {
    if (_connecting) return;

    if (_connected) {
      try {
        await _v2ray.stopV2Ray();
      } catch (_) {
        _message('قطع اتصال با خطا مواجه شد.');
      } finally {
        _lastUpload = 0;
        _lastDownload = 0;
      }
      return;
    }

    if (!_engineReady) {
      _message(_engineError == null
          ? 'موتور اتصال هنوز آماده نیست.'
          : 'موتور اتصال راه‌اندازی نشد: $_engineError');
      return;
    }
    if (!_accountActive) {
      _message('حساب کاربری غیرفعال است.');
      return;
    }
    if (_subscriptionExpired) {
      _message('اعتبار اشتراک شما به پایان رسیده است.');
      return;
    }
    if (_quotaExhausted) {
      _message('حجم مجاز حساب شما به پایان رسیده است.');
      return;
    }
    if (_configs.isEmpty) {
      _message('کانفیگی یافت نشد؛ فهرست را تازه‌سازی کنید.');
      await _loadConfigs();
      return;
    }

    final selected = _configs[_selectedIndex];
    final rawConfig = selected['url']!;
    final type = selected['type']!;

    if (type == 'SUBSCRIPTION') {
      _message('این آدرس اشتراک است، نه لینک کانفیگ تکی. ابتدا اشتراک را به کانفیگ‌ها تبدیل کنید.');
      return;
    }
    if (type == 'UNKNOWN') {
      _message('فرمت این کانفیگ شناسایی نشد.');
      return;
    }

    setState(() => _connecting = true);
    try {
      final permissionGranted = await _v2ray.requestPermission();
      if (!permissionGranted) {
        _message('برای اتصال VPN باید مجوز سیستم را تأیید کنید.');
        return;
      }

      final parsed = FlutterV2ray.parseFromURL(rawConfig);
      await _v2ray.startV2Ray(
        remark: parsed.remark.isNotEmpty ? parsed.remark : selected['name']!,
        config: rawConfig,
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );
    } catch (e) {
      _message('اتصال برقرار نشد. ممکن است این نوع کانفیگ توسط موتور فعلی پشتیبانی نشود.');
      try {
        await _v2ray.stopV2Ray();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _testSelectedPing() async {
    if (!_connected) {
      _message('برای تست تأخیر، ابتدا اتصال را برقرار کنید.');
      return;
    }
    try {
      final delay = await _v2ray.getConnectedServerDelay();
      if (!mounted) return;
      setState(() => _ping[_selectedIndex] = '${delay} ms');
    } catch (_) {
      if (mounted) setState(() => _ping[_selectedIndex] = 'خطا');
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFB33A45)),
    );
  }

  String _shortUrl(String value) {
    if (value.length <= 66) return value;
    return '${value.substring(0, 62)}…';
  }

  @override
  Widget build(BuildContext context) {
    final usedGB = _usedTrafficMB / 1024;
    final connectedColor = _connected ? const Color(0xFF62E6B3) : Colors.white54;
    final statusText = _connecting ? 'CONNECTING' : _status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xray Ultra', style: TextStyle(fontWeight: FontWeight.w500)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'خروج',
            onPressed: () => _forceLogout('از حساب کاربری خارج شدید.'),
            icon: const Icon(Icons.logout, color: Colors.white60),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 14),
            Expanded(
              child: _configs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dns_outlined, size: 44, color: Colors.white38),
                          const SizedBox(height: 12),
                          const Text('کانفیگی برای نمایش وجود ندارد',
                              style: TextStyle(color: Colors.white60)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loadConfigs,
                            icon: const Icon(Icons.refresh),
                            label: const Text('تلاش مجدد'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadConfigs,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                        itemCount: _configs.length,
                        itemBuilder: (context, index) {
                          final item = _configs[index];
                          final selected = index == _selectedIndex;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ServerCard(
                              name: item['name']!,
                              url: _shortUrl(item['url']!),
                              type: item['type']!,
                              ping: _ping[index] ?? '---',
                              selected: selected,
                              onTap: () {
                                if (_connected) {
                                  _message('برای تغییر سرور ابتدا اتصال را قطع کنید.');
                                  return;
                                }
                                setState(() => _selectedIndex = index);
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Container(
              width: double.infinity,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              color: const Color(0xFF26304A),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connectedColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: _testSelectedPing,
                      child: Text(
                        _engineError == null
                            ? '$statusText, [برای تست تأخیر لمس طولانی کنید]'
                            : 'ENGINE ERROR',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 78,
              color: const Color(0xFF151620),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  _BottomAction(
                    icon: Icons.download_for_offline_outlined,
                    label: 'Get Config',
                    onTap: _loadConfigs,
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'حجم: ${usedGB.toStringAsFixed(2)} / ${_totalTrafficGB.toStringAsFixed(1)} GB',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'اعتبار: $_remainingDays روز باقی‌مانده',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _BottomAction(
                    icon: Icons.bolt,
                    label: 'Test',
                    onTap: _testSelectedPing,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: SizedBox(
          width: 76,
          height: 76,
          child: FloatingActionButton(
            heroTag: 'vpnPowerButton',
            backgroundColor: _connected ? const Color(0xFFB33A45) : _green,
            elevation: 5,
            onPressed: _toggleConnection,
            child: _connecting
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.power_settings_new, size: 34, color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _ServerCard extends StatelessWidget {
  final String name;
  final String url;
  final String type;
  final String ping;
  final bool selected;
  final VoidCallback onTap;

  const _ServerCard({
    required this.name,
    required this.url,
    required this.type,
    required this.ping,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF43A948);
    return Material(
      color: const Color(0xFF232638),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 124),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? const Color(0xFF8299E8) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                constraints: const BoxConstraints(minHeight: 120),
                decoration: const BoxDecoration(
                  color: Color(0xFF1D2030),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                  ),
                ),
                alignment: Alignment.center,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    type,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.open_in_new, color: Colors.white54, size: 22),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: green.withOpacity(0.32),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ping,
                        style: const TextStyle(
                          color: Color(0xFF8BD49A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white60, size: 24),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
