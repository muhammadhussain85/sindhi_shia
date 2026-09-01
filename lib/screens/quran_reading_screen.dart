import 'dart:async'; // ✅ Added for Debouncer
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../controllers/settings_controller.dart';
import '../controllers/quran_audio_controller.dart';
import '../database/db_helper.dart';
import '../utils/arabic_search_utils.dart';
import '../utils/app_colors.dart';

class QuranReadingScreen extends StatefulWidget {
  final int fetchId;
  final String title;
  final bool isJuzMode;
  final String? initialSearchQuery;
  final int? initialScrollVerse;

  const QuranReadingScreen({super.key, required this.fetchId, required this.title, required this.isJuzMode, this.initialSearchQuery, this.initialScrollVerse});

  @override
  State<QuranReadingScreen> createState() => _QuranReadingScreenState();
}

class _QuranReadingScreenState extends State<QuranReadingScreen> {
  List<Map<String, dynamic>> _allAyahs = [];
  List<Map<String, dynamic>> _filteredAyahs = [];
  bool _isLoading = true;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  RegExp _activeRegex = RegExp(r'');
  Timer? _debounce;

  late Worker _translationListener;
  // Resolved once in initState — never via Get.find() in build() or
  // a conditional Get.put() inside an async method, both of which can
  // race with the first frame or silently fail in Juz mode.
  late final QuranAudioController _audioController;

  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _initialIndex = 0;

  @override
  void initState() {
    super.initState();
    // The controller is permanently registered in main.dart and outlives
    // every screen — just find it.
    _audioController = Get.find<QuranAudioController>();
    _loadData();
    _translationListener = ever(Get.find<SettingsController>().selectedTranslation, (_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    int currentIndex = _initialIndex;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      try {
        currentIndex = positions
            .where((item) => item.itemTrailingEdge > 0)
            .reduce((min, item) => item.itemLeadingEdge < min.itemLeadingEdge ? item : min)
            .index;
      } catch (_) {
        // itemPositions can throw if list is empty — fall back to _initialIndex
      }
    }

    final settings = Get.find<SettingsController>();
    settings.saveLastReadQuran(widget.fetchId, widget.title, widget.isJuzMode, index: currentIndex);

    // Only stop playback if the user has disabled background audio.
    // When enabled, audio continues after the screen closes so the user
    // can keep listening while browsing the rest of the app.
    if (!settings.enableBackgroundAudio.value) {
      _audioController.stopAudio();
    }

    // Never call Get.delete<QuranAudioController>() — the controller is
    // permanently owned by main.dart and must survive screen transitions.
    _translationListener.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final data = widget.isJuzMode
        ? await DBHelper.getAyahsByJuz(widget.fetchId)
        : await DBHelper.getAyahsBySurah(widget.fetchId);

    if (mounted) {
      setState(() {
        _allAyahs = data;
        if (_isSearching && _searchController.text.isNotEmpty) {
          _filteredAyahs = _filterAyahs(_searchController.text);
        } else {
          _filteredAyahs = data;
        }
      });

      int targetIndex = 0;
      if (widget.initialScrollVerse != null) {
        int vIndex = _filteredAyahs.indexWhere((a) => _extractNumber(a, ['verse', 'ayah', 'aya'], 0) == widget.initialScrollVerse);
        if (vIndex != -1) targetIndex = vIndex;
      } else {
        final lastRead = Get.find<SettingsController>().lastReadQuran;
        if (lastRead['id'] == widget.fetchId && lastRead['isJuz'] == widget.isJuzMode) {
          targetIndex = lastRead['index'] ?? 0;
        }
      }

      if (targetIndex >= _filteredAyahs.length || targetIndex < 0) targetIndex = 0;
      _initialIndex = targetIndex;

      Get.find<SettingsController>().saveLastReadQuran(widget.fetchId, widget.title, widget.isJuzMode, index: _initialIndex);
      setState(() => _isLoading = false);

      if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty && !_isSearching) {
        _searchController.text = widget.initialSearchQuery!;
        _isSearching = true;
        _onSearchInputChanged(widget.initialSearchQuery!);
      }

      if (!widget.isJuzMode) {
        _audioController.checkDownloadStatus(widget.fetchId, _allAyahs.length);
      }
    }
  }

