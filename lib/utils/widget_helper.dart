import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetHelper {
  static const String _appGroupId = 'com.tasneemacademy.sindhishiatoolkit';

  static Future<void> updatePrayerWidget({
    required double lat,
    required double lng,
    required CalculationParameters params,
    required String cityName,
  }) async {
    try {
      final coords = Coordinates(lat, lng);
      final prayerTimes = PrayerTimes.today(coords, params);
      final now = DateTime.now();

      String name = '---';
      String time = '--:--';

      final Prayer next = prayerTimes.nextPrayer();
      if (next == Prayer.fajr) {
        name = 'فجر';
        time = DateFormat('h:mm a').format(prayerTimes.fajr);
      } else if (next == Prayer.sunrise || next == Prayer.dhuhr) {
        name = 'ظهرين';
        time = DateFormat('h:mm a').format(prayerTimes.dhuhr);
      } else if (next == Prayer.asr || next == Prayer.maghrib) {
        name = 'مغربين';
        time = DateFormat('h:mm a').format(prayerTimes.maghrib);
      } else {
        // After isha — show tomorrow's fajr
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowTimes = PrayerTimes(coords, DateComponents.from(tomorrow), params);
        name = 'فجر';
        time = DateFormat('h:mm a').format(tomorrowTimes.fajr);
      }

      await HomeWidget.saveWidgetData<String>('next_prayer_name', name);
      await HomeWidget.saveWidgetData<String>('next_prayer_time', time);
      await HomeWidget.saveWidgetData<String>('city_name', cityName);
      await HomeWidget.updateWidget(
        androidName: 'PrayerWidgetProvider',
        qualifiedAndroidName: '$_appGroupId.PrayerWidgetProvider',
      );
    } catch (_) {}
  }

  static const List<String> _hijriMonths = [
    'محرم', 'صفر', 'ربيع الاول', 'ربيع الثاني',
    'جمادي الاول', 'جمادي الثاني', 'رجب', 'شعبان',
    'رمضان', 'شوال', 'ذوالقعدة', 'ذوالحجة',
  ];

  static Future<void> updateCalendarWidget({int hijriAdjustment = 0}) async {
    try {
      HijriCalendar.setLocal('ar');
      final today = HijriCalendar.now();
      // Apply user's hijri adjustment
      final adjusted = HijriCalendar()
        ..hYear = today.hYear
        ..hMonth = today.hMonth
        ..hDay = today.hDay + hijriAdjustment;

      final day   = adjusted.hDay.toString();
      final month = _hijriMonths[(adjusted.hMonth - 1).clamp(0, 11)];
      final year  = adjusted.hYear.toString();
      final now   = DateTime.now();
      final greg  = '${now.day}/${now.month}/${now.year}';

      await HomeWidget.saveWidgetData<String>('cal_hijri_day',   day);
      await HomeWidget.saveWidgetData<String>('cal_hijri_month', month);
      await HomeWidget.saveWidgetData<String>('cal_hijri_year',  year);
      await HomeWidget.saveWidgetData<String>('cal_gregorian',   greg);
      await HomeWidget.updateWidget(
        androidName: 'CalendarWidgetProvider',
        qualifiedAndroidName: '$_appGroupId.CalendarWidgetProvider',
      );
    } catch (_) {}
  }

  // Mirrors the defaults in TasbeehScreen — one per rotation slot.
  // Keep in the same order so the widget index matches the in-app list index.
  static const List<Map<String, String>> _widgetZikrList = [
    {
      'title':       'الله أکبر',
      'arabic':      'ٱللَّٰهُ أَكْبَرُ',
      'translation': 'الله وڏو آهي',
    },
    {
      'title':       'الحمد لله',
      'arabic':      'ٱلْحَمْدُ لِلَّٰهِ',
      'translation': 'سڀ ساراهه الله لاءِ آهي',
    },
    {
      'title':       'سبحان الله',
      'arabic':      'سُبْحَانَ ٱللَّٰهِ',
      'translation': 'الله پاڪ آهي',
    },
    {
      'title':       'استغفار',
      'arabic':      'أَسْتَغْفِرُ ٱللَّٰهَ',
      'translation': 'آئون الله کان معافي گھران ٿو',
    },
    {
      'title':       'درود شريف',
      'arabic':      'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَآلِ مُحَمَّدٍ',
      'translation': 'اي الله! محمد ﷺ ۽ آل محمد تي رحمت نازل فرما',
    },
  ];

  /// Picks today's zikr by day-of-year and pushes it to the home screen widget.
  /// Call once on every app launch — the same day always shows the same zikr.
  static Future<void> updateDailyZikrWidget() async {
    try {
      final now = DateTime.now();
      final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
      final index = dayOfYear % _widgetZikrList.length;
      final zikr  = _widgetZikrList[index];

      await HomeWidget.saveWidgetData<String>('daily_zikr_title',       zikr['title']!);
      await HomeWidget.saveWidgetData<String>('daily_zikr_arabic',      zikr['arabic']!);
      await HomeWidget.saveWidgetData<String>('daily_zikr_translation', zikr['translation']!);
      // Saved so the Kotlin tap-intent can embed the index in the deep-link URI.
      await HomeWidget.saveWidgetData<String>('daily_zikr_index',       index.toString());
      await HomeWidget.updateWidget(
        androidName: 'DailyZikrWidget',
        qualifiedAndroidName: '$_appGroupId.DailyZikrWidget',
      );
    } catch (_) {}
  }
}
