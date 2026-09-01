import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/arabic_search_utils.dart'; // Added for smart title searching
import 'reading_screen.dart';

class SectionsScreen extends StatefulWidget {
  final int chapterId;
  final String chapterTitle;

  const SectionsScreen({super.key, required this.chapterId, required this.chapterTitle});

  @override
  State<SectionsScreen> createState() => _SectionsScreenState();
}

class _SectionsScreenState extends State<SectionsScreen> {
  List<Map<String, dynamic>> _allSections = [];
  List<Map<String, dynamic>> _filteredSections = [];
  bool _isLoading = true;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    final data = await DBHelper.getSections(widget.chapterId);
    if (mounted) {
      setState(() {
        _allSections = data;
        _filteredSections = data;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _filteredSections = _allSections);
      return;
    }

    final normalizedQuery = ArabicSearchUtils.normalizeLetters(query).toLowerCase();

    setState(() {
      _filteredSections = _allSections.where((section) {
        final title = ArabicSearchUtils.normalizeLetters(section['title']?.toString() ?? '').toLowerCase();
        return title.contains(normalizedQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = Get.find<SettingsController>();

    return Obx(() {
      final isDark = settings.isDarkMode.value;
      final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF6F3E9);
      final cardColor = isDark ? const Color(0xFF111827) : Colors.white;
      final textColor = isDark ? const Color(0xFFF3F4F6) : const Color(0xFF3D3831);
      final goldColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFFB88A44);

      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          toolbarHeight: 85,
          title: _isSearching
              ? Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(fontFamily: 'MBLateefi', color: textColor, fontSize: 22),
              decoration: InputDecoration(
                hintText: 'عنوان ڳوليو...',
                hintStyle: TextStyle(color: textColor.withValues(alpha:0.5)),
                border: InputBorder.none,
              ),
              onChanged: _onSearchChanged,
            ),
          )
              : Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(widget.chapterTitle, style: const TextStyle(fontFamily: 'MBLateefi', fontSize: 28, fontWeight: FontWeight.bold, height: 1.3)),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: goldColor, size: 20),
            onPressed: () {
              if (_isSearching) {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _filteredSections = _allSections;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              padding: const EdgeInsets.only(right: 16),
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: goldColor, size: 26),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _filteredSections = _allSections;
                  }
                });
              },
            )
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: goldColor))
            : _filteredSections.isEmpty
            ? Center(child: Text("ڪو به نتيجو نه مليو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, color: textColor.withValues(alpha:0.5))))
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          physics: const BouncingScrollPhysics(),
          itemCount: _filteredSections.length,
          itemBuilder: (context, index) {
            final section = _filteredSections[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: goldColor.withValues(alpha:0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReadingScreen(sectionId: section['ID'], sectionTitle: section['title'] ?? 'Section'))),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 45, height: 45,
                    decoration: BoxDecoration(color: goldColor.withValues(alpha:0.1), shape: BoxShape.circle, border: Border.all(color: goldColor.withValues(alpha:0.2))),
                    child: Center(child: Text('${index + 1}', style: TextStyle(color: goldColor, fontSize: 18, fontWeight: FontWeight.bold))),
                  ),
                  title: Text(section['title'] ?? 'Unknown Section', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, color: textColor, height: 1.5)),
                  trailing: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: goldColor.withValues(alpha:0.5), size: 16),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}