import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adhan/adhan.dart';
import '../controllers/settings_controller.dart';
import '../utils/app_colors.dart';
import 'location_selection_screen.dart';

// Connectivity state
enum _ConnState { checking, online, offline }

class PrayerTimeScreen extends StatefulWidget {
  const PrayerTimeScreen({super.key});

  @override
  State<PrayerTimeScreen> createState() => _PrayerTimeScreenState();
}

class _PrayerTimeScreenState extends State<PrayerTimeScreen> {
  final _settings = Get.find<SettingsController>();

  PrayerTimes? _prayerTimes;
  Prayer?      _nextPrayer;
  _ConnState   _connState = _ConnState.checking;

  final List<Worker> _workers = [];

  @override
  void initState() {
    super.initState();
    _init();
    _workers.add(ever(_settings.manualLat,  (_) => _fetchTimes()));
    _workers.add(ever(_settings.calcMethod, (_) => _fetchTimes()));
    _workers.add(ever(_settings.cityUtcOffsetMinutes, (_) => _fetchTimes()));
  }

  @override
  void dispose() {
    for (final w in _workers) { w.dispose(); }
    super.dispose();
  }

  Future<void> _init() async {
    await _checkConnectivity();
    _fetchTimes();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted) setState(() => _connState = isOnline ? _ConnState.online : _ConnState.offline);
    } catch (_) {
      if (mounted) setState(() => _connState = _ConnState.offline);
    }
  }

  void _fetchTimes() {
    try {
      final coords = Coordinates(
        _settings.manualLat.value,
        _settings.manualLng.value,
      );
      final params = _settings.getPrayerParameters();

      // ─── KEY FIX: use the city's local date, not the device's date.
      // When a user in UTC+0 sets Karachi (UTC+5) as their city, the device
      // date and the city date can differ by a day near midnight.  We derive
      // DateComponents from the city's current local time to guarantee the
      // correct prayer schedule is shown.
      final cityNow = _settings.getCityLocalNow();
      final dateComponents = DateComponents(
        cityNow.year,
        cityNow.month,
        cityNow.day,
      );

      final times  = PrayerTimes(coords, dateComponents, params);
      final next   = times.nextPrayer();

      if (mounted) {
        setState(() {
          _prayerTimes = times;
          _nextPrayer  = next;
        });
      }
    } catch (_) {
      // Coordinates or calculation failed — leave _prayerTimes null to show
      // the "location not set" state.
    }
  }

  // Format a prayer DateTime in the CITY's local time, not the device's.
  // The adhan package returns .toLocal() which uses the device timezone;
  // we correct for the city offset via SettingsController.formatPrayerTime().
  String _fmt(DateTime t) => _settings.formatPrayerTime(t);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool   locationSet = _settings.selectedCity.value != 'Unknown' &&
                                 _settings.selectedCity.value.isNotEmpty;

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 80,
          title: const Text(
            'نماز جا وقت',
            style: TextStyle(
                fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.gold, size: 22),
              onPressed: () { _checkConnectivity(); _fetchTimes(); },
              tooltip: 'تازو ڪريو',
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Offline banner ───────────────────────────────────────────
            if (_connState == _ConnState.offline)
              _OfflineBanner(onRetry: _init),

            // ── Location card ────────────────────────────────────────────
            _LocationCard(
              cityName: _settings.selectedCity.value,
              isOffline: _connState == _ConnState.offline,
            ),

            const SizedBox(height: 8),

            // ── Prayer time list ─────────────────────────────────────────
            Expanded(child: _buildBody(locationSet)),
          ],
        ),
      );
    });
  }

  Widget _buildBody(bool locationSet) {
    // Location never set
    if (!locationSet) {
      return _buildNoLocationState();
    }

    // Still computing
    if (_prayerTimes == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          _PrayerRow(
            title: 'فجر',
            time: _fmt(_prayerTimes!.fajr),
            isNext: _nextPrayer == Prayer.fajr,
            isMuted: _settings.isFajrMuted.value,
            onToggleMute: _settings.toggleFajrMute,
          ),
          _PrayerRow(
            title: 'ظهرين',
            time: _fmt(_prayerTimes!.dhuhr),
            isNext: _nextPrayer == Prayer.dhuhr || _nextPrayer == Prayer.asr,
            isMuted: _settings.isDhuhrMuted.value,
            onToggleMute: _settings.toggleDhuhrMute,
          ),
          _PrayerRow(
            title: 'مغربين',
            time: _fmt(_prayerTimes!.maghrib),
            isNext: _nextPrayer == Prayer.maghrib || _nextPrayer == Prayer.isha,
            isMuted: _settings.isMaghribMuted.value,
            onToggleMute: _settings.toggleMaghribMute,
          ),
          const SizedBox(height: 20),
          // Timezone note — shown when device and city timezones differ
          _TimezoneNote(settings: _settings),
        ],
      ),
    );
  }

  Widget _buildNoLocationState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded,
                size: 72, color: AppColors.gold.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              'مقام سيٽ ناهي',
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'نماز جا صحيح وقت ڏسڻ لاءِ پهرين پنهنجو شهر يا مقام سيٽ ڪريو.',
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 18,
                  color: AppColors.text.withValues(alpha: 0.65),
                  height: 1.5),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const LocationSelectionScreen())),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('مقام چونڊيو',
                  style: TextStyle(
                      fontFamily: 'MBLateefi',
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.orange.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'انٽرنيٽ ڪنيڪشن نه آهي — محفوظ ڊيٽا مان وقت ڏيکاريا پيا وڃن.',
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 15,
                  color: Colors.orange.shade800),
              textDirection: TextDirection.rtl,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('ٻيهر ڪوشش',
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 14,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String cityName;
  final bool   isOffline;
  const _LocationCard({required this.cityName, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(
                  alpha: Get.isDarkMode ? 0.2 : 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  cityName,
                  style: TextStyle(
                      fontFamily: 'MBLateefi',
                      fontSize: 20,
                      color: AppColors.text,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOffline) ...[
                const SizedBox(width: 8),
                const Icon(Icons.cloud_off_rounded,
                    color: Colors.orange, size: 16),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const LocationSelectionScreen())),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  border:
                      Border.all(color: AppColors.text.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_location_alt_rounded,
                        size: 16,
                        color: AppColors.text.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Text(
                      'مقام تبديل ڪريو',
                      style: TextStyle(
                          fontFamily: 'MBLateefi',
                          fontSize: 16,
                          color: AppColors.text.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final String        title;
  final String        time;
  final bool          isNext;
  final bool          isMuted;
  final VoidCallback  onToggleMute;

  const _PrayerRow({
    required this.title,
    required this.time,
    required this.isNext,
    required this.isMuted,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNext
              ? AppColors.gold.withValues(alpha: 0.5)
              : (Get.isDarkMode
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03)),
          width: isNext ? 1.5 : 1,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ]
            : [
                BoxShadow(
                    color: Colors.black.withValues(
                        alpha: Get.isDarkMode ? 0.2 : 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(
                  isNext
                      ? Icons.access_time_filled_rounded
                      : Icons.access_time_rounded,
                  color: isNext
                      ? AppColors.gold
                      : AppColors.gold.withValues(alpha: 0.55),
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerRight,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: TextStyle(
                          fontFamily: 'MBLateefi',
                          fontSize: 24,
                          color: isNext ? AppColors.gold : AppColors.text,
                          fontWeight:
                              isNext ? FontWeight.bold : FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                time,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isNext ? AppColors.gold : AppColors.text,
                    fontFamily: 'Arial'),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isMuted
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_active_rounded,
              color: isMuted
                  ? Colors.redAccent
                  : (isNext ? AppColors.gold : AppColors.gold.withValues(alpha: 0.65)),
              size: 26,
            ),
            onPressed: onToggleMute,
          ),
        ],
      ),
    );
  }
}

class _TimezoneNote extends StatelessWidget {
  final SettingsController settings;
  const _TimezoneNote({required this.settings});

  @override
  Widget build(BuildContext context) {
    final deviceOffset = DateTime.now().timeZoneOffset.inMinutes;
    final cityOffset   = settings.cityUtcOffsetMinutes.value;
    if (deviceOffset == cityOffset) return const SizedBox.shrink();

    final sign    = cityOffset >= 0 ? '+' : '';
    final hours   = (cityOffset.abs() ~/ 60).toString().padLeft(2, '0');
    final minutes = (cityOffset.abs() % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.gold.withValues(alpha: 0.7), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'وقت شهر جي ٽائيم زون (UTC$sign$hours:$minutes) ۾ ڏيکاريل آهن.',
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 14,
                  color: AppColors.text.withValues(alpha: 0.65),
                  height: 1.4),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}
