import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // 통합된 가로 스크롤 컨트롤러
  final ScrollController _horizontalScrollController = ScrollController();

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
    _horizontalScrollController.dispose();
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final schedules = await DatabaseHelper.instance.getSchedulesByStatus(userId, ['예정', '확정']);
    final companies = await DatabaseHelper.instance.readAllCompanies(userId);

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

    if (!mounted) return;
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

    // 화면 높이 계산
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = kToolbarHeight;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomNavHeight = kBottomNavigationBarHeight;
    final headerHeight = 56.0; // 주 네비게이션 헤더 높이

    // 사용 가능한 높이 = 전체 화면 - 상태바 - 앱바 - 하단 네비게이션 - 헤더
    final availableHeight = screenHeight - statusBarHeight - appBarHeight - bottomNavHeight - headerHeight;

    // 각 요일의 높이 = 사용 가능한 높이 / 7일
    final dayHeight = (availableHeight - 50) / 7;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
              children: [
                // 헤더: 주 네비게이션
                Container(
                  height: headerHeight,
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
                  child: _buildScheduleList(weekDays, dayHeight),
                ),
              ],
            );
  }

  Widget _buildScheduleList(List<DateTime> weekDays, double dayHeight) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽: 날짜 헤더 (고정)
            Column(
              children: weekDays.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                return _buildDateHeader(day, index, dayHeight);
              }).toList(),
            ),
            // 오른쪽: 모든 요일의 스케줄 (가로 스크롤)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weekDays.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                return _buildScheduleRow(day, index, dayHeight);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // 날짜 헤더 (왼쪽 고정)
  Widget _buildDateHeader(DateTime day, int dayIndex, double dayHeight) {
    const koreanDays = ['일', '월', '화', '수', '목', '금', '토'];
    final today = DateTime.now();
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;

    return Container(
      width: 60,
      height: dayHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          right: BorderSide(color: Colors.grey.shade300),
        ),
        color: isToday ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            koreanDays[dayIndex],
            style: TextStyle(
              fontSize: 13,
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
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: isToday ? Colors.blue : null,
              shape: BoxShape.circle,
              border: isToday ? null : Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 16,
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
    );
  }

  // 스케줄 행 (가로로 나열)
  Widget _buildScheduleRow(DateTime day, int dayIndex, double dayHeight) {
    final today = DateTime.now();
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final schedules = _getSchedulesForDay(day);

    return Container(
      height: dayHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        color: isToday ? Colors.blue.withValues(alpha: 0.05) : null,
      ),
      child: schedules.isEmpty
          ? Container(
              width: 100,
              alignment: Alignment.center,
              child: Text(
                '일정 없음',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: schedules.map((schedule) => _buildScheduleCard(schedule)).toList(),
            ),
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    // 업체 색상 가져오기 (테두리용, 없으면 기본 회색)
    final borderColor = schedule.companyName != null && _companyColors[schedule.companyName] != null
        ? Color(_companyColors[schedule.companyName]!)
        : Colors.grey;

    // 상태별 배경색 가져오기
    final backgroundColor = _getStatusColor(schedule.computedStatus).withValues(alpha: 1);

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
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: 5,
            ),
            right: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
            bottom: BorderSide(
              color: Colors.grey.shade100,
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (schedule.visitTime != null && schedule.visitTime != '미정')
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  schedule.visitTime!,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (schedule.workItems.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _formatWorkItems(schedule.workItems),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 9,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
