import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() async {
  // اطمینان از مقداردهی اولیه نیتیو قبل از اجرای برنامه برای جلوگیری از صفحه سیاه
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const XrayUltraApp());
}

class XrayUltraApp extends StatelessWidget {
  const XrayUltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    // پالت رنگی: گرانیت سیاه، بنفش و سبز یاقوتی
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FlutterV2ray flutterV2ray;
  bool isConnected = false;
  String v2rayStatus = "DISCONNECTED";
  String pingResult = "0 ms";
  String configVless = "";

  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://pane-dcc9a-default-rtdb.firebaseio.com',
  ).ref();

  @override
  void initState() {
    super.initState();
    _initV2Ray();
    _fetchConfigFromFirebase();
  }

  void _initV2Ray() {
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        setState(() {
          v2rayStatus = status.state;
          isConnected = status.state == "CONNECTED";
        });
      },
    );
    flutterV2ray.initializeV2Ray();
  }

  Future<void> _fetchConfigFromFirebase() async {
    try {
      final snapshot = await _dbRef.child("configs/active_config").get();
      if (snapshot.exists) {
        setState(() {
          configVless = snapshot.value.toString();
        });
      }
    } catch (e) {
      debugPrint("Error fetching config: $e");
    }
  }

  Future<void> _toggleConnection() async {
    if (isConnected) {
      await flutterV2ray.stopV2Ray();
    } else {
      if (configVless.isNotEmpty) {
        if (await flutterV2ray.requestPermission()) {
          final V2RayURL parseResult = FlutterV2ray.parseFromURL(configVless);
          await flutterV2ray.startV2Ray(
            remark: parseResult.remark,
            config: parseResult.fullURL,
            blockedApps: null,
            bypassSubnets: null,
            proxyOnly: false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کانفیگی یافت نشد! در حال تلاش مجدد...')),
        );
        _fetchConfigFromFirebase();
      }
    }
  }

  Future<void> _getPing() async {
    if (isConnected) {
      final delay = await flutterV2ray.getConnectedServerDelay();
      setState(() {
        pingResult = "$delay ms";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color rubyGreen = Color(0xFF00A86B);
    const Color deepPurple = Color(0xFF8A2BE2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('XRAY ULTRA'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // کارت وضعیت اتصال و پینگ
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "پینگ: $pingResult",
                            style: TextStyle(
                              fontSize: 14,
                              color: isConnected ? rubyGreen : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: rubyGreen),
                        onPressed: _getPing,
                      )
                    ],
                  ),
                ),
              ),

              // دکمه اتصال اصلی
              GestureDetector(
                onTap: _toggleConnection,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 160,
                  height: 160,
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
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.power_settings_new,
                    size: 70,
                    color: isConnected ? rubyGreen : deepPurple,
                  ),
                ),
              ),

              // اطلاعات زیرین
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  configVless.isNotEmpty
                      ? "کانفیگ فعال دریافت شد"
                      : "در حال دریافت کانفیگ از سرور...",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
