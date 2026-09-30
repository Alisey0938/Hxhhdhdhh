import 'dart:async';
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
    const Color graniteBlack = Color(0xFF121417);
    const Color graniteCard = Color(0xFF1E2228);
    const Color rubyGreen = Color(0xFF00A86B);
    const Color deepPurple = Color(0xFF8A2BE2);

    return MaterialApp(
      title: 'Xray Ultra',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: graniteBlack,
        primaryColor: deepPurple,
        cardColor: graniteCard,
        colorScheme: const ColorScheme.dark(
          primary: deepPurple,
          secondary: rubyGreen,
          surface: graniteCard,
          background: graniteBlack,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: graniteBlack,
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

// ==================== راه‌اندازی ایمن فایربیس ====================
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
                const Text('خطا در اتصال به Firebase',
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

// ==================== صفحه لاگین ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  DatabaseReference get _dbRef => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://pane-dcc9a-default-rtdb.firebaseio.com',
      ).ref();

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showSnackBar("لطفاً نام کاربری را وارد کنید");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await _dbRef.child("users").child(username).get();
      if (snapshot.exists && snapshot.value != null) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        final bool isActive = userData['active'] ?? true;

        if (!isActive) {
          _showSnackBar("حساب کاربری شما غیرفعال شده است.");
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(username: username),
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
    const Color deepPurple = Color(0xFF8A2BE2);
    const Color rubyGreen = Color(0xFF00A86B);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 80, color: rubyGreen),
              const SizedBox(height: 20),
              const Text("ورود به Xray Ultra",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: "نام کاربری",
                  prefixIcon: const Icon(Icons.person, color: deepPurple),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ورود", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== صفحه اصلی برنامه ====================
class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FlutterV2ray flutterV2ray;
  bool isConnected = false;
  String v2rayStatus = "DISCONNECTED";
  String pingResult = "0 ms";
  List<String> configList = [];
  int selectedConfigIndex = 0;

  int _lastUpload = 0;
  int _lastDownload = 0;
  StreamSubscription<DatabaseEvent>? _userStatusSubscription;

  DatabaseReference get _dbRef => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://pane-dcc9a-default-rtdb.firebaseio.com',
      ).ref();

  @override
  void initState() {
    super.initState();
    _initV2RayEngine();
    _fetchConfigsFromFirebase();
    _listenToUserStatus();
  }

  @override
  void dispose() {
    _userStatusSubscription?.cancel();
    super.dispose();
  }

  void _listenToUserStatus() {
    _userStatusSubscription = _dbRef.child("users").child(widget.username).onValue.listen((event) async {
      if (!event.snapshot.exists) {
        _forceLogout("حساب کاربری شما توسط ادمین حذف گردید.");
      } else {
        final userData = Map<String, dynamic>.from(event.snapshot.value as Map);
        final bool isActive = userData['active'] ?? true;
        if (!isActive) {
          _forceLogout("حساب کاربری شما توسط ادمین غیرفعال گردید.");
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
        List<String> tempConfigs = [];
        if (snapshot.value is Map) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          data.forEach((key, value) {
            if (value is String && value.trim().isNotEmpty) {
              tempConfigs.add(value.trim());
            } else if (value is Map && value.containsKey('url')) {
              tempConfigs.add(value['url'].toString().trim());
            }
          });
        } else if (snapshot.value is List) {
          for (var item in snapshot.value as List) {
            if (item != null) tempConfigs.add(item.toString().trim());
          }
        }
        setState(() {
          configList = tempConfigs;
        });
      }
    } catch (e) {
      debugPrint("Error fetching configs: $e");
    }
  }

  Future<void> _toggleConnection() async {
    if (isConnected) {
      await flutterV2ray.stopV2Ray();
      _lastUpload = 0;
      _lastDownload = 0;
      return;
    }

    if (configList.isEmpty) {
      _showSnackBar('هیچ کانفیگی یافت نشد!');
      _fetchConfigsFromFirebase();
      return;
    }

    final String rawConfig = configList[selectedConfigIndex];

    try {
      if (await flutterV2ray.requestPermission()) {
        final V2RayURL parseResult = FlutterV2ray.parseFromURL(rawConfig);

        await flutterV2ray.startV2Ray(
          remark: parseResult.remark.isNotEmpty ? parseResult.remark : "Xray Ultra Server",
          config: rawConfig,
          blockedApps: null,
          bypassSubnets: null,
          proxyOnly: false,
        );
      }
    } catch (e) {
      debugPrint("V2Ray Launch Error: $e");
      _showSnackBar('خطا در اجرای کانفیگ انتخاب‌شده');
      await flutterV2ray.stopV2Ray();
    }
  }

  Future<void> _getPing() async {
    if (isConnected) {
      try {
        final delay = await flutterV2ray.getConnectedServerDelay();
        setState(() {
          pingResult = "$delay ms";
        });
      } catch (_) {
        setState(() {
          pingResult = "Error";
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
    const Color deepPurple = Color(0xFF8A2BE2);

    return Scaffold(
      appBar: AppBar(
        title: Text('Xray Ultra (${widget.username})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _forceLogout("از حساب کاربری خارج شدید."),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: rubyGreen),
            onPressed: _fetchConfigsFromFirebase,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isConnected ? rubyGreen : deepPurple,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "وضعیت: $v2rayStatus",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "پینگ: $pingResult",
                            style: TextStyle(
                              fontSize: 13,
                              color: isConnected ? rubyGreen : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.speed, color: rubyGreen),
                        onPressed: _getPing,
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: configList.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: deepPurple))
                    : ListView.builder(
                        itemCount: configList.length,
                        itemBuilder: (context, index) {
                          final bool isSelected = selectedConfigIndex == index;
                          return Card(
                            color: isSelected ? deepPurple.withOpacity(0.2) : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? rubyGreen : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                "سرور شماره ${index + 1}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                configList[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: rubyGreen)
                                  : null,
                              onTap: () {
                                setState(() {
                                  selectedConfigIndex = index;
                                });
                              },
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 10),

              GestureDetector(
                onTap: _toggleConnection,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).cardColor,
                    border: Border.all(
                      color: isConnected ? rubyGreen : deepPurple,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? rubyGreen : deepPurple).withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.power_settings_new,
                    size: 50,
                    color: isConnected ? rubyGreen : deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
