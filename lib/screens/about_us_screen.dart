import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../controllers/settings_controller.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'ورجن ${info.version}');
    });
  }

  // THE MAGIC LAUNCHER FUNCTION
  Future<void> _launch(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      Get.snackbar(
        "ايرر",
        "ايپ کولڻ ۾ مسئلو آيو",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  // ✨ NEW: COPY TO CLIPBOARD HELPER
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      "ڪاپي ٿي ويو!",
      "بئنڪ جي تفصيل ڪاپي ڪئي وئي آهي",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981), // Green success color
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();

    return Obx(() {
      final isDark = settings.isDarkMode.value;
      final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFFDFBF7);
      final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
      final textColor = isDark ? const Color(0xFFF3F4F6) : const Color(0xFF1A202C);
      final goldColor = isDark ? const Color(0xFFD4AF37) : const Color(0xFFC5A059);

      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          toolbarHeight: 80,
          title: const Text('اسان جي باري ۾', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: goldColor, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // App Logo & Version
                Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cardColor,
                    border: Border.all(color: goldColor.withValues(alpha:0.3), width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Image.asset(
                        'assets/images/tasneemlogo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.mosque_rounded, size: 60, color: goldColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Sindhi Shia Toolkit', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold, color: goldColor), textDirection: TextDirection.ltr),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: goldColor.withValues(alpha:0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _version ?? 'ورجن ...',
                    style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: textColor.withValues(alpha:0.8)),
                  ),
                ),
                const SizedBox(height: 40),

                // CARD 1: Introduction
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.black.withValues(alpha:0.03)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: goldColor, size: 28),
                          const SizedBox(width: 12),
                          Text('تعارف', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'هي ايپليڪيشن خاص طور تي سنڌي ڳالهائيندڙ شيعا مومنين لاءِ ٺاهي وئي آهي، ته جيئن اهي پنهنجي ديني ضرورتن کي آساني سان پورو ڪري سگهن. هن ايپ ۾ قرآن پاڪ، نهج البلاغه، صحيفه سجاديه، دعائون، زيارتون ۽ نماز جا درست وقت شامل آهن.\n\n'
                            'ھن ايپ ۾ قرآن مجيد جو پھريون ترجمو سائين مولانا سڪندر علي لطفي جو جڏھن تہ ٻيو ترجمو سائين قاري امان اللہ ڪربلائي جو آھي. نھج البلاغو جو ترجمو سائين قاري امان الله ڪربلائي ۽ ميرزا عباس علي بيگ جو آھي.\n\n'
                            'صحيفہ سجاديہ جو سنڌي ترجمو سائين مشتاق مسرور باريچو جو آھي.\n'
                            'احاديث جو ترجمو مولانا ڊاڪٽر غلام قاسم تسنيمي جو آھي.\n\n'
                            'جڏھن تہ دعائن ۽ زيارتن جو ترجمو سائين اخلاق احمد اخلاق، مولانا نظير احمد بھشتي ۽ مولانا ساجد علي سبحاني جو آھي.\n'
                            'قرآني استخاري جو نتيجو آيت اللہ ناصر مڪارم شيرازي مد ظلہ جي نظر مطابق آھي.\n\n'
                            'آخر ۾ دعائن جي التماس سان گڏ تعاون جي بہ گذارش ڪجي ٿي، گڏوگڏ جيڪڏھن ڪٿي ڪا غلطي نظر اچي تہ ان جي نشاندھي جي بہ درخواست ڪئي وڃي ٿي.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: textColor.withValues(alpha:0.85), height: 1.8),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: goldColor.withValues(alpha:0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: goldColor.withValues(alpha:0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 50,
                              decoration: BoxDecoration(color: goldColor, borderRadius: BorderRadius.circular(10)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'پاران: مولانا ڊاڪٽر غلام قاسم تسنيمي\nباني ادارہ تسنيم القرآن',
                                style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, fontWeight: FontWeight.bold, color: goldColor, height: 1.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // CARD 2: Contact Us
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.black.withValues(alpha:0.03)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.contact_support_outlined, color: goldColor, size: 28),
                          const SizedBox(width: 12),
                          Text('رابطو ڪريو', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'جيڪڏهن توهان کي ڪا غلطي نظر اچي يا ڪو مشورو ڏيڻ چاهيو ٿا ته اسان سان رابطو ڪريو:',
                        textAlign: TextAlign.justify,
                        style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: textColor.withValues(alpha:0.85), height: 1.6),
                      ),
                      const SizedBox(height: 16),

                      _buildContactTile(
                        Icons.email_outlined,
                        'اي ميل (Email)',
                        'tasneemulquran@gmail.com',
                        isDark, bgColor, textColor, goldColor,
                            () => _launch('mailto:tasneemulquran@gmail.com'),
                      ),
                      const SizedBox(height: 10),

                      _buildContactTile(
                        Icons.chat_bubble_outline_rounded,
                        'واٽس ايپ (WhatsApp)',
                        '+92 348 3971769',
                        isDark, bgColor, textColor, goldColor,
                            () => _launch('https://wa.me/923483971769'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ✨ CARD 3: UPDATED Bank Details (Support Us)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.black.withValues(alpha:0.03)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:isDark ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_rounded, color: goldColor, size: 28),
                          const SizedBox(width: 12),
                          Text('تعاون ڪريو (Support Us)', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'هن ديني ڪم کي جاري رکڻ ۽ وڌيڪ بهتر بڻائڻ لاءِ توهان پنهنجو مالي تعاون پڻ ڪري سگهو ٿا.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: textColor.withValues(alpha:0.85), height: 1.6),
                      ),
                      const SizedBox(height: 20),

                      // Bank Details Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: isDark ? bgColor : Colors.grey.withValues(alpha:0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: goldColor.withValues(alpha:0.15))
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اڪائونٽ جو نالو: Tasneem ul Quran',
                              style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Meezan Bank',
                              style: TextStyle(fontSize: 16, color: textColor.withValues(alpha:0.7)),
                              textDirection: TextDirection.ltr,
                            ),
                            Divider(color: goldColor.withValues(alpha:0.15), height: 30, thickness: 1),

                            // ✨ Safely built copyable rows
                            _buildCopyableBankRow(
                              label: 'IBAN:',
                              displayValue: 'PK09 MEZN 0099 7401 0737 0677',
                              copyValue: 'PK09MEZN0099740107370677',
                              textColor: textColor,
                              goldColor: goldColor,
                            ),
                            const SizedBox(height: 16),
                            _buildCopyableBankRow(
                              label: 'اڪائونٽ نمبر (Account No):',
                              displayValue: '9974 0107370677',
                              copyValue: '99740107370677',
                              textColor: textColor,
                              goldColor: goldColor,
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildContactTile(IconData icon, String title, String value, bool isDark, Color bgColor, Color textColor, Color goldColor, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: goldColor.withValues(alpha:0.2),
        highlightColor: goldColor.withValues(alpha:0.1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? bgColor : Colors.grey.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: goldColor.withValues(alpha:0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, color: goldColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: textColor.withValues(alpha:0.6))),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 1.0), textDirection: TextDirection.ltr),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, color: goldColor.withValues(alpha:0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ✨ NEW: Robust row layout that prevents horizontal overflow entirely
  Widget _buildCopyableBankRow({
    required String label,
    required String displayValue,
    required String copyValue,
    required Color textColor,
    required Color goldColor
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Using Expanded here forces the text to wrap or scale instead of pushing off-screen
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  label,
                  style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: textColor.withValues(alpha:0.7))
              ),
              const SizedBox(height: 4),
              SelectableText(
                displayValue,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: goldColor, letterSpacing: 1.0),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: goldColor.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => _copyToClipboard(copyValue),
            icon: Icon(Icons.copy_rounded, color: goldColor, size: 22),
            tooltip: 'ڪاپي ڪريو', // Copy Tooltip
          ),
        ),
      ],
    );
  }
}