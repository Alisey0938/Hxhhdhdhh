import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2Ray Xray Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const ServerListScreen(),
    );
  }
}

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  final String firebaseUrl = "https://pane-dcc9a-default-rtdb.firebaseio.com/configs.json";

  late FlutterV2ray flutterV2ray;
  List<dynamic> _configs = [];
  final Map<String, int> _pings = {};
  final Map<String, bool> _pingLoading = {};
  bool _isLoading = true;
  String? _connectedConfigId;
  bool _isConnected = false;
  String _statusText = "DISCONNECTED";

  @override
  void initState() {
    super.initState();
    _initV2Ray();
    _fetchConfigs();
  }

  // ۱. مقداردهی اولیه هسته Xray/V2Ray
  void _initV2Ray() {
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        setState(() {
          _statusText = status.state;
          _isConnected = status.state == 'CONNECTED';
          if (!_isConnected && status.state == 'DISCONNECTED') {
            _connectedConfigId = null;
          }
        });
      },
    );

    flutterV2ray.initializeV2Ray();
  }

  // ۲. دریافت سرورها از فایربیس
  Future<void> _fetchConfigs() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(firebaseUrl));
      if (response.statusCode == 200 && response.body != 'null') {
        final data = json.decode(response.body);
        List<dynamic> loadedConfigs = [];

        if (data is List) {
          loadedConfigs = data.where((item) => item != null && item['active'] == true).toList();
        } else if (data is Map) {
          data.forEach((key, value) {
            if (value != null && value['active'] == true) {
              loadedConfigs.add(value);
            }
          });
        }

        setState(() {
          _configs = loadedConfigs;
          _isLoading = false;
        });

        _testAllPings();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("خطا در دریافت لیست کانفیگ‌ها: $e");
      setState(() => _isLoading = false);
    }
  }

  // ۳. سنجش پینگ تمام کانفیگ‌ها
  Future<void> _testAllPings() async {
    for (var item in _configs) {
      _testSinglePing(item);
    }
  }

  // سنجش پینگ دقیق برای تک‌تک کانفیگ‌ها
  Future<void> _testSinglePing(Map<String, dynamic> item) async {
    final String configUrl = (item['config'] ?? '').toString().trim();
    final String configId = item['id']?.toString() ?? item['name'];

    if (configUrl.isEmpty) return;

    setState(() {
      _pingLoading[configId] = true;
    });

    try {
      V2RayURL parser = FlutterV2ray.parseFromURL(configUrl);
      
      // محاسبه پینگ واقعی از طریق هسته Xray با ارسال URL کانفیگ
      int delay = await flutterV2ray.getServerDelay(
        config: parser.getFullConfiguration(),
        url: 'https://www.gstatic.com/generate_204', // استاندارد تست پینگ v2rayNG
      );

      setState(() {
        _pings[configId] = delay;
        _pingLoading[configId] = false;
      });
    } catch (e) {
      setState(() {
        _pings[configId] = -1;
        _pingLoading[configId] = false;
      });
    }
  }

  // ۴. مدیریت اتصال و قطع اتصال
  Future<void> _toggleConnect(Map<String, dynamic> item) async {
    final String configUrl = (item['config'] ?? '').toString().trim();
    final String configId = item['id']?.toString() ?? item['name'];

    if (_isConnected && _connectedConfigId == configId) {
      await flutterV2ray.stopV2Ray();
      setState(() {
        _isConnected = false;
        _connectedConfigId = null;
      });
      return;
    }

    if (_isConnected) {
      await flutterV2ray.stopV2Ray();
    }

    if (await flutterV2ray.requestPermission()) {
      try {
        V2RayURL parser = FlutterV2ray.parseFromURL(configUrl);

        await flutterV2ray.startV2Ray(
          remark: item['name'] ?? parser.remark,
          config: parser.getFullConfiguration(),
          proxyOnly: false, // عبور تمام ترافیک دستگاه (VPN کامل)
        );

        setState(() {
          _connectedConfigId = configId;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در بارگذاری کانفیگ: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مجوز VPN داده نشد.')),
        );
      }
    }
  }

  Color _getPingColor(int ping) {
    if (ping <= 0) return Colors.redAccent;
    if (ping < 350) return Colors.greenAccent;
    if (ping < 700) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لیست سرورها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: 'تست پینگ مجدد',
            onPressed: _testAllPings,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchConfigs,
          ),
        ],
      ),
      body: Column(
        children: [
          // نوار وضعیت
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: _isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'وضعیت: $_statusText',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isConnected)
                  const Icon(Icons.vpn_lock, color: Colors.green, size: 20),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
                : _configs.isEmpty
                    ? const Center(
                        child: Text(
                          'هیچ سرور فعالی در پنل پیدا نشد!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _configs.length,
                        itemBuilder: (context, index) {
                          final item = _configs[index];
                          final String configId = item['id']?.toString() ?? item['name'];
                          final bool isThisConnected = _isConnected && _connectedConfigId == configId;

                          final bool isPingLoading = _pingLoading[configId] ?? false;
                          final int ping = _pings[configId] ?? 0;

                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isThisConnected ? Colors.green : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Text(
                                item['flag'] ?? '🌐',
                                style: const TextStyle(fontSize: 28),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['name'] ?? 'سرور V2Ray',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  isPingLoading
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigoAccent),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getPingColor(ping).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _getPingColor(ping).withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            ping > 0 ? '$ping ms' : 'تایم‌اوت',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _getPingColor(ping),
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                              subtitle: Text(
                                item['config'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isThisConnected ? Colors.redAccent : Colors.indigoAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _toggleConnect(item),
                                child: Text(
                                  isThisConnected ? 'قطع اتصال' : 'اتصال',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
