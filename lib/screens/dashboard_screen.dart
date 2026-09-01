import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/settings_controller.dart';
import '../controllers/navigation_controller.dart';
import '../utils/app_colors.dart';

import 'fehrest_screen.dart';
import 'quran_index_screen.dart';
import 'qibla_screen.dart';
import 'tasbeeh_screen.dart';
import 'istikhara_screen.dart';
import 'prayer_time_screen.dart';
import 'nahjul_index_screen.dart';
import 'quran_reading_screen.dart';
import 'nahjul_reading_screen.dart';
import 'reading_screen.dart';
import 'about_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'ahadith_index_screen.dart';
import 'ziyarat_index_screen.dart';
import 'calendar_screen.dart';
import 'ahadith_reading_screen.dart';
import 'ziyarat_reading_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  // ─── Tour GlobalKeys ───────────────────────────────────────────────────────
  // Static so they are created once per app lifetime, stable across hot
  // reloads, and accessible from MainLayout (which imports DashboardScreen).
  static final GlobalKey menuShowcaseKey      = GlobalKey(debugLabel: 'tour_menu');
  static final GlobalKey calendarShowcaseKey  = GlobalKey(debugLabel: 'tour_calendar');
  static final GlobalKey prayerShowcaseKey    = GlobalKey(debugLabel: 'tour_prayer');
  static final GlobalKey tasbeehShowcaseKey   = GlobalKey(debugLabel: 'tour_tasbeeh');
  static final GlobalKey searchTabShowcaseKey = GlobalKey(debugLabel: 'tour_search_tab');

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String todayGregorian = '';
  String todayHijri = '';
  String currentPrayerName = 'نماز...';
  String nextPrayerName = '...';
  String nextPrayerTime = '--:--';
  DateTime? _nextPrayerDateTime;
  // Cached Maghrib time — the Islamic day boundary. Set by _calculatePrayers()
  // and read by both _loadDates() and build() with no extra PrayerTimes call.
  DateTime? _todayMaghrib;
  String _appVersion = 'v1.0.0';

  Timer? _syncTimer;     // one-shot: waits until the next exact :00 second
  Timer? _periodicTimer; // 1-minute periodic, started only after the sync fires
  final List<Worker> _workers = [];

  @override
  void initState() {
    super.initState();
    _initDashboard();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = 'v${info.version}');
    });

    final settings = Get.find<SettingsController>();
    _workers.add(ever(settings.manualLat, (_) => _calculatePrayers()));
    _workers.add(ever(settings.calcMethod, (_) => _calculatePrayers()));
    _workers.add(ever(settings.hijriAdjustment, (_) => _loadDates()));

    _startSyncedTimer();

    // First-launch tour: show once, mark as seen immediately so even if the
    // user kills the app mid-tour they won't see it again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hasSeen = GetStorage().read<bool>('has_seen_tour') ?? false;
      if (!hasSeen) {
        GetStorage().write('has_seen_tour', true);
        _startTour();
      }
    });
  }

  /// Starts the app tour from the first step.
  /// Can be called from initState (first launch) or from the drawer (replay).
  void _startTour() {
    try {
      ShowCaseWidget.of(context).startShowCase([
        DashboardScreen.menuShowcaseKey,
        DashboardScreen.calendarShowcaseKey,
        DashboardScreen.prayerShowcaseKey,
        DashboardScreen.tasbeehShowcaseKey,
        DashboardScreen.searchTabShowcaseKey,
      ]);
    } catch (e) {
      debugPrint('Showcase could not start: $e');
    }
  }

  // Waits until the next exact :00-second mark, then runs every 60 s perfectly
  // in sync with the system clock so the countdown never lags by up to 59 s.
  void _startSyncedTimer() {
    final now = DateTime.now();
    final msUntilNextMinute = (60 - now.second) * 1000 - now.millisecond;

    _syncTimer = Timer(Duration(milliseconds: msUntilNextMinute), () {
      if (!mounted) return;
      _calculatePrayers();
      _loadDates();
      _periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) {
          _calculatePrayers();
          _loadDates();
        }
      });
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _periodicTimer?.cancel();
    for (var worker in _workers) { worker.dispose(); }
    super.dispose();
  }

  Future<void> _initDashboard() async {
    _loadDates();
    _calculatePrayers();
  }

  void _loadDates() {
    if (!mounted) return;
    final SettingsController settings = Get.find<SettingsController>();
    final DateTime now = DateTime.now();
    todayGregorian = DateFormat('EEE dd-MM-yyyy').format(now);

    final DateTime maghrib = _todayMaghrib ??
        PrayerTimes.today(
          Coordinates(settings.manualLat.value, settings.manualLng.value),
          settings.getPrayerParameters(),
        ).maghrib;

    // Islamic day starts at Maghrib (sunset), not midnight.
    final int islamicDayOffset = now.isAfter(maghrib) ? 1 : 0;
    final DateTime adjustedDate =
        now.add(Duration(days: settings.hijriAdjustment.value + islamicDayOffset));
    final HijriCalendar hijriToday = HijriCalendar.fromDate(adjustedDate);

    setState(() {
      todayHijri = '${hijriToday.hDay} ${hijriToday.longMonthName}, ${hijriToday.hYear}';
    });
  }

  void _calculatePrayers() {
    if (!mounted) return;
    final settings = Get.find<SettingsController>();
    final myCoordinates = Coordinates(settings.manualLat.value, settings.manualLng.value);
    final params = settings.getPrayerParameters();

    final prayerTimesToday = PrayerTimes.today(myCoordinates, params);
    final nextPrayer = prayerTimesToday.nextPrayer();
    _todayMaghrib = prayerTimesToday.maghrib;

    setState(() {
      switch (nextPrayer) {
        case Prayer.fajr:
          currentPrayerName   = 'مغربين';
          nextPrayerName      = 'فجر';
          nextPrayerTime      = DateFormat('h:mm a').format(prayerTimesToday.fajr);
          _nextPrayerDateTime = prayerTimesToday.fajr;

        case Prayer.sunrise:
        case Prayer.dhuhr:
          currentPrayerName   = 'فجر';
          nextPrayerName      = 'ظهرين';
          nextPrayerTime      = DateFormat('h:mm a').format(prayerTimesToday.dhuhr);
          _nextPrayerDateTime = prayerTimesToday.dhuhr;

        case Prayer.asr:
        case Prayer.maghrib:
          currentPrayerName   = 'ظهرين';
          nextPrayerName      = 'مغربين';
          nextPrayerTime      = DateFormat('h:mm a').format(prayerTimesToday.maghrib);
          _nextPrayerDateTime = prayerTimesToday.maghrib;

        case Prayer.isha:
        case Prayer.none:
          currentPrayerName = 'مغربين';
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          final tomorrowTimes = PrayerTimes(
            myCoordinates,
            DateComponents.from(tomorrow),
            params,
          );
          nextPrayerName      = 'فجر (سڀاڻي)';
          nextPrayerTime      = DateFormat('h:mm a').format(tomorrowTimes.fajr);
          _nextPrayerDateTime = tomorrowTimes.fajr;
      }
    });
  }

  String _getCountdown() {
    if (_nextPrayerDateTime == null) return '';
    final diff = _nextPrayerDateTime!.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds < 60) return '';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m left';
    return '${m}m left';
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h >= 4 && h < 12) return 'صبح بخير';
    if (h >= 12 && h < 17) return 'ظهرين مبارڪ';
    if (h >= 17 && h < 21) return 'مغربين مبارڪ';
    return 'السلام عليکم';
  }

  // ─── Shared tooltip style helpers ─────────────────────────────────────────

  TextStyle get _showcaseTitleStyle => TextStyle(
    fontFamily: 'MBLateefi',
    color: AppColors.gold,
    fontSize: 19,
    fontWeight: FontWeight.bold,
  );

  TextStyle get _showcaseDescStyle => TextStyle(
    fontFamily: 'MBLateefi',
    color: AppColors.text,
    fontSize: 16,
    height: 1.5,
  );

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = Get.find<SettingsController>();

    return Obx(() {
      final isDark = settings.isDarkMode.value;

      final DateTime now = DateTime.now();
      final String obxGregorian = DateFormat('EEE dd-MM-yyyy').format(now);
      final int islamicDayOffset =
          (_todayMaghrib != null && now.isAfter(_todayMaghrib!)) ? 1 : 0;
      final DateTime adjustedDate =
          now.add(Duration(days: settings.hijriAdjustment.value + islamicDayOffset));
      final HijriCalendar today = HijriCalendar.fromDate(adjustedDate);
      final String obxHijri = '${today.hDay} ${today.longMonthName}, ${today.hYear}';

      return Scaffold(
        backgroundColor: AppColors.background,
        drawer: _buildDrawer(isDark, context),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero header ────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF111827), const Color(0xFF0B0F19)]
                          : [const Color(0xFF064E3B), const Color(0xFF022C22)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.4 : 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: -10,
                        child: Icon(
                          Icons.mosque_rounded,
                          size: 240,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 24, right: 24, top: 20, bottom: 35,
                        ),
                        child: Column(
                          children: [
                            // ── Top row: menu | date | calendar ────────────
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Tour step 1 — Sidebar / Drawer icon
                                  Showcase(
                                    key: DashboardScreen.menuShowcaseKey,
                                    title: 'مينو (Sidebar)',
                                    description:
                                        'هتي ڪلڪ ڪري سيٽنگز، اسان جي باري ۾، '
                                        'ريٽنگ ۽ وڌيڪ آپشن ڏسو.',
                                    tooltipBackgroundColor: AppColors.card,
                                    titleTextStyle: _showcaseTitleStyle,
                                    descTextStyle: _showcaseDescStyle,
                                    child: Builder(
                                      builder: (ctx) => IconButton(
                                        padding:
                                            const EdgeInsets.only(left: 15),
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.menu_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        onPressed: () =>
                                            Scaffold.of(ctx).openDrawer(),
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            obxHijri,
                                            style: const TextStyle(
                                              fontFamily: 'MBLateefi',
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          obxGregorian,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Tour step 2 — Islamic Calendar button
                                  Showcase(
                                    key: DashboardScreen.calendarShowcaseKey,
                                    title: 'اسلامي ڪئلينڊر (Calendar)',
                                    description:
                                        'هتي ڪلڪ ڪري هجري تاريخون ۽ '
                                        'اهم اسلامي واقعا ڏسو.',
                                    tooltipBackgroundColor: AppColors.card,
                                    titleTextStyle: _showcaseTitleStyle,
                                    descTextStyle: _showcaseDescStyle,
                                    child: GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CalendarScreen(),
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: AppColors.gold
                                                .withValues(alpha: 0.5),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.calendar_month_rounded,
                                          color: AppColors.gold,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 35),

                            // Tour step 3 — Prayer time card
                            Showcase(
                              key: DashboardScreen.prayerShowcaseKey,
                              title: 'نماز جو وقت (Prayer Times)',
                              description:
                                  'هاڻوڪي نماز ۽ ايندڙ نماز جو وقت هتي ڏسو. '
                                  'وڌيڪ تفصيل لاءِ ڪلڪ ڪريو.',
                              tooltipBackgroundColor: AppColors.card,
                              titleTextStyle: _showcaseTitleStyle,
                              descTextStyle: _showcaseDescStyle,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const PrayerTimeScreen(),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(28),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'هاڻي (Now)',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.6),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    currentPrayerName,
                                                    style: const TextStyle(
                                                      fontFamily: 'MBLateefi',
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 28,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.gold
                                                  .withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              color: AppColors.gold,
                                              size: 24,
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  nextPrayerTime,
                                                  style: TextStyle(
                                                    color: AppColors.gold,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (_getCountdown()
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 3),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.gold
                                                          .withValues(
                                                              alpha: 0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
                                                    child: Text(
                                                      _getCountdown(),
                                                      style: TextStyle(
                                                        color: AppColors.gold,
                                                        fontSize: 10,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 4),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    nextPrayerName,
                                                    style: const TextStyle(
                                                      fontFamily: 'MBLateefi',
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 28,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                _buildContinueReadingBanner(settings, isDark),

                // ── Content grid ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.88,
                    children: [
                      _buildPremiumGridCard(
                        title: 'قرآن مجيد',
                        icon: Icons.menu_book_outlined,
                        isDark: isDark,
                        onTap: () => Get.to(() => const QuranIndexScreen()),
                      ),
                      _buildPremiumGridCard(
                        title: 'صحيفه سجاديه',
                        icon: Icons.import_contacts_outlined,
                        isDark: isDark,
                        onTap: () => Get.to(() => const FehrestScreen()),
                      ),
                      _buildPremiumGridCard(
                        title: 'نهج البلاغه',
                        icon: Icons.auto_stories_outlined,
                        isDark: isDark,
                        onTap: () => Get.to(() => const NahjulIndexScreen()),
                      ),
                      _buildPremiumGridCard(
                        title: 'احاديث',
                        icon: Icons.history_edu_outlined,
                        isDark: isDark,
                        onTap: () => Get.to(() => const AhadithIndexScreen()),
                      ),
                      _buildPremiumGridCard(
                        title: 'زيارات',
                        icon: Icons.mosque_outlined,
                        isDark: isDark,
                        onTap: () => Get.to(() => const ZiyaratIndexScreen()),
                      ),

                      // Tour step 4 — Tasbeeh card
                      Showcase(
                        key: DashboardScreen.tasbeehShowcaseKey,
                        title: 'تسبيح (Tasbeeh)',
                        description:
                            'ڊجيٽل تسبيح لاءِ هتي ڪلڪ ڪريو. '
                            'مختلف تسبيح چونڊي ڳڻپ شروع ڪريو.',
                        tooltipBackgroundColor: AppColors.card,
                        titleTextStyle: _showcaseTitleStyle,
                        descTextStyle: _showcaseDescStyle,
                        child: _buildPremiumGridCard(
                          title: 'تسبيح',
                          icon: Icons.touch_app_outlined,
                          isDark: isDark,
                          onTap: () => Get.to(() => const TasbeehScreen()),
                        ),
                      ),

                      _buildPremiumGridCard(
                        title: 'استخاره',
                        icon: Icons.lightbulb_outline_rounded,
                        isDark: isDark,
                        onTap: () => Get.to(() => const IstikharaScreen()),
                      ),
                      _buildPremiumGridCard(
                        title: 'قبله نما',
                        icon: Icons.explore_outlined,
                        isDark: isDark,
                        onTap: () => Get.to(() => const QiblaScreen()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ─── Drawer ────────────────────────────────────────────────────────────────

  Widget _buildDrawer(bool isDark, BuildContext context) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF111827), const Color(0xFF0B0F19)]
                    : [const Color(0xFF064E3B), const Color(0xFF022C22)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/tasneemlogo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.mosque_rounded, size: 50, color: AppColors.gold),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Sindhi Shia Toolkit',
                  style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _appVersion,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 17,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 10),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildDrawerItem(Icons.home_rounded, 'هوم (Home)', () {
                  Navigator.pop(context);
                  Get.find<NavigationController>().goToTab(0);
                }),
                _buildDrawerItem(
                    Icons.search_rounded, 'سڀني ۾ ڳوليو (Search in all)', () {
                  Navigator.pop(context);
                  Get.find<NavigationController>().goToTab(1);
                }),
                _buildDrawerItem(Icons.bookmark_rounded, 'بڪ مارڪس', () {
                  Navigator.pop(context);
                  Get.find<NavigationController>().goToTab(2);
                }),
                _buildDrawerItem(Icons.settings_rounded, 'سيٽنگز', () {
                  Navigator.pop(context);
                  Get.find<NavigationController>().goToTab(3);
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  child: Divider(color: AppColors.gold.withValues(alpha: 0.2)),
                ),
                _buildDrawerItem(
                    Icons.info_outline_rounded, 'اسان جي باري ۾', () {
                  Navigator.pop(context);
                  Get.to(() => const AboutUsScreen());
                }),
                _buildDrawerItem(
                    Icons.privacy_tip_outlined, 'پرائيويسي پاليسي', () {
                  Navigator.pop(context);
                  Get.to(() => const PrivacyPolicyScreen());
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  child: Divider(color: AppColors.gold.withValues(alpha: 0.2)),
                ),
                // ── App Tour replay ───────────────────────────────────────
                _buildDrawerItem(
                    Icons.tour_rounded, 'ايپ جو سير (App Tour)', () {
                  Navigator.pop(context);
                  // Wait one frame so the drawer is fully closed before the
                  // showcase overlay appears.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _startTour();
                  });
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  child: Divider(color: AppColors.gold.withValues(alpha: 0.2)),
                ),
                _buildDrawerItem(
                    Icons.star_rounded, 'ريٽنگ ڏيو (Rate App)', () async {
                  Navigator.pop(context);
                  final uri = Uri.parse(
                    'https://play.google.com/store/apps/details?id=com.tasneemacademy.sindhishiatoolkit',
                  );
                  if (await canLaunchUrl(uri)) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }),
                _buildDrawerItem(
                    Icons.share_rounded, 'دوستن سان شيئر ڪريو', () {
                  Navigator.pop(context);
                  Share.share(
                    'سنڌي شيعہ ٽول ڪٽ — قرآن، نهج البلاغه، صحيفه سجاديه، اذان ۽ گھڻو ڪجھ!\n'
                    'https://play.google.com/store/apps/details?id=com.tasneemacademy.sindhishiatoolkit',
                    subject: 'Sindhi Shia Toolkit',
                  );
                }),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Made by ",
                    style: TextStyle(
                      fontFamily: 'MBLateefi',
                      color: AppColors.text.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "Tasneem ul Quran",
                    style: TextStyle(
                      fontFamily: 'MBLateefi',
                      color: AppColors.gold.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.translate(
                    offset: const Offset(0, 3.5),
                    child: Image.asset(
                      'assets/images/tasneemlogo.png',
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'MBLateefi',
          fontSize: 18,
          color: AppColors.text,
        ),
      ),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  // ─── Continue Reading banner ──────────────────────────────────────────────

  Widget _buildContinueReadingBanner(SettingsController settings, bool isDark) {
    return Obx(() {
      final quran   = settings.lastReadQuran;
      final nahjul  = settings.lastReadNahjul;
      final sahifa  = settings.lastReadSahifa;
      final ahadith = settings.lastReadAhadith;
      final ziyarat = settings.lastReadZiyarat;

      List<Map<String, dynamic>> history = [];
      if (quran.isNotEmpty)   { history.add({'type': 'quran',   'label': 'قرآن مجيد',    'data': quran,   'icon': Icons.book_outlined}); }
      if (nahjul.isNotEmpty)  { history.add({'type': 'nahjul',  'label': 'نهج البلاغه',  'data': nahjul,  'icon': Icons.library_books_outlined}); }
      if (sahifa.isNotEmpty)  { history.add({'type': 'sahifa',  'label': 'صحيفه سجاديه', 'data': sahifa,  'icon': Icons.import_contacts_outlined}); }
      if (ahadith.isNotEmpty) { history.add({'type': 'ahadith', 'label': 'احاديث',       'data': ahadith, 'icon': Icons.history_edu_outlined}); }
      if (ziyarat.isNotEmpty) { history.add({'type': 'ziyarat', 'label': 'زيارات',        'data': ziyarat, 'icon': Icons.mosque_outlined}); }

      if (history.isEmpty) return const SizedBox();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
            child: Text(
              "جاري رکو",
              style: TextStyle(
                fontFamily: 'MBLateefi',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text.withValues(alpha: 0.8),
              ),
            ),
          ),
          SizedBox(
            height: 115,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: history.length,
              separatorBuilder: (context, index) => const SizedBox(width: 15),
              itemBuilder: (context, index) {
                final item = history[index];
                final data = item['data'];
                final type = item['type'];
                return GestureDetector(
                  onTap: () {
                    if (type == 'quran') {
                      Get.to(() => QuranReadingScreen(
                        fetchId: data['id'] ?? 1,
                        title: data['title'] ?? 'قرآن',
                        isJuzMode: data['isJuz'] ?? false,
                      ));
                    } else if (type == 'nahjul') {
                      Get.to(() => NahjulReadingScreen(
                        secRowId: data['id'] ?? 1,
                        title: data['title'] ?? 'نهج البلاغه',
                      ));
                    } else if (type == 'sahifa') {
                      Get.to(() => ReadingScreen(
                        sectionId: data['id'] ?? 1,
                        sectionTitle: data['title'] ?? 'صحيفه سجاديه',
                      ));
                    } else if (type == 'ahadith') {
                      Get.to(() => AhadithReadingScreen(
                        categoryId: data['id'] ?? 1,
                        categoryTitle: data['title'] ?? 'احاديث',
                      ));
                    } else if (type == 'ziyarat') {
                      Get.to(() => ZiyaratReadingScreen(
                        sectionId: data['id'] ?? 1,
                        sectionTitle: data['title'] ?? 'زيارات',
                      ));
                    }
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item['icon'],
                              color: AppColors.gold, size: 26),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['label'],
                                style: TextStyle(
                                  fontFamily: 'MBLateefi',
                                  fontSize: 14,
                                  color: AppColors.gold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                data['title'] ?? '',
                                style: TextStyle(
                                  fontFamily: 'MBLateefi',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                  height: 1.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.read_more_outlined,
                            color: AppColors.gold, size: 36),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 25),
        ],
      );
    });
  }

  // ─── Grid card ────────────────────────────────────────────────────────────

  Widget _buildPremiumGridCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 24,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          splashColor: AppColors.gold.withValues(alpha: 0.1),
          highlightColor: AppColors.gold.withValues(alpha: 0.05),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.gold.withValues(alpha: 0.08)
                        : AppColors.gold.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: AppColors.gold),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'MBLateefi',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
