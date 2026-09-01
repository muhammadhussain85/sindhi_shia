import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/app_colors.dart';

class ZikrItem {
  String title;
  String arabic;
  int target;

  ZikrItem({required this.title, required this.arabic, required this.target});
}

class TasbeehScreen extends StatefulWidget {
  final int initialIndex;
  const TasbeehScreen({super.key, this.initialIndex = 0});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> with SingleTickerProviderStateMixin {
  static const String _storageKey = 'tasbeeh_zikr_list';
  final _storage = GetStorage();

  static final List<Map<String, dynamic>> _defaults = [
    {'title': 'الله أکبر',    'arabic': 'ٱللَّٰهُ أَكْبَرُ',                                    'target': 34},
    {'title': 'الحمد لله',    'arabic': 'ٱلْحَمْدُ لِلَّٰهِ',                                   'target': 33},
    {'title': 'سبحان الله',   'arabic': 'سُبْحَانَ ٱللَّٰهِ',                                   'target': 33},
    {'title': 'استغفار',      'arabic': 'أَسْتَغْفِرُ ٱللَّٰهَ',                               'target': 100},
    {'title': 'درود شريف',    'arabic': 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَآلِ مُحَمَّدٍ',  'target': 100},
  ];

  List<ZikrItem> _zikrList = [];

  int _selectedIndex = 0;
  int _currentCount = 0;
  double _buttonScale = 1.0;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _loadZikrs();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  void _loadZikrs() {
    final saved = _storage.read<List>(_storageKey);
    if (saved != null && saved.isNotEmpty) {
      _zikrList = saved.map((e) => ZikrItem(
        title:  (e['title']  as String?) ?? '',
        arabic: (e['arabic'] as String?) ?? (e['title'] as String?) ?? '',
        target: ((e['target'] as num?) ?? 33).toInt(),
      )).toList();
    } else {
      _zikrList = _defaults.map((e) => ZikrItem(
        title:  e['title']  as String,
        arabic: e['arabic'] as String,
        target: e['target'] as int,
      )).toList();
    }
    // Honour the index passed from the home screen widget tap
    _selectedIndex = widget.initialIndex.clamp(0, _zikrList.length - 1);
  }

  void _saveZikrs() {
    _storage.write(_storageKey, _zikrList.map((z) => {
      'title':  z.title,
      'arabic': z.arabic,
      'target': z.target,
    }).toList());
  }

  void _incrementCounter() {
    final target = _zikrList[_selectedIndex].target;

    if (_currentCount < target) {
      setState(() => _currentCount++);
      HapticFeedback.lightImpact();

      if (_currentCount == target) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);

        // Auto-advance to the next zikr after 1.5 s if there is one
        if (_zikrList.length > 1) {
          _autoAdvanceTimer?.cancel();
          _autoAdvanceTimer = Timer(const Duration(milliseconds: 1500), () {
            if (mounted) {
              _selectZikr((_selectedIndex + 1) % _zikrList.length);
              HapticFeedback.mediumImpact();
            }
          });
        }
      }
    }
  }

  void _resetCounter() {
    _autoAdvanceTimer?.cancel();
    setState(() => _currentCount = 0);
    HapticFeedback.mediumImpact();
  }

  void _selectZikr(int index) {
    _autoAdvanceTimer?.cancel();
    setState(() {
      _selectedIndex = index;
      _currentCount = 0;
    });
  }

  Color _getDynamicProgressColor(double progress, bool isDark) {
    final red = isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    final yellow = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final green = isDark ? const Color(0xFF10B981) : const Color(0xFF059669);

    if (progress < 0.5) {
      return Color.lerp(red, yellow, progress * 2) ?? red;
    } else {
      return Color.lerp(yellow, green, (progress - 0.5) * 2) ?? yellow;
    }
  }

