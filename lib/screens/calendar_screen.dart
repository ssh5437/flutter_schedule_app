import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/schedule.dart';
import '../database/database_helper.dart';
import 'schedule_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Schedule>> _schedulesByDate = {};
  bool _isLoading = true;
  bool _isPortrait = true; // true: 세로보기, false: 가로보기
  final ScrollController _scrollController = ScrollController();

  // 외부에서 호출 가능한 새로고침 메서드
  void refresh() {
    _loadSchedules();
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadSchedules();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentWeek() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final rowHeights = _calculateRowHeights();
      final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final calendarStartDay = firstDay.subtract(Duration(days: firstDay.weekday % 7));
      final today = DateTime.now();

      // 현재 날짜가 속한 주 찾기
      int currentWeek = 0;
      for (int week = 0; week < 6; week++) {
        final weekStart = calendarStartDay.add(Duration(days: week * 7));
        final weekEnd = weekStart.add(const Duration(days: 6));

        if (today.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            today.isBefore(weekEnd.add(const Duration(days: 1)))) {
          currentWeek = week;
          break;
        }
      }

      // 현재 주까지의 높이 계산 (헤더 50px + 요일 30px 포함)
      double scrollOffset = 80.0; // 헤더 + 요일 행
      for (int i = 0; i < currentWeek; i++) {
        scrollOffset += rowHeights[i];
      }

      // 현재 주를 화면 중앙에 배치하기 위해 조정
      final screenHeight = MediaQuery.of(context).size.height - kToolbarHeight;
      final currentWeekHeight = rowHeights[currentWeek];
      scrollOffset -= (screenHeight - currentWeekHeight) / 2;

      // 스크롤 범위 체크
      if (scrollOffset < 0) scrollOffset = 0;
      if (scrollOffset > _scrollController.position.maxScrollExtent) {
        scrollOffset = _scrollController.position.maxScrollExtent;
      }

      _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final schedules = await DatabaseHelper.instance.getSchedulesByStatus(['예정', '확정']);

    final Map<DateTime, List<Schedule>> schedulesByDate = {};
    for (var schedule in schedules) {
      // visitDate가 있으면 visitDate를 사용, 없으면 requestDate를 사용
      final displayDate = schedule.visitDate ?? schedule.requestDate;
      final date = DateTime(
        displayDate.year,
        displayDate.month,
        displayDate.day,
      );
      if (schedulesByDate[date] == null) {
        schedulesByDate[date] = [];
      }
      schedulesByDate[date]!.add(schedule);
    }

    // 각 날짜별로 스케줄 정렬: 시간 없는 것이 먼저, 그 다음 시간순
    for (var date in schedulesByDate.keys) {
      schedulesByDate[date]!.sort((a, b) {
        // visitTime이 없는 것을 먼저
        if (a.visitTime == null && b.visitTime != null) return -1;
        if (a.visitTime != null && b.visitTime == null) return 1;
        if (a.visitTime == null && b.visitTime == null) return 0;

        // 둘 다 visitTime이 있으면 시간순으로 정렬
        return a.visitTime!.compareTo(b.visitTime!);
      });
    }

    setState(() {
      _schedulesByDate = schedulesByDate;
      _isLoading = false;
    });

    // 데이터 로드 후 현재 주로 스크롤
    _scrollToCurrentWeek();
  }

  List<Schedule> _getSchedulesForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _schedulesByDate[key] ?? [];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '확정':
        return Colors.green;
      case '예정':
        return Colors.orange;
      case '완료':
        return Colors.grey;
      case '취소':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Widget _buildDayCell(DateTime day, bool isToday, bool isSelected, {bool isOutside = false}) {
    final schedules = _getSchedulesForDay(day);
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    Color borderColor = Colors.grey.shade300;
    Color? backgroundColor;

    if (isToday) {
      borderColor = Colors.blue;
      backgroundColor = Colors.blue.withValues(alpha: 0.1);
    } else if (isSelected) {
      borderColor = Colors.deepPurple;
      backgroundColor = Colors.deepPurple.withValues(alpha: 0.1);
    }

    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedDay = day;
          _focusedDay = day;
        });

        if (schedules.isNotEmpty) {
          // 스케줄이 있으면 첫 번째 스케줄 상세로 이동
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScheduleDetailScreen(schedule: schedules[0]),
            ),
          );
          _loadSchedules();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: isToday || isSelected ? 2 : 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 날짜 표시
            Container(
              padding: const EdgeInsets.all(6.0),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  color: isOutside
                      ? Colors.grey.shade400
                      : isWeekend
                          ? (day.weekday == DateTime.sunday ? Colors.red : Colors.blue)
                          : Colors.black87,
                ),
              ),
            ),
            // 스케줄 목록
            Expanded(
              child: schedules.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: schedules.length,
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(schedule.status),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            schedule.visitTime != null
                                ? '${schedule.visitTime} ${schedule.workItems.join(', ')}, ${schedule.workCount}건'
                                : '${schedule.workItems.join(', ')}, ${schedule.workCount}건',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isPortrait ? Icons.phone_android : Icons.phone_iphone_outlined),
            onPressed: () {
              setState(() {
                _isPortrait = !_isPortrait;
              });
            },
            tooltip: _isPortrait ? '가로보기' : '세로보기',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (_isPortrait) {
                  // 세로보기: 스크롤 가능
                  return SingleChildScrollView(
                    controller: _scrollController,
                    child: _buildDynamicCalendar(constraints.maxWidth),
                  );
                } else {
                  // 가로보기: 화면을 90도 회전하고 스크롤 가능
                  return RotatedBox(
                    quarterTurns: 1,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: SizedBox(
                        width: constraints.maxHeight,
                        child: _buildDynamicCalendar(constraints.maxHeight),
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }

  // 각 주의 최대 스케줄 개수를 계산하여 동적 높이 적용
  List<double> _calculateRowHeights() {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);

    // 캘린더 시작일 (첫 주의 일요일)
    final calendarStartDay = firstDay.subtract(Duration(days: firstDay.weekday % 7));

    List<double> rowHeights = [];
    DateTime currentWeekStart = calendarStartDay;

    // 최대 6주 계산
    for (int week = 0; week < 6; week++) {
      int maxSchedulesInWeek = 0;

      // 해당 주의 각 날짜에서 최대 스케줄 개수 찾기
      for (int day = 0; day < 7; day++) {
        final currentDay = currentWeekStart.add(Duration(days: day));
        final schedules = _getSchedulesForDay(currentDay);
        if (schedules.length > maxSchedulesInWeek) {
          maxSchedulesInWeek = schedules.length;
        }
      }

      // 스케줄이 2개 이상이면 기본 높이 없이 스케줄 개수만큼만 계산
      // 스케줄이 0~1개면 기본 높이 80px 사용
      final rowHeight = maxSchedulesInWeek >= 2
          ? (maxSchedulesInWeek * 25.0) + 50.0  // 날짜 표시 공간 50px만 추가
          : 80.0 + (maxSchedulesInWeek * 25.0);
      rowHeights.add(rowHeight);

      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    return rowHeights;
  }

  Widget _buildDynamicCalendar(double width) {
    final rowHeights = _calculateRowHeights();

    return Column(
      children: [
        // 캘린더 헤더
        _buildCalendarHeader(),
        // 요일 행
        _buildDaysOfWeekRow(),
        // 동적 높이를 가진 캘린더 행들
        ..._buildCalendarRows(rowHeights, width),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              });
            },
          ),
          Text(
            '${_focusedDay.year}년 ${_focusedDay.month}월',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeekRow() {
    const koreanDays = ['일', '월', '화', '수', '목', '금', '토'];

    return Container(
      height: 30,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: List.generate(7, (index) {
          return Expanded(
            child: Center(
              child: Text(
                koreanDays[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: index == 0
                      ? Colors.red
                      : index == 6
                          ? Colors.blue
                          : Colors.black87,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildCalendarRows(List<double> rowHeights, double width) {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final calendarStartDay = firstDay.subtract(Duration(days: firstDay.weekday % 7));

    List<Widget> rows = [];

    for (int week = 0; week < 6; week++) {
      List<Widget> dayCells = [];

      for (int day = 0; day < 7; day++) {
        final currentDay = calendarStartDay.add(Duration(days: week * 7 + day));
        final isCurrentMonth = currentDay.month == _focusedDay.month;
        final isToday = isSameDay(currentDay, DateTime.now());
        final isSelected = isSameDay(currentDay, _selectedDay);

        dayCells.add(
          Expanded(
            child: _buildDayCell(currentDay, isToday, isSelected, isOutside: !isCurrentMonth),
          ),
        );
      }

      rows.add(
        SizedBox(
          height: rowHeights[week],
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: dayCells,
          ),
        ),
      );
    }

    return rows;
  }
}
