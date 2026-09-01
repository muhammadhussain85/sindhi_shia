import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; // ✨ NEW

import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/app_colors.dart'; // ✨ NEW: Centralized Colors

class AhadithReadingScreen extends StatefulWidget {
  final int categoryId;
  final String categoryTitle;
  final String? initialSearchQuery;
  final int? initialScrollIndex; // ✨ NEW: Accepts exact position

  const AhadithReadingScreen({super.key, required this.categoryId, required this.categoryTitle, this.initialSearchQuery, this.initialScrollIndex});

  @override
  State<AhadithReadingScreen> createState() => _AhadithReadingScreenState();
}

class _AhadithReadingScreenState extends State<AhadithReadingScreen> {
  List<Map<String, dynamic>> _allAhadith = [];
  List<Map<String, dynamic>> _filteredAhadith = [];
  bool _isLoading = true;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // ✨ NEW: Controllers to steer the list and track position
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _initialIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAhadith();
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

    Get.find<SettingsController>().saveLastReadAhadith(widget.categoryId, widget.categoryTitle, index: currentIndex);

    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAhadith() async {
    try {
      final data = await DBHelper.getAhadithByCategory(widget.categoryId);
      if (mounted) {
        setState(() {
          _allAhadith = data;
          _filteredAhadith = data;
        });

        // ✨ NEW: Calculate exactly where to jump to
        int targetIndex = 0;
        if (widget.initialScrollIndex != null) {
          targetIndex = widget.initialScrollIndex!;
        } else {
          final lastRead = Get.find<SettingsController>().lastReadAhadith;
          if (lastRead['id'] == widget.categoryId) {
            targetIndex = lastRead['index'] ?? 0;
          }
        }

        if (targetIndex >= _filteredAhadith.length || targetIndex < 0) targetIndex = 0;
        _initialIndex = targetIndex;

        // Log the opening of the book
        Get.find<SettingsController>().saveLastReadAhadith(widget.categoryId, widget.categoryTitle, index: _initialIndex);

        setState(() => _isLoading = false);

        if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
          _searchController.text = widget.initialSearchQuery!;
          _isSearching = true;
          _onSearchChanged(widget.initialSearchQuery!);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "ڊيٽابيس غلطي: $e", backgroundColor: Colors.black87, textColor: Colors.white);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredAhadith = _allAhadith;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();

    setState(() {
      _filteredAhadith = _allAhadith.where((hadith) {
        final text = (hadith['contentar'] ?? '').toString().toLowerCase();
        return text.contains(lowerQuery);
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
                widget.categoryTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'MBLateefi', fontWeight: FontWeight.bold, fontSize: 24, height: 1.5)
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
                    _filteredAhadith = _allAhadith;
                  });
                } else {
                  Navigator.pop(context);
                }
              }
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
                    _filteredAhadith = _allAhadith;
                  }
                });
              },
            )
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _filteredAhadith.isEmpty
            ? Center(child: Text("ڪو به نتيجو نه مليو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: AppColors.text.withValues(alpha:0.5))))
            : Directionality(
          textDirection: TextDirection.rtl,
          child: ScrollablePositionedList.builder(
            itemScrollController: _scrollController,
            itemPositionsListener: _itemPositionsListener,
            initialScrollIndex: _initialIndex,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            physics: const BouncingScrollPhysics(),
            itemCount: _filteredAhadith.length,
            itemBuilder: (context, index) {
              final hadith = _filteredAhadith[index];
              final String idStr = (hadith['id'] ?? index).toString();
              String text = hadith['contentar']?.toString().trim() ?? '';

              if (text.isEmpty || text.toLowerCase() == 'null') {
                text = "(حديث نمبر $idStr موجود ناهي)";
              }

              final baseStyle = TextStyle(fontFamily: 'MBLateefi', fontSize: settings.sindhiFontSize.value + 2, color: AppColors.text.withValues(alpha:0.9), height: 1.8);
              final highlightStyle = baseStyle.copyWith(color: AppColors.highlight, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: AppColors.highlight);

              const String appLink = "ڊائونلوڊ ڪريو (Sindhi Shia Toolkit):\nhttps://play.google.com/store/apps/details?id=com.tasneemacademy.sindhishiatoolkit";
              final String reference = "حوالو: (${widget.categoryTitle} - حديث ${index + 1})";
              final String finalShareText = "$text\n\n$reference\n\n$appLink";

              List<TextSpan> buildSindhiSpans(String source, String query) {
                if (query.isEmpty) return [TextSpan(text: source, style: baseStyle)];
                final matches = query.toLowerCase().allMatches(source.toLowerCase());
                if (matches.isEmpty) return [TextSpan(text: source, style: baseStyle)];

                List<TextSpan> spans = [];
                int start = 0;
                for (var match in matches) {
                  if (match.start > start) spans.add(TextSpan(text: source.substring(start, match.start), style: baseStyle));
                  spans.add(TextSpan(text: source.substring(match.start, match.end), style: highlightStyle));
                  start = match.end;
                }
                if (start < source.length) spans.add(TextSpan(text: source.substring(start), style: baseStyle));
                return spans;
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.gold.withValues(alpha:0.1), width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:Get.isDarkMode ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      color: AppColors.gold.withValues(alpha:0.05),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("حديث ${index + 1}", style: TextStyle(fontFamily: 'MBLateefi', color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 20)),
                          Icon(Icons.format_quote_rounded, color: AppColors.gold.withValues(alpha:0.5), size: 24),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
                      color: AppColors.card,
                      child: SelectableText.rich(
                        TextSpan(
                          children: _isSearching
                              ? buildSindhiSpans(text, _searchController.text.trim())
                              : [TextSpan(text: text, style: baseStyle)],
                        ),
                        textAlign: TextAlign.justify,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Get.isDarkMode ? Colors.white.withValues(alpha:0.02) : Colors.black.withValues(alpha:0.02),
                        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha:0.1))),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.copy_rounded, color: AppColors.gold.withValues(alpha:0.7), size: 24),
                              tooltip: "ڪاپي ڪريو",
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: finalShareText));
                                _showToast("حديث ڪاپي ٿي وئي");
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.share_rounded, color: AppColors.gold.withValues(alpha:0.7), size: 24),
                              tooltip: "شيئر ڪريو",
                              onPressed: () => Share.share(finalShareText),
                            ),
                            Obx(() {
                              final bool isSaved = settings.isBookmarked('hadith', idStr);
                              return IconButton(
                                icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isSaved ? AppColors.gold : AppColors.gold.withValues(alpha:0.7), size: 24),
                                tooltip: "محفوظ ڪريو",
                                onPressed: () => settings.toggleBookmark('hadith', idStr, widget.categoryTitle, "", text),
                              );
                            }),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    });
  }
}