import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../utils/app_colors.dart'; // ✨ IMPORT CENTRALIZED COLORS

// IMPORT THE READING SCREENS SO WE CAN NAVIGATE TO THEM
import 'quran_reading_screen.dart';
import 'reading_screen.dart';
import 'nahjul_reading_screen.dart';
import 'ziyarat_reading_screen.dart';
import 'ahadith_reading_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  // ✨ UPGRADED: Extracts the exact Verse/Paragraph Index from the uniqueId and passes it!
  void _navigateToBookmark(BuildContext context, Map<String, dynamic> bookmark) {
    String type = bookmark['bookType'];
    String uniqueId = bookmark['uniqueId'];
    String title = bookmark['title'] ?? '';

    List<String> idParts = uniqueId.split('_');

    if (type == 'quran' && idParts.length >= 2) {
      int surahId = int.tryParse(idParts[1]) ?? 1;
      int verseNum = idParts.length >= 3 ? (int.tryParse(idParts[2]) ?? 1) : 1;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuranReadingScreen(fetchId: surahId, title: title.split(' - ')[0], isJuzMode: false, initialScrollVerse: verseNum)));

    } else if (type == 'sahifa' && idParts.length >= 2) {
      int sectionId = int.tryParse(idParts[1]) ?? 1;
      int index = idParts.length >= 3 ? (int.tryParse(idParts[2]) ?? 0) : 0;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReadingScreen(sectionId: sectionId, sectionTitle: title.split(' - ')[0], initialScrollIndex: index)));

    } else if (type == 'nahjul' && idParts.length >= 2) {
      int secRowId = int.tryParse(idParts[1]) ?? 1;
      int index = idParts.length >= 3 ? (int.tryParse(idParts[2]) ?? 0) : 0;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => NahjulReadingScreen(secRowId: secRowId, title: title.split(' - ')[0], initialScrollIndex: index)));

    } else if (type == 'ziyarat' && idParts.length >= 2) {
      int sectionId = int.tryParse(idParts[1]) ?? 1;
      int index = idParts.length >= 3 ? (int.tryParse(idParts[2]) ?? 0) : 0;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ZiyaratReadingScreen(sectionId: sectionId, sectionTitle: title.split(' - ')[0], initialScrollIndex: index)));

    } else if (type == 'hadith' && idParts.length >= 1) {
      int categoryId = int.tryParse(idParts[0]) ?? 1;
      int index = idParts.length >= 2 ? (int.tryParse(idParts[1]) ?? 0) : 0;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AhadithReadingScreen(categoryId: categoryId, categoryTitle: title.split(' - ')[0], initialScrollIndex: index)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = Get.find<SettingsController>();

    return Obx(() {
      final isDark = settings.isDarkMode.value;
      final bookmarks = settings.bookmarks;

      return Scaffold(
        backgroundColor: AppColors.background, // ✨ CLEANED UP
        appBar: AppBar(
          toolbarHeight: 80,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text("محفوظ ڪيل", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.text)),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 22),
            onPressed: () => Get.back(),
          ),
        ),
        body: bookmarks.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border_rounded, size: 80, color: AppColors.gold.withValues(alpha:0.3)),
              const SizedBox(height: 20),
              Text("ڪو به بڪ مارڪ ناهي", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 24, color: AppColors.text.withValues(alpha:0.5))),
            ],
          ),
        )
            : ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final mark = bookmarks[index];
            final String type = mark['bookType'];
            final String originalTitle = mark['title'] ?? 'نامعلوم';
            final String arabicText = mark['arabic'] ?? '';
            final String transText = mark['translation'] ?? '';
            final String uniqueId = mark['uniqueId'];

            final String nickname = mark['nickname'] ?? '';
            final String note = mark['note'] ?? '';

            String tag = 'صحيفه';
            if (type == 'quran') tag = 'القرآن';
            if (type == 'nahjul') tag = 'نهج البلاغه';
            if (type == 'hadith') tag = 'احاديث';
            if (type == 'ziyarat') tag = 'زيارات ۽ دعائون';

            final String displayTitle = nickname.trim().isNotEmpty ? nickname : originalTitle;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withValues(alpha:0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ExpansionTile(
                shape: const Border(),
                iconColor: AppColors.gold,
                collapsedIconColor: AppColors.gold.withValues(alpha:0.6),
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha:0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(tag, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 14, color: AppColors.gold, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text, height: 1.4)),
                            if (nickname.trim().isNotEmpty)
                              Text(originalTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 14, color: AppColors.text.withValues(alpha:0.5))),
                          ],
                        )
                    ),
                  ],
                ),
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _navigateToBookmark(context, mark),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Divider(color: AppColors.gold.withValues(alpha:0.1)),
                            const SizedBox(height: 10),

                            if (arabicText.isNotEmpty)
                              Text(arabicText, textAlign: TextAlign.justify, textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Amiri', fontSize: 24, color: isDark ? Colors.white : const Color(0xFF1B4332), height: 1.8)),

                            if (arabicText.isNotEmpty && transText.isNotEmpty)
                              Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Divider(color: AppColors.gold.withValues(alpha:0.15))),

                            if (transText.isNotEmpty)
                              Text(
                                  transText,
                                  textAlign: TextAlign.justify,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: AppColors.text.withValues(alpha:0.8), height: 1.6)
                              ),

                            if (note.trim().isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha:0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.gold.withValues(alpha:0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.edit_note_rounded, color: AppColors.gold, size: 20),
                                        const SizedBox(width: 8),
                                        Text("منهنجو نوٽ:", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: AppColors.gold, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(note, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: AppColors.text.withValues(alpha:0.9), height: 1.5)),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text("پڙهڻ لاءِ ڪلڪ ڪريو ", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: AppColors.gold, fontWeight: FontWeight.bold)),
                                Icon(Icons.arrow_forward_rounded, color: AppColors.gold, size: 18),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                  onPressed: () => settings.toggleBookmark(type, uniqueId, originalTitle, arabicText, transText),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  label: const Text("ڊليٽ", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16)),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    _showEditDialog(context, settings, type, uniqueId, nickname, note);
                                  },
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  label: const Text("نوٽ لکو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            )
                          ],
                        ),
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

  void _showEditDialog(BuildContext context, SettingsController settings, String type, String uniqueId, String currentNickname, String currentNote) {
    final nicknameCtrl = TextEditingController(text: currentNickname);
    final noteCtrl = TextEditingController(text: currentNote);

    Get.dialog(
      Dialog(
        backgroundColor: AppColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.edit_note_rounded, size: 40, color: AppColors.gold),
                const SizedBox(height: 10),
                Text("تفصيل تبديل ڪريو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text), textAlign: TextAlign.center),
                const SizedBox(height: 25),

                TextField(
                  controller: nicknameCtrl,
                  style: TextStyle(color: AppColors.text, fontFamily: 'MBLateefi', fontSize: 18),
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'نئون نالو',
                    labelStyle: TextStyle(color: AppColors.gold.withValues(alpha:0.8), fontFamily: 'MBLateefi', fontSize: 18),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.gold.withValues(alpha:0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.gold, width: 2)),
                  ),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: noteCtrl,
                  maxLines: 4,
                  style: TextStyle(color: AppColors.text, fontFamily: 'MBLateefi', fontSize: 18),
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'نوٽ لکو',
                    labelStyle: TextStyle(color: AppColors.gold.withValues(alpha:0.8), fontFamily: 'MBLateefi', fontSize: 18),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.gold.withValues(alpha:0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.gold, width: 2)),
                  ),
                ),
                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text("رد ڪريو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: AppColors.text.withValues(alpha:0.6))),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        settings.editBookmarkNote(type, uniqueId, nicknameCtrl.text, noteCtrl.text);
                        Get.back();
                      },
                      child: const Text("محفوظ ڪريو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}