import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_filial_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_user_provider.dart';
import 'package:uz_ai_dev/admin/services/upload_image.dart';
import 'package:uz_ai_dev/admin_agent/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin_agent/provider/admin_filial_provider.dart';
import 'package:uz_ai_dev/admin_agent/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin_agent/provider/admin_user_provider.dart';
import 'package:uz_ai_dev/admin_agent/services/upload_image.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/splash_screen.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';
import 'package:uz_ai_dev/user_agent/provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupInit();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ProductProviderAdmin()),
        ChangeNotifierProvider(create: (_) => CategoryProviderAdmin()),
        ChangeNotifierProvider(create: (_) => CategoryProviderAdminAgent()),
        ChangeNotifierProvider(create: (_) => FilialProviderAdmin()),
        ChangeNotifierProvider(create: (_) => UserProviderAdmin()),
        ChangeNotifierProvider(create: (_) => CategoryProviderAdminUpload()),
        ChangeNotifierProvider(create: (_) => ProductProviderAgent()),
        ChangeNotifierProvider(create: (_) => ProductProviderAgentAdmin()),
        ChangeNotifierProvider(create: (_) => FilialProviderAdminAgent()),
        ChangeNotifierProvider(create: (_) => UserProviderAdminAgent()),
        ChangeNotifierProvider(
            create: (_) => CategoryProviderAdminAgentUpload()),
      ],
      child: const MyApp(), // 🟢 MUHIM: shu joy qo‘shilishi kerak
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Panel',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
        ),
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
