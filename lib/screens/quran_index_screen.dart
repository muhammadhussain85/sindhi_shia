import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../controllers/settings_controller.dart';
import '../controllers/quran_audio_controller.dart';
import '../database/db_helper.dart';
import 'quran_reading_screen.dart';
import '../utils/arabic_search_utils.dart';

class QuranIndexScreen extends StatefulWidget {
  const QuranIndexScreen({super.key});

  @override
  State<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends State<QuranIndexScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  var _downloadedSurahs = <int>{}.obs;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allSurahs = [];
  List<Map<String, dynamic>> _filteredSurahs = [];

  List<Map<String, dynamic>> _allJuz = [];
  List<Map<String, dynamic>> _filteredJuz = [];
  bool _isLoading = true;

  final List<String> juzNames = [
    "الم ", "سيقول", "تلك الرسل",
    "لن تنالوا", "والمحصنات", "لا يحب الله",
    "وإذا سمعوا", "ولو أننا ", "قال الملأ ",
    "واعلموا ", "يعتذرون ", "وما من دابة",
    "وما أبرئ ", "ربما", "سبحان الذي",
    "قال ألم", "اقترب", "قد أفلح",
    "وقال الذين", "أمن خلق", "اتل ما اوحي ",
    "ومن يقنت ", "وما لي ", "فمن أظلم ",
    "إليه يرد", "حم ", "قال فما خطبكم ",
    "قد سمع الله", "تبارك الذي ", "عمّ يتساءلون "
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _setupData();
    _scanStorage();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _setupData() async {
    final surahs = await DBHelper.getSurahs();

    final juzList = List.generate(30, (index) => {
      'id': index + 1,
      'name': juzNames[index]
    });

    if (mounted) {
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = surahs;
        _allJuz = juzList;
        _filteredJuz = juzList;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = _allSurahs;
        _filteredJuz = _allJuz;
      } else {
        // ✨ NEW: Generate the smart Arabic regex that ignores aerabs
        final RegExp searchRegex = ArabicSearchUtils.getHighlightRegex(query, isLegacyFont: false);

        _filteredSurahs = _allSurahs.where((surah) {
          final name = (surah['Name'] ?? '').toString();
          // Normalize the database name (fixes variations of Alif, Yeh, etc.)
          final normalizedName = ArabicSearchUtils.normalizeLetters(name);
          final id = surah['Id'].toString();

          // Check if the smart regex matches the name, OR if they searched by Surah number
          return searchRegex.hasMatch(normalizedName) || id.contains(query);
        }).toList();

        _filteredJuz = _allJuz.where((juz) {
          final name = juz['name'].toString();
          final normalizedName = ArabicSearchUtils.normalizeLetters(name);
          final id = juz['id'].toString();

          return searchRegex.hasMatch(normalizedName) || id.contains(query);
        }).toList();
      }
    });
  }
  Future<void> _scanStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/quran_audio');
      Set<int> foundSurahs = {};

      if (await audioDir.exists()) {
        final List<FileSystemEntity> folders = audioDir.listSync();
        for (var folder in folders) {
          if (folder is Directory) {
            final String folderName = folder.uri.pathSegments.reversed.skip(1).first;
            final int? surahId = int.tryParse(folderName);
            if (surahId != null) foundSurahs.add(surahId);
          }
        }
      }
      _downloadedSurahs.assignAll(foundSurahs);
    } catch (e) {
      debugPrint("Storage scan failed: $e");
    }
  }

  Future<void> _handleDownload(int surahId, int totalAyahs) async {
    final audioController = Get.put(QuranAudioController());
    await audioController.downloadFullSurah(surahId, totalAyahs);
    _scanStorage();
  }

  void _showDeleteConfirm(int surahId, Color bgColor, Color textColor, Color goldColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("آڊيو ڊليٽ ڪريو", style: TextStyle(fontFamily: 'MBLateefi', color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text("ڇا توهان هن سورة جي آف لائن آڊيو ڊليٽ ڪرڻ چاهيو ٿا؟", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("رد", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: textColor.withValues(alpha:0.6)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              final audioController = Get.put(QuranAudioController());
              await audioController.deleteSurah(surahId);
              await _scanStorage();
            },
            child: const Text("ها، ڊليٽ ڪريو", style: TextStyle(fontFamily: 'MBLateefi', color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = Get.find<SettingsController>();

    return Obx(() {
      final isDark = settings.isDarkMode.value;
      final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFFDFBF7);
      final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
      final textColor = isDark ? const Color(0xFFF3F4F6) : const Color(0xFF1A202C);
      final goldColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFFC5A059);

      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          toolbarHeight: 85,
          title: const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('قرآن مجيد', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold, height: 1.3)),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: goldColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: goldColor,
            indicatorWeight: 3,
            labelColor: goldColor,
            unselectedLabelColor: textColor.withValues(alpha:0.5),
            labelStyle: const TextStyle(fontFamily: 'MBLateefi', fontSize: 22, fontWeight: FontWeight.bold),
            tabs: const [Tab(text: 'سورتون (Surahs)'), Tab(text: 'سيپارا (Juz)')],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.transparent),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor, fontSize: 18, fontFamily: 'MBLateefi'),
                    decoration: InputDecoration(
                      hintText: _tabController.index == 0 ? 'سورة ڳوليو...' : 'سيپارو ڳوليو...',
                      hintStyle: TextStyle(color: textColor.withValues(alpha:0.5)),
                      border: InputBorder.none,
                      icon: Icon(Icons.search_rounded, color: goldColor),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: textColor.withValues(alpha:0.5), size: 20),
                        onPressed: () => _searchController.clear(),
                      )
                          : null,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: goldColor))
                  : TabBarView(
                controller: _tabController,
                children: [
                  _filteredSurahs.isEmpty
                      ? Center(child: Text('ڪا به سورة نه ملي', style: TextStyle(color: textColor, fontFamily: 'MBLateefi', fontSize: 20)))
                      : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    itemCount: _filteredSurahs.length,
                    itemBuilder: (context, index) {
                      final surah = _filteredSurahs[index];
                      final int surahId = surah['Id'];
                      final int totalVerses = int.tryParse(surah['Verse'].toString()) ?? 0;

                      return _buildSurahCard(
                        id: surahId,
                        title: surah['Name'] ?? 'Surah',
                        subtitle: '${surah['Nozol']} • آيتون: $totalVerses',
                        totalAyahs: totalVerses,
                        cardColor: cardColor, textColor: textColor, goldColor: goldColor, isDark: isDark, bgColor: bgColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuranReadingScreen(fetchId: surahId, title: surah['Name'], isJuzMode: false))).then((_) => _scanStorage()),
                      );
                    },
                  ),

                  _filteredJuz.isEmpty
                      ? Center(child: Text('ڪو به سيپارو نه مليو', style: TextStyle(color: textColor, fontFamily: 'MBLateefi', fontSize: 20)))
                      : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    itemCount: _filteredJuz.length,
                    itemBuilder: (context, index) {
                      final juz = _filteredJuz[index];
                      final int juzNum = juz['id'];
                      return _buildJuzCard(
                        id: juzNum,
                        title: juz['name'],
                        subtitle: 'سيپارو $juzNum',
                        cardColor: cardColor, textColor: textColor, goldColor: goldColor, isDark: isDark,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuranReadingScreen(fetchId: juzNum, title: 'سيپارو $juzNum', isJuzMode: true))),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSurahCard({required int id, required String title, required String subtitle, required int totalAyahs, required Color cardColor, required Color textColor, required Color goldColor, required bool isDark, required Color bgColor, required VoidCallback onTap}) {
    final audioController = Get.put(QuranAudioController());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.transparent), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16), onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4, right: 8),
            child: ListTile(
              leading: Container(width: 45, height: 45, decoration: BoxDecoration(color: goldColor.withValues(alpha:0.1), shape: BoxShape.circle, border: Border.all(color: goldColor.withValues(alpha:0.3))), child: Center(child: Text('$id', style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold)))),
              title: Text(title, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 24, color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: textColor.withValues(alpha:0.6))),
              trailing: Obx(() {
                if (audioController.isDownloading.value && audioController.downloadingSurahId.value == id) {
                  return IconButton(
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                            width: 28, height: 28,
                            child: CircularProgressIndicator(value: audioController.downloadProgress.value, color: goldColor, strokeWidth: 2.5)
                        ),
                        const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                      ],
                    ),
                    onPressed: () => audioController.cancelDownload(),
                    tooltip: "روڪيو (Stop)",
                  );
                } else if (_downloadedSurahs.contains(id)) {
                  // ✨ FIX: Changed from Green Tick to a respectful "Remove" button
                  return IconButton(
                      icon: Icon(Icons.highlight_remove_rounded, color: Colors.redAccent.withValues(alpha:0.8), size: 28),
                      onPressed: () => _showDeleteConfirm(id, bgColor, textColor, goldColor),
                      tooltip: "آڊيو ختم ڪريو"
                  );
                } else {
                  return IconButton(
                      icon: Icon(Icons.cloud_download_outlined, color: goldColor.withValues(alpha:0.8), size: 28),
                      onPressed: () => _handleDownload(id, totalAyahs),
                      tooltip: "ڊائونلوڊ ڪريو"
                  );
                }
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJuzCard({required int id, required String title, required String subtitle, required Color cardColor, required Color textColor, required Color goldColor, required bool isDark, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.transparent), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16), onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: Container(width: 45, height: 45, decoration: BoxDecoration(color: goldColor.withValues(alpha:0.1), shape: BoxShape.circle, border: Border.all(color: goldColor.withValues(alpha:0.3))), child: Center(child: Text('$id', style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold)))),
              title: Text(title, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 24, color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: textColor.withValues(alpha:0.6))),
              // ✨ FIX: Added Directionality to force the arrow to point Left (<)
              trailing: Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: goldColor.withValues(alpha:0.5)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}