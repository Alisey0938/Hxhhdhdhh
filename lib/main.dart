import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XrayUltraApp());
}

class XrayUltraApp extends StatelessWidget {
  const XrayUltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF14171F);
    const Color cardBg = Color(0xFF1E222D);
    const Color primaryPurple = Color(0xFF8A2BE2);
    const Color rubyGreen = Color(0xFF00A86B);

    return MaterialApp(
      title: 'Xray Ultra',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        primaryColor: primaryPurple,
        cardColor: cardBg,
        colorScheme: const ColorScheme.dark(
          primary: primaryPurple,
          secondary: rubyGreen,
          surface: cardBg,
          background: bgDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const FirebaseInitScreen(),
    );
  }
}

// ==================== راه‌اندازی فایربیس ====================
class FirebaseInitScreen extends StatefulWidget {
  const FirebaseInitScreen({super.key});

  @override
  State<FirebaseInitScreen> createState() => _FirebaseInitScreenState();
}

class _FirebaseInitScreenState extends State<FirebaseInitScreen> {
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupFirebase();
  }

  Future<void> _setupFirebase() async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDummyKeyForFirebaseToInitialize12345",
          appId: "1:1234567890:android:abcdef123456",
          messagingSenderId: "1234567890",
          projectId: "pane-dcc9a",
          databaseURL: "https://pane-dcc9a-default-rtdb.firebaseio.com",
        ),
      );
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized) {
      return const LoginScreen();
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 70),
                const SizedBox(height: 16),
                const Text('خطا در اتصال به فایربیس',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8A2BE2)),
                  onPressed: _setupFirebase,
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF00A86B)),
      ),
    );
  }
}

// ==================== صفحه لاگین (مطابق اسکرین‌شات) ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  DatabaseReference get _dbRef => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://pane-dcc9a-default-rtdb.firebaseio.com',
      ).ref();

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar("لطفاً نام کاربری و رمز عبور را وارد کنید");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await _dbRef.child("users").child(username).get();
      if (snapshot.exists && snapshot.value != null) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);

        final String dbPassword = userData['password']?.toString() ?? '';
        final bool isActive = userData['active'] ?? true;

        if (dbPassword != password) {
          _showSnackBar("رمز عبور اشتباه است.");
        } else if (!isActive) {
          _showSnackBar("حساب کاربری شما غیرفعال شده است.");
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(username: username, userData: userData),
            ),
          );
        }
      } else {
        _showSnackBar("کاربری با این مشخصات یافت نشد.");
      }
    } catch (e) {
      _showSnackBar("خطا در برقراری ارتباط با سرور");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color purpleBorder = Color(0xFF8A2BE2);
    const Color rubyGreen = Color(0xFF00A86B);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // لوگوی سپر در اسکرین‌شات
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: rubyGreen, width: 3),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 50,
                  color: rubyGreen,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "ورود به Xray Ultra",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // فایلد نام کاربری
              TextField(
                controller: _usernameController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "نام کاربری",
                  labelStyle: const TextStyle(color: purpleBorder),
                  prefixIcon: const Icon(Icons.person, color: purpleBorder),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: purpleBorder, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: rubyGreen, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1D26),
                ),
              ),
              const SizedBox(height: 16),

              // فیلد رمز عبور
              TextField(
                controller: _passwordController,
                obscureText: true,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "رمز عبور",
                  labelStyle: const TextStyle(color: purpleBorder),
                  prefixIcon: const Icon(Icons.lock, color: purpleBorder),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: purpleBorder, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: rubyGreen, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1D26),
                ),
              ),
              const SizedBox(height: 24),

              // دکمه ورود بنفش
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleBorder,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "ورود",
                          style: TextStyle(
                            fontSize: 18,
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
    );
  }
}

// ==================== صفحه اصلی (اصلی مطابق UI اسکرین‌شات دوم) ====================
class HomeScreen extends StatefulWidget {
  final String username;
  final Map<String, dynamic> userData;

