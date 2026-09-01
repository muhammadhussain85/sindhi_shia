import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;

import 'package:home_widget/home_widget.dart';

import 'notification_helper.dart';
import 'screens/splash_screen.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/quran_audio_controller.dart';
import 'controllers/settings_controller.dart';
import 'utils/widget_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the full IANA timezone database then pin tz.local to the
  // device's real zone so that zonedSchedule() fires at the correct instant.
  tzData.initializeTimeZones();
  try {
    final localZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localZone.identifier));
  } catch (_) {
    // Fallback: tz.local stays UTC — epoch-based alarms still fire correctly
    // because TZDateTime.from() converts via millisecondsSinceEpoch.
  }

  await NotificationHelper.initialize();
  await GetStorage.init();

  // Set iOS App Group so home_widget can share data with the widget extension.
  await HomeWidget.setAppGroupId('group.com.tasneemacademy.sindhishiatoolkit');
  // Rotate today's Daily Zikr widget content (fire-and-forget).
  unawaited(WidgetHelper.updateDailyZikrWidget());

  // Paint the Android system bars before the first frame so there is never
  // a white flash on dark-mode devices.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0B0F19),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  Get.put(NavigationController());
  Get.put(SettingsController());
  // permanent: true → GetX never auto-disposes this controller even when no
  // widget is observing it, which keeps background audio alive across tabs.
  Get.put(QuranAudioController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Sindhi Shia Toolkit',
      debugShowCheckedModeBanner: false,

      // LIGHT THEME
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
        fontFamily: 'MBLateefi',
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Color(0xFF0F4C3A)),
        typography: Typography.material2021(),
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'MBLateefi',
          bodyColor: const Color(0xFF1A202C),
          displayColor: const Color(0xFF1A202C),
        ),
      ),

      // DARK THEME
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        fontFamily: 'MBLateefi',
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Color(0xFFD4AF37)),
        typography: Typography.material2021(),
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'MBLateefi',
          bodyColor: const Color(0xFFF3F4F6),
          displayColor: const Color(0xFFF3F4F6),
        ),
      ),

      themeMode: Get.find<SettingsController>().isDarkMode.value
          ? ThemeMode.dark
          : ThemeMode.light,

      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
