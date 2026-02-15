import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionChecker {
  static const String _endpoint =
      "https://version.uzaidev.uz/health?appName=moneapp";

  static const String fallbackAppStoreUrl =
      "https://apps.apple.com/app/id6752371524";
  static const String fallbackPlayStoreUrl =
      "https://play.google.com/store/apps/details?id=com.example.app";

  /// 🔹 Versiyani tekshiradi va isRelease qiymatini qaytaradi:
  /// agar backend versiyasi katta bo'lsa → update majburiy
  /// Returns: {needsUpdate: bool, isRelease: bool}
  static Future<Map<String, bool>> checkVersionAndRelease(
      BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_endpoint));
      print(response.statusCode);
      print(response.body);

      if (response.statusCode != 200) {
        debugPrint("⚠️ Server status: ${response.statusCode}");
        return {'needsUpdate': false, 'isRelease': true};
      }

      final decoded = jsonDecode(response.body);
      final data = decoded['data'];
      if (data == null) {
        return {'needsUpdate': false, 'isRelease': true};
      }

      // isRelease qiymatini olish
      final isRelease = data['isRelease'] ?? true;
      debugPrint("🔍 isRelease: $isRelease");

      // Version check
      final iosVersion = data['iosVersion']?.toString();
      final androidVersion = data['androidVersion']?.toString();
      final appStoreUrl =
          (data['appstoreUrl'] ?? fallbackAppStoreUrl).toString();
      final playStoreUrl =
          (data['playstoreUrl'] ?? fallbackPlayStoreUrl).toString();

      if (iosVersion == null || androidVersion == null) {
        return {'needsUpdate': false, 'isRelease': isRelease};
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      final latestVersion =
          Platform.isIOS ? iosVersion.trim() : androidVersion.trim();
      final storeUrl = Platform.isIOS ? appStoreUrl : playStoreUrl;

      debugPrint("📱 Current version: $currentVersion");
      debugPrint("🆕 Backend version: $latestVersion");

      final requiresUpdate = _isNewerVersion(latestVersion, currentVersion);

      debugPrint("🔍 Update needed: $requiresUpdate");

      if (requiresUpdate) {
        _showUpdateDialog(context, storeUrl);
        return {'needsUpdate': true, 'isRelease': isRelease};
      }

      return {'needsUpdate': false, 'isRelease': isRelease};
    } catch (e) {
      debugPrint("❌ Version check error: $e");
      return {'needsUpdate': false, 'isRelease': true};
    }
  }

  /// 🔹 Versiyalarni solishtirish:
  /// agar latest > current → true (update kerak)
  /// agar latest <= current → false
  static bool _isNewerVersion(String latest, String current) {
    final latestParts =
        latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts =
        current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (int i = 0; i < maxLength; i++) {
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;

      if (latestPart > currentPart) return true; // yangi versiya
      if (latestPart < currentPart) return false; // eski emas
    }

    return false; // teng bo'lsa update kerak emas
  }

  static void _showUpdateDialog(BuildContext context, String storeUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          'Update required',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'A new version of the app is available.\nPlease update to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse(storeUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Update now'),
          ),
        ],
      ),
    );
  }
}