  const HomeScreen({
    super.key,
    required this.username,
    required this.userData,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FlutterV2ray flutterV2ray;
  bool isConnected = false;
  String v2rayStatus = "DISCONNECTED";

  List<Map<String, dynamic>> configItems = [];
  int selectedConfigIndex = 0;
  Map<int, String> pingResults = {};

  int _lastUpload = 0;
  int _lastDownload = 0;
  StreamSubscription<DatabaseEvent>? _userSubscription;

  double usedTrafficMB = 0.0;
  double totalTrafficGB = 20.0;
  int remainingDays = 30;

  DatabaseReference get _dbRef => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://pane-dcc9a-default-rtdb.firebaseio.com',
      ).ref();

  @override
  void initState() {
    super.initState();
    _updateUserDataLocal(widget.userData);
    _initV2RayEngine();
    _fetchConfigsFromFirebase();
    _listenToUserData();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _updateUserDataLocal(Map<String, dynamic> data) {
    setState(() {
      usedTrafficMB = (data['usedTrafficMB'] ?? 0.0).toDouble();
      totalTrafficGB = (data['totalTrafficGB'] ?? 20.0).toDouble();
      remainingDays = data['remainingDays'] ?? 30;
    });
  }

  void _listenToUserData() {
    _userSubscription = _dbRef.child("users").child(widget.username).onValue.listen((event) async {
      if (!event.snapshot.exists) {
        _forceLogout("حساب کاربری شما حذف گردید.");
      } else {
        final userData = Map<String, dynamic>.from(event.snapshot.value as Map);
        final bool isActive = userData['active'] ?? true;
        if (!isActive) {
          _forceLogout("حساب کاربری شما توسط ادمین غیرفعال شد.");
        } else {
          _updateUserDataLocal(userData);
        }
      }
    });
  }

  Future<void> _forceLogout(String reason) async {
    if (isConnected) {
      await flutterV2ray.stopV2Ray();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason), backgroundColor: Colors.redAccent),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _initV2RayEngine() {
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        setState(() {
          v2rayStatus = status.state;
          isConnected = status.state == "CONNECTED";
        });

        if (status.upload > _lastUpload || status.download > _lastDownload) {
          final int deltaUpload = status.upload - _lastUpload;
          final int deltaDownload = status.download - _lastDownload;
          _lastUpload = status.upload;
          _lastDownload = status.download;

          final double deltaMB = (deltaUpload + deltaDownload) / (1024 * 1024);
          if (deltaMB > 0) {
            _dbRef.child("users").child(widget.username).update({
              "usedTrafficMB": ServerValue.increment(deltaMB),
              "lastOnline": ServerValue.timestamp,
            });
          }
        }
      },
    );
    flutterV2ray.initializeV2Ray();
  }

  Future<void> _fetchConfigsFromFirebase() async {
    try {
      final snapshot = await _dbRef.child("configs").get();
      if (snapshot.exists && snapshot.value != null) {
        List<Map<String, dynamic>> parsedList = [];

        void processItem(dynamic raw) {
          String url = "";
          String name = "سرور اتصال";
          String type = "VLESS";

          if (raw is String) {
            url = raw.trim();
          } else if (raw is Map) {
            url = raw['url']?.toString().trim() ?? "";
            name = raw['name']?.toString() ?? "سرور اتصال";
          }

          if (url.isNotEmpty) {
            if (url.startsWith("vless://")) type = "VLESS";
            else if (url.startsWith("vmess://")) type = "VMESS";
            else if (url.startsWith("trojan://")) type = "TROJAN";
            else if (url.startsWith("ss://")) type = "SHADOWSOCKS";

            // استخراج اسم از رمارک کانفیگ در صورت وجود
            if (url.contains("#")) {
              try {
                name = Uri.decodeComponent(url.split("#").last);
              } catch (_) {}
            }

            parsedList.add({
              "url": url,
              "name": name,
              "type": type,
            });
          }
        }

        if (snapshot.value is Map) {
          (snapshot.value as Map).forEach((k, v) => processItem(v));
        } else if (snapshot.value is List) {
          for (var item in snapshot.value as List) {
            if (item != null) processItem(item);
          }
        }

        setState(() {
          configItems = parsedList;
        });
      }
    } catch (e) {
      debugPrint("Error loading configs: $e");
    }
  }

