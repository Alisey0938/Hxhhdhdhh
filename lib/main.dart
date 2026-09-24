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
      title: 'V2Ray App',
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
  // آدرس دیتابیس اختصاصی شما
  final String firebaseUrl = "https://pane-dcc9a-default-rtdb.firebaseio.com/configs.json";

  late FlutterV2ray flutterV2ray;
  List<dynamic> _configs = [];
  bool _isLoading = true;
  String? _connectedConfigId;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initV2Ray();
    _fetchConfigs();
  }

  // ۱. مقداردهی اولیه هسته V2Ray
  void _initV2Ray() {
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        setState(() {
          _isConnected = status.state == 'CONNECTED';
          if (!_isConnected && status.state == 'DISCONNECTED') {
            _connectedConfigId = null;
          }
        });
      },
    );
    flutterV2ray.initializeV2Ray();
  }

  // ۲. دریافت آنلاین کانفیگ‌ها از پنل مدیریت (فایربیس)
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
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("خطا در دریافت سرورها: $e");
      setState(() => _isLoading = false);
    }
  }

  // ۳. مدیریت اتصال و قطع اتصال
  Future<void> _toggleConnect(Map<String, dynamic> item) async {
    final String configUrl = item['config'] ?? '';
    final String configId = item['id']?.toString() ?? item['name'];

    if (_isConnected && _connectedConfigId == configId) {
      // قطع اتصال
      await flutterV2ray.stopV2Ray();
      setState(() {
        _isConnected = false;
        _connectedConfigId = null;
      });
      return;
    }

    // بررسی مجوز VPN
    if (await flutterV2ray.requestPermission()) {
      try {
        V2RayURL parser = FlutterV2ray.parseFromURL(configUrl);
        await flutterV2ray.startV2Ray(
          remark: item['name'] ?? parser.remark,
          config: parser.getFullConfiguration(),
          proxyOnly: false,
        );
        setState(() {
          _isConnected = true;
          _connectedConfigId = configId;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در قالب کانفیگ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لیست سرورها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchConfigs,
          ),
        ],
      ),
      body: _isLoading
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
                        title: Text(
                          item['name'] ?? 'سرور V2Ray',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
    );
  }
}
