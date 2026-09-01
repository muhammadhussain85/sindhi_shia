import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';

class AppColors {
  static bool get _isDark => Get.find<SettingsController>().isDarkMode.value;

  // ==========================================
  // 1. STANDARD THEME (Dashboard, Settings)
  // ==========================================
  static Color get background => _isDark ? const Color(0xFF0B0F19) : const Color(0xFFFDFBF7);
  static Color get surfaceBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  static Color get card => _isDark ? const Color(0xFF161B22) : Colors.white;
  static Color get text => _isDark ? const Color(0xFFF3F4F6) : const Color(0xFF1A202C);
  static Color get gold => _isDark ? const Color(0xFFD4AF37) : const Color(0xFFC5A059);
  static Color get divider => _isDark ? Colors.white10 : Colors.black12;

  // ==========================================
  // 2. PARCHMENT THEME (Index & Books)
  // ==========================================
  static Color get parchmentBackground => _isDark ? const Color(0xFF0B0F19) : const Color(0xFFF6F3E9);
  static Color get parchmentCard => _isDark ? const Color(0xFF111827) : Colors.white;
  static Color get parchmentText => _isDark ? const Color(0xFFF3F4F6) : const Color(0xFF3D3831);
  static Color get parchmentGold => _isDark ? const Color(0xFFD4AF37) : const Color(0xFFB88A44);

  // ==========================================
  // 3. ARABIC READING COLORS
  // ==========================================
  static Color get arabicBg => _isDark ? const Color(0xFF103020) : const Color(0xFFD4E7D7);
  static Color get arabicText => _isDark ? Colors.white : const Color(0xFF1B4332);
  static Color get highlight => _isDark ? Colors.yellowAccent : Colors.orange[800]!;
  static Color get searchBarBg => _isDark ? const Color(0xFF1E293B) : Colors.white;
  static Color get chipBg => _isDark ? const Color(0xFF1E293B) : Colors.grey.withValues(alpha:0.1);
}