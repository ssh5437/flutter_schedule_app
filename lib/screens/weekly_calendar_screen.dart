import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Map<String, int> _companyColors = {}; // 업체명 -> 색상 매핑
  bool _isLoading = true;
  Color _pendingColor = const Color(0xFFFAE6BB); // 예정 스케줄 색상
  Color _confirmedColor = const Color(0xFFC7EAFA); // 확정 스케줄 색상

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _loadColors();
  }

  Future<void> _loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pendingColor = Color(prefs.getInt('pending_color') ?? 0xFFFAE6BB);
      _confirmedColor = Color(prefs.getInt('confirmed_color') ?? 0xFFC7EAFA);
    });
  }

  @override
  void dispose() {
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
    final companies = await DatabaseHelper.instance.readAllCompanies();

    // 업체별 색상 매핑 생성
    final Map<String, int> companyColors = {};
    for (var company in companies) {
      companyColors[company.name] = company.color;
    }

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
      _companyColors = companyColors;
      _isLoading = false;
    });
  }

  List<Schedule> _getSchedulesForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _schedulesByDate[key] ?? [];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '확정':
        return _confirmedColor;
      case '예정':
        return _pendingColor;
      case '완료':
        return Colors.grey;
      case '취소':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _formatWorkItems(List<String> workItems) {
    if (workItems.isEmpty) return '-';

    // 작업 항목별 건수 카운팅
    final Map<String, int> itemCount = {};
    for (var item in workItems) {
      // 기존 데이터에 " X건" 형식이 포함된 경우 제거
      String cleanedItem = item.replaceAll(RegExp(r'\s+\d+건$'), '');
      itemCount[cleanedItem] = (itemCount[cleanedItem] ?? 0) + 1;
    }

    // "항목명 건수" 형식으로 변환
    return itemCount.entries.map((e) => '${e.key} ${e.value}건').join(', ');
  }

  String _formatPhoneNumber(String phone) {
    // 전화번호 포맷팅 (010-1234-5678)
    if (phone.length == 11) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 7)}-${phone.substring(7)}';
    } else if (phone.length == 10) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}';
    }
    return phone;
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
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _goToPreviousWeek,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${DateFormat('yyyy년 M월 d일', 'ko_KR').format(weekStart)} - ${DateFormat('M월 d일', 'ko_KR').format(weekEnd)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _goToToday,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('오늘', style: TextStyle(fontSize: 15)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _goToNextWeek,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // 일정 리스트 (세로로 날짜, 가로로 스케줄)
                Expanded(
                  child: _buildScheduleList(weekDays),
                ),
              ],
            );
  }

  Widget _buildScheduleList(List<DateTime> weekDays) {
    return ListView.builder(
      itemCount: weekDays.length,
      itemBuilder: (context, index) {
        return _buildDayRow(weekDays[index], index);
      },
    );
  }

  Widget _buildDayRow(DateTime day, int dayIndex) {
    const koreanDays = ['일', '월', '화', '수', '목', '금', '토'];
    final today = DateTime.now();
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final schedules = _getSchedulesForDay(day);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        color: isToday ? Colors.blue.withValues(alpha: 0.05) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 헤더 (세로)
          Container(
            width: 60,
            height: 100,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
              color: isToday ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.shade50,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  koreanDays[dayIndex],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: dayIndex == 0
                        ? Colors.red
                        : dayIndex == 6
                            ? Colors.blue
                            : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isToday ? Colors.blue : null,
                    shape: BoxShape.circle,
                    border: isToday ? null : Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        color: isToday
                            ? Colors.white
                            : dayIndex == 0
                                ? Colors.red
                                : dayIndex == 6
                                    ? Colors.blue
                                    : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 스케줄 목록 (가로 스크롤)
          Expanded(
            child: schedules.isEmpty
                ? Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: Text(
                      '일정 없음',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  )
                : SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: schedules.length,
                      itemBuilder: (context, index) {
                        return _buildScheduleCard(schedules[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    // 업체 색상 가져오기 (테두리용, 없으면 기본 회색)
    final borderColor = schedule.companyName != null && _companyColors[schedule.companyName] != null
        ? Color(_companyColors[schedule.companyName]!)
        : Colors.grey;

    // 상태별 배경색 가져오기
    final backgroundColor = _getStatusColor(schedule.status).withValues(alpha: 1);

    // 배경색 밝기에 따라 텍스트 색상 자동 조정
    final textColor = backgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

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
        width: 70,
        height: double.infinity,
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: 5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (schedule.visitTime != null && schedule.visitTime != '미정')
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  schedule.visitTime!,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Text(
              schedule.customerName,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatPhoneNumber(schedule.phoneNumber),
                style: TextStyle(
                  color: textColor,
                  fontSize: 8,
                  height: 1.2,
                ),
              ),
            ),
            if (schedule.workItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatWorkItems(schedule.workItems),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 9,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
