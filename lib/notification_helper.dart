import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'controllers/settings_controller.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _isScheduling = false;

  static const String _channelId   = 'adhan_channel';
  static const String _channelName = 'Adhan Notifications';

  // Call once from main() before runApp.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {
        // Notification tapped — no extra action needed for adhan.
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Delete the stale channel so Android applies our current settings.
    // Without deletion Android silently ignores any channel update
    // (e.g. the vibration=false change we shipped recently).
    await androidPlugin?.deleteNotificationChannel(_channelId);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Prayer time adhan alerts',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('adhan'),
      playSound: true,
      enableVibration: false,
      showBadge: true,
    );

    await androidPlugin?.createNotificationChannel(channel);
  }

  static Future<void> cancelAllAdhans() async {
    await _plugin.cancelAll();
  }

  static Future<void> scheduleNext7Days() async {
    if (_isScheduling) return;
    _isScheduling = true;

    try {
      // ✅ CRITICAL FIX: Check permission BEFORE cancelling anything.
      // The old order (cancelAll → check permission) wiped all scheduled
      // alarms and left users with zero notifications when the permission
      // check returned false for any reason (e.g. OEM background kill,
      // Android < 12 returning false incorrectly, temporary glitch).
      final bool hasPermission = await _hasExactAlarmPermission();

      if (!hasPermission) {
        debugPrint('scheduleNext7Days: no exact alarm permission — existing alarms preserved');
        return;
      }

      // Permission confirmed. Safe to cancel old alarms and reschedule.
      await _plugin.cancelAll();

      final settings = Get.find<SettingsController>();

      final bool playFajr    = !settings.isFajrMuted.value;
      final bool playDhuhr   = !settings.isDhuhrMuted.value;
      final bool playMaghrib = !settings.isMaghribMuted.value;

      if (!playFajr && !playDhuhr && !playMaghrib) {
        debugPrint('scheduleNext7Days: all prayers muted — nothing to schedule');
        return;
      }

      final coordinates =
          Coordinates(settings.manualLat.value, settings.manualLng.value);
      final params = settings.getPrayerParameters();

      int scheduled = 0;

      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().add(Duration(days: i));
        final times = PrayerTimes(coordinates, DateComponents.from(date), params);

        // IDs: day 0 → 1/2/3, day 1 → 4/5/6, …, day 6 → 19/20/21
        final base = i * 3;

        // Each prayer is scheduled independently. A PlatformException from
        // one prayer (e.g. MIUI blocking a specific slot) does NOT cancel
        // the others — _schedule() handles its own errors.
        if (playFajr)    if (await _schedule(base + 1, 'فجر',    times.fajr))    scheduled++;
        if (playDhuhr)   if (await _schedule(base + 2, 'ظهرين',  times.dhuhr))   scheduled++;
        if (playMaghrib) if (await _schedule(base + 3, 'مغربين', times.maghrib)) scheduled++;
      }

      debugPrint('scheduleNext7Days: $scheduled alarms scheduled for the next 7 days');
    } catch (e) {
      debugPrint('scheduleNext7Days error: $e');
    } finally {
      _isScheduling = false;
    }
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Returns true if this device/OS allows exact-alarm scheduling.
  /// On Android < 12 the permission doesn't exist as a runtime grant —
  /// isGranted may return false even though exact alarms work fine.
  /// We treat those cases as "permitted" and let the OS reject individual
  /// alarms at _schedule() level instead of skipping them all.
  static Future<bool> _hasExactAlarmPermission() async {
    try {
      return await Permission.scheduleExactAlarm.isGranted;
    } catch (_) {
      // Permission not recognised on this Android version (<12) — assume granted.
      return true;
    }
  }

  /// Schedules a single prayer notification.
  /// Returns true if the alarm was queued, false if it was in the past or failed.
  static Future<bool> _schedule(int id, String prayerName, DateTime time) async {
    // Skip prayers already in the past (10-second safety buffer).
    if (time.isBefore(DateTime.now().add(const Duration(seconds: 10)))) return false;

    try {
      final scheduledTime = tz.TZDateTime.from(time, tz.local);

      await _plugin.zonedSchedule(
        id,
        '$prayerName جو وقت',
        'نماز جو وقت ٿي ويو آهي.',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Prayer time adhan alerts',
            importance: Importance.high,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('adhan'),
            playSound: true,
            enableVibration: false,
            icon: 'launcher_icon',
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: false,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('_schedule: [$prayerName id=$id] → ${scheduledTime.toString()}');
      return true;
    } on PlatformException catch (e) {
      // Common on MIUI, ColorOS, and some Samsung builds that block exact
      // alarms at the OS level even when the user has granted the permission.
      debugPrint('_schedule[$prayerName id=$id] PlatformException ${e.code}: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('_schedule[$prayerName id=$id] error: $e');
      return false;
    }
  }
}
