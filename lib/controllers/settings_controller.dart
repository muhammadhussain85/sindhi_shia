import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../database/db_helper.dart';
import 'quran_audio_controller.dart';
import '../notification_helper.dart';
import '../utils/smart_permission_helper.dart';
import '../utils/widget_helper.dart';

class SettingsController extends GetxController {
  final storage = GetStorage();

  // ── Display ──────────────────────────────────────────────────────────────
  var isDarkMode        = false.obs;
  var arabicFontSize    = 28.0.obs;
  var sindhiFontSize    = 20.0.obs;
  var readingMode       = 0.obs;
  var selectedTranslation = 0.obs;

  // ── Prayer / Adhan ───────────────────────────────────────────────────────
  var isFajrMuted     = false.obs;
  var isDhuhrMuted    = false.obs;
  var isMaghribMuted  = false.obs;
  var adhanVolume     = 1.0.obs;       // 0.0 – 1.0
  var enableBackgroundAudio = true.obs;

  // ── Location ─────────────────────────────────────────────────────────────
  var isManualLocation      = false.obs;
  var selectedCity          = 'لوڊ ٿي رهيو آهي...'.obs;
  var manualLat             = 25.3960.obs;
  var manualLng             = 68.3578.obs;
  var calcMethod            = 0.obs;

  /// UTC offset (minutes) of the *selected city* — used by the Prayer Time
  /// screen so times are shown in city-local time even when the device is in
  /// a different timezone.  Set to device offset in GPS mode; approximated
  /// from longitude (±30 min accuracy) for manual cities.
  var cityUtcOffsetMinutes = 0.obs;

  // ── Hijri ────────────────────────────────────────────────────────────────
  var hijriAdjustment = 0.obs;   // –5 … +5 days

  // ── Content history & bookmarks ──────────────────────────────────────────
  var lastReadQuran   = {}.obs;
  var lastReadNahjul  = {}.obs;
  var lastReadSahifa  = {}.obs;
  var lastReadAhadith = {}.obs;
  var lastReadZiyarat = {}.obs;
  var bookmarks = <Map<String, dynamic>>[].obs;

  // ── Loading state (for UI) ────────────────────────────────────────────────
  var isFetchingLocation = false.obs;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    loadSettings();
    _loadAndMigrateBookmarks();

    // Schedule adhans on every launch — covers first-run, 7-day expiry and
    // post-reboot scenarios.
    Future.delayed(const Duration(seconds: 5), () {
      NotificationHelper.scheduleNext7Days();
      _updateWidget();
      _updateCalendarWidget();
    });

    ever(hijriAdjustment, (_) => _updateCalendarWidget());

