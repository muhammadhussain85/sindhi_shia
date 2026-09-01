import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:showcaseview/showcaseview.dart';

import '../controllers/navigation_controller.dart';
import '../controllers/quran_audio_controller.dart';
import '../controllers/settings_controller.dart';
import '../utils/app_colors.dart';
import 'dashboard_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';
import 'global_search_screen.dart';
import 'tasbeeh_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Tracks whether a showcase tour is currently running so we can
  // conditionally show the floating "Skip Tour" button.
  final _isTourRunning = false.obs;

  StreamSubscription<Uri?>? _widgetSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Handle tap that cold-started the app from the Zikr widget.
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _navigateFromWidgetUri(uri);
      // Handle taps while the app is already running in the background.
      _widgetSub = HomeWidget.widgetClicked.listen(_navigateFromWidgetUri);
    });
  }

  @override
  void dispose() {
    _widgetSub?.cancel();
    super.dispose();
  }

  void _navigateFromWidgetUri(Uri? uri) {
    if (uri?.host == 'tasbeeh') {
      final index = int.tryParse(uri?.queryParameters['index'] ?? '0') ?? 0;
      Get.to(() => TasbeehScreen(initialIndex: index));
    }
  }

  Widget _buildTabNavigator(int index, Widget rootScreen) {
    final navCtrl = Get.find<NavigationController>();
    return Navigator(
      key: navCtrl.navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (context) => rootScreen);
      },
    );
  }

  // Mini player — only visible when a Quran verse is active.
  // Scoped in its own Obx so audio-state changes never rebuild the full Scaffold.
  Widget _buildMiniPlayer(bool isDark, Color goldColor) {
    return Obx(() {
      final audio = Get.find<QuranAudioController>();
      final verse = audio.currentPlayingVerse.value;
      final surah = audio.currentPlayingSurah.value;

      if (verse == 0) return const SizedBox.shrink();

      final bgColor   = isDark ? const Color(0xFF161B22) : Colors.white;
      final textColor = isDark ? const Color(0xFFF3F4F6) : const Color(0xFF1A202C);

      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(color: goldColor.withValues(alpha: 0.35), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.menu_book_rounded, color: goldColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'قرآن پاڪ',
                    style: TextStyle(
                      fontFamily: 'MBLateefi',
                      fontSize: 13,
                      color: goldColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'سورة $surah  —  آيت $verse',
                    style: TextStyle(
                      fontFamily: 'MBLateefi',
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Play / Pause
            GestureDetector(
              onTap: () {
                if (audio.isPlaying.value) {
                  audio.pauseAudio();
                } else {
                  audio.resumeAudio();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: audio.isLoading.value
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: goldColor,
                        ),
                      )
                    : Icon(
                        audio.isPlaying.value
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: goldColor,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            // Stop
            GestureDetector(
              onTap: () => audio.stopAudio(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.stop_rounded,
                  color: textColor.withValues(alpha: 0.55),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final navCtrl  = Get.find<NavigationController>();
    final settings = Get.find<SettingsController>();

    // ShowCaseWidget sits OUTSIDE Obx so a theme-mode rebuild cannot
    // recreate it and reset a tour that is currently in progress.
    return ShowCaseWidget(
      // onStart fires on every individual step.
      // We flip _isTourRunning on the very first step (index 0).
      onStart: (index, _) {
        if (index == 0) _isTourRunning.value = true;
      },
      // onFinish fires only when all steps are completed naturally.
      // dismiss() does NOT call onFinish, so the Skip FAB resets the flag itself.
      onFinish: () => _isTourRunning.value = false,
      builder: (showCaseContext) => Obx(() {
        final isDark       = settings.isDarkMode.value;
        final currentIndex = navCtrl.currentIndex.value;
        final navColor     = isDark ? const Color(0xFF161B22) : Colors.white;
        final goldColor    = isDark ? const Color(0xFFD4AF37) : const Color(0xFFB88A44);
        final unselected   = isDark ? Colors.white54 : Colors.black54;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final currentNavigator =
                navCtrl.navigatorKeys[currentIndex].currentState!;
            if (currentNavigator.canPop()) {
              currentNavigator.pop();
            } else if (currentIndex != 0) {
              navCtrl.currentIndex.value = 0;
            } else {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            // Floating "Skip Tour" button — only visible while a tour is running.
            // Uses its own Obx so it doesn't force a full Scaffold rebuild
            // every time _isTourRunning flips.
            floatingActionButton: Obx(() {
              if (!_isTourRunning.value) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                onPressed: () {
                  ShowCaseWidget.of(showCaseContext).dismiss();
                  // dismiss() does not call onFinish, so we reset manually.
                  _isTourRunning.value = false;
                },
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.close_rounded, size: 20),
                label: const Text(
                  'بند ڪريو (Skip Tour)',
                  style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
            body: IndexedStack(
              index: currentIndex,
              children: [
                _buildTabNavigator(0, const DashboardScreen()),
                _buildTabNavigator(1, const GlobalSearchScreen()),
                _buildTabNavigator(2, const BookmarksScreen()),
                _buildTabNavigator(3, const SettingsScreen()),
              ],
            ),
            // The mini player sits directly above the bottom nav bar.
            // Column(mainAxisSize: min) keeps the IndexedStack body unaffected.
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMiniPlayer(isDark, goldColor),
                // Tour step 5: Highlights the entire bottom nav bar and points
                // the user to the Search tab. Wrapping the full bar is the only
                // practical option since BottomNavigationBarItem widgets are not
                // individually addressable in the widget tree.
                Showcase(
                  key: DashboardScreen.searchTabShowcaseKey,
                  title: 'ڳولا ٽيب (Search)',
                  description:
                      'هتي ڪلڪ ڪري پوري ايپ ۾ — قرآن، احاديث، زيارات — ڳوليو.',
                  tooltipBackgroundColor: AppColors.card,
                  titleTextStyle: TextStyle(
                    fontFamily: 'MBLateefi',
                    color: AppColors.gold,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  descTextStyle: TextStyle(
                    fontFamily: 'MBLateefi',
                    color: AppColors.text,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: BottomNavigationBar(
                      backgroundColor: navColor,
                      currentIndex: currentIndex,
                      selectedItemColor: goldColor,
                      unselectedItemColor: unselected,
                      selectedLabelStyle: const TextStyle(
                        fontFamily: 'MBLateefi',
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontFamily: 'MBLateefi',
                        fontWeight: FontWeight.w500,
                      ),
                      type: BottomNavigationBarType.fixed,
                      elevation: 0,
                      onTap: navCtrl.goToTab,
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home_rounded),
                          label: 'هوم',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.search_rounded),
                          label: 'ڳوليو',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.bookmark_rounded),
                          label: 'بڪ مارڪس',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.settings_rounded),
                          label: 'سيٽنگز',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
