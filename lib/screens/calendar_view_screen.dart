import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/gradient_app_bar.dart';
import 'calendar_screen.dart';
import 'weekly_calendar_screen.dart';

class CalendarViewScreen extends StatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  State<CalendarViewScreen> createState() => CalendarViewScreenState();
}

class CalendarViewScreenState extends State<CalendarViewScreen> {
  bool _isWeeklyView = true; // true: 주간, false: 월간
  final GlobalKey<WeeklyCalendarScreenState> _weeklyKey = GlobalKey<WeeklyCalendarScreenState>();
  final GlobalKey<CalendarScreenState> _monthlyKey = GlobalKey<CalendarScreenState>();

  @override
  void initState() {
    super.initState();
    _loadDefaultCalendar();
  }

  Future<void> _loadDefaultCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultCalendar = prefs.getString('default_calendar') ?? 'monthly';
    setState(() {
      _isWeeklyView = defaultCalendar == 'weekly';
    });
  }

  void refresh() {
    if (_isWeeklyView) {
      _weeklyKey.currentState?.refresh();
    } else {
      _monthlyKey.currentState?.refresh();
    }
  }

  void _toggleOrientation() {
    if (!_isWeeklyView) {
      _monthlyKey.currentState?.toggleOrientation();
    }
  }

  void _toggleCalendarCompact() {
    if (!_isWeeklyView) {
      _monthlyKey.currentState?.toggleCalendarCompactMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: _isWeeklyView ? '주간 캘린더' : '월간 캘린더',
        toolbarHeight: 40,
        actions: [
          // 월간 캘린더일 때만 확장/축소 버튼 표시
          if (!_isWeeklyView)
            IconButton(
              icon: Icon(
                _monthlyKey.currentState?.isCalendarCompact ?? false
                    ? Icons.unfold_more
                    : Icons.unfold_less,
              ),
              onPressed: _toggleCalendarCompact,
              tooltip: _monthlyKey.currentState?.isCalendarCompact ?? false
                  ? '캘린더 확장'
                  : '캘린더 축소',
            ),
          // 월간 캘린더일 때만 가로/세로 전환 버튼 표시
          if (!_isWeeklyView)
            IconButton(
              icon: Icon(
                _monthlyKey.currentState?.isPortrait ?? true
                    ? Icons.screen_rotation
                    : Icons.stay_current_portrait,
              ),
              onPressed: _toggleOrientation,
              tooltip: _monthlyKey.currentState?.isPortrait ?? true ? '가로보기' : '세로보기',
            ),
          IconButton(
            icon: Icon(_isWeeklyView ? Icons.calendar_month : Icons.calendar_view_week),
            onPressed: () {
              setState(() {
                _isWeeklyView = !_isWeeklyView;
              });
            },
            tooltip: _isWeeklyView ? '월간 보기' : '주간 보기',
          ),
        ],
      ),
      body: _isWeeklyView
          ? WeeklyCalendarScreen(key: _weeklyKey)
          : CalendarScreen(key: _monthlyKey),
    );
  }
}
