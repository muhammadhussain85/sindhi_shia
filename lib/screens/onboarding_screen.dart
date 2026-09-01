import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_colors.dart';
import '../utils/smart_permission_helper.dart';
import 'main_layout.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _currentPage = 0;
  bool _adhanAllGranted = false;

  // Bottom-nav tab indices: 0=هوم, 1=ڳوليو, 2=بڪ مارڪس, 3=سيٽنگز
  static const List<_OnboardPage> _pages = [
    _OnboardPage(
      icon: Icons.mosque_rounded,
      title: 'خوش آمديد',
      subtitle: 'سنڌي شيعہ ٽول ڪٽ',
      description: 'سنڌي ٻوليءَ ۾ قرآن، دعائون، زيارتون، نماز جا وقت، قبله نما ۽ گھڻو ڪجھ.\nاچو اپليڪيشن جو مختصر سفر ڪريون.',
      gradient: [Color(0xFF0B0F19), Color(0xFF1A2340)],
      navTabs: [],
      homeCardLabel: null,
      homeCardIcon: null,
    ),
    _OnboardPage(
      icon: Icons.alarm_rounded,
      title: 'نماز جا وقت ۽ اذان',
      subtitle: 'درست وقت تي اذان ٻڌو',
      description: 'پهريون: سيٽنگز ۾ پنهنجو شهر سيٽ ڪريو.\nپوءِ هوم اسڪرين تي نماز جا وقت ڏسو ۽ اذان جون اجازتون ڏيو.',
      gradient: [Color(0xFF0F1B2D), Color(0xFF1C3250)],
      navTabs: [0, 3],
      homeCardLabel: 'نماز جا وقت',
      homeCardIcon: Icons.access_time_filled_rounded,
    ),
    _OnboardPage(
      icon: Icons.menu_book_rounded,
      title: 'ڪتاب پڙهو',
      subtitle: 'قرآن، نهج البلاغه، صحيفه سجاديه',
      description: 'هوم اسڪرين تان قرآن، نهج البلاغه، صحيفه سجاديه، احاديث ۽ زيارتون کوليو.\nپڙهڻ جي جاءِ خودبخود محفوظ ٿيندي.',
      gradient: [Color(0xFF1A150A), Color(0xFF302510)],
      navTabs: [0],
      homeCardLabel: 'قرآن / ڪتاب',
      homeCardIcon: Icons.menu_book_rounded,
    ),
    _OnboardPage(
      icon: Icons.calendar_month_rounded,
      title: 'اسلامي ڪيلنڊر',
      subtitle: 'هجري تاريخ ۽ مهم ڏينهن',
      description: 'هوم اسڪرين تان "ڪيلنڊر" ڪارڊ کوليو.\nاسلامي تاريخ، مهم واقعا ۽ هجري مهينا ڏسو.',
      gradient: [Color(0xFF0D1A0A), Color(0xFF1A3015)],
      navTabs: [0],
      homeCardLabel: 'اسلامي ڪيلنڊر',
      homeCardIcon: Icons.calendar_month_rounded,
    ),
    _OnboardPage(
      icon: Icons.radio_button_checked_rounded,
      title: 'تسبيح',
      subtitle: 'ذڪر ڳڻيو، دل کي سڪون ڏيو',
      description: 'هوم اسڪرين تان "تسبيح" ڪارڊ کوليو.\nهڪ ذڪر مڪمل ٿيڻ تي ايندڙ پاڻ شروع ٿيندو.',
      gradient: [Color(0xFF1A0F1A), Color(0xFF301A30)],
      navTabs: [0],
      homeCardLabel: 'تسبيح',
      homeCardIcon: Icons.radio_button_checked_rounded,
    ),
    _OnboardPage(
      icon: Icons.explore_rounded,
      title: 'قبله نما',
      subtitle: 'ڪعبي جو رخ معلوم ڪريو',
      description: 'هوم اسڪرين تان "قبله نما" ڪارڊ کوليو.\nبهتر نتيجن لاءِ پهريون سيٽنگز مان شهر سيٽ ڪريو.',
      gradient: [Color(0xFF0D1F1A), Color(0xFF1A3828)],
      navTabs: [0],
      homeCardLabel: 'قبله نما',
      homeCardIcon: Icons.explore_rounded,
    ),
    _OnboardPage(
      icon: Icons.search_rounded,
      title: 'ڳولا ۽ بُڪ مارڪ',
      subtitle: 'ڪجھ به ڳوليو، ياد رکو',
      description: 'هيٺ "ڳوليو" ٽيب مان سڄي اپ ۾ عربي يا سنڌي ۾ ڳوليو.\n"بُڪ مارڪس" ٽيب مان محفوظ ڪيل آيتون ڳوليو.',
      gradient: [Color(0xFF0A1520), Color(0xFF102030)],
      navTabs: [1, 2],
      homeCardLabel: null,
      homeCardIcon: null,
    ),
    _OnboardPage(
      icon: Icons.tune_rounded,
      title: 'سيٽنگز',
      subtitle: 'پنهنجي مرضي مطابق سيٽ ڪريو',
      description: 'هيٺ "سيٽنگز" ٽيب مان:\n• شهر / GPS مقام سيٽ ڪريو\n• ڊارڪ موڊ، فونٽ سائيز\n• اذان جون اجازتون\n• قرآن جو ترجمو چونڊيو',
      gradient: [Color(0xFF1A1200), Color(0xFF302200)],
      navTabs: [3],
      homeCardLabel: null,
      homeCardIcon: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _refreshAdhanStatus();
  }

  Future<void> _refreshAdhanStatus() async {
    final n = await Permission.notification.isGranted;
    final a = await Permission.scheduleExactAlarm.isGranted;
    final b = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) setState(() => _adhanAllGranted = n && a && b);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 480), curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() {
    GetStorage().write('onboarding_done', true);
    Get.offAll(() => const MainLayout(), transition: Transition.fadeIn, duration: const Duration(milliseconds: 700));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, _) {
              double page = _currentPage.toDouble();
              try { page = _pageController.page ?? _currentPage.toDouble(); } catch (_) {}
              final int a = page.floor().clamp(0, _pages.length - 1);
              final int b = (page.floor() + 1).clamp(0, _pages.length - 1);
              final double t = page - page.floor();
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(_pages[a].gradient[0], _pages[b].gradient[0], t)!,
                      Color.lerp(_pages[a].gradient[1], _pages[b].gradient[1], t)!,
                    ],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, top: 8),
                    child: TextButton(
                      onPressed: _finish,
                      child: Text('ڇڏيو (Skip)', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: Colors.white.withValues(alpha: 0.4))),
                    ),
                  ),
                ),

                // Page view
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) {
                      _fadeController.reset();
                      _fadeController.forward();
                      setState(() => _currentPage = i);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) => FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildPage(_pages[index], index),
                    ),
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Column(
                    children: [
                      // Expanding-dot indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final bool active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 24 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          onPressed: _nextPage,
                          child: Text(
                            _currentPage == _pages.length - 1 ? 'شروع ڪريو!' : 'اڳتي',
                            style: const TextStyle(fontFamily: 'MBLateefi', fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardPage page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon glow card
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.gold.withValues(alpha: 0.18), AppColors.gold.withValues(alpha: 0.0)]),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5),
                    ),
                    child: Icon(page.icon, size: 50, color: AppColors.gold),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Page counter badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Text('${index + 1} / ${_pages.length}', style: TextStyle(fontFamily: 'Arial', fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 16),

          // Title
          Text(page.title, textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'MBLateefi', fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),

          const SizedBox(height: 6),

          // Subtitle in gold
          Text(page.subtitle, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'MBLateefi', fontSize: 19, color: AppColors.gold, fontWeight: FontWeight.w500)),

          const SizedBox(height: 18),

          // Gold divider
          Container(width: 44, height: 2, decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(1))),

          const SizedBox(height: 16),

          // Description
          Text(page.description, textAlign: TextAlign.center, textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'MBLateefi', fontSize: 17, color: Colors.white.withValues(alpha: 0.8), height: 1.7)),

          const SizedBox(height: 20),

          // Navigation hint (where to tap in the app)
          if (page.navTabs.isNotEmpty || page.homeCardLabel != null)
            _buildNavHint(page),

          if (index == 1) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _adhanAllGranted
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 22),
                          const SizedBox(width: 8),
                          Text("سڀ اجازتون مليل آهن", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: Colors.green.shade400, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await SmartPermissionHelper.requestAdhanPermissions();
                        await _refreshAdhanStatus();
                      },
                      icon: const Icon(Icons.notifications_active_rounded, size: 20),
                      label: const Text("اذان جون اجازتون ڏيو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 19, fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // Visual mockup showing the bottom nav + optional home card label
  Widget _buildNavHint(_OnboardPage page) {
    const List<_TabDef> tabs = [
      _TabDef(Icons.home_rounded, 'هوم', 0),
      _TabDef(Icons.search_rounded, 'ڳوليو', 1),
      _TabDef(Icons.bookmark_rounded, 'بُڪ مارڪس', 2),
      _TabDef(Icons.settings_rounded, 'سيٽنگز', 3),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Optional: home card hint
          if (page.homeCardLabel != null && page.homeCardIcon != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, color: AppColors.gold, size: 15),
                const SizedBox(width: 6),
                Text('هوم اسڪرين تي ڳوليو:', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 13, color: Colors.white.withValues(alpha: 0.55))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(page.homeCardIcon!, size: 14, color: AppColors.gold),
                      const SizedBox(width: 5),
                      Text(page.homeCardLabel!, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Bottom nav mockup
          Text('هيٺئين ٽيب مان:', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tabs.map((tab) {
                final bool active = page.navTabs.contains(tab.index);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active)
                      Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.gold, size: 14)
                    else
                      const SizedBox(height: 14),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: active ? AppColors.gold.withValues(alpha: 0.22) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: active ? Border.all(color: AppColors.gold.withValues(alpha: 0.5)) : null,
                      ),
                      child: Icon(tab.icon, color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.3), size: 22),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontFamily: 'MBLateefi',
                        fontSize: 11,
                        color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.28),
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradient;
  final List<int> navTabs;
  final String? homeCardLabel;
  final IconData? homeCardIcon;

  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    required this.navTabs,
    required this.homeCardLabel,
    required this.homeCardIcon,
  });
}

class _TabDef {
  final IconData icon;
  final String label;
  final int index;
  const _TabDef(this.icon, this.label, this.index);
}
