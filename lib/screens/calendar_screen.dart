import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hijri/hijri_calendar.dart';
import '../controllers/settings_controller.dart';
import '../database/db_helper.dart';
import '../utils/app_colors.dart'; // ✨ IMPORTING APP COLORS

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _jafariEvents = {};

  final List<String> _hijriMonths = [
    '', 'محرم', 'صفر', 'ربيع الاول', 'ربيع الثاني', 'جمادي الاول', 'جمادي الثاني',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذوالقعده', 'ذوالحجه'
  ];

  final List<String> _gregorianMonths = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadEventsFromDB();
  }

  Future<void> _loadEventsFromDB() async {
    try {
      final data = await DBHelper.getAllCalendarEvents();
      Map<String, List<Map<String, dynamic>>> parsedEvents = {};

      for (var row in data) {
        String key = '${row['hijri_month']}-${row['hijri_day']}';
        if (parsedEvents[key] == null) {
          parsedEvents[key] = [];
        }
        parsedEvents[key]!.add(row);
      }

      if (mounted) {
        setState(() {
          _jafariEvents = parsedEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading Database: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  HijriCalendar _getHijriDate(DateTime date) {
    try {
      final settings = Get.find<SettingsController>();
      DateTime adjustedDate = date.add(Duration(days: settings.hijriAdjustment.value));
      return HijriCalendar.fromDate(adjustedDate);
    } catch (e) {
      return HijriCalendar.now();
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    HijriCalendar hijri = _getHijriDate(day);
    String key = '${hijri.hMonth}-${hijri.hDay}';
    return _jafariEvents[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = Get.find<SettingsController>();

    return Obx(() {
      DateTime activeDate = _selectedDay ?? _focusedDay;
      HijriCalendar currentHijri = _getHijriDate(activeDate);
      List<Map<String, dynamic>> todayEvents = _getEventsForDay(activeDate);

      return Scaffold(
        backgroundColor: AppColors.background, // ✨ CLEANER CODE
        appBar: AppBar(
          toolbarHeight: 80,
          title: const Text('اسلامي ڪئلينڊر', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 32, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.gold, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.gold))
            : SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.gold.withValues(alpha:0.2), width: 1.5),
                  boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha:Get.isDarkMode ? 0.05 : 0.08), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${currentHijri.hDay} ${_hijriMonths[currentHijri.hMonth]}',
                          style: TextStyle(fontFamily: 'MBLateefi', fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.gold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${currentHijri.hYear} هجري',
                          style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, color: AppColors.text.withValues(alpha:0.7)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha:0.1), shape: BoxShape.circle),
                      child: Icon(Icons.auto_awesome_rounded, size: 36, color: AppColors.gold),
                    ),
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.only(bottom: 20, top: 10, left: 8, right: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Get.isDarkMode ? Colors.white.withValues(alpha:0.05) : Colors.black.withValues(alpha:0.03)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:Get.isDarkMode ? 0.2 : 0.03), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: TableCalendar(
                    key: ValueKey(settings.hijriAdjustment.value),
                    firstDay: DateTime.utc(1900, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    availableGestures: AvailableGestures.horizontalSwipe,

                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },

                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      headerPadding: const EdgeInsets.symmetric(vertical: 16),
                      leftChevronIcon: Icon(Icons.chevron_left_rounded, color: AppColors.gold, size: 32),
                      rightChevronIcon: Icon(Icons.chevron_right_rounded, color: AppColors.gold, size: 32),
                    ),

                    rowHeight: 70,
                    daysOfWeekHeight: 30,

                    calendarBuilders: CalendarBuilders(
                      headerTitleBuilder: (context, day) {
                        String engMonth = _gregorianMonths[day.month];
                        String year = day.year.toString();

                        DateTime firstDay = DateTime(day.year, day.month, 1);
                        DateTime lastDay = DateTime(day.year, day.month + 1, 0);

                        HijriCalendar hijriFirst = _getHijriDate(firstDay);
                        HijriCalendar hijriLast = _getHijriDate(lastDay);

                        String hijriText = hijriFirst.hMonth == hijriLast.hMonth
                            ? _hijriMonths[hijriFirst.hMonth]
                            : "${_hijriMonths[hijriFirst.hMonth]} / ${_hijriMonths[hijriLast.hMonth]}";

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "$engMonth $year",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha:0.7), letterSpacing: 1.2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hijriText,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'MBLateefi', fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.gold),
                            ),
                          ],
                        );
                      },

                      dowBuilder: (context, day) {
                        String weekDayString = _weekDays[day.weekday - 1];

                        return Center(
                          child: Text(
                            weekDayString,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text.withValues(alpha:0.5)),
                          ),
                        );
                      },

                      defaultBuilder: (context, day, focusedDay) => _buildCleanCell(day, AppColors.text, false, false, AppColors.gold),
                      todayBuilder: (context, day, focusedDay) => _buildCleanCell(day, AppColors.text, true, false, AppColors.gold),
                      selectedBuilder: (context, day, focusedDay) => _buildCleanCell(day, AppColors.text, false, true, AppColors.gold),
                      outsideBuilder: (context, day, focusedDay) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('اهم واقعا', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text)),
                      const SizedBox(height: 20),

                      if (todayEvents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 40),
                          child: Center(child: Text('اڄ ڪو خاص واقعو ناهي', style: TextStyle(fontFamily: 'MBLateefi', fontSize: 22, color: AppColors.text.withValues(alpha:0.4)))),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: todayEvents.length,
                          itemBuilder: (context, index) {
                            final event = todayEvents[index];
                            final title = event['title']?.toString().trim() ?? '';
                            final description = event['description']?.toString().trim() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.gold.withValues(alpha:0.25), width: 1.5),
                                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha:Get.isDarkMode ? 0.05 : 0.08), blurRadius: 15, offset: const Offset(0, 6))],
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 8,
                                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: const BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24))),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(title, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.text, height: 1.3)),
                                            if (description.isNotEmpty && description != 'null') ...[
                                              const SizedBox(height: 12),
                                              Text(description, textAlign: TextAlign.justify, style: TextStyle(fontFamily: 'MBLateefi', fontSize: 20, color: AppColors.text.withValues(alpha:0.85), height: 1.8)),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCleanCell(DateTime day, Color baseTextColor, bool isToday, bool isSelected, Color goldColor) {
    HijriCalendar hijri = _getHijriDate(day);
    Color dayTextColor = isSelected ? Colors.white : baseTextColor;

    String key = '${hijri.hMonth}-${hijri.hDay}';
    bool hasEvent = _jafariEvents.containsKey(key);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? goldColor : (isToday ? goldColor.withValues(alpha:0.15) : Colors.transparent),
        borderRadius: BorderRadius.circular(16),
        border: isToday && !isSelected ? Border.all(color: goldColor.withValues(alpha:0.5), width: 1.5) : null,
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
              child: Text('${hijri.hDay}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white.withValues(alpha:0.9) : goldColor)),
            ),
          ),
          Center(child: Text('${day.day}', style: TextStyle(fontSize: 20, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: dayTextColor))),
          if (hasEvent)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(width: 7, height: 7, decoration: BoxDecoration(color: isSelected ? Colors.white : goldColor, shape: BoxShape.circle)),
              ),
            ),
        ],
      ),
    );
  }
}