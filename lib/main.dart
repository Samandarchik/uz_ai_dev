// main.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_categoriy_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_filial_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_product_provider.dart';
import 'package:uz_ai_dev/admin/provider/admin_user_provider.dart';
import 'package:uz_ai_dev/admin/services/upload_image.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'package:uz_ai_dev/user/provider/provider.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await setupInit();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ProductProviderAdmin()),
        ChangeNotifierProvider(create: (_) => CategoryProviderAdmin()),
        ChangeNotifierProvider(create: (_) => FilialProviderAdmin()),
        ChangeNotifierProvider(create: (_) => UserProviderAdmin()),
        ChangeNotifierProvider(create: (_) => CategoryProviderAdminUpload()),
      ],
      child: EasyLocalization(
        supportedLocales: const [
          Locale('ru'),
        ],
        path: 'assets/translations', // JSON tarjima fayllar yo‘li
        fallbackLocale: const Locale('ru'),
        child: const MyApp(),
      ),
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
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