  String _extractText(Map<String, dynamic> item, List<String> keywords) {
    for (String key in item.keys) {
      String lowerKey = key.toLowerCase();
      for (String keyword in keywords) {
        if (lowerKey.contains(keyword) && item[key] != null) {
          String val = item[key].toString().trim();
          if (val.isNotEmpty && int.tryParse(val) == null) {
            return val;
          }
        }
      }
    }
    return '';
  }

  int _extractNumber(Map<String, dynamic> item, List<String> keywords, int fallback) {
    for (String key in item.keys) {
      String lowerKey = key.toLowerCase();
      for (String keyword in keywords) {
        if (lowerKey.contains(keyword) && item[key] != null) {
          String val = item[key].toString().trim();
          if (val.isNotEmpty) {
            int? parsed = int.tryParse(val);
            if (parsed != null) return parsed;
          }
        }
      }
    }
    return fallback;
  }

  List<Map<String, dynamic>> _filterAyahs(String query) {
    final settings = Get.find<SettingsController>();
    final mode = settings.readingMode.value;
    final bool isEncrypted = settings.selectedTranslation.value == 0;
    final lowerQuery = query.toLowerCase();

    _activeRegex = ArabicSearchUtils.getHighlightRegex(query, isLegacyFont: isEncrypted);

    return _allAyahs.where((ayah) {
      final arabic = _extractText(ayah, ['arabic', 'text', 'ayahtext']).toLowerCase();
      final rawTranslation = _extractText(ayah, ['sindhi', 'trans', 'tr', 'tarjuma']);

      bool matches = false;

      if (isEncrypted) {
        if (mode == 1) {
          matches = _activeRegex.hasMatch(ArabicSearchUtils.normalizeLetters(arabic));
        } else if (mode == 2) {
          matches = _activeRegex.hasMatch(rawTranslation);
        } else {
          matches = _activeRegex.hasMatch(ArabicSearchUtils.normalizeLetters(arabic)) ||
              _activeRegex.hasMatch(rawTranslation);
        }
      } else {
        String targetTranslation = ArabicSearchUtils.normalizeLetters(rawTranslation).toLowerCase();
        if (mode == 1) {
          matches = _activeRegex.hasMatch(ArabicSearchUtils.normalizeLetters(arabic));
        } else if (mode == 2) {
          matches = _activeRegex.hasMatch(targetTranslation) || targetTranslation.contains(lowerQuery);
        } else {
          matches = _activeRegex.hasMatch(ArabicSearchUtils.normalizeLetters(arabic)) ||
              _activeRegex.hasMatch(targetTranslation) ||
              targetTranslation.contains(lowerQuery);
        }
      }
      return matches;
    }).toList();
  }

