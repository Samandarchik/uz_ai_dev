import 'package:package_info_plus/package_info_plus.dart';

Future<void> getAppVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  print('App Name: ${packageInfo.appName}');
  print('Package Name: ${packageInfo.packageName}');
  print('Version: ${packageInfo.version}');
  print('Build Number: ${packageInfo.buildNumber}');
}
