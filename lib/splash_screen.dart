import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uz_ai_dev/admin/ui/admin_home_ui.dart';
import 'package:uz_ai_dev/bugalter/ui/bugalter_home_ui.dart';
import 'package:uz_ai_dev/ombor/ui/ombor_home_ui.dart';
import 'package:uz_ai_dev/shef/ui/shef_home_ui.dart';
import 'package:uz_ai_dev/yuk/ui/yuk_home_ui.dart';
import 'package:uz_ai_dev/user/ui/user_home_ui.dart';
import 'package:uz_ai_dev/core/constants/roles.dart';
import 'package:uz_ai_dev/core/context_extension.dart';
import 'package:uz_ai_dev/core/data/local/token_storage.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/check_version.dart';
import 'package:uz_ai_dev/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final TokenStorage tokenStorage = sl<TokenStorage>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('SplashScreen');

      // 🔹 Bitta request bilan ham version check ham isRelease ni olamiz
      final result = await VersionChecker.checkVersionAndRelease(context);
      bool needsUpdate = result['needsUpdate'] ?? false;
      bool versionsMatch = result['versionsMatch'] ?? true;

      debugPrint('needsUpdate: $needsUpdate');
      debugPrint('versionsMatch: $versionsMatch');

      // Agar update kerak bo'lmasa, tokenni tekshiramiz
      // versionsMatch = true → isRelease = true (Try login ko'rinmaydi)
      // versionsMatch = false → isRelease = false (Try login ko'rinadi)
      if (!needsUpdate) {
        _checkToken(versionsMatch);
      }
    });
  }

  Future<void> _checkToken(bool isRelease) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = await tokenStorage.getToken();
    String role = prefs.getString('role') ?? AppRoles.seller;
    bool? isAdmin = prefs.getBool('is_admin');

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    if (token.isEmpty) {
      context.pushReplacement(LoginPage(isRelease: isRelease));
      return;
    }

    // Role bo'yicha yo'naltirish
    if (isAdmin == true || role == AppRoles.superAdmin) {
      context.pushReplacement(const AdminHomeUi());
    } else if (role == AppRoles.ombor) {
      context.pushReplacement(const OmborHomeUi());
    } else if (role == AppRoles.yukKeltiruvchi) {
      context.pushReplacement(const YukHomeUi());
    } else if (role == AppRoles.bugalter) {
      context.pushReplacement(const BugalterHomeUi());
    } else if (role == AppRoles.shef) {
      context.pushReplacement(const ShefHomeUi());
    } else if (role == 'customer' || role == 'bringer') {
      // Bu rollar hozircha qo'llab-quvvatlanmaydi
      await prefs.remove('token');
      if (!mounted) return;
      _showUnsupportedRoleDialog(isRelease);
    } else {
      // seller yoki default
      context.pushReplacement(const UserHomeUi());
    }
  }

  void _showUnsupportedRoleDialog(bool isRelease) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 10),
            Text('error'),
          ],
        ),
        content: const Text('Bu rol qo\'llab-quvvatlanmaydi'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pushReplacement(LoginPage(isRelease: isRelease));
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                    color: Colors.blue.withValues(alpha: 0.3),
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
