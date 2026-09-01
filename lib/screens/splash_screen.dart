import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/settings_controller.dart';
import 'main_layout.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();

    // Wait 3.5 seconds, then route: onboarding on first launch, home otherwise
    Timer(const Duration(milliseconds: 3500), () {
      final bool onboardingDone = GetStorage().read('onboarding_done') ?? false;
      Get.offAll(
        () => onboardingDone ? const MainLayout() : const OnboardingScreen(),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 1000),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = Get.find<SettingsController>();

    return Obx(() {
      final isDark = settings.isDarkMode.value;

      final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFFDFBF7);
      final textColor = isDark ? const Color(0xFFF3F4F6) : const Color(0xFF1A202C);
      final goldColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFFB88A44);
      final circleColor = isDark ? const Color(0xFF161B22) : Colors.white;

      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          // ✨ THE FIX: Forcing the container to take the FULL width of the phone.
          // Without this, the Column shrinks to the text width and sits on the left side!
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // Enforces absolute centering
              children: [
                const Spacer(flex: 3),

                // --- MAIN LOGO ---
                ScaleTransition(
                  scale: _animation,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circleColor,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.3 : 0.1), blurRadius: 20, offset: const Offset(0, 10)),
                        BoxShadow(color: goldColor.withValues(alpha:isDark ? 0.1 : 0.2), blurRadius: 30, spreadRadius: 5),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Image.asset(
                        'assets/images/tasneemlogo.png',
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.mosque_rounded, size: 80, color: goldColor),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 35),

                // --- MAIN APP TITLE ---
                Text(
                  "سنڌي شيعہ ٽول ڪٽ",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'MBLateefi', fontSize: 40, fontWeight: FontWeight.bold, color: goldColor, letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),

                // --- APP FEATURES ---
                Text(
                  "قرآن، نھج البلاغہ، صحيفہ سجاديہ\nقرآني استخارو، دعائون ۽ زيارتون",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 22,
                    color: textColor.withValues(alpha:0.85),
                    height: 1.6,
                  ),
                ),

                const Spacer(flex: 2),

                // --- FOOTER: PRESENTED BY ---
                Column(
                  children: [
                    Text(
                      "پيشڪش: ادارہ تسنيم القرآن",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'MBLateefi',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: goldColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "مولانا ڊاڪٽر غلام قاسم تسنيمي",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'MBLateefi',
                        fontSize: 18,
                        color: textColor.withValues(alpha:0.6),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    });
  }
}