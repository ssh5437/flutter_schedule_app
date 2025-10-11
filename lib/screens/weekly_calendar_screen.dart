import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../database/database_helper.dart';
import 'schedule_detail_screen.dart';

class WeeklyCalendarScreen extends StatefulWidget {
  const WeeklyCalendarScreen({super.key});

  @override
  State<WeeklyCalendarScreen> createState() => WeeklyCalendarScreenState();
}

class WeeklyCalendarScreenState extends State<WeeklyCalendarScreen> {
  DateTime _focusedWeek = DateTime.now();
  Map<DateTime, List<Schedule>> _schedulesByDate = {};
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  // 시간대 (5:00 ~ 23:00, 1시간 단위)
  final List<int> _hours = List.generate(19, (index) => 5 + index);

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void refresh() {
    _loadSchedules();
  }

  // 주의 시작일 (일요일) 계산
  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  // 현재 주의 날짜 목록 (일~토)
  List<DateTime> _getWeekDays() {
    final weekStart = _getWeekStart(_focusedWeek);
    return List.generate(7, (index) => weekStart.add(Duration(days: index)));
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final schedules = await DatabaseHelper.instance.getSchedulesByStatus(['예정', '확정']);

    final Map<DateTime, List<Schedule>> schedulesByDate = {};
    for (var schedule in schedules) {
      final displayDate = schedule.visitDate ?? schedule.requestDate;
      final date = DateTime(displayDate.year, displayDate.month, displayDate.day);

      if (schedulesByDate[date] == null) {
        schedulesByDate[date] = [];
      }
      schedulesByDate[date]!.add(schedule);
    }

    // 각 날짜별로 스케줄 정렬: 시간순
    for (var date in schedulesByDate.keys) {
      schedulesByDate[date]!.sort((a, b) {
        if (a.visitTime == null && b.visitTime != null) return -1;
        if (a.visitTime != null && b.visitTime == null) return 1;
        if (a.visitTime == null && b.visitTime == null) return 0;
        return a.visitTime!.compareTo(b.visitTime!);
      });
    }

    setState(() {
      _schedulesByDate = schedulesByDate;
      _isLoading = false;
    });

    _scrollToCurrentTime();
  }

  void _scrollToCurrentTime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final now = DateTime.now();
      final currentHour = now.hour;

      if (currentHour >= 5 && currentHour <= 23) {
        final hourIndex = currentHour - 5;
        const hourHeight = 60.0;
        final scrollOffset = hourIndex * hourHeight - 100;

        _scrollController.animateTo(
          scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
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

  int? _parseHour(String? time) {
    if (time == null) return null;
    try {
      final parts = time.split(':');
      return int.parse(parts[0]);
    } catch (e) {
      return null;
    }
  }

  void _goToPreviousWeek() {
    setState(() {
      _focusedWeek = _focusedWeek.subtract(const Duration(days: 7));
    });
  }

  void _goToNextWeek() {
    setState(() {
      _focusedWeek = _focusedWeek.add(const Duration(days: 7));
    });
  }

  void _goToToday() {
    setState(() {
      _focusedWeek = DateTime.now();
    });
    _scrollToCurrentTime();
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays();
    final weekStart = weekDays.first;
    final weekEnd = weekDays.last;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
              children: [
                // 헤더: 주 네비게이션
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _goToPreviousWeek,
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${DateFormat('yyyy년 M월 d일', 'ko_KR').format(weekStart)} - ${DateFormat('M월 d일', 'ko_KR').format(weekEnd)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _goToToday,
                        child: const Text('오늘'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _goToNextWeek,
                      ),
                    ],
                  ),
                ),
                // 요일 헤더
                _buildDayHeaders(weekDays),
                // 시간대별 스케줄 그리드
                Expanded(
                  child: _buildTimeGrid(weekDays),
                ),
              ],
            );
  }

  Widget _buildDayHeaders(List<DateTime> weekDays) {
    const koreanDays = ['일', '월', '화', '수', '목', '금', '토'];
    final today = DateTime.now();

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // 시간 컬럼 공간
          Container(
            width: 50,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          // 요일 헤더들
          ...weekDays.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final isToday = day.year == today.year &&
                day.month == today.month &&
                day.day == today.day;

            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: index < 6
                        ? BorderSide(color: Colors.grey.shade300)
                        : BorderSide.none,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      koreanDays[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: index == 0
                            ? Colors.red
                            : index == 6
                                ? Colors.blue
                                : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isToday ? Colors.blue : null,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? Colors.white
                                : index == 0
                                    ? Colors.red
                                    : index == 6
                                        ? Colors.blue
                                        : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeGrid(List<DateTime> weekDays) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 시간 컬럼
          _buildTimeColumn(),
          // 날짜별 컬럼들
          ...weekDays.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            return Expanded(
              child: _buildDayColumn(day, index < 6),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    return Container(
      width: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: _hours.map((hour) {
          return Container(
            height: 60,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 4, top: 2),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayColumn(DateTime day, bool showRightBorder) {
    final schedules = _getSchedulesForDay(day);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: showRightBorder
              ? BorderSide(color: Colors.grey.shade300)
              : BorderSide.none,
        ),
      ),
      child: Stack(
        children: [
          // 시간 그리드 라인
          Column(
            children: _hours.map((hour) {
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
              );
            }).toList(),
          ),
          // 스케줄들
          ...schedules.map((schedule) {
            return _buildScheduleBlock(schedule);
          }),
        ],
      ),
    );
  }

  Widget _buildScheduleBlock(Schedule schedule) {
    final hour = _parseHour(schedule.visitTime);

    if (hour == null || hour < 5 || hour > 23) {
      // 시간이 없거나 범위 밖이면 맨 위에 표시
      return Positioned(
        top: 0,
        left: 2,
        right: 2,
        child: _buildScheduleCard(schedule),
      );
    }

    final hourIndex = hour - 5;
    const hourHeight = 60.0;

    return Positioned(
      top: hourIndex * hourHeight,
      left: 2,
      right: 2,
      child: _buildScheduleCard(schedule),
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScheduleDetailScreen(schedule: schedule),
          ),
        );
        _loadSchedules();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor(schedule.status),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (schedule.visitTime != null)
              Text(
                schedule.visitTime!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              schedule.customerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              schedule.workItems.join(', '),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
