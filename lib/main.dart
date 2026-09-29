import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() async {
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
  List<String> configList = [];
  int selectedConfigIndex = 0;

  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://pane-dcc9a-default-rtdb.firebaseio.com',
  ).ref();

  @override
  void initState() {
    super.initState();
    _initV2RayEngine();
    _fetchConfigsFromFirebase();
  }

  void _initV2RayEngine() {
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

  Future<void> _fetchConfigsFromFirebase() async {
    try {
      final snapshot = await _dbRef.child("configs").get();
      if (snapshot.exists) {
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
      return;
    }

    if (configList.isEmpty) {
      _showSnackBar('هیچ کانفیگی از سرور دریافت نشده است!');
      _fetchConfigsFromFirebase();
      return;
    }

    final String rawConfig = configList[selectedConfigIndex];

    try {
      if (await flutterV2ray.requestPermission()) {
        // پشتیبانی مستقیم از تمام لینک‌های vless, vmess, trojan, ss, xhttp, ws
        final V2RayURL parseResult = FlutterV2ray.parseFromURL(rawConfig);
        
        await flutterV2ray.startV2Ray(
          remark: parseResult.remark.isNotEmpty ? parseResult.remark : "Xray Ultra Server",
          config: parseResult.fullURL,
          blockedApps: null,
          bypassSubnets: null,
          proxyOnly: false,
        );
      }
    } catch (e) {
      debugPrint("V2Ray Launch Error: $e");
      _showSnackBar('خطا در اجرای این کانفیگ. در حال تست هسته...');
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
        title: const Text('XRAY ULTRA (FULL CORE)'),
        actions: [
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
              // کارت وضعیت اتصال
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

              // لیست سرورهای دریافت شده از Firebase
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

              // دکمه اتصال
              GestureDetector(
                onTap: _toggleConnection,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 120,
                  height: 120,
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
                    size: 55,
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
