// user/services/info_piuls.dart — Ilova versiyasini qaytaruvchi kichik yordamchi: getAppVersion()
// (package_info_plus orqali "Version: x.y.z" matni).
import 'package:package_info_plus/package_info_plus.dart';

Future<String> getAppVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return "Version: ${packageInfo.version}";
}
