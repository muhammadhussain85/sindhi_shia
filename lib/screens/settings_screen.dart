import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../controllers/settings_controller.dart';
import '../utils/app_colors.dart';
import 'location_selection_screen.dart';
import 'about_us_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    } catch (_) {
      if (mounted) setState(() => _version = '1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      body: SafeArea(
        child: Obx(() => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header bar ─────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: AppColors.card,
              surfaceTintColor: Colors.transparent,
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              toolbarHeight: 66,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.gold, size: 20),
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).maybePop(),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'سيٽنگز',
                    style: TextStyle(
                        fontFamily: 'MBLateefi',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text),
                  ),
                  const Spacer(),
                  // Sync button — refreshes prayer times & widget
                  _SyncButton(settings: settings),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── GROUP 1: Prayer & Location ──────────────────────
                        _GroupLabel(
                          icon: Icons.access_time_rounded,
                          label: 'نماز جا وقت ۽ مقام',
                        ),
                        _DashCard(children: [
                          // Auto / Manual location toggle
                          _LocationToggle(settings: settings),
                          _CardDivider(),

                          // GPS mode: status row
                          if (!settings.isManualLocation.value) ...[
                            _InfoRow(
                              icon: Icons.gps_fixed_rounded,
                              text: 'موجوده مقام: ${settings.selectedCity.value}',
                              textColor: AppColors.gold,
                            ),
                          ] else ...[
                            // Manual mode: city picker
                            _ActionRow(
                              icon: Icons.location_city_rounded,
                              label: settings.selectedCity.value,
                              subtitle: 'شهر تبديل ڪريو',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const LocationSelectionScreen()),
                              ),
                            ),
                            _CardDivider(),
                            // Calculation method
                            _DropdownRow(
                              icon: Icons.calculate_rounded,
                              label: 'نماز جو حساب',
                              value: settings.calcMethod.value,
                              items: const {
                                0: 'تهران يونيورسٽي (Tehran)',
                                1: 'ليوا انسٽيٽيوٽ، قم (Qum)',
                              },
                              onChanged: settings.setCalcMethod,
                            ),
                          ],
                        ]),

                        // ── GROUP 2: Appearance ─────────────────────────────
                        _GroupLabel(
                          icon: Icons.palette_outlined,
                          label: 'ظاهري ترتيب',
                        ),
                        _DashCard(children: [
                          _SwitchRow(
                            icon: Icons.dark_mode_rounded,
                            label: 'ڊارڪ موڊ',
                            value: settings.isDarkMode.value,
                            onChanged: settings.toggleTheme,
                          ),
                          _CardDivider(),
                          _SliderRow(
                            icon: Icons.text_fields_rounded,
                            label: 'عربي فانٽ سائيز',
                            value: settings.arabicFontSize.value,
                            min: 16, max: 50, divisions: 34,
                            onChanged: settings.updateArabicSize,
                          ),
                          _CardDivider(),
                          _SliderRow(
                            icon: Icons.translate_rounded,
                            label: 'سنڌي فانٽ سائيز',
                            value: settings.sindhiFontSize.value,
                            min: 16, max: 40, divisions: 24,
                            onChanged: settings.updateSindhiSize,
                          ),
                          _CardDivider(),
                          _FontPreview(settings: settings),
                          _CardDivider(),
                          _RadioGroup(
                            icon: Icons.menu_book_rounded,
                            label: 'پڙهڻ جو انداز',
                            options: const {
                              0: 'عربي ۽ سنڌي ترجمو',
                              1: 'صرف عربي',
                              2: 'صرف سنڌي ترجمو',
                            },
                            groupValue: settings.readingMode.value,
                            onChanged: settings.setReadingMode,
                          ),
                          _CardDivider(),
                          _DropdownRow(
                            icon: Icons.menu_book_outlined,
                            label: 'قرآن جو ترجمو',
                            value: settings.selectedTranslation.value,
                            items: const {
                              0: 'سڪندر علي لطفي',
                              1: 'قاري امان اللہ ڪربلائي',
                            },
                            onChanged: settings.changeTranslation,
                          ),
                          _CardDivider(),
                          _SliderRow(
                            icon: Icons.tune_rounded,
                            label: 'هجري تاريخ جي درستي',
                            value: settings.hijriAdjustment.value.toDouble(),
                            min: -5, max: 5, divisions: 10,
                            showSign: true,
                            onChanged: (v) =>
                                settings.adjustHijri(v.toInt()),
                          ),
                          _CardDivider(),
                          _InfoRow(
                            icon: Icons.info_outline_rounded,
                            text:
                                'جيڪڏهن هجري تاريخ ڏهاڙي اڳتي يا پٺتي آهي ته +1 يا −1 ڪريو.',
                          ),
                        ]),

                        // ── GROUP 3: Notifications ──────────────────────────
                        _GroupLabel(
                          icon: Icons.notifications_outlined,
                          label: 'نوٽيفڪيشن ۽ آذان',
                        ),
                        _DashCard(children: [
                          _SwitchRow(
                            icon: Icons.notifications_off_rounded,
                            label: 'فجر آذان بند ڪريو',
                            value: settings.isFajrMuted.value,
                            onChanged: (_) => settings.toggleFajrMute(),
                            activeColor: Colors.redAccent,
                          ),
                          _CardDivider(),
                          _SwitchRow(
                            icon: Icons.notifications_off_rounded,
                            label: 'ظهرين آذان بند ڪريو',
                            value: settings.isDhuhrMuted.value,
                            onChanged: (_) => settings.toggleDhuhrMute(),
                            activeColor: Colors.redAccent,
                          ),
                          _CardDivider(),
                          _SwitchRow(
                            icon: Icons.notifications_off_rounded,
                            label: 'مغربين آذان بند ڪريو',
                            value: settings.isMaghribMuted.value,
                            onChanged: (_) => settings.toggleMaghribMute(),
                            activeColor: Colors.redAccent,
                          ),
                          _CardDivider(),
                          _SliderRow(
                            icon: Icons.volume_up_rounded,
                            label: 'آذان جو آواز',
                            value: settings.adhanVolume.value,
                            min: 0, max: 1, divisions: 10,
                            showPercent: true,
                            onChanged: settings.setAdhanVolume,
                          ),
                          _CardDivider(),
                          _SwitchRow(
                            icon: Icons.headphones_rounded,
                            label: 'لاڪ-اسڪرين تي آڊيو',
                            value: settings.enableBackgroundAudio.value,
                            onChanged: settings.toggleBackgroundAudio,
                          ),
                          _CardDivider(),
                          _ActionRow(
                            icon: Icons.build_circle_outlined,
                            label: 'آذان جا مسئلا حل ڪريو',
                            iconColor: Colors.orange,
                            labelColor: Colors.orange,
                            onTap: settings.showAdhanFixWarning,
                          ),
                        ]),

                        // ── GROUP 4: About ──────────────────────────────────
                        _GroupLabel(
                          icon: Icons.info_outline_rounded,
                          label: 'ايپ بابت',
                        ),
                        _DashCard(children: [
                          _ActionRow(
                            icon: Icons.info_outline_rounded,
                            label: 'اسان جي باري ۾',
                            onTap: () => Get.to(
                              () => const AboutUsScreen(),
                              transition: Transition.rightToLeft,
                              duration: const Duration(milliseconds: 270),
                            ),
                          ),
                          _CardDivider(),
                          _ActionRow(
                            icon: Icons.privacy_tip_outlined,
                            label: 'پرائيويسي پاليسي',
                            onTap: () => Get.to(
                              () => const PrivacyPolicyScreen(),
                              transition: Transition.rightToLeft,
                              duration: const Duration(milliseconds: 270),
                            ),
                          ),
                          _CardDivider(),
                          _VersionRow(version: _version),
                        ]),

                        // ── Data Management ─────────────────────────────────
                        _GroupLabel(
                          icon: Icons.storage_rounded,
                          label: 'ڊيٽا مئنيجمينٽ',
                          color: Colors.redAccent,
                        ),
                        _DashCard(children: [
                          _ActionRow(
                            icon: Icons.restore_rounded,
                            label: 'سيٽنگز ري سيٽ ڪريو',
                            iconColor: Colors.redAccent,
                            labelColor: Colors.redAccent,
                            onTap: () => _confirm(
                                context,
                                'سيٽنگز ري سيٽ ڪرڻ چاهيو ٿا؟',
                                settings.resetToDefault),
                          ),
                          _CardDivider(),
                          _ActionRow(
                            icon: Icons.bookmark_remove_rounded,
                            label: 'سڀ بڪ مارڪس ختم ڪريو',
                            iconColor: Colors.redAccent,
                            labelColor: Colors.redAccent,
                            onTap: () => _confirm(
                                context,
                                'ڇا توهان سڀ بڪ مارڪس ڊليٽ ڪرڻ چاهيو ٿا؟',
                                settings.clearBookmarks),
                          ),
                          _CardDivider(),
                          _ActionRow(
                            icon: Icons.history_rounded,
                            label: 'آخري ڀيرو پڙهيل ڊليٽ ڪريو',
                            iconColor: Colors.redAccent,
                            labelColor: Colors.redAccent,
                            onTap: () => _confirm(
                                context,
                                'ڇا توهان هسٽري ڊليٽ ڪرڻ چاهيو ٿا؟',
                                settings.clearLastReads),
                          ),
                          _CardDivider(),
                          _ActionRow(
                            icon: Icons.audiotrack_rounded,
                            label: 'ڊائونلوڊ ٿيل آڊيو ڊليٽ ڪريو',
                            iconColor: Colors.redAccent,
                            labelColor: Colors.redAccent,
                            onTap: () => _confirm(
                                context,
                                'ڇا توهان قرآن جي آڊيو ڊليٽ ڪرڻ چاهيو ٿا؟',
                                settings.clearDownloadedAudio),
                          ),
                        ]),

                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        )),
      ),
    );
  }

  void _confirm(
      BuildContext context, String message, VoidCallback action) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'پڪ ڪريو',
            style: TextStyle(
                fontFamily: 'MBLateefi',
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 22),
          ),
          content: Text(
            message,
            style: TextStyle(
                fontFamily: 'MBLateefi',
                fontSize: 18,
                color: AppColors.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'رد ڪريو',
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 16,
                    color: AppColors.text.withValues(alpha: 0.5)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, elevation: 0),
              onPressed: () {
                Get.back();
                action();
              },
              child: const Text(
                'ها',
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync button (header)
// ─────────────────────────────────────────────────────────────────────────────

class _SyncButton extends StatelessWidget {
  final SettingsController settings;
  const _SyncButton({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = settings.isFetchingLocation.value;
      return AnimatedOpacity(
        opacity: busy ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: busy ? null : () => _sync(),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: AppColors.gold, strokeWidth: 2),
                        )
                      : Icon(Icons.sync_rounded,
                          color: AppColors.gold, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'تازو ڪريو',
                    style: TextStyle(
                        fontFamily: 'MBLateefi',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  void _sync() {
    final s = settings;
    if (!s.isManualLocation.value) {
      // Re-fetch GPS + re-schedule adhans
      s.setAutoMode(true);
    } else {
      // Re-schedule adhans based on saved manual city coordinates
      try {
        s.setCity(s.selectedCity.value, s.manualLat.value, s.manualLng.value);
        Fluttertoast.showToast(msg: 'نماز جا وقت تازا ڪيا ويا');
      } catch (_) {
        Fluttertoast.showToast(msg: 'تازو ڪرڻ ۾ مسئلو آيو');
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout primitives
// ─────────────────────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color?   color;
  const _GroupLabel(
      {required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.gold;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: c),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                fontFamily: 'MBLateefi',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: c),
          ),
        ],
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final List<Widget> children;
  const _DashCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black
                  .withValues(alpha: Get.isDarkMode ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: AppColors.divider, indent: 56, endIndent: 16);
}

// ─────────────────────────────────────────────────────────────────────────────
// Row types
// ─────────────────────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  final IconData       icon;
  final String         label;
  final bool           value;
  final Function(bool) onChanged;
  final Color?         activeColor;
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Icon(icon, color: AppColors.gold, size: 22),
      title: Text(
        label,
        style: TextStyle(
            fontFamily: 'MBLateefi', fontSize: 18, color: AppColors.text),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeColor ?? AppColors.gold,
      activeTrackColor:
          (activeColor ?? AppColors.gold).withValues(alpha: 0.4),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData        icon;
  final String          label;
  final double          value;
  final double          min;
  final double          max;
  final int             divisions;
  final Function(double) onChanged;
  final bool            showSign;
  final bool            showPercent;
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.showSign    = false,
    this.showPercent = false,
  });

  @override
  Widget build(BuildContext context) {
    final safe = value.clamp(min, max);
    String display;
    if (showPercent) {
      display = '${(safe * 100).round()}%';
    } else if (showSign) {
      display = '${safe > 0 ? '+' : ''}${safe.toInt()}';
    } else {
      display = safe.toInt().toString();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                      fontFamily: 'MBLateefi',
                      fontSize: 18,
                      color: AppColors.text),
                ),
              ),
              Text(
                display,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                    fontFamily: 'Arial'),
              ),
            ],
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Slider(
              value: safe,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: AppColors.gold,
              inactiveColor: AppColors.gold.withValues(alpha: 0.18),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final IconData         icon;
  final String           label;
  final int              value;
  final Map<int, String> items;
  final Function(int)    onChanged;
  const _DropdownRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safe = items.containsKey(value) ? value : items.keys.first;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: AppColors.gold, size: 22),
      title: Text(
        label,
        style: TextStyle(
            fontFamily: 'MBLateefi', fontSize: 18, color: AppColors.text),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: safe,
          dropdownColor: AppColors.card,
          icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.gold),
          style: TextStyle(
              fontFamily: 'MBLateefi', color: AppColors.gold, fontSize: 14),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final String?      subtitle;
  final Color?       iconColor;
  final Color?       labelColor;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.iconColor,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: iconColor ?? AppColors.gold, size: 22),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontFamily: 'MBLateefi',
            fontSize: 18,
            fontWeight:
                labelColor != null ? FontWeight.bold : FontWeight.normal,
            color: labelColor ?? AppColors.text),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 13,
                  color: AppColors.text.withValues(alpha: 0.5)),
            )
          : null,
      trailing: Directionality(
        textDirection: TextDirection.ltr,
        child: Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.text.withValues(alpha: 0.3), size: 15),
      ),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color?   textColor;
  const _InfoRow({required this.icon, required this.text, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              color: textColor ?? AppColors.gold.withValues(alpha: 0.65),
              size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 16,
                  color: textColor ??
                      AppColors.text.withValues(alpha: 0.65),
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioGroup extends StatelessWidget {
  final IconData         icon;
  final String           label;
  final Map<int, String> options;
  final int              groupValue;
  final Function(int)    onChanged;
  const _RadioGroup({
    required this.icon,
    required this.label,
    required this.options,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text),
              ),
            ],
          ),
        ),
        ...options.entries.map(
          (e) => Theme(
            data: Theme.of(context).copyWith(
                unselectedWidgetColor:
                    AppColors.text.withValues(alpha: 0.4)),
            child: RadioListTile<int>(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              dense: true,
              title: Text(
                e.value,
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 17,
                    color: AppColors.text),
              ),
              value: e.key,
              groupValue: groupValue,
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
              activeColor: AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }
}

