import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xray Ultra Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090B10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF131722),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF131722),
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

  late V2ray v2ray;
  List<dynamic> _configs = [];
  final Map<String, int> _pings = {};
  final Map<String, bool> _pingLoading = {};

  bool _isLoading = true;
  bool _isConnectingProcess = false;
  String? _connectedConfigId;
  bool _isConnected = false;
  String _statusText = "DISCONNECTED";

  @override
  void initState() {
    super.initState();
    _initV2Ray();
    _fetchConfigs();
  }

  // ۱. مقداردهی اولیه هسته Xray
  void _initV2Ray() async {
    v2ray = V2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        final stateUpper = status.state.toUpperCase();
        
        // همگام‌سازی مستقیم وضعیت با تغییرات هسته
        setState(() {
          _statusText = stateUpper;
          if (stateUpper == 'CONNECTED') {
            _isConnected = true;
          } else if (stateUpper == 'DISCONNECTED' || stateUpper == 'STOPPED') {
            _isConnected = false;
            _connectedConfigId = null;
          }
        });
      },
    );

    await v2ray.initialize(
      notificationIconResourceType: "mipmap",
      notificationIconResourceName: "ic_launcher",
    );
  }

  // ۲. دریافت لیست سرورها
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
      debugPrint("خطا در دریافت سرورها: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ۳. سنجش پینگ دقیق
  Future<void> _testAllPings() async {
    for (var item in _configs) {
      _testSinglePing(item);
    }
  }

  Future<void> _testSinglePing(Map<String, dynamic> item) async {
    final String configUrl = (item['config'] ?? '').toString().trim();
    final String configId = item['id']?.toString() ?? item['name'];

    if (configUrl.isEmpty) return;

    if (mounted) {
      setState(() {
        _pingLoading[configId] = true;
      });
    }

    try {
      V2RayURL parser = V2ray.parseFromURL(configUrl);
      
      int delay = await v2ray.getServerDelay(
        config: parser.getFullConfiguration(),
        url: 'https://1.1.1.1',
      );

      if (delay <= 0) {
        final stopwatch = Stopwatch()..start();
        final int targetPort = int.tryParse(parser.port.toString()) ?? 443;
        final socket = await Socket.connect(
          parser.address,
          targetPort,
          timeout: const Duration(seconds: 3),
        );
        stopwatch.stop();
        delay = stopwatch.elapsedMilliseconds;
        await socket.close();
      }

      if (mounted) {
        setState(() {
          _pings[configId] = delay;
          _pingLoading[configId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pings[configId] = -1;
          _pingLoading[configId] = false;
        });
      }
    }
  }

  // ۴. مدیریت اتصال و قطع اتصال دقیق
  Future<void> _toggleConnect(Map<String, dynamic> item) async {
    if (_isConnectingProcess) return;

    final String configUrl = (item['config'] ?? '').toString().trim();
    final String configId = item['id']?.toString() ?? item['name'];

    // اقدام به قطع اتصال
    if (_isConnected && _connectedConfigId == configId) {
      setState(() {
        _isConnectingProcess = true;
        // تغییر آنی وضعیت محلی برای آپدیت UI قبل از پاسخ هسته
        _isConnected = false;
        _connectedConfigId = null;
        _statusText = "DISCONNECTED";
      });

      try {
        await v2ray.stopV2Ray();
      } catch (e) {
        debugPrint("خطا در قطع اتصال: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isConnectingProcess = false;
          });
        }
      }
      return;
    }

    // عدم اجازه سوییچ بدون قطع سرور قبلی
    if (_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً ابتدا اتصال سرور فعال را قطع کنید.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // اقدام به اتصال جدید
    setState(() => _isConnectingProcess = true);

    try {
      if (await v2ray.requestPermission()) {
        V2RayURL parser = V2ray.parseFromURL(configUrl);

        await v2ray.startV2Ray(
          remark: item['name'] ?? parser.remark,
          config: parser.getFullConfiguration(),
          proxyOnly: false,
        );

        setState(() {
          _connectedConfigId = configId;
          _isConnected = true;
          _statusText = "CONNECTED";
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مجوز VPN تأیید نشد.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در برقراری اتصال: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnectingProcess = false);
      }
    }
  }

  Color _getPingColor(int ping) {
    if (ping <= 0) return Colors.redAccent;
    if (ping < 300) return const Color(0xFF10B981);
    if (ping < 600) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: Color(0xFF8B5CF6)),
            SizedBox(width: 8),
            Text(
              'XRAY ULTRA',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed_rounded, color: Color(0xFF8B5CF6)),
            tooltip: 'تست پینگ مجدد',
            onPressed: _testAllPings,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
            onPressed: _fetchConfigs,
          ),
        ],
      ),
      body: Column(
        children: [
          // باکس وضعیت هدر (سبز در حالت متصل / قرمز در حالت قطع)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isConnected
                    ? [const Color(0xFF064E3B), const Color(0xFF10B981)]
                    : [const Color(0xFF451225), const Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (_isConnected ? const Color(0xFF10B981) : const Color(0xFFDC2626)).withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(
                    _isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isConnected ? "اتصال ایمن برقرار است" : "قطع اتصال",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'وضعیت هسته: $_statusText',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isConnectingProcess)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.dns_rounded, size: 18, color: Color(0xFF8B5CF6)),
                SizedBox(width: 8),
                Text(
                  "سرورهای در دسترس (پشتیبانی XHTTP/gRPC/REALITY)",
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // لیست کانفیگ‌ها
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  )
                : _configs.isEmpty
                    ? const Center(
                        child: Text(
                          'هیچ سرور فعالی یافت نشد.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _configs.length,
                        itemBuilder: (context, index) {
                          final item = _configs[index];
                          final String configId = item['id']?.toString() ?? item['name'];
                          final bool isThisConnected = _isConnected && _connectedConfigId == configId;

                          final bool isPingLoading = _pingLoading[configId] ?? false;
                          final int ping = _pings[configId] ?? 0;

                          // فقط زمانی که متصل هستیم و این آی‌دی با آی‌دی متصل فرق دارد غیرفعال می‌شود
                          final bool isDisabledButton = _isConnected && !isThisConnected;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131722),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isThisConnected ? const Color(0xFF10B981) : Colors.white.withOpacity(0.08),
                                width: isThisConnected ? 2 : 1,
                              ),
                              boxShadow: isThisConnected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withOpacity(0.2),
                                        blurRadius: 12,
                                      )
                                    ]
                                  : [],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item['flag'] ?? '🌐',
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['name'] ?? 'سرور Xray',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDisabledButton ? Colors.white38 : Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  isPingLoading
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _getPingColor(ping).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _getPingColor(ping).withOpacity(0.4)),
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
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  item['config'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isThisConnected
                                      ? Colors.redAccent.withOpacity(0.9)
                                      : isDisabledButton
                                          ? Colors.grey.withOpacity(0.15)
                                          : const Color(0xFF8B5CF6),
                                  elevation: isThisConnected ? 0 : 4,
                                  shadowColor: const Color(0xFF8B5CF6).withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onPressed: (_isConnectingProcess || isDisabledButton)
                                    ? null
                                    : () => _toggleConnect(item),
                                child: Text(
                                  isThisConnected ? 'قطع' : 'اتصال',
                                  style: TextStyle(
                                    color: isDisabledButton ? Colors.white24 : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
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
