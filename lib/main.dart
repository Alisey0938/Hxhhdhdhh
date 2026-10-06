import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const V2RayApp());
}

class V2RayApp extends StatelessWidget {
  const V2RayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2Ray Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF18181B), // تم گرانیتی تاریک
        primaryColor: Colors.purple,
        colorScheme: const ColorScheme.dark(
          primary: Colors.purple,
          secondary: Color(0xFF00E676), // سبز یاقوتی
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String apiBase = "https://socialmedia-ad.ir/api.php";

  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = "";

  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == '1' || v == 'true' || v == 'yes';
    }
    return false;
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    final username = _userController.text.trim();
    final password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "لطفاً نام کاربری و رمز عبور را وارد کنید";
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http
          .get(Uri.parse("$apiBase?action=users"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> usersData = json.decode(response.body);
        Map<String, dynamic>? matchedUser;

        usersData.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            if (value['username'] == username && value['password'] == password) {
              matchedUser = value;
              matchedUser!['id'] = key;
            }
          }
        });

        if (matchedUser != null) {
          final bool isActive = _isTruthy(matchedUser!['active']);
          if (!isActive) {
            setState(() {
              _errorMessage = "حساب کاربری شما غیرفعال است.";
              _isLoading = false;
            });
            return;
          }

          // بررسی میزان حجم مصرفی
          final double maxVolume = (matchedUser!['max_volume_gb'] ?? 0).toDouble();
          final int usedBytes = (matchedUser!['used_bytes'] ?? 0);
          final double usedGb = usedBytes / (1024 * 1024 * 1024);

          if (maxVolume > 0 && usedGb >= maxVolume) {
            setState(() {
              _errorMessage = "حجم اشتراک شما به پایان رسیده است.";
              _isLoading = false;
            });
            return;
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainDashboardScreen(userData: matchedUser!),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = "نام کاربری یا رمز عبور اشتباه است.";
          });
        }
      } else {
        setState(() {
          _errorMessage = "خطا در برقراری ارتباط با سرور (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "خطای شبکه یا عدم پاسخگویی سرور";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, size: 80, color: Colors.purple),
              const SizedBox(height: 20),
              const Text(
                "ورود به برنامه",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: "نام کاربری",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "رمز عبور",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("ورود", style: TextStyle(fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class MainDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MainDashboardScreen({super.key, required this.userData});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  static const String apiBase = "https://socialmedia-ad.ir/api.php";
  List<dynamic> _servers = [];
  bool _isLoading = true;
  bool _isConnected = false;
  int _selectedServerIndex = -1;
  int _pingMs = -1;

  @override
  void initState() {
    super.initState();
    _fetchServers();
  }

  Future<void> _fetchServers() async {
    try {
      final response = await http.get(Uri.parse("$apiBase?action=servers"));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _servers = data.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPing(int index) async {
    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(Uri.parse(apiBase)).timeout(const Duration(seconds: 3));
      stopwatch.stop();
      if (res.statusCode == 200) {
        setState(() {
          _pingMs = stopwatch.elapsedMilliseconds;
        });
      }
    } catch (_) {
      setState(() {
        _pingMs = -1;
      });
    }
  }

  void _toggleConnection() {
    if (_selectedServerIndex == -1 && !_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لطفاً ابتدا یک سرور را انتخاب کنید")),
      );
      return;
    }

    setState(() {
      _isConnected = !_isConnected;
    });

    if (_isConnected) {
      _testPing(_selectedServerIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxVolume = (widget.userData['max_volume_gb'] ?? 0).toDouble();
    final int usedBytes = (widget.userData['used_bytes'] ?? 0);
    final double usedGb = usedBytes / (1024 * 1024 * 1024);

    return Scaffold(
      appBar: AppBar(
        title: Text("کاربر: ${widget.userData['username']}"),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // کارت اطلاعات حجم مصرفی
                Card(
                  margin: const EdgeInsets.all(16),
                  color: Colors.grey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("حجم مصرف‌شده:"),
                            Text("${usedGb.toStringAsFixed(2)} GB / ${maxVolume == 0 ? 'نامحدود' : '$maxVolume GB'}"),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: maxVolume == 0 ? 0.0 : (usedGb / maxVolume).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[800],
                          color: const Color(0xFF00E676),
                        ),
                      ],
                    ),
                  ),
                ),

                // دکمه اتصال اصلی
                GestureDetector(
                  onTap: _toggleConnection,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isConnected ? const Color(0xFF00E676) : Colors.purple,
                      boxShadow: [
                        BoxShadow(
                          color: (_isConnected ? const Color(0xFF00E676) : Colors.purple).withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      size: 70,
                      color: _isConnected ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isConnected ? "متصل شد (Ping: ${_pingMs > 0 ? '$_pingMs ms' : '...'})" : "قطع شده",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isConnected ? const Color(0xFF00E676) : Colors.red,
                  ),
                ),
                const SizedBox(height: 20),

                // لیست سرورها
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text("انتخاب سرور:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _servers.length,
                    itemBuilder: (context, index) {
                      final server = _servers[index];
                      final isSelected = _selectedServerIndex == index;
                      return ListTile(
                        leading: Icon(
                          Icons.dns,
                          color: isSelected ? const Color(0xFF00E676) : Colors.purple,
                        ),
                        title: Text(server['name'] ?? 'سرور بدون نام'),
                        subtitle: Text(
                          server['config'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF00E676))
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedServerIndex = index;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
