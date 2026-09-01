import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/app_colors.dart';
import 'ahadith_reading_screen.dart';

class AhadithIndexScreen extends StatefulWidget {
  const AhadithIndexScreen({super.key});

  @override
  State<AhadithIndexScreen> createState() => _AhadithIndexScreenState();
}

class _AhadithIndexScreenState extends State<AhadithIndexScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await DBHelper.getAhadithCategories();
      setState(() {
        _categories = data;
        _isLoading = false;
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "ڊيٽابيس ايرر: $e",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        backgroundColor: AppColors.parchmentBackground,
        appBar: AppBar(
          title: const Text('احاديث', style: TextStyle(fontFamily: 'MBLateefi', fontWeight: FontWeight.bold, fontSize: 28)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.text,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _categories.isEmpty
            ? Center(
          child: Text(
            "ڪا به ڪيٽيگري نه ملي\n(ڊيٽابيس چيڪ ڪريو)",
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, color: AppColors.text.withValues(alpha:0.5)),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final title = category['title']?.toString() ?? 'نامعلوم';
            final id = category['id'] as int;

            return Card(
              color: AppColors.card,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Get.isDarkMode ? Colors.white.withValues(alpha:0.05) : Colors.transparent)),
              elevation: Get.isDarkMode ? 0 : 2,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(backgroundColor: AppColors.gold.withValues(alpha:0.15), child: Icon(Icons.menu_book_rounded, color: AppColors.gold, size: 20)),
                title: Text(title, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
                trailing: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold.withValues(alpha:0.5), size: 16),
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AhadithReadingScreen(categoryId: id, categoryTitle: title)));
                },
              ),
            );
          },
        ),
      );
    });
  }
}