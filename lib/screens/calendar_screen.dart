import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  Map<String, int> _companyColors = {}; // 업체명 -> 색상 매핑
  bool _isLoading = true;
  bool _isPortrait = true; // true: 세로보기, false: 가로보기
  final ScrollController _scrollController = ScrollController();
  Color _pendingColor = const Color(0xFFFAE6BB); // 예정 스케줄 색상
  Color _confirmedColor = const Color(0xFFFFFFFF); // 확정 스케줄 색상 (흰색)

  // 외부에서 호출 가능한 새로고침 메서드
  void refresh() {
    _loadSchedules();
  }

  // 외부에서 접근 가능한 isPortrait getter
  bool get isPortrait => _isPortrait;

  // 외부에서 호출 가능한 가로/세로 전환 메서드
  void toggleOrientation() {
    setState(() {
      _isPortrait = !_isPortrait;
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadSchedules();
    _loadColors();
  }

  Future<void> _loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pendingColor = Color(prefs.getInt('pending_color') ?? 0xFFFAE6BB);
      _confirmedColor = Color(prefs.getInt('confirmed_color') ?? 0xFFFFFFFF);
    });
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
      final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
      final calendarStartDay = firstDay.subtract(Duration(days: firstDay.weekday % 7));
      final today = DateTime.now();

      // 마지막 날짜가 포함된 주의 인덱스 계산
      final lastDayWeekIndex = ((lastDay.difference(calendarStartDay).inDays) / 7).ceil();
      final maxWeeks = lastDayWeekIndex;

      // 현재 날짜가 속한 주 찾기
      int currentWeek = 0;
      for (int week = 0; week < maxWeeks; week++) {
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
      final currentWeekHeight = currentWeek < rowHeights.length ? rowHeights[currentWeek] : 80.0;
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

  void _scrollToScheduleList() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // 스크롤을 맨 아래로 이동 (하단 스케줄 목록이 보이도록)
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
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

    // 각 날짜별로 스케줄 정렬: 요청 스케줄 먼저, 각각 시간순
    for (var date in schedulesByDate.keys) {
      schedulesByDate[date]!.sort((a, b) {
        // 1. 상태별 정렬: 예정(요청) 스케줄이 확정 스케줄보다 먼저
        final aStatus = a.computedStatus;
        final bStatus = b.computedStatus;

        if (aStatus != bStatus) {
          if (aStatus == '예정') return -1;  // 예정이 먼저
          if (bStatus == '예정') return 1;
        }

        // 2. 같은 상태 내에서 시간순 정렬
        // 요청 스케줄(예정): requestDate의 시간 순서 (시간 정보가 없으면 날짜만)
        // 확정 스케줄: visitTime 순서
        if (aStatus == '확정' && bStatus == '확정') {
          // 확정 스케줄끼리: visitTime으로 정렬
          final aTime = a.visitTime ?? '99:99';  // 시간 없으면 맨 뒤로
          final bTime = b.visitTime ?? '99:99';
          return aTime.compareTo(bTime);
        } else {
          // 예정 스케줄끼리: requestDate 시간으로 정렬
          return a.requestDate.compareTo(b.requestDate);
        }
      });
    }

    if (!mounted) return;
    setState(() {
      _schedulesByDate = schedulesByDate;
      _companyColors = companyColors;
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

  String _formatPhoneNumber(String phone) {
    // 전화번호 포맷팅 (010-1234-5678)
    if (phone.length == 11) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 7)}-${phone.substring(7)}';
    } else if (phone.length == 10) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}';
    }
    return phone;
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
      onTap: () {
        setState(() {
          _selectedDay = day;
          _focusedDay = day;
        });
        // 하단 스케줄 목록으로 스크롤
        _scrollToScheduleList();
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
                        // 업체 색상 가져오기 (없으면 기본 회색)
                        final companyColor = schedule.companyName != null
                            ? _companyColors[schedule.companyName] ?? 0xFF9E9E9E
                            : 0xFF9E9E9E;
                        final borderColor = Color(companyColor);

                        // 상태별 배경색 가져오기
                        final backgroundColor = _getStatusColor(schedule.computedStatus).withValues(alpha: 1);

                        // 배경색 밝기에 따라 텍스트 색상 자동 조정
                        final textColor = backgroundColor.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            border: Border(
                              left: BorderSide(
                                color: borderColor,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            schedule.visitTime != null
                                ? '${schedule.visitTime} ${_formatWorkItems(schedule.workItems)}'
                                : _formatWorkItems(schedule.workItems),
                            style: TextStyle(
                              color: textColor,
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
    return _isLoading
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
            );
  }

  // 각 주의 최대 스케줄 개수를 계산하여 동적 높이 적용
  List<double> _calculateRowHeights() {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0); // 해당 월의 마지막 날

    // 캘린더 시작일 (첫 주의 일요일)
    final calendarStartDay = firstDay.subtract(Duration(days: firstDay.weekday % 7));

    // 마지막 날짜가 포함된 주의 인덱스 계산
    final lastDayWeekIndex = ((lastDay.difference(calendarStartDay).inDays) / 7).ceil();
    final maxWeeks = lastDayWeekIndex;

    List<double> rowHeights = [];
    DateTime currentWeekStart = calendarStartDay;

    // 필요한 주만큼만 계산
    for (int week = 0; week < maxWeeks; week++) {
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
        // 선택된 날짜의 스케줄 목록
        if (_selectedDay != null) _buildSelectedDaySchedules(),
      ],
    );
  }

  Widget _buildSelectedDaySchedules() {
    final schedules = _getSchedulesForDay(_selectedDay!);
    const koreanDays = ['일', '월', '화', '수', '목', '금', '토'];
    final dayOfWeek = koreanDays[_selectedDay!.weekday % 7];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 선택된 날짜 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedDay!.month}월 ${_selectedDay!.day}일 ($dayOfWeek)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${schedules.length}건',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // 스케줄이 없을 때
          if (schedules.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                '해당 날짜에 스케줄이 없습니다',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            // 스케줄 목록
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final schedule = schedules[index];
          // 업체 색상 가져오기 (없으면 기본 회색)
          final companyColor = schedule.companyName != null
              ? _companyColors[schedule.companyName] ?? 0xFF9E9E9E
              : 0xFF9E9E9E;
          final borderColor = Color(companyColor);

          // 상태별 배경색 가져오기
          final backgroundColor = _getStatusColor(schedule.computedStatus).withValues(alpha: 1);

          // 배경색 밝기에 따라 텍스트 색상 자동 조정
          final textColor = backgroundColor.computeLuminance() > 0.5
              ? Colors.black87
              : Colors.white;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                left: BorderSide(
                  color: borderColor,
                  width: 6,
                ),
              ),
            ),
            child: ListTile(
              title: Row(
                children: [
                  if (schedule.visitTime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        schedule.visitTime!,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (schedule.visitTime != null) const SizedBox(width: 8),
                  Text(
                    schedule.customerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatPhoneNumber(schedule.phoneNumber),
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const Spacer(),
                  if (schedule.companyName != null && schedule.companyName!.isNotEmpty)
                    Text(
                      schedule.companyName!,
                      style: TextStyle(
                        fontSize: 13,
                        color: borderColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  
                  Text(
                    schedule.address,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  Text(
                    _formatWorkItems(schedule.workItems),
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                ],
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScheduleDetailScreen(schedule: schedule),
                  ),
                );
                _loadSchedules();
              },
            ),
          );
        },
      ),
        ],
      ),
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
                _selectedDay = null; // 월 변경 시 선택 초기화
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
                _selectedDay = null; // 월 변경 시 선택 초기화
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
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0); // 해당 월의 마지막 날
    final calendarStartDay = firstDay.subtract(Duration(days: firstDay.weekday % 7));

    List<Widget> rows = [];

    // 마지막 날짜가 포함된 주의 인덱스 계산
    final lastDayWeekIndex = ((lastDay.difference(calendarStartDay).inDays) / 7).ceil();
    final maxWeeks = lastDayWeekIndex;

    for (int week = 0; week < maxWeeks; week++) {
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
