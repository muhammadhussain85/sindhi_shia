import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/arabic_search_utils.dart';
import '../utils/app_colors.dart';
import 'ziyarat_reading_screen.dart';

class ZiyaratIndexScreen extends StatelessWidget {
  const ZiyaratIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        backgroundColor: AppColors.parchmentBackground,
        appBar: AppBar(
          toolbarHeight: 85,
          title: const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text("زيارات ۽ دعائون", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold, height: 1.3)),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.text,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: DBHelper.getZiyaratChapters(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: AppColors.gold));
            final chaps = snapshot.data ?? [];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: chaps.length,
              itemBuilder: (context, index) {
                final chap = chaps[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withValues(alpha:0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ZiyaratSectionScreen(chapRowId: chap['ID'], title: chap['title'].toString()))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 45, height: 45,
                        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha:0.1), shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withValues(alpha:0.2))),
                        child: Center(child: Text('${index + 1}', style: TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold))),
                      ),
                      title: Text(chap['title'].toString(), textAlign: TextAlign.right, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
                      trailing: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold.withValues(alpha:0.5), size: 16),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    });
  }
}

class ZiyaratSectionScreen extends StatefulWidget {
  final int chapRowId;
  final String title;
  const ZiyaratSectionScreen({super.key, required this.chapRowId, required this.title});

  @override
  State<ZiyaratSectionScreen> createState() => _ZiyaratSectionScreenState();
}

class _ZiyaratSectionScreenState extends State<ZiyaratSectionScreen> {
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
    final data = await DBHelper.getZiyaratSections(widget.chapRowId);
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
    return Obx(() {
      return Scaffold(
        backgroundColor: AppColors.parchmentBackground,
        appBar: AppBar(
          toolbarHeight: 85,
          title: _isSearching
              ? Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(fontFamily: 'MBLateefi', color: AppColors.text, fontSize: 22),
              decoration: InputDecoration(
                hintText: 'عنوان ڳوليو...',
                hintStyle: TextStyle(color: AppColors.text.withValues(alpha:0.5)),
                border: InputBorder.none,
              ),
              onChanged: _onSearchChanged,
            ),
          )
              : Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(widget.title, style: const TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, height: 1.3)),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.text,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 20),
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
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: AppColors.gold, size: 26),
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
            ? Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _filteredSections.isEmpty
            ? Center(child: Text("ڪو به نتيجو نه مليو", style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, color: AppColors.text.withValues(alpha:0.5))))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: _filteredSections.length,
          itemBuilder: (context, index) {
            final section = _filteredSections[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withValues(alpha:0.1)),
              ),
              child: ListTile(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ZiyaratReadingScreen(sectionId: section['ID'], sectionTitle: section['title'].toString()))),
                title: Text(section['title'].toString(), textAlign: TextAlign.right, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, color: AppColors.text)),
                leading: Icon(Icons.mosque_rounded, color: AppColors.gold.withValues(alpha:0.7)),
              ),
            );
          },
        ),
      );
    });
  }
}