  Future<void> _toggleConnection() async {
    if (isConnected) {
      await flutterV2ray.stopV2Ray();
      _lastUpload = 0;
      _lastDownload = 0;
      return;
    }

    if (configItems.isEmpty) {
      _showSnackBar('کانفیگی یافت نشد! در حال بروزرسانی...');
      _fetchConfigsFromFirebase();
      return;
    }

    final String rawConfig = configItems[selectedConfigIndex]["url"];

    try {
      if (await flutterV2ray.requestPermission()) {
        final V2RayURL parseResult = FlutterV2ray.parseFromURL(rawConfig);

        await flutterV2ray.startV2Ray(
          remark: parseResult.remark.isNotEmpty ? parseResult.remark : "Xray Ultra",
          config: rawConfig,
          blockedApps: null,
          bypassSubnets: null,
          proxyOnly: false,
        );
      }
    } catch (e) {
      _showSnackBar('خطا در برقراری اتصال سرور');
      await flutterV2ray.stopV2Ray();
    }
  }

  Future<void> _testAllPings() async {
    if (!isConnected) {
      _showSnackBar('برای تست پینگ ابتدا اتصال را برقرار کنید.');
      return;
    }

    for (int i = 0; i < configItems.length; i++) {
      try {
        final delay = await flutterV2ray.getConnectedServerDelay();
        setState(() {
          pingResults[i] = "${delay}ms";
        });
      } catch (_) {
        setState(() {
          pingResults[i] = "خطا";
        });
      }
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color rubyGreen = Color(0xFF00A86B);
    const Color borderPurple = Color(0xFF5C6BC0);

    final double usedGB = usedTrafficMB / 1024.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xray Ultra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () => _forceLogout("خروج از حساب کاربری"),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 10),
              // لیست سرورها مطابق طراحی اسکرین‌شات
              Expanded(
                child: configItems.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: rubyGreen))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: configItems.length,
                        itemBuilder: (context, index) {
                          final item = configItems[index];
                          final bool isSelected = selectedConfigIndex == index;
                          final String ping = pingResults[index] ?? "---";

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedConfigIndex = index;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E222D),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? borderPurple : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // برچسب نوع پروتکل (مثلا VLESS)
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                    ),
                                    child: RotatedBox(
                                      quarterTurns: 3,
                                      child: Text(
                                        item['type'],
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // جزییات سرور
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['url'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // مقدار پینگ سبز
                                  Container(
                                    margin: const EdgeInsets.all(10),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: rubyGreen.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      ping,
                                      style: const TextStyle(
                                        color: rubyGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
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

              // نوار آبی متنی وضعیت اتصال
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: const Color(0xFF1B2333),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? rubyGreen : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "$v2rayStatus, [long press->show ip,speed test]",
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // نوار منوی سفارشی پایین صفحه (شامل حجم و دکمه‌ها)
              Container(
                height: 60,
                color: const Color(0xFF14171F),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // دکمه دریافت کانفیگ
                    InkWell(
                      onTap: _fetchConfigsFromFirebase,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.file_download_outlined, color: Colors.white70, size: 20),
                          SizedBox(height: 2),
                          Text("Get Config", style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),

                    // نمایش اطلاعات حجم و اعتبار
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "حجم: ${usedGB.toStringAsFixed(2)} / ${totalTrafficGB.toStringAsFixed(1)} GB",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "اعتبار: $remainingDays روز باقی‌مانده",
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),

                    // دکمه تست پینگ
                    InkWell(
                      onTap: _testAllPings,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on, color: Colors.white70, size: 20),
                          SizedBox(height: 2),
                          Text("Test", style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),

          // دکمه قدرتمند و شناور power (دقیقاً مشابه سمت راست اسکرین‌شات دوم)
          Positioned(
            right: 20,
            bottom: 75,
            child: FloatingActionButton(
              backgroundColor: rubyGreen,
              elevation: 8,
              onPressed: _toggleConnection,
              child: const Icon(Icons.power_settings_new, size: 32, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
