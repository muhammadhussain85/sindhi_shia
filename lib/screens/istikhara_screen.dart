import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart'; // ✅ Added Fluttertoast for safe popups
import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/app_colors.dart';

enum IstikharaState { preparation, loading, revealed }

class IstikharaScreen extends StatefulWidget {
  const IstikharaScreen({super.key});

  @override
  State<IstikharaScreen> createState() => _IstikharaScreenState();
}

class _IstikharaScreenState extends State<IstikharaScreen> {
  IstikharaState _currentState = IstikharaState.preparation;
  Map<String, dynamic>? _resultData;

  Future<void> _performIstikhara() async {
    setState(() => _currentState = IstikharaState.loading);

    try {
      final data = await DBHelper.getRandomIstikhara();
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        setState(() {
          _resultData = data;
          _currentState = IstikharaState.revealed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currentState = IstikharaState.preparation);
        // ✅ Safe context-free error message
        Fluttertoast.showToast(
          msg: "ڊيٽابيس نه پڙهي سگهيو: $e",
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
        );
      }
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1: return const Color(0xFF10B981);
      case 2: return const Color(0xFFFFEA00);
      case 3: return const Color(0xFFEF4444);
      default: return AppColors.gold;
    }
  }

  // ✅ CRITICAL FIX: Context-Free Clipboard Notification
  void _copyToClipboard(String text, Color accentColor) {
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(
      msg: "ڪاپي ٿي ويو (Copied)",
      backgroundColor: accentColor,
      textColor: Colors.white,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 85,
          title: const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('استخاره', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold, height: 1.3)),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _buildCurrentState(),
          ),
        ),
      );
    });
  }

  Widget _buildCurrentState() {
    switch (_currentState) {
      case IstikharaState.preparation:
        return _buildPreparationScreen();
      case IstikharaState.loading:
        return _buildLoadingScreen();
      case IstikharaState.revealed:
        return _buildRevealScreen();
    }
  }

  Widget _buildBulletPoint(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: fontSize * 0.5),
            child: Icon(Icons.circle, color: AppColors.gold, size: 8),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.justify,
              style: TextStyle(fontFamily: 'MBLateefi', fontSize: fontSize, color: AppColors.text.withValues(alpha:0.9), height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationScreen() {
    final settings = Get.find<SettingsController>();
    final double textScale = settings.sindhiFontSize.value;
    final bool isDark = settings.isDarkMode.value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.gold.withValues(alpha:0.3), width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 28),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('ضروري ڄاڻ', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.gold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ڪنهن ڪم کي ڪرڻ لاءِ ضروري آهي ته پهرين سوچ ويچار سان صحيح رستو چونڊيو وڃي، ۽ ان کان پوءِ تجربيڪار ماڻهن سان صلاح مشورو ڪيو وڃي؛ جيڪڏهن ان سان به ڪو نتيجو حاصل نه ٿئي ته پوءِ استخارو ڪري سگهجي ٿو. ان سان گڏ، قرآن سان فال ڪڍي ڪنهن شخص يا ڪم جي مستقبل بابت ڄاڻ حاصل ڪرڻ جائز ناهي.',
                    textAlign: TextAlign.justify,
                    style: TextStyle(fontFamily: 'MBLateefi', fontSize: textScale, color: AppColors.text.withValues(alpha:0.85), height: 1.8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.transparent),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.format_list_bulleted_rounded, color: AppColors.gold, size: 28),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('استخاري جو طريقو', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildBulletPoint('نيت ڪريو، ٽي ڀيرا سورت اخلاص جي تلاوت ڪريو، ٽي ڀيرا صلوات پڙھي، ھيٺين دعا پڙھو ۽ بٽڻ تي ڪلڪ ڪريو.', textScale),

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha:0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold.withValues(alpha:0.2)),
                    ),
                    child: Text(
                      'اَللّهُمَّ اِنّى تَفَأَّلْتُ بِكِتابِكَ، وَ تَوَكَّلْتُ عَلَیْكَ، فَاَرِنى مِنْ كِتابِكَ ما هُوَ مَكْتُومٌ مِنْ سِرِّكَ الْمَكْنُونِ فـى غَیْبِـكَ',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: 'Amiri', fontSize: settings.arabicFontSize.value, color: AppColors.text, height: 2.0),
                    ),
                  ),

                  _buildBulletPoint('صفحي جي هيٺان موجود استخاري واري بٽڻ کي دٻايو ته جيئن توهان لاءِ هڪ آيت چونڊي وڃي ۽ ان آيت بابت آيت الله مڪارم شيرازي مد ظلہ جي رائي مطابق نتيجو ڏيکاريو وڃي. ان کان علاوه، هن سافٽويئر ۾ استخاري جي نتيجي کي شيئر ڪرڻ جي سهولت به موجود آهي.', textScale),
                ],
              ),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              onPressed: _performIstikhara,
              child: const Text('استخاره ڏسو', style: TextStyle(fontFamily: 'MBLateefi', color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 80, height: 80, child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 6)),
          const SizedBox(height: 32),
          Text('استخاره ڪيو پيو وڃي...', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 24, color: AppColors.text.withValues(alpha:0.8))),
        ],
      ),
    );
  }

  Widget _buildRevealScreen() {
    if (_resultData == null) return const SizedBox();

    final settings = Get.find<SettingsController>();
    final bool isDark = settings.isDarkMode.value;

    final result = _resultData!['result'] ?? '';
    final arabicText = _resultData!['text'] ?? '';
    final sindhiText = _resultData!['translation'] ?? '';
    final surahName = _resultData!['SurahName'] ?? '';
    final ayahNum = _resultData!['shAyah']?.toString() ?? '';

    int statusVal = 2;
    if (_resultData!['status'] != null) {
      statusVal = int.tryParse(_resultData!['status'].toString()) ?? 2;
    }
    final Color dynamicColor = _getStatusColor(statusVal);

    const String appLink = "📱 ڊائونلوڊ (Sindhi Shia Toolkit):\nhttps://play.google.com/store/apps/details?id=com.tasneemacademy.sindhishiatoolkit";
    final String shareText = '''استخاري جو نتيجو: $result\n\n$arabicText\n\n$sindhiText\n\n📖 قرآن مجيد (سورة $surahName — آيت $ayahNum)\n\n$appLink''';

    return Center(
      key: const ValueKey('reveal'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 28, left: 28, right: 28, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: dynamicColor.withValues(alpha:0.6), width: 2),
                boxShadow: [BoxShadow(color: dynamicColor.withValues(alpha:isDark ? 0.2 : 0.3), blurRadius: 40, spreadRadius: 5)],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      color: dynamicColor.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: dynamicColor.withValues(alpha:0.5)),
                    ),
                    child: Text(result, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: dynamicColor, height: 1.3)),
                  ),
                  const SizedBox(height: 24),
                  Text(arabicText, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Amiri', fontSize: settings.arabicFontSize.value + 4, color: AppColors.text, height: 2.2)),
                  const SizedBox(height: 24),
                  Divider(color: dynamicColor.withValues(alpha:0.3), thickness: 1, indent: 40, endIndent: 40),
                  const SizedBox(height: 20),
                  Text(sindhiText, textAlign: TextAlign.center, textDirection: TextDirection.rtl, strutStyle: StrutStyle(fontFamily: 'SindhiFont', fontSize: settings.sindhiFontSize.value, height: 1.8), style: TextStyle(fontFamily: 'MBLateefi', fontSize: settings.sindhiFontSize.value, color: AppColors.text.withValues(alpha:0.85), height: 1.8)),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: dynamicColor.withValues(alpha:0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('سورة $surahName — آيت $ayahNum', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: dynamicColor, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 20),
                  Divider(color: AppColors.text.withValues(alpha:0.1), thickness: 1),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy_rounded, color: AppColors.text.withValues(alpha:0.5), size: 22),
                        onPressed: () => _copyToClipboard(shareText, dynamicColor),
                        tooltip: 'ڪاپي ڪريو',
                      ),
                      Container(width: 1, height: 20, color: AppColors.text.withValues(alpha:0.1), margin: const EdgeInsets.symmetric(horizontal: 16)),
                      IconButton(
                        icon: Icon(Icons.ios_share_rounded, color: AppColors.text.withValues(alpha:0.5), size: 22),
                        onPressed: () => Share.share(shareText),
                        tooltip: 'شيئر ڪريو',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.text.withValues(alpha:0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('واپس وڃو', style: TextStyle(fontFamily: 'MBLateefi', color: AppColors.text, fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _performIstikhara,
                    child: const Text('ٻيهر استخاره', style: TextStyle(fontFamily: 'MBLateefi', color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}