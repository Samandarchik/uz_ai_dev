import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/admin/ui/admin_home_ui.dart';
import 'package:uz_ai_dev/user/ui/user_home_ui.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/check_version.dart';
import 'package:uz_ai_dev/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final TokenStorage tokenStorage = sl<TokenStorage>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('SplashScreen');

      // 🔹 Bitta request bilan ham version check ham isRelease ni olamiz
      final result = await VersionChecker.checkVersionAndRelease(context);
      bool needsUpdate = result['needsUpdate'] ?? false;
      bool isRelease = result['isRelease'] ?? true;

      print('needsUpdate: $needsUpdate');
      print('isRelease: $isRelease');

      // Agar update kerak bo'lmasa, tokenni tekshiramiz va LoginPage ga isRelease ni o'tkazamiz
      if (!needsUpdate) {
        _checkToken(isRelease);
      }
    });
  }

  Future<void> _checkToken(bool isRelease) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = await tokenStorage.getToken();
    bool? isAdmin = prefs.getBool('is_admin');

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    if (token.isEmpty) {
      // 🔹 Token yo'q — Login sahifasiga o'tish (isRelease ni o'tkazamiz)
      context.pushReplacement(LoginPage(isRelease: isRelease));
      return;
    }

    // Oddiy user tizimi
    if (isAdmin == true) {
      context.pushReplacement(const AdminHomeUi());
    } else {
      context.pushReplacement(const UserHomeUi());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.store,
                size: 60,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "загрузка",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