    // Keep system nav-bar colour in sync with theme changes.
    ever(isDarkMode, (dark) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: dark ? const Color(0xFF0B0F19) : Colors.white,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ));
    });

    // Silently refresh GPS once per 24 h for auto-mode users.
    Future.delayed(const Duration(seconds: 8), _maybeRefreshLocation);
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  void _updateWidget() {
    WidgetHelper.updatePrayerWidget(
      lat: manualLat.value,
      lng: manualLng.value,
      params: getPrayerParameters(),
      cityName: selectedCity.value,
    );
  }

  void _updateCalendarWidget() {
    WidgetHelper.updateCalendarWidget(hijriAdjustment: hijriAdjustment.value);
  }

  // ── Location refresh ──────────────────────────────────────────────────────

  Future<void> _maybeRefreshLocation() async {
    if (isManualLocation.value) return;
    final lastRefresh = storage.read<int>('last_location_refresh') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const twentyFourHours = 24 * 60 * 60 * 1000;
    if (now - lastRefresh < twentyFourHours) return;

    final success = await _fetchRealLocation(showPrompts: false);
    if (success) {
      storage.write('last_location_refresh', now);
      NotificationHelper.scheduleNext7Days();
    }
  }

  // ── Toast ─────────────────────────────────────────────────────────────────

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isDarkMode.value ? const Color(0xFFD4AF37) : Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // ── Load / Save ───────────────────────────────────────────────────────────

  void loadSettings() {
    try { isDarkMode.value = storage.read('isDarkMode') ?? false; } catch (_) {}
    try { arabicFontSize.value = ((storage.read('arabicFontSize') ?? 28.0) as num).toDouble().clamp(16.0, 50.0); } catch (_) {}
    try { sindhiFontSize.value = ((storage.read('sindhiFontSize') ?? 20.0) as num).toDouble().clamp(16.0, 40.0); } catch (_) {}
    try { readingMode.value = storage.read('readingMode') ?? 0; } catch (_) {}
    try { selectedTranslation.value = storage.read('selectedTranslation') ?? 0; } catch (_) {}
    try { hijriAdjustment.value = ((storage.read('hijriAdjustment') ?? 0) as num).toInt().clamp(-5, 5); } catch (_) {}

    try { isFajrMuted.value    = storage.read('isFajrMuted')    ?? false; } catch (_) {}
    try { isDhuhrMuted.value   = storage.read('isDhuhrMuted')   ?? false; } catch (_) {}
    try { isMaghribMuted.value = storage.read('isMaghribMuted') ?? false; } catch (_) {}
    try { adhanVolume.value    = ((storage.read('adhanVolume') ?? 1.0) as num).toDouble().clamp(0.0, 1.0); } catch (_) {}
    try { enableBackgroundAudio.value = storage.read('enableBackgroundAudio') ?? true; } catch (_) {}

    try { isManualLocation.value = storage.read('isManualLocation') ?? false; } catch (_) {}
    try { selectedCity.value     = storage.read('selectedCity') ?? 'دستي مقام (Manual)'; } catch (_) {}
    try { manualLat.value = ((storage.read('manualLat') ?? 25.3960) as num).toDouble(); } catch (_) {}
    try { manualLng.value = ((storage.read('manualLng') ?? 68.3578) as num).toDouble(); } catch (_) {}
    try { calcMethod.value = storage.read('calcMethod') ?? 0; } catch (_) {}
    try {
      cityUtcOffsetMinutes.value =
          (storage.read('cityUtcOffsetMinutes') ?? DateTime.now().timeZoneOffset.inMinutes) as int;
    } catch (_) {
      cityUtcOffsetMinutes.value = DateTime.now().timeZoneOffset.inMinutes;
    }

    lastReadQuran.value   = _safeMapRead('lastReadQuran');
    lastReadNahjul.value  = _safeMapRead('lastReadNahjul');
    lastReadSahifa.value  = _safeMapRead('lastReadSahifa');
    lastReadAhadith.value = _safeMapRead('lastReadAhadith');
    lastReadZiyarat.value = _safeMapRead('lastReadZiyarat');

    _applyTheme();

    if (!isManualLocation.value && selectedCity.value == 'لوڊ ٿي رهيو آهي...') {
      _fetchRealLocation(showPrompts: false);
    }
  }

  Future<void> _loadAndMigrateBookmarks() async {
    try {
      final List? old = storage.read<List>('bookmarks');
      if (old != null && old.isNotEmpty) {
        for (final item in old) {
          await DBHelper.insertBookmark(Map<String, dynamic>.from(item as Map));
        }
        storage.remove('bookmarks');
      }
    } catch (_) {}

    try {
      bookmarks.value = await DBHelper.getAllBookmarks();
    } catch (_) {
      bookmarks.value = [];
    }
  }

  Map<String, dynamic> _safeMapRead(String key) {
    try {
      final data = storage.read(key);
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(
            data.map((k, v) => MapEntry(k.toString(), v)));
      }
    } catch (_) {}
    return {};
  }

  // ── Prayer calculation ────────────────────────────────────────────────────

  /// Returns CalculationParameters for the selected method.
  /// Method 0 = Tehran University (standard Shia, default).
  /// Method 1 = Leva Institute, Qum (alternative Shia).
  CalculationParameters getPrayerParameters() {
    CalculationParameters params;
    if (calcMethod.value == 1) {
      // Leva Institute, Qum
      params = CalculationMethod.other.getParameters();
      params.fajrAngle   = 16.0;
      params.maghribAngle = 4.0;
      params.ishaAngle   = 14.0;
    } else {
      // Tehran University — default Shia method
      params = CalculationMethod.tehran.getParameters();
    }
    params.madhab = Madhab.shafi;
    return params;
  }

  /// Returns today's date in the *selected city's* local timezone so that
  /// prayer times are calculated for the correct calendar day even when the
  /// device is in a different timezone.
  DateTime getCityLocalNow() {
    return DateTime.now()
        .toUtc()
        .add(Duration(minutes: cityUtcOffsetMinutes.value));
  }

  /// Formats a prayer-time DateTime (returned as device-local by the adhan
  /// package) into the selected city's local time string.
  String formatPrayerTime(DateTime prayerTime) {
    // adhan returns .toLocal() — convert back to UTC then apply city offset.
    final cityTime = prayerTime.toUtc()
        .add(Duration(minutes: cityUtcOffsetMinutes.value));
    final h  = cityTime.hour % 12 == 0 ? 12 : cityTime.hour % 12;
    final m  = cityTime.minute.toString().padLeft(2, '0');
    final ap = cityTime.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  // ── Location control ──────────────────────────────────────────────────────

  Future<void> setAutoMode(bool isAuto) async {
    if (isAuto) {
      final context = Get.context ?? Get.overlayContext;
      if (context != null) {
        final hasPermission =
            await SmartPermissionHelper.requireLocation(context);
        if (!hasPermission) return;
      }

      final success = await _fetchRealLocation(showPrompts: true);
      if (success) {
        isManualLocation.value = false;
        calcMethod.value = 0;
        storage.write('isManualLocation', false);
        storage.write('calcMethod', 0);
        _showToast("آٽو لوڪيشن ڪاميابي سان سيٽ ٿي وئي!");
        NotificationHelper.scheduleNext7Days();
      }
    } else {
      isManualLocation.value = true;
      storage.write('isManualLocation', true);
      NotificationHelper.scheduleNext7Days();
    }
  }

  Future<bool> _fetchRealLocation({required bool showPrompts}) async {
    if (isFetchingLocation.value) return false;
    isFetchingLocation.value = true;

    final bool isDark     = isDarkMode.value;
    final Color bgColor   = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color goldColor =
        isDark ? const Color(0xFFD4AF37) : const Color(0xFFB88A44);

    if (showPrompts) {
      Get.dialog(
        Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 15)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: goldColor),
                  const SizedBox(height: 20),
                  Text(
                    "لوڪيشن ڳولي پئي وڃي...",
                    style: TextStyle(
                        fontFamily: 'MBLateefi',
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );
    }

    try {
      // ── Connectivity check ────────────────────────────────────────────
      bool online = false;
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        online = false;
      }

      // ── GPS position ──────────────────────────────────────────────────
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) throw Exception("Location unavailable");

      // ── City name resolution (online: geocoding; offline: SQLite) ─────
      String foundCity = "موجوده لوڪيشن (GPS)";

      if (online) {
        try {
          final marks = await placemarkFromCoordinates(
              position.latitude, position.longitude);
          if (marks.isNotEmpty) {
            final p = marks.first;
            foundCity =
                "${p.locality ?? p.subAdministrativeArea ?? p.name}, ${p.country}";
          }
        } catch (_) {
          // Geocoding failed even online — fall back to SQLite
          final nearest = await DBHelper.getNearestCity(
              position.latitude, position.longitude);
          if (nearest != null) {
            foundCity = "${nearest['city']}, ${nearest['country']}";
          }
        }
      } else {
        // Offline: use local SQLite city database
        final nearest = await DBHelper.getNearestCity(
            position.latitude, position.longitude);
        if (nearest != null) {
          foundCity = "${nearest['city']}, ${nearest['country']}";
        }
      }

      manualLat.value    = position.latitude;
      manualLng.value    = position.longitude;
      selectedCity.value = foundCity;

      final deviceOffset = DateTime.now().timeZoneOffset.inMinutes;
      cityUtcOffsetMinutes.value = deviceOffset;

      storage.write('manualLat', position.latitude);
      storage.write('manualLng', position.longitude);
      storage.write('selectedCity', foundCity);
      storage.write('cityUtcOffsetMinutes', deviceOffset);

      _updateWidget();
      _updateCalendarWidget();

      if (showPrompts) Get.back();
      return true;

    } catch (_) {
      if (showPrompts) {
        Get.back();
        _showActionDialog(
          "مسئلو",
          "لوڪيشن ڳولڻ ۾ مسئلو پيش آيو. GPS يا انٽرنيٽ چيڪ ڪريو.",
          isDark,
          bgColor,
          textColor,
          goldColor,
          null,
          null,
        );
      }
      return false;
    } finally {
      isFetchingLocation.value = false;
    }
  }

  void _showActionDialog(
    String title,
    String message,
    bool isDark,
    Color bgColor,
    Color textColor,
    Color goldColor,
    VoidCallback? onAction,
    String? actionText,
  ) {
    Get.defaultDialog(
      title: title,
      titleStyle: TextStyle(
          fontFamily: 'MBLateefi',
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: Colors.redAccent.shade200),
      middleText: message,
      middleTextStyle: TextStyle(
          fontFamily: 'MBLateefi',
          fontSize: 20,
          color: textColor.withValues(alpha: 0.8)),
      backgroundColor: bgColor,
      radius: 16,
      barrierDismissible: true,
      actions: [
        if (onAction != null && actionText != null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: goldColor, elevation: 0),
            onPressed: () {
              Get.back();
              onAction();
            },
            child: Text(actionText,
                style: const TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        TextButton(
          onPressed: () => Get.back(),
          child: Text("رد ڪريو",
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 18,
                  color: textColor.withValues(alpha: 0.5))),
        ),
      ],
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    );
  }

  void setCity(String city, double lat, double lng) {
    selectedCity.value = city;
    manualLat.value    = lat;
    manualLng.value    = lng;
    // Approximate UTC offset from longitude (±30 min accuracy; GPS mode uses
    // exact device offset instead).
    final approxOffset = (lng / 15.0 * 60).round();
    cityUtcOffsetMinutes.value = approxOffset;

    storage.write('selectedCity', city);
    storage.write('manualLat', lat);
    storage.write('manualLng', lng);
    storage.write('cityUtcOffsetMinutes', approxOffset);

    NotificationHelper.scheduleNext7Days();
    _updateWidget();
    _updateCalendarWidget();
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  Future<void> clearDownloadedAudio() async {
    try {
      final dir      = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/quran_audio');
      if (await audioDir.exists()) {
        await audioDir.delete(recursive: true);
        if (Get.isRegistered<QuranAudioController>()) {
          final audioCtrl = Get.find<QuranAudioController>();
          await audioCtrl.stopAudio();
          audioCtrl.isSurahDownloaded.value = false;
        }
        _showToast("سڀ ڊائونلوڊ ٿيل آڊيو ڊليٽ ٿي وئي");
      } else {
        _showToast("ڪا به آڊيو فائل موجود ناهي");
      }
    } catch (_) {
      _showToast("ڊليٽ ڪرڻ ۾ مسئلو آيو");
    }
  }

  void toggleFajrMute() {
    isFajrMuted.value = !isFajrMuted.value;
    storage.write('isFajrMuted', isFajrMuted.value);
    NotificationHelper.scheduleNext7Days();
  }

  void toggleDhuhrMute() {
    isDhuhrMuted.value = !isDhuhrMuted.value;
    storage.write('isDhuhrMuted', isDhuhrMuted.value);
    NotificationHelper.scheduleNext7Days();
  }

  void toggleMaghribMute() {
    isMaghribMuted.value = !isMaghribMuted.value;
    storage.write('isMaghribMuted', isMaghribMuted.value);
    NotificationHelper.scheduleNext7Days();
  }

  void setAdhanVolume(double vol) {
    adhanVolume.value = vol;
    storage.write('adhanVolume', vol);
  }

  void toggleBackgroundAudio(bool val) {
    enableBackgroundAudio.value = val;
    storage.write('enableBackgroundAudio', val);
  }

  // ── Calc & Hijri ──────────────────────────────────────────────────────────

  void setCalcMethod(int val) {
    calcMethod.value = val;
    storage.write('calcMethod', val);
    NotificationHelper.scheduleNext7Days();
  }

  void adjustHijri(int val) {
    hijriAdjustment.value = val.clamp(-5, 5);
    storage.write('hijriAdjustment', hijriAdjustment.value);
  }

  // ── Content tracking ──────────────────────────────────────────────────────

  void saveLastReadQuran(int id, String t, bool j, {int index = 0}) {
    final d = {'id': id, 'title': t, 'isJuz': j, 'index': index};
    lastReadQuran.value = d;
    storage.write('lastReadQuran', d);
  }

  void saveLastReadNahjul(int id, String t, {int index = 0}) {
    final d = {'id': id, 'title': t, 'index': index};
    lastReadNahjul.value = d;
    storage.write('lastReadNahjul', d);
  }

  void saveLastReadSahifa(int id, String t, {int index = 0}) {
    final d = {'id': id, 'title': t, 'index': index};
    lastReadSahifa.value = d;
    storage.write('lastReadSahifa', d);
  }

  void saveLastReadAhadith(int id, String t, {int index = 0}) {
    final d = {'id': id, 'title': t, 'index': index};
    lastReadAhadith.value = d;
    storage.write('lastReadAhadith', d);
  }

  void saveLastReadZiyarat(int id, String t, {int index = 0}) {
    final d = {'id': id, 'title': t, 'index': index};
    lastReadZiyarat.value = d;
    storage.write('lastReadZiyarat', d);
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────────

  bool isBookmarked(String type, String uid) =>
      bookmarks.any((b) => b['bookType'] == type && b['uniqueId'] == uid);

  void toggleBookmark(String type, String uid, String title, String arabic,
      String tr) {
    if (isBookmarked(type, uid)) {
      bookmarks.removeWhere(
          (b) => b['bookType'] == type && b['uniqueId'] == uid);
      DBHelper.deleteBookmark(type, uid);
      _showToast("محفوظ ڪيل فهرست مان ڪڍيو ويو");
    } else {
      final mark = {
        'bookType': type,
        'uniqueId': uid,
        'title': title,
        'arabic': arabic,
        'translation': tr,
        'nickname': '',
        'note': '',
        'translationIndex': selectedTranslation.value,
        'timestamp': DateTime.now().toIso8601String(),
      };
      bookmarks.insert(0, mark);
      DBHelper.insertBookmark(mark);
      _showToast("محفوظ ڪيو ويو");
    }
  }

  void editBookmarkNote(
      String type, String uid, String newNickname, String newNote) {
    final index =
        bookmarks.indexWhere((b) => b['bookType'] == type && b['uniqueId'] == uid);
    if (index != -1) {
      bookmarks[index]['nickname'] = newNickname;
      bookmarks[index]['note']     = newNote;
      bookmarks.refresh();
      DBHelper.updateBookmarkNote(type, uid, newNickname, newNote);
      _showToast("توهان جو نوٽ محفوظ ٿي ويو آهي");
    }
  }

  // ── Theme & Display ───────────────────────────────────────────────────────

  void setReadingMode(int val) { readingMode.value = val; storage.write('readingMode', val); }
  void updateArabicSize(double size) { arabicFontSize.value = size; storage.write('arabicFontSize', size); }
  void updateSindhiSize(double size) { sindhiFontSize.value = size; storage.write('sindhiFontSize', size); }
  void toggleTheme(bool val) { isDarkMode.value = val; storage.write('isDarkMode', val); _applyTheme(); }
  void _applyTheme() => Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  void changeTranslation(int val) {
    DBHelper.clearQuranDatabase();
    selectedTranslation.value = val;
    storage.write('selectedTranslation', val);
  }

  // ── Reset / Clear ─────────────────────────────────────────────────────────

  void resetToDefault() {
    isDarkMode.value = false;
    arabicFontSize.value = 28.0;
    sindhiFontSize.value = 20.0;
    readingMode.value = 0;
    selectedTranslation.value = 0;
    hijriAdjustment.value = 0;
    enableBackgroundAudio.value = true;
    adhanVolume.value = 1.0;
    isFajrMuted.value = false;
    isDhuhrMuted.value = false;
    isMaghribMuted.value = false;
    isManualLocation.value = false;
    selectedCity.value = 'Unknown';
    manualLat.value = 25.3960;
    manualLng.value = 68.3578;
    calcMethod.value = 0;
    storage.erase();
    setAutoMode(true);
    _applyTheme();
    _showToast("سيٽنگز ڊفالٽ تي ري سيٽ ٿي ويون");
  }

  void clearBookmarks() {
    bookmarks.clear();
    DBHelper.clearAllBookmarks();
    _showToast("سڀ بڪ مارڪس ڊليٽ ٿي ويا");
  }

  void clearLastReads() {
    lastReadQuran.value   = {};
    lastReadNahjul.value  = {};
    lastReadSahifa.value  = {};
    lastReadAhadith.value = {};
    lastReadZiyarat.value = {};
    storage.remove('lastReadQuran');
    storage.remove('lastReadNahjul');
    storage.remove('lastReadSahifa');
    storage.remove('lastReadAhadith');
    storage.remove('lastReadZiyarat');
    _showToast("آخري ڀيرو پڙهيل ڊيٽا صاف ڪئي وئي");
  }

  Future<void> showAdhanFixWarning() async {
    await SmartPermissionHelper.checkAndShowAdhanPermissionSheet();
    NotificationHelper.scheduleNext7Days();
  }
}
