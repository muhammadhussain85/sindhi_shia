import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import 'location_selection_screen.dart';
import '../utils/app_colors.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with WidgetsBindingObserver {
  final SettingsController settings = Get.find<SettingsController>();

  bool _hasTriggered       = false;
  bool _noCompassHardware  = false;
  bool _permissionGranted  = false;
  bool _permissionChecked  = false;

  // Stores the low-pass-filtered heading; null = no reading yet
  double? _displayHeading;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _timeoutTimer;

  // Low-pass filter state
  double _smoothedHeading   = 0.0;
  bool   _hasInitialHeading = false;

  static const double _alpha    = 0.12; // 0 = frozen, 1 = raw; 0.12 gives smooth ~8° lag
  static const double _kaabaLat = 21.422487;
  static const double _kaabaLng = 39.826206;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCompass();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopCompass();
    } else if (state == AppLifecycleState.resumed && _permissionGranted) {
      _startCompass();
    }
  }

  // ── Permission ──────────────────────────────────────────────────────────────

  Future<void> _checkPermission() async {
    // The compass sensor doesn't need runtime permission on Android, but we
    // verify location permission here so the user can't see a Qibla direction
    // based on the default coordinates they never actually set.
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    final granted = perm == LocationPermission.whileInUse ||
                    perm == LocationPermission.always;
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
        _permissionChecked = true;
      });
    }
    if (granted) _startCompass();
  }

  // ── Compass lifecycle ────────────────────────────────────────────────────────

  void _startCompass() {
    if (_compassSub != null) return;
    final stream = FlutterCompass.events;
    if (stream == null) {
      if (mounted) setState(() => _noCompassHardware = true);
      return;
    }
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _displayHeading == null) {
        setState(() => _noCompassHardware = true);
      }
    });
    _compassSub = stream.listen((event) {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      if (event.heading == null) return;
      final smoothed = _applyLowPassFilter(event.heading!);
      if (mounted) {
        setState(() {
          _displayHeading    = smoothed;
          _noCompassHardware = false;
        });
      }
    });
  }

  void _stopCompass() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _compassSub?.cancel();
    _compassSub = null;
  }

  // ── Exponential low-pass filter with angle wrap-around ───────────────────────
  //
  // Operating directly on the angle (e.g. 0.12 * 350 + 0.88 * 10) would
  // produce ~52° instead of ~1°.  We decompose into sin/cos components,
  // blend those independently, then reconstruct the angle with atan2.
  double _applyLowPassFilter(double newHeading) {
    if (!_hasInitialHeading) {
      _smoothedHeading   = newHeading;
      _hasInitialHeading = true;
      return _smoothedHeading;
    }
    final newRad      = newHeading * math.pi / 180;
    final smoothedRad = _smoothedHeading * math.pi / 180;

    final sinS = (1 - _alpha) * math.sin(smoothedRad) + _alpha * math.sin(newRad);
    final cosS = (1 - _alpha) * math.cos(smoothedRad) + _alpha * math.cos(newRad);

    _smoothedHeading = math.atan2(sinS, cosS) * 180 / math.pi;
    if (_smoothedHeading < 0) _smoothedHeading += 360;
    return _smoothedHeading;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final double userLat       = settings.manualLat.value;
      final double userLng       = settings.manualLng.value;
      final String cityName      = settings.selectedCity.value;
      final double bearing       = Geolocator.bearingBetween(userLat, userLng, _kaabaLat, _kaabaLng);
      final double qiblaBearing  = (bearing + 360) % 360;

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 80,
          title: const Text('قبله نما',
              style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            _buildCompassBody(qiblaBearing, cityName),
            // Permission overlay rendered on top of the compass body
            if (_permissionChecked && !_permissionGranted)
              _PermissionOverlay(onGrant: _checkPermission),
          ],
        ),
      );
    });
  }

  Widget _buildCompassBody(double qiblaBearing, String cityName) {
    if (!_permissionChecked) {
      return Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_noCompassHardware) return _buildNoHardwareWidget();
    if (_displayHeading == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    final double heading = _displayHeading!;

    double delta = qiblaBearing - heading;
    if (delta > 180)  delta -= 360;
    if (delta < -180) delta += 360;

    final bool isAligned = delta.abs() <= 2.5;

    if (isAligned && !_hasTriggered) {
      _hasTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => HapticFeedback.heavyImpact());
    } else if (!isAligned) {
      _hasTriggered = false;
    }

    final Color activeColor = isAligned
        ? (Get.isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669))
        : AppColors.gold;

    const double compassSize = 280;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Location not set warning
          if (cityName == 'Unknown' || cityName.isEmpty)
            _LocationWarning(cityName: cityName),

          if (cityName == 'Unknown' || cityName.isEmpty)
            const SizedBox(height: 12),

          // Location card
          _LocationCard(cityName: cityName),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LocationSelectionScreen())),
            icon: Icon(Icons.edit_location_alt_rounded,
                size: 16, color: AppColors.text.withValues(alpha: 0.5)),
            label: Text('مقام تبديل ڪريو',
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 16,
                    color: AppColors.text.withValues(alpha: 0.6))),
          ),

          const SizedBox(height: 30),

          Text(
            isAligned ? 'الحمدلله، رخ صحيح آهي' : 'ڪعبي جي طرف منهن ڪريو',
            style: TextStyle(
                fontFamily: 'MBLateefi',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isAligned ? activeColor : AppColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            '${delta.abs().toStringAsFixed(0)}°',
            style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: activeColor,
                letterSpacing: 1,
                fontFamily: 'Arial'),
          ),
          const SizedBox(height: 50),

          // ── Compass dial ──────────────────────────────────────────────────
          SizedBox(
            width: compassSize,
            height: compassSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isAligned)
                  Container(
                    width: compassSize,
                    height: compassSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: activeColor.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: 10)],
                    ),
                  ),
                // Rotating compass rose (north tracking)
                Transform.rotate(
                  angle: -heading * math.pi / 180,
                  child: Container(
                    width: compassSize,
                    height: compassSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.card,
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.2), width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                            top: 12,
                            child: Text('N',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18))),
                        Positioned(
                            bottom: 12,
                            child: Text('S',
                                style: TextStyle(
                                    color: AppColors.text.withValues(alpha: 0.4),
                                    fontSize: 16))),
                        Positioned(
                            right: 12,
                            child: Text('E',
                                style: TextStyle(
                                    color: AppColors.text.withValues(alpha: 0.4),
                                    fontSize: 16))),
                        Positioned(
                            left: 12,
                            child: Text('W',
                                style: TextStyle(
                                    color: AppColors.text.withValues(alpha: 0.4),
                                    fontSize: 16))),
                        Container(
                            width: 1,
                            height: compassSize,
                            color: AppColors.text.withValues(alpha: 0.05)),
                        Container(
                            width: compassSize,
                            height: 1,
                            color: AppColors.text.withValues(alpha: 0.05)),
                      ],
                    ),
                  ),
                ),
                // Qibla pointer (rotates relative to compass reading)
                Transform.rotate(
                  angle: delta * math.pi / 180,
                  child: SizedBox(
                    width: compassSize,
                    height: compassSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 10,
                          child: Image.asset(
                            'assets/images/kaaba.png',
                            width: 40,
                            height: 40,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.mosque_rounded, size: 36, color: activeColor),
                          ),
                        ),
                        Positioned(
                          top: 55,
                          bottom: compassSize / 2,
                          child: Container(
                            width: 3,
                            decoration: BoxDecoration(
                                color: activeColor,
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: activeColor, width: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildNoHardwareWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compass_calibration_rounded,
                size: 70, color: AppColors.gold.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text('ڪمپاس دستياب ناهي',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 24,
                    color: AppColors.text,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'توهان جي فون ۾ ڪمپاس سينسر موجود ناهي.',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 18,
                  color: AppColors.text.withValues(alpha: 0.7),
                  height: 1.5),
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

class _PermissionOverlay extends StatelessWidget {
  final VoidCallback onGrant;
  const _PermissionOverlay({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withValues(alpha: 0.97),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on_rounded,
                    size: 64, color: AppColors.gold),
              ),
              const SizedBox(height: 28),
              Text(
                'مقام جي اجازت گهربل آهي',
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'قبلي جو صحيح رخ معلوم ڪرڻ لاءِ ايپ کي توهان جي مقام تائين رسائي ضروري آهي. مهرباني ڪري اجازت ڏيو.',
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 18,
                    color: AppColors.text.withValues(alpha: 0.65),
                    height: 1.5),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: onGrant,
                  child: const Text(
                    'اجازت ڏيو',
                    style: TextStyle(
                        fontFamily: 'MBLateefi',
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('پوءِ ڪنديس',
                    style: TextStyle(
                        fontFamily: 'MBLateefi',
                        fontSize: 18,
                        color: AppColors.text.withValues(alpha: 0.45))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationWarning extends StatelessWidget {
  final String cityName;
  const _LocationWarning({required this.cityName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "مقام سيٽ ناهي — قبلي جو رخ غلط ٿي سگهي ٿو. هيٺ 'مقام تبديل ڪريو' تي ڪلڪ ڪريو.",
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 15,
                  color: Colors.orange.shade800,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String cityName;
  const _LocationCard({required this.cityName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(
                  alpha: Get.isDarkMode ? 0.2 : 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on_rounded, size: 20, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cityName,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 18,
                  color: AppColors.text,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
