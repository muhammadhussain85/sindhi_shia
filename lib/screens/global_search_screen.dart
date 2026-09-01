import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/arabic_search_utils.dart';
import '../utils/app_colors.dart';
import 'quran_reading_screen.dart';
import 'reading_screen.dart';
import 'nahjul_reading_screen.dart';
import 'ziyarat_reading_screen.dart';
import 'ahadith_reading_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isSearching      = false;
  bool _smartSearchEnabled = true;
  int  _selectedTabIndex = 0; // 0 = Sindhi, 1 = Arabic

  List<Map<String, dynamic>> _quranResults   = [];
  List<Map<String, dynamic>> _sahifaResults  = [];
  List<Map<String, dynamic>> _nahjulResults  = [];
  List<Map<String, dynamic>> _ziyaratResults = [];
  List<Map<String, dynamic>> _ahadithResults = [];

  // Search-token pattern: stale Future.wait results are discarded.
  int  _searchToken        = 0;
  bool _isSearchInProgress = false;

  @override
  void initState() {
    super.initState();
    // Rebuild instantly on every keystroke so the clear-X button
    // appears/disappears without waiting for the debounce.
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Search logic ────────────────────────────────────────────────────────────

  void _onSearchInputChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  // Why Future.wait and not compute():
  // sqflite's method channel only works on the main Dart isolate.
  // Future.wait dispatches all five LIKE queries concurrently — sqflite
  // serialises them on its own native background thread. The main isolate
  // suspends but the UI thread keeps rendering at 60 fps. The secondary
  // Dart filter (RegExp over ≤150 rows) is negligible on the main isolate.
  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _quranResults.clear();
          _sahifaResults.clear();
          _nahjulResults.clear();
          _ziyaratResults.clear();
          _ahadithResults.clear();
          _isSearching        = false;
          _isSearchInProgress = false;
        });
      }
      return;
    }

    final token = ++_searchToken;
    if (mounted) setState(() => _isSearchInProgress = true);

    final settings    = Get.find<SettingsController>();
    final isEncrypted = settings.selectedTranslation.value == 0;
    final arabicMode  = _selectedTabIndex == 1;

    try {
      final results = await Future.wait([
        DBHelper.searchQuranLike(trimmed,   arabicMode: arabicMode),
        DBHelper.searchSahifaLike(trimmed,  arabicMode: arabicMode),
        DBHelper.searchNahjulLike(trimmed,  arabicMode: arabicMode),
        DBHelper.searchZiyaratLike(trimmed, arabicMode: arabicMode),
        DBHelper.searchAhadithLike(trimmed, arabicMode: arabicMode),
      ]);

      if (token != _searchToken || !mounted) return;

      final regex = _smartSearchEnabled
          ? ArabicSearchUtils.getHighlightRegex(trimmed,
              isLegacyFont: isEncrypted && !arabicMode)
          : RegExp(RegExp.escape(trimmed), caseSensitive: false);
      final lower = trimmed.toLowerCase();

      setState(() {
        _quranResults   = results[0].where((i) => _matchItem(i, ['arabic', 'text', 'ayahtext'], ['sindhi', 'trans', 'tr', 'tarjuma'], regex, lower, isEncrypted)).toList();
        _sahifaResults  = results[1].where((i) => _matchItem(i, ['txt'], ['mean'], regex, lower, false)).toList();
        _nahjulResults  = results[2].where((i) => _matchItem(i, ['txt'], ['mean'], regex, lower, false)).toList();
        _ziyaratResults = results[3].where((i) => _matchItem(i, ['txt'], ['mean'], regex, lower, false)).toList();
        _ahadithResults = results[4].where((i) => _matchItem(i, ['contentar'], ['contentur', 'sindhi'], regex, lower, false)).toList();
        _isSearchInProgress = false;
        _isSearching        = true;
      });
    } catch (_) {
      if (token != _searchToken || !mounted) return;
      setState(() => _isSearchInProgress = false);
      Fluttertoast.showToast(msg: 'ڳولا ۾ مسئلو آيو');
    }
  }

  bool _matchItem(
    Map<String, dynamic> item,
    List<String> arKeys,
    List<String> sdKeys,
    RegExp regex,
    String lowerQuery,
    bool isEncrypted,
  ) {
    final arabic = _extractValue(item, arKeys);
    final sindhi = _extractValue(item, sdKeys);
    if (_selectedTabIndex == 1) {
      return _smartSearchEnabled
          ? regex.hasMatch(ArabicSearchUtils.normalizeLetters(arabic))
          : arabic.contains(lowerQuery);
    } else {
      if (isEncrypted && sdKeys.contains('tarjuma')) {
        return regex.hasMatch(sindhi);
      }
      final target = _smartSearchEnabled
          ? ArabicSearchUtils.normalizeLetters(sindhi).toLowerCase()
          : sindhi.toLowerCase();
      return _smartSearchEnabled
          ? regex.hasMatch(target) || target.contains(lowerQuery)
          : target.contains(lowerQuery);
    }
  }

  String _extractValue(Map<String, dynamic> item, List<String> keys) {
    for (final k in item.keys) {
      if (keys.contains(k.toLowerCase()) && item[k] != null) {
        return item[k].toString().trim();
      }
    }
    return '';
  }

  int _extractNumber(
      Map<String, dynamic> item, List<String> keywords, int fallback) {
    for (final key in item.keys) {
      final lk = key.toLowerCase();
      for (final keyword in keywords) {
        if (lk.contains(keyword) && item[key] != null) {
          final parsed = int.tryParse(item[key].toString().trim());
          if (parsed != null) return parsed;
        }
      }
    }
    return fallback;
  }

  // ── Derived state ────────────────────────────────────────────────────────────

  bool get _hasResults =>
      _quranResults.isNotEmpty ||
      _sahifaResults.isNotEmpty ||
      _nahjulResults.isNotEmpty ||
      _ziyaratResults.isNotEmpty ||
      _ahadithResults.isNotEmpty;

  int get _totalResults =>
      _quranResults.length +
      _sahifaResults.length +
      _nahjulResults.length +
      _ziyaratResults.length +
      _ahadithResults.length;

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Floating header (title + filter pills + search bar) ──────
                SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppColors.card,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  forceElevated: true,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  toolbarHeight: 64,
                  title: _buildTitleRow(),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(124),
                    child: _buildSearchHeader(),
                  ),
                ),

                // ── Thin progress bar ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isSearchInProgress ? 3 : 0,
                    child: LinearProgressIndicator(
                      color: AppColors.gold,
                      backgroundColor:
                          AppColors.gold.withValues(alpha: 0.15),
                    ),
                  ),
                ),

                // ── Content area ─────────────────────────────────────────────
                if (!_isSearching)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildInitialState(),
                  )
                else if (!_hasResults)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else ...[
                  // Result-count badge row
                  SliverToBoxAdapter(child: _buildResultCountRow()),
                  // Result sections
                  ..._buildResultSlivers(),
                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ],
            ),
          ),
        ));
  }

  // ── Header sub-widgets ───────────────────────────────────────────────────────

  Widget _buildTitleRow() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.manage_search_rounded,
              color: AppColors.gold, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          'ڳولا',
          style: TextStyle(
              fontFamily: 'MBLateefi',
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: AppColors.text),
        ),
        const Spacer(),
        // Smart search toggle (compact, always visible in title bar)
        Row(
          children: [
            Text(
              'اسمارٽ',
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 14,
                  color: AppColors.text.withValues(alpha: 0.65)),
            ),
            const SizedBox(width: 2),
            Transform.scale(
              scale: 0.78,
              child: Switch(
                value: _smartSearchEnabled,
                activeThumbColor: AppColors.gold,
                activeTrackColor: AppColors.gold.withValues(alpha: 0.35),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (val) {
                  setState(() => _smartSearchEnabled = val);
                  _performSearch(_searchController.text);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter Pills ───────────────────────────────────────────
          Row(
            children: [
              _FilterPill(
                label: 'سنڌي',
                icon: Icons.translate_rounded,
                selected: _selectedTabIndex == 0,
                onTap: () {
                  setState(() => _selectedTabIndex = 0);
                  _performSearch(_searchController.text);
                },
              ),
              const SizedBox(width: 8),
              _FilterPill(
                label: 'عربي',
                icon: Icons.text_fields_rounded,
                selected: _selectedTabIndex == 1,
                onTap: () {
                  setState(() => _selectedTabIndex = 1);
                  _performSearch(_searchController.text);
                },
              ),
              const SizedBox(width: 12),
              Text(
                _selectedTabIndex == 0
                    ? 'زير، زبر ۽ اسپيس نظرانداز'
                    : 'حرڪات کان سواءِ ڳوليو',
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 13,
                    color: AppColors.text.withValues(alpha: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Search Field ────────────────────────────────────────────
          TextField(
            controller: _searchController,
            style: TextStyle(
                fontFamily: 'MBLateefi',
                fontSize: 20,
                color: AppColors.text),
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: _selectedTabIndex == 0
                  ? 'سنڌي لفظ ڳوليو...'
                  : 'عربي لفظ ڳوليو...',
              hintStyle: TextStyle(
                  fontFamily: 'MBLateefi',
                  color: AppColors.text.withValues(alpha: 0.38)),
              prefixIcon:
                  Icon(Icons.search_rounded, color: AppColors.gold, size: 22),
              filled: true,
              fillColor: AppColors.surfaceBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.22))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      BorderSide(color: AppColors.gold, width: 1.5)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.text.withValues(alpha: 0.45),
                          size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: _onSearchInputChanged,
          ),
        ],
      ),
    );
  }

  // ── State screens ────────────────────────────────────────────────────────────

  Widget _buildInitialState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.manage_search_rounded,
                  size: 52, color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            const SizedBox(height: 22),
            Text(
              'ڳولا شروع ڪريو',
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 10),
            Text(
              'قرآن، نهج البلاغه، صحيفه سجاديه\nزيارات ۽ احاديث ۾ ڳوليو',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 17,
                  height: 1.6,
                  color: AppColors.text.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.scale(scale: 0.75 + 0.25 * v, child: child),
              ),
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.manage_search_rounded,
                    size: 52,
                    color: AppColors.gold.withValues(alpha: 0.35)),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'ڪو به نتيجو نه مليو',
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 10),
            Text(
              '"${_searchController.text.trim()}"',
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 20,
                  color: AppColors.gold.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'لاءِ ڪجهه نه مليو\nٻيو لفظ آزمايو يا زير / زبر هٽايو',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 16,
                  height: 1.6,
                  color: AppColors.text.withValues(alpha: 0.35)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result count badge ───────────────────────────────────────────────────────

  Widget _buildResultCountRow() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 14, color: AppColors.gold),
                  const SizedBox(width: 5),
                  Text(
                    '$_totalResults نتيجا مليا',
                    style: TextStyle(
                        fontFamily: 'MBLateefi',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result slivers ───────────────────────────────────────────────────────────

  static const _sections = [
    ('قرآن مجيد',       Icons.menu_book_rounded),
    ('نهج البلاغه',     Icons.auto_stories_rounded),
    ('صحيڤه سجاديه',   Icons.library_books_rounded),
    ('زيارات ۽ دعائون', Icons.mosque_rounded),
    ('احاديث',          Icons.history_edu_rounded),
  ];

  List<Widget> _buildResultSlivers() {
    final allResults = [
      _quranResults,
      _nahjulResults,
      _sahifaResults,
      _ziyaratResults,
      _ahadithResults,
    ];

    final slivers = <Widget>[];
    for (int s = 0; s < _sections.length; s++) {
      final results = allResults[s];
      if (results.isEmpty) continue;
      final label = _sections[s].$1;
      final icon  = _sections[s].$2;
      final cap   = results.length > 50 ? 50 : results.length;

      slivers.add(
        SliverToBoxAdapter(
          child: _SectionHeader(title: label, count: results.length, icon: icon),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              if (i == cap) return _OverflowMessage(remaining: results.length - 50);
              return _buildResultCard(label, results[i]);
            },
            childCount: results.length > 50 ? cap + 1 : cap,
          ),
        ),
      );
    }
    return slivers;
  }

  // ── Result card ──────────────────────────────────────────────────────────────

  Widget _buildResultCard(String category, Map<String, dynamic> item) {
    String previewText = '';
    VoidCallback onTap = () {};

    if (category == 'قرآن مجيد') {
      final sId = _extractNumber(item, ['chapter', 'surah'], 1);
      final vId = _extractNumber(item, ['verse', 'ayah', 'aya'], 1);
      previewText = 'سورة $sId، آيت $vId';
      onTap = () => Get.to(
            () => QuranReadingScreen(
              fetchId: sId,
              title: 'سورة $sId',
              isJuzMode: false,
              initialSearchQuery: _searchController.text,
              initialScrollVerse: vId,
            ),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 270),
          );
    } else if (category == 'نهج البلاغه') {
      final secTitle = item['section_title']?.toString() ?? 'نامعلوم';
      final pNum     = _extractNumber(item, ['paganum'], 1);
      final secId    = _extractNumber(item, ['secid'], 1);
      final rowId    = item['section_row_id'] ?? secId;
      previewText = '$secTitle  •  حصو $pNum';
      onTap = () => Get.to(
            () => NahjulReadingScreen(
              secRowId: rowId,
              title: secTitle,
              initialSearchQuery: _searchController.text,
              initialScrollIndex: pNum - 1,
            ),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 270),
          );
    } else if (category == 'صحيڤه سجاديه') {
      final secTitle = item['section_title']?.toString() ?? 'نامعلوم';
      final pNum     = _extractNumber(item, ['paganum'], 1);
      final secId    = _extractNumber(item, ['secid'], 1);
      final rowId    = item['section_row_id'] ?? secId;
      previewText = '$secTitle  •  پيراگراف $pNum';
      onTap = () => Get.to(
            () => ReadingScreen(
              sectionId: rowId,
              sectionTitle: secTitle,
              initialSearchQuery: _searchController.text,
              initialScrollIndex: pNum - 1,
            ),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 270),
          );
    } else if (category == 'زيارات ۽ دعائون') {
      final secTitle = item['section_title']?.toString() ?? 'نامعلوم';
      final pNum     = _extractNumber(item, ['paganum'], 1);
      final secId    = _extractNumber(item, ['secid'], 1);
      final rowId    = item['section_row_id'] ?? secId;
      previewText = '$secTitle  •  پيراگراف $pNum';
      onTap = () => Get.to(
            () => ZiyaratReadingScreen(
              sectionId: rowId,
              sectionTitle: secTitle,
              initialSearchQuery: _searchController.text,
              initialScrollIndex: pNum - 1,
            ),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 270),
          );
    } else if (category == 'احاديث') {
      final catTitle = item['category_title']?.toString() ?? 'نامعلوم';
      final id       = item['id'] ?? 1;
      final catId    = item['numorison_id'] ?? 1;
      previewText = '$catTitle  •  حديث $id';
      onTap = () => Get.to(
            () => AhadithReadingScreen(
              categoryId: catId,
              categoryTitle: catTitle,
              initialSearchQuery: _searchController.text,
              initialScrollIndex: 0,
            ),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 270),
          );
    }

    String arTxt = _extractValue(
        item, ['arabic', 'text', 'ayahtext', 'txt', 'contentar']);
    String sdTxt = _extractValue(
        item, ['sindhi', 'trans', 'tr', 'tarjuma', 'mean', 'contentur']);

    if (Get.find<SettingsController>().selectedTranslation.value == 0 &&
        category == 'قرآن مجيد') {
      sdTxt = ArabicSearchUtils.decryptRNLashari(sdTxt);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: AppColors.gold.withValues(alpha: 0.07),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black
                          .withValues(alpha: Get.isDarkMode ? 0.18 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          previewText,
                          style: TextStyle(
                              fontFamily: 'MBLateefi',
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: AppColors.gold),
                        ),
                        const SizedBox(height: 5),
                        if (_selectedTabIndex == 1 && arTxt.isNotEmpty)
                          Text(
                            arTxt,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 17,
                                height: 1.6,
                                color: AppColors.text),
                          ),
                        if (_selectedTabIndex == 0 && sdTxt.isNotEmpty)
                          Text(
                            sdTxt,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                fontFamily: 'MBLateefi',
                                fontSize: 15,
                                height: 1.4,
                                color:
                                    AppColors.text.withValues(alpha: 0.72)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.gold.withValues(alpha: 0.4),
                      size: 15),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stateless sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color:
                    selected ? Colors.white : AppColors.text.withValues(alpha: 0.65)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  fontFamily: 'MBLateefi',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? Colors.white
                      : AppColors.text.withValues(alpha: 0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String   title;
  final int      count;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    fontFamily: 'MBLateefi',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4AF37)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverflowMessage extends StatelessWidget {
  final int remaining;
  const _OverflowMessage({required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.text.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '+ $remaining وڌيڪ نتيجا — ڳولا کي وڌيڪ واضع ڪريو',
                  style: TextStyle(
                      fontFamily: 'MBLateefi',
                      fontSize: 14,
                      color: AppColors.text.withValues(alpha: 0.45)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
