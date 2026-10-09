import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

class AuthService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();
  static StreamSubscription<DatabaseEvent>? _userSubscription;

  /// شروع شنود لحظه‌ای وضعیت کاربر
  static void startUserListener(BuildContext context, String userId, V2ray v2rayClient) {
    _userSubscription?.cancel();

    _userSubscription = _db.child('users/$userId').onValue.listen((event) async {
      if (!event.snapshot.exists) {
        await _forceLogout(context, v2rayClient, "حساب کاربری شما حذف شده است.");
      } else {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final bool isActive = data['isActive'] ?? true;

        if (!isActive) {
          await _forceLogout(context, v2rayClient, "حساب کاربری شما غیرفعال شده است.");
        }
      }
    });
  }

  /// متوقف کردن شنود
  static void stopUserListener() {
    _userSubscription?.cancel();
    _userSubscription = null;
  }

  /// خروج اجباری و قطع وی‌پی‌ان
  static Future<void> _forceLogout(BuildContext context, V2ray v2rayClient, String message) async {
    stopUserListener();

    try {
      await v2rayClient.stopV2Ray();
    } catch (_) {}

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  /// خروج دستی
  static Future<void> logoutManual(BuildContext context, V2ray v2rayClient) async {
    stopUserListener();

    try {
      await v2rayClient.stopV2Ray();
    } catch (_) {}

    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
