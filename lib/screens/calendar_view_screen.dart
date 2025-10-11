import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isWeeklyView ? '주간 캘린더' : '월간 캘린더'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 월간 캘린더일 때만 가로/세로 전환 버튼 표시
          if (!_isWeeklyView)
            IconButton(
              icon: Icon(
                _monthlyKey.currentState?.isPortrait ?? true
                    ? Icons.phone_android
                    : Icons.phone_iphone_outlined,
              ),
              onPressed: _toggleOrientation,
              tooltip: _monthlyKey.currentState?.isPortrait ?? true ? '가로보기' : '세로보기',
            ),
          IconButton(
            icon: Icon(_isWeeklyView ? Icons.calendar_month : Icons.view_week),
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
