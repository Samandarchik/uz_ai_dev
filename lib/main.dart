import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_filial_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/provider/upload_image_provider.dart';
import 'package:uz_ai_dev/bugalter/provider/bugalter_provider.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/ombor/provider/ombor_provider.dart';
import 'package:uz_ai_dev/production/provider/production_orders_provider.dart';
import 'package:uz_ai_dev/production/provider/stock_provider.dart';
import 'package:uz_ai_dev/shef/provider/shef_provider.dart';
import 'package:uz_ai_dev/yuk/provider/yuk_provider.dart';
import 'package:uz_ai_dev/splash_screen.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupInit();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => OmborProvider()),
        ChangeNotifierProvider(create: (_) => YukProvider()),
        ChangeNotifierProvider(create: (_) => BugalterProvider()),
        ChangeNotifierProvider(create: (_) => ShefProvider()),
        // Ishlab chiqarish (ombor/admin/bugalter) + sklad qoldig'i.
        ChangeNotifierProvider(create: (_) => OmborProductionProvider()),
        ChangeNotifierProvider(create: (_) => AdminProductionProvider()),
        ChangeNotifierProvider(create: (_) => BugalterProductionProvider()),
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => ProductProviderAdmin()),
        ChangeNotifierProvider(create: (_) => CategoryProviderAdmin()),
        ChangeNotifierProvider(create: (_) => FilialProviderAdmin()),
        ChangeNotifierProvider(create: (_) => CategoryProviderAdminUpload()),
      ],
      child: const MyApp(),
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