  void _showEditTargetDialog() {
    final currentZikr = _zikrList[_selectedIndex];
    final targetController = TextEditingController(text: currentZikr.target.toString());

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: AppColors.gold.withValues(alpha:0.2))),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.track_changes_rounded, color: AppColors.gold, size: 48),
                  const SizedBox(height: 16),
                  Text('نئون هدف سيٽ ڪريو', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, color: AppColors.text, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 24),

                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.text, fontSize: 22, fontFamily: 'Arial', fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'نئون تعداد (ڳڻپ)',
                      labelStyle: TextStyle(color: AppColors.gold.withValues(alpha:0.8), fontFamily: 'MBLateefi', fontSize: 18),
                      filled: true,
                      fillColor: Get.isDarkMode ? Colors.white.withValues(alpha:0.03) : Colors.black.withValues(alpha:0.03),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.gold.withValues(alpha:0.3))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.gold, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          child: Text('رد ڪريو', style: TextStyle(fontFamily: 'MBLateefi', color: AppColors.text.withValues(alpha:0.6), fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                          onPressed: () {
                            if (targetController.text.isNotEmpty) {
                              int newTarget = int.tryParse(targetController.text) ?? currentZikr.target;
                              setState(() {
                                _zikrList[_selectedIndex].target = newTarget;
                                if (_currentCount >= newTarget) _currentCount = 0;
                              });
                              _saveZikrs();
                              Get.back();
                            }
                          },
                          child: const Text('محفوظ ڪريو', style: TextStyle(fontFamily: 'MBLateefi', color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCustomZikrDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '100');

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: AppColors.gold.withValues(alpha:0.2))),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: AppColors.gold, size: 48),
                  const SizedBox(height: 16),
                  Text('نئون ذڪر شامل ڪريو', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, color: AppColors.text, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 24),

                  TextField(
                    controller: titleController,
                    style: TextStyle(color: AppColors.text, fontFamily: 'MBLateefi', fontSize: 22),
                    decoration: InputDecoration(
                      labelText: 'ذڪر جو نالو',
                      labelStyle: TextStyle(color: AppColors.gold.withValues(alpha:0.8), fontFamily: 'MBLateefi', fontSize: 18),
                      hintText: 'مثال: يا رحمٰن',
                      hintStyle: TextStyle(color: AppColors.text.withValues(alpha:0.3), fontFamily: 'MBLateefi'),
                      filled: true,
                      fillColor: Get.isDarkMode ? Colors.white.withValues(alpha:0.03) : Colors.black.withValues(alpha:0.03),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.gold.withValues(alpha:0.3))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.gold, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.text, fontSize: 22, fontFamily: 'Arial', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'تعداد (ڳڻپ)',
                      labelStyle: TextStyle(color: AppColors.gold.withValues(alpha:0.8), fontFamily: 'MBLateefi', fontSize: 18),
                      hintText: 'مثال: 100',
                      hintStyle: TextStyle(color: AppColors.text.withValues(alpha:0.3), fontFamily: 'Arial'),
                      filled: true,
                      fillColor: Get.isDarkMode ? Colors.white.withValues(alpha:0.03) : Colors.black.withValues(alpha:0.03),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.gold.withValues(alpha:0.3))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.gold, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          child: Text('رد ڪريو', style: TextStyle(fontFamily: 'MBLateefi', color: AppColors.text.withValues(alpha:0.6), fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                          onPressed: () {
                            if (titleController.text.isNotEmpty && targetController.text.isNotEmpty) {
                              int target = int.tryParse(targetController.text) ?? 100;
                              setState(() {
                                _zikrList.add(ZikrItem(title: titleController.text, arabic: titleController.text, target: target));
                                _selectedIndex = _zikrList.length - 1;
                                _currentCount = 0;
                              });
                              _saveZikrs();
                              Get.back();
                            }
                          },
                          child: const Text('محفوظ ڪريو', style: TextStyle(fontFamily: 'MBLateefi', color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = (screenWidth * 0.65).clamp(200.0, 320.0);

    return Obx(() {
      final isDark = Get.isDarkMode;
      final currentZikr = _zikrList[_selectedIndex];
      final double progress = currentZikr.target > 0 ? _currentCount / currentZikr.target : 0.0;
      final bool isFinished = _currentCount >= currentZikr.target;

      final Color dynamicColor = _getDynamicProgressColor(progress, isDark);

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 100,
          title: const Text('تسبيح', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 28, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha:0.08), shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(Icons.refresh_rounded, color: AppColors.gold, size: 22),
                onPressed: _resetCounter,
                tooltip: 'ريسٽ ڪريو',
              ),
            ),
          ],
        ),
        body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Container(
                          height: 50,
                          margin: const EdgeInsets.only(top: 8),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            reverse: true,
                            itemCount: _zikrList.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _zikrList.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: ActionChip(
                                    backgroundColor: AppColors.card,
                                    side: BorderSide(color: AppColors.gold.withValues(alpha:0.3)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    label: Row(
                                      children: [
                                        Icon(Icons.add_rounded, color: AppColors.gold, size: 18),
                                        const SizedBox(width: 6),
                                        Text('پنهنجو شامل ڪريو', style: TextStyle(fontFamily: 'MBLateefi', color: AppColors.gold, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    onPressed: () => _showAddCustomZikrDialog(),
                                  ),
                                );
                              }

                              final isSelected = index == _selectedIndex;
                              return Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: ChoiceChip(
                                  label: Text(
                                    _zikrList[index].title,
                                    style: TextStyle(
                                      fontFamily: 'MBLateefi',
                                      fontSize: 18,
                                      color: isSelected ? (isDark ? AppColors.background : Colors.white) : AppColors.text.withValues(alpha:0.8),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.gold,
                                  backgroundColor: AppColors.card,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  side: BorderSide(color: isSelected ? AppColors.gold : AppColors.text.withValues(alpha:0.05)),
                                  showCheckmark: false,
                                  onSelected: (selected) {
                                    if (selected) _selectZikr(index);
                                  },
                                ),
                              );
                            },
                          ),
                        ),

                        const Spacer(flex: 1),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  currentZikr.arabic,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 48,
                                    color: isFinished ? dynamicColor : AppColors.text,
                                    height: 1.5,
                                    shadows: isDark ? [BoxShadow(color: Colors.black.withValues(alpha:0.5), blurRadius: 10)] : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => _showEditTargetDialog(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.card : dynamicColor.withValues(alpha:0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: dynamicColor.withValues(alpha:0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_rounded, size: 16, color: dynamicColor.withValues(alpha:0.8)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ڪاونٽ: ${currentZikr.target}',
                                        style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: dynamicColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(flex: 1),

                        GestureDetector(
                          onTapDown: (_) => setState(() => _buttonScale = 0.94),
                          onTapUp: (_) {
                            setState(() => _buttonScale = 1.0);
                            _incrementCounter();
                          },
                          onTapCancel: () => setState(() => _buttonScale = 1.0),
                          child: AnimatedScale(
                            scale: _buttonScale,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeInOut,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: circleSize,
                                  height: circleSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.card,
                                    border: Border.all(color: AppColors.text.withValues(alpha:0.02), width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: dynamicColor.withValues(alpha:isDark ? 0.15 : 0.08),
                                        blurRadius: isFinished ? 40 : 20,
                                        spreadRadius: isFinished ? 5 : 2,
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(
                                  width: circleSize,
                                  height: circleSize,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0, end: progress),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, _) {
                                      return CircularProgressIndicator(
                                        value: value,
                                        strokeWidth: 10,
                                        backgroundColor: AppColors.text.withValues(alpha:0.03),
                                        valueColor: AlwaysStoppedAnimation<Color>(dynamicColor),
                                      );
                                    },
                                  ),
                                ),

                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return SlideTransition(
                                          position: Tween<Offset>(begin: const Offset(0.0, -0.3), end: Offset.zero).animate(animation),
                                          child: FadeTransition(opacity: animation, child: child),
                                        );
                                      },
                                      child: FittedBox(
                                        key: ValueKey<int>(_currentCount),
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '$_currentCount',
                                          style: TextStyle(
                                            fontSize: circleSize * 0.35,
                                            fontWeight: FontWeight.w300,
                                            color: AppColors.text,
                                            letterSpacing: -1,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isFinished)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: Icon(Icons.check_circle_rounded, color: dynamicColor, size: 30),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              );
            }
        ),
      );
    });
  }
}