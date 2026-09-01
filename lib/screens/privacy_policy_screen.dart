import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 80,
          title: const Text('پرائيويسي پاليسي', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha:0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.privacy_tip_outlined, size: 60, color: AppColors.gold),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'توهان جي پرائيويسي اسان لاءِ اهم آهي.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
                const SizedBox(height: 10),
                Text(
                  'هيٺ ڄاڻايل پرائيويسي پاليسي ۾ اهو واضح ڪيو ويو آهي ته "Sindhi Shia Toolkit" توهان جي ڪهڙي ڊيٽا استعمال ڪري ٿي ۽ ان کي ڪيئن محفوظ رکي ٿي.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'MBLateefi', fontSize: 18, color: AppColors.text.withValues(alpha:0.7), height: 1.6),
                ),
                const SizedBox(height: 30),

                _buildPolicyCard(
                  title: 'ذاتي معلومات (Personal Data)',
                  icon: Icons.person_off_outlined,
                  content: 'هي ايپليڪيشن توهان کان ڪنهن به قسم جي ذاتي معلومات (جيئن نالو، اي ميل، يا فون نمبر) نه ٿي گهري. هن ايپ کي استعمال ڪرڻ لاءِ ڪنهن به اڪائونٽ ٺاهڻ يا لاگ ان ڪرڻ جي ضرورت ناهي.',
                ),

                _buildPolicyCard(
                  title: 'مقام جي ڄاڻ (Location Data)',
                  icon: Icons.location_on_outlined,
                  content: 'توهان جي شهر مطابق نماز ۽ آذان جي درست وقتن جو اندازو لڳائڻ لاءِ هي ايپ توهان جي مقام (GPS/Location) تائين رسائي حاصل ڪري ٿي. اهو سمورو عمل صرف توهان جي موبائل اندر ٿئي ٿو ۽ توهان جي لوڪيشن ڪنهن به ٻئي سرور تي محفوظ يا شيئر نه ڪئي ويندي آهي.',
                ),

                _buildPolicyCard(
                  title: 'مقامي اسٽوريج (Local Storage)',
                  icon: Icons.save_alt_rounded,
                  content: 'توهان جون سيٽنگون، بڪ مارڪس، ۽ پڙهڻ جي هسٽري (Last Read) صرف ۽ صرف توهان جي پنهنجي ڊوائيس (موبائل) اندر محفوظ ڪئي وڃي ٿي. ان ڊيٽا تائين اسان جي يا ڪنهن ٽين ڌر (Third Party) جي ڪا به رسائي ناهي.',
                ),

                _buildPolicyCard(
                  title: 'انٽرنيٽ جو استعمال (Internet Usage)',
                  icon: Icons.wifi_rounded,
                  content: 'هيءَ هڪ مڪمل آف لائن ايپليڪيشن آهي. انٽرنيٽ جو استعمال صرف ان وقت ٿيندو آهي جڏهن توهان قرآن مجيد جي آڊيو (تلاوت) ڊائونلوڊ ڪندا آهيو. ان کان علاوه ڪنهن به قسم جي ڊيٽا انٽرنيٽ تي منتقل نه ٿيندي آهي.',
                ),

                _buildPolicyCard(
                  title: 'اشتهار (Advertisements)',
                  icon: Icons.block_rounded,
                  content: 'هن ايپ ۾ ڪي به اشتهار (Ads) شامل ناهن، ۽ نه ئي ڪنهن اشتهاري ڪمپني سان توهان جو ڪو به ڊيٽا شيئر ڪيو وڃي ٿو. هيءَ ايپ مڪمل طور تي ديني خدمت لاءِ ٺاهي وئي آهي.',
                ),

                const SizedBox(height: 30),
                Center(
                  child: Text(
                    'آخري اپڊيٽ: اپريل 2026',
                    style: TextStyle(fontFamily: 'MBLateefi', fontSize: 16, color: AppColors.text.withValues(alpha:0.5)),
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

  Widget _buildPolicyCard({required String title, required IconData icon, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Get.isDarkMode ? Colors.white.withValues(alpha:0.05) : Colors.black.withValues(alpha:0.03)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:Get.isDarkMode ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontFamily: 'MBLateefi', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            textAlign: TextAlign.justify,
            style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: AppColors.text.withValues(alpha:0.85), height: 1.7),
          ),
        ],
      ),
    );
  }
}