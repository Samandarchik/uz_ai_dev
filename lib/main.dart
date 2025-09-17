// main.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uz_ai_dev/core/di/di.dart';
import 'ui/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await setupInit();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('uz'),
        Locale('ru'),
      ],
      path: 'assets/translations', // JSON tarjima fayllar yo‘li
      fallbackLocale: const Locale('uz'),
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
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const LanguageSelectorWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Bu widget SplashScreen va til tanlashni o‘rab turadi
class LanguageSelectorWrapper extends StatelessWidget {
  const LanguageSelectorWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SplashScreen(),
          Positioned(
            top: 40,
            right: 16,
            child: LanguageDropdown(),
          ),
        ],
      ),
    );
  }
}

/// Dropdown orqali til tanlash
class LanguageDropdown extends StatelessWidget {
  LanguageDropdown({super.key});

  final List<Locale> locales = const [
    Locale('uz'),
    Locale('ru'),
  ];

  final Map<String, String> languageNames = const {
    'uz': '🇺🇿 UZ',
    'ru': '🇷🇺 RU',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButton<Locale>(
      value: context.locale,
      underline: const SizedBox(),
      icon: const Icon(Icons.language, color: Colors.blue),
      items: locales.map((locale) {
        return DropdownMenuItem(
          value: locale,
          child: Text(
            languageNames[locale.languageCode]!,
            selectionColor: Colors.white,
          ),
        );
      }).toList(),
      onChanged: (newLocale) {
        if (newLocale != null) {
          context.setLocale(newLocale);
        }
      },
    );
  }
}
