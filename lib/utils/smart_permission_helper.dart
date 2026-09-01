import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'app_colors.dart';
import '../notification_helper.dart';

class SmartPermissionHelper {

  // ✨ ADHAN PERMISSION SHEET

  // Fixed: use isGranted instead of isDenied.
  // isDenied misses permanently-denied and restricted states on Android 12+,
  // causing SCHEDULE_EXACT_ALARM to silently fail with no dialog ever shown.
  static Future<bool> needsAdhanPermissions() async {
    if (!Platform.isAndroid) return false;
    final bool notif = await Permission.notification.isGranted;
    final bool alarm = await Permission.scheduleExactAlarm.isGranted;
    final bool batt  = await Permission.ignoreBatteryOptimizations.isGranted;
    return !notif || !alarm || !batt;
  }

  static Future<void> checkAndShowAdhanPermissionSheet() async {
    if (await needsAdhanPermissions()) {
      Get.bottomSheet(
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        const _AdhanPermissionSheet(),
      );
    }
  }

  // Called from settings "Fix Adhan" button and from the grant button on the sheet.
  // NOTE: scheduleExactAlarm.request() on Android 12+ opens System Settings and returns
  // immediately — the user hasn't granted yet. So we do NOT schedule here.
  // Rescheduling happens in didChangeAppLifecycleState(resumed) after the user returns.
  static Future<void> requestAdhanPermissions() async {
    if (!Platform.isAndroid) return;
    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }
    if (!await Permission.scheduleExactAlarm.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  // ✨ LOCATION PERMISSIONS (unchanged)

  static Future<bool> requireLocation(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showExplanationDialog(
        title: "لوڪيشن آن ڪريو",
        message: "قبلي جي رخ ۽ نماز جي وقتن لاءِ، مهرباني ڪري پنهنجي موبائيل جي لوڪيشن (GPS) آن ڪريو.",
        icon: Icons.location_off_rounded,
        onConfirm: () async { Get.back(); await Geolocator.openLocationSettings(); },
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      bool userAgreed = await _showExplanationDialog(
        title: "لوڪيشن جي اجازت",
        message: "توهان جي شهر جي حساب سان نماز جا درست وقت ۽ قبلي جو رخ ڏيکارڻ لاءِ لوڪيشن جي اجازت گهربل آهي.",
        icon: Icons.my_location_rounded,
        onConfirm: () => Get.back(result: true),
      ) ?? false;
      if (userAgreed) permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await _showExplanationDialog(
        title: "اجازت رد ٿيل آهي",
        message: "توهان لوڪيشن جي اجازت هميشه لاءِ بند ڪئي آهي. سيٽنگز ۾ وڃي ان کي آن ڪريو يا دستي طور شهر چونڊيو.",
        icon: Icons.settings_rounded,
        onConfirm: () async { Get.back(); await openAppSettings(); },
      );
      return false;
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  static Future<dynamic> _showExplanationDialog({required String title, required String message, required IconData icon, required VoidCallback onConfirm}) {
    return Get.dialog(
      Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.gold.withValues(alpha:0.1), shape: BoxShape.circle), child: Icon(icon, size: 40, color: AppColors.gold)),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: AppColors.text.withValues(alpha:0.8), height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: onConfirm,
                  child: const Text("ٺيڪ آهي", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ✨ Dedicated StatefulWidget for the permission sheet so it can
// show real-time permission status for each row.
class _AdhanPermissionSheet extends StatefulWidget {
  const _AdhanPermissionSheet();

  @override
  State<_AdhanPermissionSheet> createState() => _AdhanPermissionSheetState();
}

class _AdhanPermissionSheetState extends State<_AdhanPermissionSheet> with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _alarmGranted = false;
  bool _battGranted  = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Called when user returns from Android Settings (e.g. after granting scheduleExactAlarm).
  // This is the correct place to reschedule — scheduleExactAlarm.request() opens Settings
  // and returns immediately, so the permission isn't actually granted until the user comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus().then((_) {
        if (_notifGranted && _alarmGranted && _battGranted) {
          NotificationHelper.scheduleNext7Days();
        }
      });
    }
  }

