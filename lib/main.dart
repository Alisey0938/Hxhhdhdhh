import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2Ray Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050508),
        primaryColor: const Color(0xFF00FF9D),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late FlutterV2ray v2ray;
  bool isConnected = false;
  String downloadSpeed = '0.0 KB/s';
  String uploadSpeed = '0.0 KB/s';
  
  // دیتای نمونه سرورها (که در اپ قرار می‌گیرد)
  List<Map<String, dynamic>> servers = [
    {
      'id': 1,
      'name': '🇩🇪 سرور آلمان - اختصاصی',
      'config': 'vless://example-uuid@1.2.3.4:443?type=ws&security=tls#Germany'
    },
    {
      'id': 2,
      'name': '🇫🇮 سرور فنلاند - پرسرعت',
      'config': 'vmess://example-config-base64-here#Finland'
    },
  ];

  Map<String, dynamic>? selectedServer;
  
  // اطلاعات کاربر (حجم 0 یعنی نامحدود)
  double limitGB = 0; // 0 = Unlimited
  double usedBytes = 0;

  @override
  void initState() {
    super.initState();
    selectedServer = servers.first;
    _initV2RayCore();
  }

  void _initV2RayCore() {
    v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (mounted) {
          setState(() {
            isConnected = status.state == "CONNECTED";
            
            // ۱. دریافت سرعت واقعی محاسبه‌شده توسط هسته
            downloadSpeed = _formatSpeed(status.downloadSpeed);
            uploadSpeed = _formatSpeed(status.uploadSpeed);

            // ۲. محاسبه حجم واقعی کسر شده بر اساس بایت‌های دریافتی/ارسالی
            usedBytes = (status.download + status.upload).toDouble();
            
            // بررسی سقف حجم (اگر محدود تعریف شده باشد)
            if (limitGB > 0) {
              double usedGB = usedBytes / (1024 * 1024 * 1024);
              if (usedGB >= limitGB) {
                v2ray.stopV2Ray();
                _showExpiredDialog();
              }
            }
          });
        }
      },
    );
    v2ray.initializeV2Ray();
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return "$bytesPerSecond B/s";
    if (bytesPerSecond < 1024 * 1024) return "${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s";
    return "${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s";
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پایان اعتبار'),
        content: const Text('حجم حساب شما به پایان رسیده است.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تایید'),
          )
        ],
      ),
    );
  }

  void _toggleConnect() async {
    if (isConnected) {
      await v2ray.stopV2Ray();
    } else {
      if (selectedServer == null) return;
      if (await v2ray.requestPermission()) {
        await v2ray.startV2Ray(
          remark: selectedServer!['name'],
          config: selectedServer!['config'],
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double usedGB = usedBytes / (1024 * 1024 * 1024);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2Ray PRO', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // انتخاب سرور
            InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServerListScreen(servers: servers, v2ray: v2ray),
                  ),
                );
                if (result != null) {
                  setState(() => selectedServer = result);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141221),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(selectedServer?['name'] ?? 'انتخاب سرور'),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
            const Spacer(),
            
            // دکمه اتصال
            GestureDetector(
              onTap: _toggleConnect,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? const Color(0xFF0B3826) : const Color(0xFF2E1065),
                  border: Border.all(
                    color: isConnected ? const Color(0xFF00FF9D) : const Color(0xFFA855F7),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isConnected ? const Color(0xFF00FF9D).withOpacity(0.3) : const Color(0xFFA855F7).withOpacity(0.3),
                      blurRadius: 25,
                    )
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new,
                  size: 50,
                  color: isConnected ? const Color(0xFF00FF9D) : const Color(0xFFA855F7),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isConnected ? 'متصل شد' : 'آماده اتصال',
              style: TextStyle(
                color: isConnected ? const Color(0xFF00FF9D) : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),

            // نمایش سرعت آپلود و دانلود
            Row(
              children: [
                Expanded(child: _speedCard('سرعت دانلود', downloadSpeed, const Color(0xFF00FF9D))),
                const SizedBox(width: 10),
                Expanded(child: _speedCard('سرعت آپلود', uploadSpeed, const Color(0xFFA855F7))),
              ],
            ),
            const SizedBox(height: 10),

            // نمایش حجم باقی مانده / مصرفی
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141221),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('حجم باقی‌مانده', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        limitGB == 0 ? '∞ نامحدود' : '${(limitGB - usedGB).toStringAsFixed(2)} GB',
                        style: const TextStyle(color: Color(0xFF00FF9D), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('مصرف شده', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '${usedGB.toStringAsFixed(2)} GB',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141221),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// صفحه لیست سرورها به همراه گرفتن پینگ واقعی خودکار
class ServerListScreen extends StatefulWidget {
  final List<Map<String, dynamic>> servers;
  final FlutterV2ray v2ray;

  const ServerListScreen({Key? key, required this.servers, required this.v2ray}) : super(key: key);

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  Map<int, int> serverPings = {};
  Map<int, bool> isLoading = {};

  @override
  void initState() {
    super.initState();
    _getPings();
  }

  // گرفتن پینگ واقعی بر اساس اینترنت فعلی کاربر
  Future<void> _getPings() async {
    for (var server in widget.servers) {
      int id = server['id'];
      setState(() => isLoading[id] = true);

      try {
        final delay = await widget.v2ray.getServerDelay(config: server['config']);
        if (mounted) {
          setState(() {
            serverPings[id] = delay;
            isLoading[id] = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            serverPings[id] = -1;
            isLoading[id] = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('انتخاب سرور')),
      body: ListView.builder(
        itemCount: widget.servers.length,
        itemBuilder: (context, index) {
          final server = widget.servers[index];
          final id = server['id'];
          final ping = serverPings[id];
          final loading = isLoading[id] ?? true;

          return ListTile(
            title: Text(server['name']),
            trailing: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    ping == null || ping == -1 ? 'Timeout ❌' : '$ping ms',
                    style: TextStyle(
                      color: (ping ?? 999) < 300 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            onTap: () => Navigator.pop(context, server),
          );
        },
      ),
    );
  }
}
