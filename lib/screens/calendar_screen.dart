import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule.dart';
import '../models/date_memo.dart';
import '../database/database_helper.dart';
import '../widgets/memo_dialog.dart';
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
  Map<DateTime, DateMemo> _memosByDate = {}; // 날짜별 메모 저장
  bool _isLoading = true;
  bool _isPortrait = true; // true: 세로보기, false: 가로보기
  final ScrollController _scrollController = ScrollController();
  Color _pendingColor = const Color(0xFFFAE6BB); // 미확정 스케줄 색상
  Color _confirmedColor = const Color(0xFFFFFFFF); // 확정 스케줄 색상 (흰색)
  bool _isCalendarCompact = false; // 캘린더 축소 모드 여부

  // 외부에서 호출 가능한 새로고침 메서드
  void refresh() {
    _loadSchedules();
  }

  // 외부에서 접근 가능한 getter들
  bool get isPortrait => _isPortrait;
  bool get isCalendarCompact => _isCalendarCompact;

  // 외부에서 호출 가능한 가로/세로 전환 메서드
  void toggleOrientation() {
    setState(() {
      _isPortrait = !_isPortrait;
    });
  }

  // 외부에서 호출 가능한 캘린더 확장/축소 전환 메서드
  void toggleCalendarCompactMode() {
    _toggleCalendarCompactMode();
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadSchedules();
    _loadColors();
    _loadCalendarCompactState();
    // 현재 월의 메모 로드 (await 없이 호출하지만 setState는 내부에서 처리됨)
    _loadMemosForMonth(_focusedDay);
  }

  Future<void> _loadCalendarCompactState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isCalendarCompact = prefs.getBool('calendar_compact_mode') ?? false;
    });
  }

  Future<void> _toggleCalendarCompactMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCalendarCompact = !_isCalendarCompact;
    });
    await prefs.setBool('calendar_compact_mode', _isCalendarCompact);
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
      // visitDate가 있는 경우만 캘린더에 표시
      if (schedule.visitDate == null) continue;

      final date = DateTime(
        schedule.visitDate!.year,
        schedule.visitDate!.month,
        schedule.visitDate!.day,
      );
      if (schedulesByDate[date] == null) {
        schedulesByDate[date] = [];
      }
      schedulesByDate[date]!.add(schedule);
    }

    // 각 날짜별로 스케줄 정렬: 미확정 스케줄 먼저, 각각 시간순
    for (var date in schedulesByDate.keys) {
      schedulesByDate[date]!.sort((a, b) {
        // 1. 상태별 정렬: 미확정 스케줄이 확정 스케줄보다 먼저
        final aStatus = a.computedStatus;
        final bStatus = b.computedStatus;

        if (aStatus != bStatus) {
          if (aStatus == '예정') return -1;  // 예정이 먼저
          if (bStatus == '예정') return 1;
        }

        // 2. 같은 상태 내에서 시간순 정렬
        // 확정 스케줄: visitTime으로 정렬
        // 미확정 스케줄: visitTime이 있으면 사용, 없으면 뒤로
        final aTime = a.visitTime ?? '99:99';  // 시간 없으면 맨 뒤로
        final bTime = b.visitTime ?? '99:99';
        return aTime.compareTo(bTime);
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

  // 특정 월의 메모 로드
  Future<void> _loadMemosForMonth(DateTime month) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final memos = await DatabaseHelper.instance.readMemosByDateRange(userId, monthStart, monthEnd);

    final Map<DateTime, DateMemo> memosByDate = {};
    for (var memo in memos) {
      final dateKey = DateTime(memo.date.year, memo.date.month, memo.date.day);
      memosByDate[dateKey] = memo;
    }

    if (mounted) {
      setState(() {
        _memosByDate = memosByDate;
      });
    }
  }

  // 메모 다이얼로그 표시
  Future<void> _showMemoDialog(DateTime date) async {
    final dateKey = DateTime(date.year, date.month, date.day);
    final existingMemo = _memosByDate[dateKey];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => MemoDialog(
        date: date,
        existingMemo: existingMemo,
      ),
    );

    // 메모가 변경되었으면 다시 로드
    if (result == true) {
      await _loadMemosForMonth(_focusedDay);
    }
  }

  // 메모 삭제 확인 후 삭제
  Future<void> _deleteMemoWithConfirmation(DateTime date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFAFAFA),
        title: const Text('메모 삭제'),
        content: const Text('이 메모를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final dateKey = DateTime(date.year, date.month, date.day);
      final memo = _memosByDate[dateKey];
      if (memo?.id == null) return;

      try {
        await DatabaseHelper.instance.deleteMemo(userId, memo!.id!);

        // 메모 목록 다시 로드
        await _loadMemosForMonth(_focusedDay);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('메모가 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('메모 삭제 실패: $e')),
          );
        }
      }
    }
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

  Widget _buildMemoCardForCalendar(DateMemo memo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        border: Border.all(color: const Color(0xFFFFE082), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.note,
            size: 10,
            color: Color(0xFFF57C00),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              memo.content,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5D4037),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime day, bool isToday, bool isSelected, {bool isOutside = false}) {
    final schedules = _getSchedulesForDay(day);
    final dateKey = DateTime(day.year, day.month, day.day);
    final memo = _memosByDate[dateKey];
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 날짜 표시
              if (_isCalendarCompact)
                // 축소 모드: 날짜와 업체별 색상 점 표시
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 날짜와 메모 아이콘
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                              color: isOutside
                                  ? Colors.grey.shade400
                                  : isWeekend
                                      ? (day.weekday == DateTime.sunday ? Colors.red : Colors.blue)
                                      : Colors.black87,
                            ),
                          ),
                          // 메모 표시 (오른쪽 상단에 동그라미)
                          if (memo != null)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF57C00),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      // 업체별 색상 점 표시
                      if (schedules.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: schedules.map((schedule) {
                              // 업체 색상 가져오기
                              final companyColor = schedule.companyName != null
                                  ? _companyColors[schedule.companyName] ?? 0xFF9E9E9E
                                  : 0xFF9E9E9E;
                              final color = Color(companyColor);

                              return Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                )
              else
                // 확장 모드: 날짜만 표시
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
              // 스케줄 목록 또는 개수 표시 (확장 모드에서만)
              if (!_isCalendarCompact)
                Expanded(
                  child: (schedules.isEmpty && memo == null)
                      ? const SizedBox.shrink()
                        // 확장 모드: 메모 및 스케줄 상세 정보 표시
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              // 메모 카드 (있는 경우 맨 위에 표시)
                              if (memo != null) _buildMemoCardForCalendar(memo),
                              // 스케줄 카드들
                              ...schedules.map((schedule) {
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
                                        ? '${schedule.visitTime} ${schedule.computedStatus == '예정' ? '[미확정] ' : ''}${schedule.customerName} ${_formatWorkItems(schedule.workItems)}'
                                        : '${schedule.computedStatus == '예정' ? '[미확정] ' : ''}${schedule.customerName} ${_formatWorkItems(schedule.workItems)}',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                ),
            ],
          ),
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

      // 축소 모드: 고정 높이 50px (날짜와 개수만 표시)
      if (_isCalendarCompact) {
        rowHeights.add(50.0);
      } else {
        // 확장 모드: 기존 로직
        // 스케줄이 2개 이상이면 기본 높이 없이 스케줄 개수만큼만 계산
        // 스케줄이 0~1개면 기본 높이 80px 사용
        final rowHeight = maxSchedulesInWeek >= 2
            ? (maxSchedulesInWeek * 25.0) + 50.0  // 날짜 표시 공간 50px만 추가
            : 80.0 + (maxSchedulesInWeek * 25.0);
        rowHeights.add(rowHeight);
      }

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

    // 날짜 키 정규화 (시간 제거)
    final selectedDateKey = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);

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
                const SizedBox(width: 8),
                // 메모 아이콘
                GestureDetector(
                  onTap: () => _showMemoDialog(_selectedDay!),
                  child: Icon(
                    _memosByDate.containsKey(selectedDateKey)
                        ? Icons.edit_note
                        : Icons.note_add_outlined,
                    size: 20,
                    color: _memosByDate.containsKey(selectedDateKey)
                        ? const Color(0xFF579bf2)
                        : Colors.grey.shade600,
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
          // 메모 표시 (있는 경우)
          if (_memosByDate.containsKey(selectedDateKey))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note, size: 16, color: Color(0xFFF57C00)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _memosByDate[selectedDateKey]!.content,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showMemoDialog(_selectedDay!),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.edit, size: 18, color: Color(0xFF579bf2)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _deleteMemoWithConfirmation(_selectedDay!),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.delete, size: 18, color: Colors.red.shade400),
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
              borderRadius: BorderRadius.circular(8),
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
                  if (schedule.computedStatus == '예정')
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '[미확정]',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
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
                    schedule.address ?? '',
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
              _loadMemosForMonth(_focusedDay); // 새로운 월의 메모 로드
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
              _loadMemosForMonth(_focusedDay); // 새로운 월의 메모 로드
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
