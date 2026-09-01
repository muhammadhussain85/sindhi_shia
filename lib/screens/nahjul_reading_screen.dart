import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; // ✨ NEW

import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/arabic_search_utils.dart';
import '../utils/app_colors.dart'; // ✨ NEW: Centralized Colors

class NahjulReadingScreen extends StatefulWidget {
  final int secRowId;
  final String title;
  final String? initialSearchQuery;
  final int? initialScrollIndex; // ✨ NEW: Accepts exact position

  const NahjulReadingScreen({super.key, required this.secRowId, required this.title, this.initialSearchQuery, this.initialScrollIndex});

  @override
  State<NahjulReadingScreen> createState() => _NahjulReadingScreenState();
}

class _NahjulReadingScreenState extends State<NahjulReadingScreen> {
  List<Map<String, dynamic>> _allParagraphs = [];
  List<Map<String, dynamic>> _filteredParagraphs = [];
  bool _isLoading = true;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  RegExp _activeRegex = RegExp(r'');

  // ✨ NEW: Controllers to steer the list and track position
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _initialIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadParagraphs();
  }

  @override
  void dispose() {
    // ✨ NEW: Find exactly which paragraph is on the screen before closing, and save it!
    int currentIndex = _initialIndex;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      try {
        currentIndex = positions
            .where((item) => item.itemTrailingEdge > 0)
            .reduce((min, item) => item.itemLeadingEdge < min.itemLeadingEdge ? item : min)
            .index;
      } catch (e) {}
    }

    Get.find<SettingsController>().saveLastReadNahjul(widget.secRowId, widget.title, index: currentIndex);

    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParagraphs() async {
    final data = await DBHelper.getNahjulParagraphs(widget.secRowId);
    if (mounted) {
      setState(() {
        _allParagraphs = data;
        _filteredParagraphs = data;
      });

      // ✨ NEW: Calculate exactly where to jump to
      int targetIndex = 0;
      if (widget.initialScrollIndex != null) {
        targetIndex = widget.initialScrollIndex!;
      } else {
        final lastRead = Get.find<SettingsController>().lastReadNahjul;
        if (lastRead['id'] == widget.secRowId) {
          targetIndex = lastRead['index'] ?? 0;
        }
      }

      if (targetIndex >= _filteredParagraphs.length || targetIndex < 0) targetIndex = 0;
      _initialIndex = targetIndex;

      // Log the opening of the book
      Get.find<SettingsController>().saveLastReadNahjul(widget.secRowId, widget.title, index: _initialIndex);

      setState(() => _isLoading = false);

      if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
        _searchController.text = widget.initialSearchQuery!;
        _isSearching = true;
        _onSearchChanged(widget.initialSearchQuery!);
      }
    }
  }

  void _onSearchChanged(String query) {
    final settings = Get.find<SettingsController>();
    final mode = settings.readingMode.value;

    if (query.trim().isEmpty) {
      setState(() {
        _filteredParagraphs = _allParagraphs;
        _activeRegex = RegExp(r'');
      });
      return;
    }

    final lowerQuery = query.toLowerCase();

    setState(() {
      _activeRegex = ArabicSearchUtils.getHighlightRegex(query);
      _filteredParagraphs = _allParagraphs.where((parag) {
        final arabic = (parag['txt'] ?? '').toString().toLowerCase();
        final translation = (parag['mean'] ?? '').toString().toLowerCase();

        bool matches = false;
        if (mode == 1) {
          matches = _activeRegex.hasMatch(ArabicSearchUtils.normalizeLetters(arabic));
        } else if (mode == 2) {
          matches = _activeRegex.hasMatch(ArabicSearchUtils.normalizeLetters(translation));
        } else {
          matches = _activeRegex.hasMatch(ArabicSearchUtils.normalizeLetters(arabic)) ||
              _activeRegex.hasMatch(ArabicSearchUtils.normalizeLetters(translation));
        }
        return matches;
      }).toList();
    });
  }

  void _showToast(String message) {
    Fluttertoast.showToast(msg: message, backgroundColor: Colors.black87, textColor: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = Get.find<SettingsController>();

    return Obx(() {
      final mode = settings.readingMode.value;

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 100,
          title: _isSearching
              ? Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(fontFamily: 'MBLateefi', color: AppColors.text, fontSize: 22),
              decoration: InputDecoration(
                hintText: 'تلاش ڪريو...',
                hintStyle: TextStyle(color: AppColors.text.withValues(alpha:0.5)),
                border: InputBorder.none,
              ),
              onChanged: _onSearchChanged,
            ),
          )
              : Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text(
                widget.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'MBLateefi', fontSize: 24, fontWeight: FontWeight.bold, height: 1.5)
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.text,
          leading: IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: AppColors.gold, size: 32),
            onPressed: () {
              if (_isSearching) {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _filteredParagraphs = _allParagraphs;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              padding: const EdgeInsets.only(right: 16),
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: AppColors.gold, size: 28),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _filteredParagraphs = _allParagraphs;
                  }
                });
              },
            )
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _filteredParagraphs.isEmpty
            ? Center(child: Text("ڪو به نتيجو نه مليو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, color: AppColors.text.withValues(alpha:0.5))))
            : ScrollablePositionedList.builder(
          itemScrollController: _scrollController,
          itemPositionsListener: _itemPositionsListener,
          initialScrollIndex: _initialIndex,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          physics: const BouncingScrollPhysics(),
          itemCount: _filteredParagraphs.length,
          itemBuilder: (context, index) {
            final item = _filteredParagraphs[index];
            final String arabicText = (item['txt'] ?? '').toString();
            final String translationText = (item['mean'] ?? '').toString();

            final bool showArabic = mode == 0 || mode == 1;
            final bool showTrans = mode == 0 || mode == 2;
            final bottomBgColor = (mode == 1) ? AppColors.arabicBg : AppColors.card;

            final baseArabicStyle = TextStyle(fontFamily: 'Amiri', fontSize: settings.arabicFontSize.value, color: AppColors.text, height: 2.2, fontWeight: FontWeight.w500);
            final highlightArabicStyle = baseArabicStyle.copyWith(color: AppColors.highlight, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: AppColors.highlight);

            final baseSindhiStyle = TextStyle(fontFamily: 'MBLateefi', fontSize: settings.sindhiFontSize.value, color: AppColors.text.withValues(alpha:0.85), height: 1.8);
            final highlightSindhiStyle = baseSindhiStyle.copyWith(color: AppColors.highlight, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: AppColors.highlight);

            String shareContent = "";
            if (mode == 0) shareContent = "$arabicText\n\n$translationText";
            else if (mode == 1) shareContent = arabicText;
            else if (mode == 2) shareContent = translationText;

            const String appLink = "ڊائونلوڊ ڪريو (Sindhi Shia Toolkit):\nhttps://play.google.com/store/apps/details?id=com.tasneemacademy.sindhishiatoolkit";
            final String reference = "حوالو: (${widget.title} - پيراگراف ${index + 1})";
            final String finalShareText = "$shareContent\n\n$reference\n\n$appLink";

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.gold.withValues(alpha:0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:Get.isDarkMode ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showArabic && arabicText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: AppColors.arabicBg,
                      child: SelectableText.rich(
                        TextSpan(
                          children: _isSearching
                              ? ArabicSearchUtils.buildHighlightedSpans(arabicText, _activeRegex, baseArabicStyle, highlightArabicStyle)
                              : [TextSpan(text: arabicText, style: baseArabicStyle)],
                        ),
                        textAlign: TextAlign.justify,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  if (showTrans && translationText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
                      color: AppColors.card,
                      child: SelectableText.rich(
                        TextSpan(
                          children: _isSearching
                              ? ArabicSearchUtils.buildHighlightedSpans(translationText, _activeRegex, baseSindhiStyle, highlightSindhiStyle)
                              : [TextSpan(text: translationText, style: baseSindhiStyle)],
                        ),
                        textAlign: TextAlign.justify,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  Container(
                    color: bottomBgColor,
                    padding: const EdgeInsets.only(left: 8, bottom: 6, top: 4),
                    alignment: Alignment.centerLeft,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.copy_rounded, color: AppColors.gold.withValues(alpha:0.6), size: 24),
                            tooltip: "ڪاپي ڪريو",
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: finalShareText));
                              _showToast("ڪاپي ٿي ويو");
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.share_rounded, color: AppColors.gold.withValues(alpha:0.6), size: 24),
                            tooltip: "شيئر ڪريو",
                            onPressed: () => Share.share(finalShareText),
                          ),
                          Obx(() {
                            final String uniqueId = "nahjul_${widget.secRowId}_${item['ID'] ?? index}";
                            final bool isSaved = settings.isBookmarked('nahjul', uniqueId);
                            return IconButton(
                              icon: Icon(
                                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: AppColors.gold.withValues(alpha:isSaved ? 1.0 : 0.6),
                                size: 24,
                              ),
                              tooltip: "محفوظ ڪريو",
                              onPressed: () {
                                settings.toggleBookmark('nahjul', uniqueId, "${widget.title} - حصو ${index + 1}", arabicText, translationText);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}