  // ✅ CRITICAL FIX: Add Debouncer to local search
  void _onSearchInputChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.trim().isEmpty) {
        setState(() {
          _filteredAyahs = _allAyahs;
          _activeRegex = RegExp(r'');
        });
        return;
      }
      setState(() {
        _filteredAyahs = _filterAyahs(query);
      });
    });
  }

  String _getAyahEnd(int number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String numStr = number.toString();
    for (int i = 0; i < english.length; i++) {
      numStr = numStr.replaceAll(english[i], arabic[i]);
    }
    return " ﴿$numStr﴾ ";
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = Get.find<SettingsController>();

    return Obx(() {
      final currentTranslation = settings.selectedTranslation.value;

      final bgColor = AppColors.parchmentBackground;
      final goldColor = AppColors.parchmentGold;
      final textColor = AppColors.parchmentText;
      final cardColor = AppColors.parchmentCard;

      return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            toolbarHeight: 100,
            title: _isSearching
                ? Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(fontFamily: 'MBLateefi', color: textColor, fontSize: 22),
                decoration: InputDecoration(
                  hintText: 'ڳوليو...',
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchInputChanged, // ✅ Using debouncer
              ),
            )
                : Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'MBLateefi', fontSize: 28, fontWeight: FontWeight.bold, height: 1.5)
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            foregroundColor: textColor,
            leading: IconButton(
              icon: Icon(Icons.chevron_left_rounded, color: goldColor, size: 32),
              onPressed: () {
                if (_isSearching) {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _filteredAyahs = _allAyahs;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            actions: [
              IconButton(
                padding: const EdgeInsets.only(right: 4),
                icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: goldColor, size: 28),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _filteredAyahs = _allAyahs;
                    }
                  });
                },
              ),

              if (!widget.isJuzMode && _allAyahs.isNotEmpty && !_isSearching)
                Obx(() {
                  bool isAutoPlaying = _audioController.isContinuousPlay.value;
                  return IconButton(
                    padding: const EdgeInsets.only(right: 4),
                    icon: Icon(
                      isAutoPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                      color: isAutoPlaying ? Colors.redAccent : goldColor,
                      size: 28,
                    ),
                    tooltip: isAutoPlaying ? "بند ڪريو (Stop)" : "مڪمل سورة ٻڌو (Play All)",
                    onPressed: () {
                      if (isAutoPlaying) {
                        _audioController.stopAudio();
                      } else {
                        _audioController.playFullSurah(widget.fetchId, _allAyahs.length);
                      }
                    },
                  );
                }),
            ],
          ),
          // ✅ CRITICAL FIX: The top level stack NO LONGER listens to currentPlayingVerse!
          body: Stack(
            children: [
              if (_isLoading)
                Center(child: CircularProgressIndicator(color: goldColor))
              else if (_filteredAyahs.isEmpty)
                Center(child: Text("ڪو به نتيجو نه مليو", style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 20, fontFamily: 'MBLateefi')))
              else
                ScrollablePositionedList.builder(
                  key: ValueKey(currentTranslation),
                  itemCount: _filteredAyahs.length,
                  itemScrollController: _scrollController,
                  itemPositionsListener: _itemPositionsListener,
                  initialScrollIndex: _initialIndex,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                  itemBuilder: (context, index) {
                    return _buildPremiumAyahCard(context, _filteredAyahs[index], settings, goldColor, cardColor, textColor);
                  },
                ),
              _buildFloatingPlayer(goldColor),
            ],
          ),
        );
    });
  }

  Widget _buildPremiumAyahCard(BuildContext context, Map<String, dynamic> ayah, SettingsController settings, Color goldColor, Color cardColor, Color textColor) {
    final String arabicText = _extractText(ayah, ['arabic', 'text', 'ayahtext']);
    final String tarjumaText = _extractText(ayah, ['sindhi', 'trans', 'tr', 'tarjuma']);
    final String tafseerText = _extractText(ayah, ['tafseer', 'tafsir', 'talighe']);

    final int verseNum = _extractNumber(ayah, ['verse', 'ayah', 'aya'], 0);
    final int surahId = _extractNumber(ayah, ['chapter', 'surah'], widget.fetchId);

    // ✅ CRITICAL FIX: Obx is pushed down HERE so only the active card repaints!
    return Obx(() {
      final bool isCurrent = _audioController.currentPlayingVerse.value == verseNum && _audioController.currentPlayingSurah.value == surahId;
      final mode = settings.readingMode.value;
      final isDark = settings.isDarkMode.value;

      final bool isEncrypted = settings.selectedTranslation.value == 0;
      final translationFont = isEncrypted ? 'SindhiFont' : 'MBLateefi';

      final arabicBg = AppColors.arabicBg;
      final highlightColor = AppColors.highlight;

      final baseArabicStyle = TextStyle(fontFamily: 'Amiri', fontSize: settings.arabicFontSize.value + 4, color: AppColors.arabicText, height: 1.8);
      final highlightArabicStyle = baseArabicStyle.copyWith(color: highlightColor, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: highlightColor);

      final baseSindhiStyle = TextStyle(fontFamily: translationFont, fontSize: settings.sindhiFontSize.value + 2, color: textColor.withValues(alpha: 0.9), height: 1.6);
      final highlightSindhiStyle = baseSindhiStyle.copyWith(color: highlightColor, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: highlightColor);

      String shareableTarjuma = isEncrypted ? ArabicSearchUtils.decryptRNLashari(tarjumaText) : tarjumaText;

      final String shareContent;
      if (mode == 1) {
        shareContent = arabicText;
      } else if (mode == 2) {
        shareContent = shareableTarjuma;
      } else {
        shareContent = "$arabicText\n\n$shareableTarjuma";
      }

      const String appLink = "📱 ڊائونلوڊ (Sindhi Shia Toolkit):\nhttps://play.google.com/store/apps/details?id=com.tasneemacademy.sindhishiatoolkit";
      final String reference = "📖 قرآن مجيد (سورة ${widget.title}، آيت $verseNum)";
      final String finalShareText = "$shareContent\n\n$reference\n\n$appLink";

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isCurrent ? goldColor : goldColor.withValues(alpha: 0.05), width: isCurrent ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ CRITICAL FIX: Removed GestureDetector to allow Text Selection UX
            if ((mode == 0 || mode == 1) && arabicText.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                color: arabicBg,
                child: SelectableText.rich(
                  TextSpan(
                      children: [
                        if (_isSearching)
                          ...ArabicSearchUtils.buildHighlightedSpans(arabicText, _activeRegex, baseArabicStyle, highlightArabicStyle)
                        else
                          TextSpan(text: arabicText, style: baseArabicStyle),
                        TextSpan(text: _getAyahEnd(verseNum), style: baseArabicStyle),
                      ]
                  ),
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                ),
              ),

            // ✅ CRITICAL FIX: Removed GestureDetector to allow Text Selection UX
            if ((mode == 0 || mode == 2) && tarjumaText.isNotEmpty)
              Container(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
                color: cardColor,
                child: isEncrypted
                    ? Text.rich(
                  TextSpan(
                    children: _isSearching
                        ? ArabicSearchUtils.buildHighlightedSpans(tarjumaText, _activeRegex, baseSindhiStyle, highlightSindhiStyle, isLegacyFont: true)
                        : [TextSpan(text: tarjumaText, style: baseSindhiStyle)],
                  ),
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                )
                    : SelectableText.rich(
                  TextSpan(
                    children: _isSearching
                        ? ArabicSearchUtils.buildHighlightedSpans(tarjumaText, _activeRegex, baseSindhiStyle, highlightSindhiStyle, isLegacyFont: false)
                        : [TextSpan(text: tarjumaText, style: baseSindhiStyle)],
                  ),
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                ),
              ),

            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    (tafseerText.trim().isNotEmpty && tafseerText.trim().toLowerCase() != 'null')
                        ? IconButton(
                      icon: Icon(Icons.menu_book_rounded, color: goldColor.withValues(alpha: 0.7), size: 22),
                      tooltip: "تفسير",
                      onPressed: () {
                        String showTafseer = isEncrypted ? ArabicSearchUtils.decryptRNLashari(tafseerText) : tafseerText;
                        _showTafseerBottomSheet(context, verseNum, showTafseer, isDark, cardColor, goldColor, 'MBLateefi', settings.sindhiFontSize.value);
                      },
                    )
                        : const SizedBox(width: 48),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ✅ CRITICAL FIX: Added specific Play button to replace text tapping!
                        IconButton(
                            icon: Icon(isCurrent ? Icons.stop_rounded : Icons.play_arrow_rounded, color: isCurrent ? Colors.redAccent : goldColor.withValues(alpha: 0.7), size: 26),
                            tooltip: isCurrent ? "بند ڪريو" : "آڊيو هلايو",
                            onPressed: () {
                              if (isCurrent) {
                                _audioController.stopAudio();
                              } else {
                                _audioController.playAyah(surahId, verseNum);
                              }
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.copy_rounded, color: goldColor.withValues(alpha: 0.7), size: 22),
                          tooltip: "ڪاپي",
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: finalShareText));
                            Fluttertoast.showToast(msg: "آيت ڪاپي ڪئي وئي آهي", backgroundColor: isDark ? Colors.grey[900] : Colors.white, textColor: goldColor);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.share_rounded, color: goldColor.withValues(alpha: 0.7), size: 22),
                          tooltip: "شيئر",
                          onPressed: () => Share.share(finalShareText),
                        ),
                        Obx(() {
                          final String uniqueId = "quran_${surahId}_$verseNum";
                          final bool isSaved = settings.isBookmarked('quran', uniqueId);
                          return IconButton(
                            icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isSaved ? goldColor : goldColor.withValues(alpha: 0.7), size: 22),
                            tooltip: "بڪ مارڪ",
                            onPressed: () => settings.toggleBookmark('quran', uniqueId, "${widget.title} - آيت $verseNum", arabicText, shareableTarjuma),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showTafseerBottomSheet(BuildContext context, int verseNum, String tafseerText, bool isDark, Color bgColor, Color goldColor, String font, double fontSize) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A202C);
    Get.bottomSheet(
      DraggableScrollableSheet(
        initialChildSize: 0.65, minChildSize: 0.4, maxChildSize: 0.96, expand: false,
        builder: (context, scrollController) {
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverAppBar(
                  primary: false, pinned: true, backgroundColor: bgColor, elevation: 0, automaticallyImplyLeading: false, titleSpacing: 0, toolbarHeight: 100,
                  title: Container(
                    height: 100, padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(color: bgColor, border: Border(bottom: BorderSide(color: goldColor.withValues(alpha: 0.1)))),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 50, height: 5, decoration: BoxDecoration(color: goldColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(icon: Icon(Icons.close_rounded, color: textColor.withValues(alpha: 0.5)), onPressed: () => Get.back()),
                            Text("آيت $verseNum جو تفسير", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 24, fontWeight: FontWeight.bold, color: goldColor)),
                            Icon(Icons.swipe_up_rounded, color: goldColor.withValues(alpha: 0.4), size: 24),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                    child: SelectableText(
                      tafseerText.isNotEmpty ? tafseerText : "هن آيت جو تفسير اڃا موجود ناهي.",
                      textAlign: TextAlign.justify, textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: font, fontSize: fontSize, color: textColor.withValues(alpha: 0.9), height: 1.8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true, backgroundColor: Colors.transparent,
    );
  }

  Widget _buildFloatingPlayer(Color goldColor) {
    return Obx(() {
      if (_audioController.currentPlayingVerse.value == 0 && !_audioController.isLoading.value) return const SizedBox();
      bool continuous = _audioController.isContinuousPlay.value;
      final isDark = Get.isDarkMode;

      return Positioned(
        bottom: 30, left: 20, right: 20,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: goldColor.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_audioController.isPlaying.value) {
                        _audioController.pauseAudio();
                      } else {
                        _audioController.resumeAudio();
                      }
                    },
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [goldColor, goldColor.withValues(alpha: 0.8)]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: goldColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                      ),
                      child: Center(
                        child: _audioController.isLoading.value
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(_audioController.isPlaying.value ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            continuous ? "مڪمل سورة (Auto-Play)" : "آيت پڙهي پئي وڃي",
                            style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
                          ),
                          const SizedBox(height: 2),
                          Text(
                              "آيت نمبر: ${_audioController.currentPlayingVerse.value}",
                              style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                        icon: const Icon(Icons.stop_rounded, color: Colors.redAccent, size: 28),
                        onPressed: () => _audioController.stopAudio()
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}