  Future<void> _refreshStatus() async {
    final n = await Permission.notification.isGranted;
    final a = await Permission.scheduleExactAlarm.isGranted;
    final b = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) {
      setState(() {
        _notifGranted = n;
        _alarmGranted = a;
        _battGranted  = b;
      });
    }
  }

  Future<void> _grant() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    // Request each permission while sheet stays open.
    // scheduleExactAlarm opens Android Settings and returns immediately —
    // didChangeAppLifecycleState(resumed) will refresh status when user comes back.
    await SmartPermissionHelper.requestAdhanPermissions();
    await _refreshStatus();
    if (mounted) setState(() => _isRequesting = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool allGranted = _notifGranted && _alarmGranted && _battGranted;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withValues(alpha:0.12), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44, height: 5,
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha:0.25), borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 22),

          Icon(Icons.mosque_rounded, size: 56, color: AppColors.gold),
          const SizedBox(height: 14),

          Text(
            allGranted ? "سڀ اجازتون مليل آهن ✓" : "اذان لاءِ اجازت گهربل آهي",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'MBLateefi', fontSize: 26,
              fontWeight: FontWeight.bold,
              color: allGranted ? Colors.green : AppColors.text,
            ),
          ),
          const SizedBox(height: 8),

          if (!allGranted)
            Text(
              "صحيح وقت تي اذان ٻڌڻ لاءِ، مھرباني ڪري هيٺيون اجازتون ڏيو.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'MBLateefi', fontSize: 17, color: AppColors.text.withValues(alpha:0.65), height: 1.5),
            ),
          const SizedBox(height: 26),

          // Permission rows with live status indicators
          _permissionRow(Icons.notifications_active_rounded, "نوٽيفڪيشن",       "اذان جي وقت اسڪرين تي پيغام", _notifGranted),
          const SizedBox(height: 14),
          _permissionRow(Icons.alarm_rounded,                "الارم جي اجازت",  "مقرر وقت تي اذان هلائڻ لاءِ", _alarmGranted),
          const SizedBox(height: 14),
          _permissionRow(Icons.battery_saver_rounded,       "بيٽري پابندي هٽايو", "بيٽري سيور کي اذان روڪڻ کان منع", _battGranted),

          const SizedBox(height: 30),

          if (!allGranted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _isRequesting ? null : _grant,
                child: _isRequesting
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text("اجازت ڏيو (Grant Permissions)",
                        style: TextStyle(fontFamily: 'MBLateefi', fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                "هاڻي نه (Skip for now)",
                style: TextStyle(fontFamily: 'MBLateefi', fontSize: 17, color: AppColors.text.withValues(alpha:0.45)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () => Get.back(),
                child: const Text("بند ڪريو (Close)",
                    style: TextStyle(fontFamily: 'MBLateefi', fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],

          const SizedBox(height: 4),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                "مسئلو آهي؟ (Troubleshooting)",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: AppColors.text.withValues(alpha: 0.5)),
              ),
              iconColor: AppColors.text.withValues(alpha: 0.35),
              collapsedIconColor: AppColors.text.withValues(alpha: 0.35),
              children: [
                const SizedBox(height: 6),
                _troubleshootRow(Icons.battery_saver_rounded, "بيٽري سيور بند ڪريو",
                    "Settings → Battery → Battery Saver → Turn Off"),
                const SizedBox(height: 10),
                _troubleshootRow(Icons.phone_android_rounded, "Xiaomi / Redmi ڦون",
                    "Settings → Apps → Special App Access → Alarms & Reminders → Allow"),
                const SizedBox(height: 10),
                _troubleshootRow(Icons.settings_applications_rounded, "Samsung / Oppo / Vivo",
                    "Settings → Apps → هي اپ → Battery → Unrestricted"),
                const SizedBox(height: 10),
                _troubleshootRow(Icons.help_outline_rounded, "اجازت نه ٿي ملي؟",
                    "هيٺ 'اپ سيٽنگز' بٽڻ دٻائو ۽ اجازتون هٿ سان ڏيو"),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text("اپ سيٽنگز کوليو (Open App Settings)",
                        style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _troubleshootRow(IconData icon, String title, String subtitle) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.gold.withValues(alpha: 0.75), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              Text(title, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
              Text(subtitle, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 13, color: AppColors.text.withValues(alpha: 0.55), height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _permissionRow(IconData icon, String title, String subtitle, bool isGranted) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: isGranted ? Colors.green.withValues(alpha:0.1) : AppColors.gold.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isGranted ? Colors.green : AppColors.gold, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              Text(title, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.text)),
              Text(subtitle, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 15, color: AppColors.text.withValues(alpha:0.55))),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Icon(
          isGranted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isGranted ? Colors.green : AppColors.text.withValues(alpha:0.3),
          size: 22,
        ),
      ],
    );
  }
}
