import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/app_colors.dart'; // ✅ Imported AppColors
import 'sections_screen.dart';

class FehrestScreen extends StatelessWidget {
  const FehrestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Completely removed local color variables!
    return Obx(() {
      return Scaffold(
        backgroundColor: AppColors.parchmentBackground, // ✅ Special reading background
        appBar: AppBar(
          toolbarHeight: 85,
          title: const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('صحيڤه سجاديه', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold, height: 1.3)),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text, // ✅
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 20), // ✅
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: DBHelper.getChapters(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: AppColors.gold)); // ✅
            final chapters = snapshot.data ?? [];
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card, // ✅
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold.withValues(alpha:0.1)), // ✅
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SectionsScreen(chapterId: chapter['ID'], chapterTitle: chapter['title']))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 45, height: 45,
                        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha:0.1), shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withValues(alpha:0.2))), // ✅
                        child: Center(child: Text('${index + 1}', style: TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold))), // ✅
                      ),
                      title: Text(chapter['title'], textAlign: TextAlign.right, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 24, color: AppColors.text, height: 1.5)), // ✅
                      trailing: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold.withValues(alpha:0.5), size: 16), // ✅
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