class _FontPreview extends StatelessWidget {
  final SettingsController settings;
  const _FontPreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Get.isDarkMode
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: settings.arabicFontSize.value,
                  color: AppColors.gold),
            ),
            const SizedBox(height: 8),
            Text(
              'الله وڏي مهربان نهايت رحم واري جي نالي سان شروع۔',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: settings.sindhiFontSize.value,
                  color: AppColors.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationToggle extends StatelessWidget {
  final SettingsController settings;
  const _LocationToggle({required this.settings});

  @override
  Widget build(BuildContext context) {
    final isAuto = !settings.isManualLocation.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Get.isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _TogglePill(
              label: 'آٽو (GPS)',
              selected: isAuto,
              isBusy: settings.isFetchingLocation.value && isAuto,
              onTap: () => settings.setAutoMode(true),
            ),
            _TogglePill(
              label: 'دستي (Manual)',
              selected: !isAuto,
              onTap: () => settings.setAutoMode(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final bool         isBusy;
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  label,
                  style: TextStyle(
                      fontFamily: 'MBLateefi',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? Colors.white
                          : AppColors.text.withValues(alpha: 0.55)),
                ),
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  final String version;
  const _VersionRow({required this.version});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(Icons.verified_rounded, color: AppColors.gold, size: 22),
      title: Text(
        'ورجن',
        style: TextStyle(
            fontFamily: 'MBLateefi', fontSize: 18, color: AppColors.text),
      ),
      trailing: version.isEmpty
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: AppColors.gold, strokeWidth: 2),
            )
          : Text(
              version,
              style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text.withValues(alpha: 0.45)),
            ),
    );
  }
}
