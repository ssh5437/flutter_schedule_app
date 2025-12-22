import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule.dart';
import '../models/date_memo.dart';
import '../database/database_helper.dart';
import '../widgets/memo_dialog.dart';
import 'schedule_detail_screen.dart';

class WeeklyCalendarScreen extends StatefulWidget {
  const WeeklyCalendarScreen({super.key});

  @override
  State<WeeklyCalendarScreen> createState() => WeeklyCalendarScreenState();
}

class WeeklyCalendarScreenState extends State<WeeklyCalendarScreen> {
  Map<DateTime, List<Schedule>> _schedulesByDate = {};
  Map<String, int> _companyColors = {};
  Map<DateTime, DateMemo> _memosByDate = {}; // 날짜별 메모 저장
  bool _isLoading = true;
  Color _pendingColor = const Color(0xFFFAE6BB);
  Color _confirmedColor = const Color(0xFFFFFFFF);
  DateTime? _selectedDate;
  final PageController _pageController = PageController(initialPage: 1000);
  int _currentPageIndex = 1000; // 현재 페이지 인덱스

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _loadColors();
    // 오늘부터 7일의 메모 로드
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    _loadMemosForWeek(startDate);
    // 오늘 날짜를 기본 선택
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
  }

  Future<void> _loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pendingColor = Color(prefs.getInt('pending_color') ?? 0xFFFAE6BB);
      _confirmedColor = Color(prefs.getInt('confirmed_color') ?? 0xFFFFFFFF);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 7일간의 날짜 목록 생성
  List<DateTime> _get7Days(DateTime startDate) {
    return List.generate(7, (index) => startDate.add(Duration(days: index)));
  }

  Future<void> _loadSchedules({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final schedules = await DatabaseHelper.instance.getSchedulesByStatus(userId, ['예정', '확정']);
    final companies = await DatabaseHelper.instance.readAllCompanies(userId);

    final Map<String, int> companyColors = {};
    for (var company in companies) {
      companyColors[company.name] = company.color;
    }

    final Map<DateTime, List<Schedule>> schedulesByDate = {};
    for (var schedule in schedules) {
      if (schedule.visitDate == null) continue;

      final dateKey = DateTime(
        schedule.visitDate!.year,
        schedule.visitDate!.month,
        schedule.visitDate!.day,
      );

      if (!schedulesByDate.containsKey(dateKey)) {
        schedulesByDate[dateKey] = [];
      }
      schedulesByDate[dateKey]!.add(schedule);
    }

    // 각 날짜의 스케줄 정렬: 1) 미확정이 먼저, 2) 시간순
    schedulesByDate.forEach((date, schedules) {
      schedules.sort((a, b) {
        // 1. 상태별 정렬: 예정(미확정)이 먼저, 확정이 나중
        final aIsConfirmed = a.computedStatus == '확정';
        final bIsConfirmed = b.computedStatus == '확정';

        if (!aIsConfirmed && bIsConfirmed) return -1;
        if (aIsConfirmed && !bIsConfirmed) return 1;

        // 2. 같은 상태 내에서 시간순 정렬
        if (a.visitTime == null && b.visitTime == null) return 0;
        if (a.visitTime == null) return 1;
        if (b.visitTime == null) return -1;
        return a.visitTime!.compareTo(b.visitTime!);
      });
    });

    if (!mounted) return;
    setState(() {
      _schedulesByDate = schedulesByDate;
      _companyColors = companyColors;
      _isLoading = false;
    });
  }

  void _onPageChanged(int pageIndex) {
    // 페이지가 변경될 때 화면을 다시 그려서 스케줄 카드 영역 크기를 업데이트
    if (mounted) {
      setState(() {
        _currentPageIndex = pageIndex;
      });

      // 새로운 주의 메모 로드 (오늘 기준으로 offset * 7일 이동)
      final offset = pageIndex - 1000;
      final today = DateTime.now();
      final startDate = DateTime(today.year, today.month, today.day);
      final weekStart = startDate.add(Duration(days: offset * 7));
      _loadMemosForWeek(weekStart);
    }
  }

  // 외부에서 호출할 수 있는 refresh 메서드
  void refresh() {
    // 로딩 인디케이터 없이 백그라운드에서 새로고침
    _loadSchedules(showLoading: false);
    // 현재 페이지의 메모도 다시 로드 (오늘 기준으로 offset * 7일 이동)
    final offset = _currentPageIndex - 1000;
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    final weekStart = startDate.add(Duration(days: offset * 7));
    _loadMemosForWeek(weekStart);
  }

  // 특정 주의 메모 로드
  Future<void> _loadMemosForWeek(DateTime weekStart) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final weekEnd = weekStart.add(const Duration(days: 6));
    final memos = await DatabaseHelper.instance.readMemosByDateRange(userId, weekStart, weekEnd);

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
      final offset = _currentPageIndex - 1000;
      final startDate = DateTime.now().add(Duration(days: offset * 7));
      await _loadMemosForWeek(startDate);
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
        final offset = _currentPageIndex - 1000;
        final startDate = DateTime.now().add(Duration(days: offset * 7));
        await _loadMemosForWeek(startDate);

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

    // 작업 항목만 추출 (건수 제외)
    final Set<String> uniqueItems = {};
    for (var item in workItems) {
      // 기존 데이터에 " X건" 형식이 포함된 경우 제거
      String cleanedItem = item.replaceAll(RegExp(r'\s+\d+건$'), '');
      uniqueItems.add(cleanedItem);
    }

    // 작업명만 쉼표로 연결
    return uniqueItems.join(', ');
  }

  Widget _buildDateHeader(List<DateTime> days) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: days.map((date) {
          final isToday = DateTime.now().year == date.year &&
              DateTime.now().month == date.month &&
              DateTime.now().day == date.day;
          final dateKey = DateTime(date.year, date.month, date.day);
          final isSelected = _selectedDate != null &&
              _selectedDate!.year == date.year &&
              _selectedDate!.month == date.month &&
              _selectedDate!.day == date.day;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = dateKey;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1976D2).withValues(alpha: 0.1) : Colors.transparent,
                  border: Border(
                    right: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E', 'ko_KR').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: date.weekday == 7
                            ? Colors.red
                            : date.weekday == 6
                                ? Colors.blue
                                : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isToday ? const Color(0xFF1976D2) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isSelected && !isToday
                            ? Border.all(color: const Color(0xFF1976D2), width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Colors.white
                              : isSelected
                                  ? const Color(0xFF1976D2)
                                  : date.weekday == 7
                                      ? Colors.red
                                      : date.weekday == 6
                                          ? Colors.blue
                                          : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMemoCard(DateMemo memo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        border: Border.all(color: const Color(0xFFFFE082), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.note,
            size: 12,
            color: Color(0xFFF57C00),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              memo.content,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF5D4037),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    final companyColor = _companyColors[schedule.companyName] ?? 0xFF1976D2;
    final backgroundColor = schedule.computedStatus == '예정' ? _pendingColor : _confirmedColor;
    final borderColor = Color(companyColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          left: BorderSide(color: borderColor, width: 3),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (schedule.visitTime != null)
                Text(
                  schedule.visitTime!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
              if (schedule.visitTime != null && schedule.computedStatus == '예정')
                const SizedBox(width: 2),
              if (schedule.computedStatus == '예정')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text(
                    '미확정',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
            ],
          ),
          Text(
            _formatWorkItems(schedule.workItems),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(DateTime date, List<DateTime> days) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final schedules = _schedulesByDate[dateKey] ?? [];
    final memo = _memosByDate[dateKey];
    final hasContent = schedules.isNotEmpty || memo != null;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDate = dateKey;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(2),
          child: !hasContent
              ? Center(
                  child: Text(
                    '일정없음',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // 메모 카드 (있는 경우 맨 위에 표시)
                      if (memo != null) _buildMemoCard(memo),
                      // 스케줄 카드들
                      ...schedules.map((schedule) {
                        return _buildScheduleCard(schedule);
                      }),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSelectedDateSchedules() {
    if (_selectedDate == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(
            top: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '날짜를 선택하세요',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    final schedules = _schedulesByDate[_selectedDate!] ?? [];
    final dayOfWeek = DateFormat('E', 'ko_KR').format(_selectedDate!);

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
                  '${_selectedDate!.month}월 ${_selectedDate!.day}일 ($dayOfWeek)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                // 메모 아이콘
                GestureDetector(
                  onTap: () => _showMemoDialog(_selectedDate!),
                  child: Icon(
                    _memosByDate.containsKey(_selectedDate)
                        ? Icons.edit_note
                        : Icons.note_add_outlined,
                    size: 20,
                    color: _memosByDate.containsKey(_selectedDate)
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
          if (_memosByDate.containsKey(_selectedDate))
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
                      _memosByDate[_selectedDate]!.content,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showMemoDialog(_selectedDate!),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.edit, size: 18, color: Color(0xFF579bf2)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _deleteMemoWithConfirmation(_selectedDate!),
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
            // 스케줄 목록 (높이 자동 조절)
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
                    // 현재 페이지 유지하면서 새로고침
                    refresh();
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildYearMonthHeader(DateTime startDate) {
    // 7일 중 시작일과 종료일 계산
    final endDate = startDate.add(const Duration(days: 6));

    // 시작일과 종료일의 년월이 같은 경우
    if (startDate.year == endDate.year && startDate.month == endDate.month) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                // 이전 주로 이동
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            Text(
              '${startDate.year}년 ${startDate.month}월',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                // 다음 주로 이동
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ],
        ),
      );
    } else {
      // 두 달에 걸쳐있는 경우
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                // 이전 주로 이동
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            Text(
              '${startDate.year}년 ${startDate.month}월 - ${endDate.month}월',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                // 다음 주로 이동
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // 현재 페이지의 날짜 계산 (오늘 기준으로 offset * 7일 이동)
                final offset = _currentPageIndex - 1000;
                final today = DateTime.now();
                final todayStart = DateTime(today.year, today.month, today.day);
                final startDate = todayStart.add(Duration(days: offset * 7));
                final days = _get7Days(startDate);
                bool hasMemo = false;
                // 현재 페이지의 최대 스케줄 개수 + 메모 계산
                int maxItemCount = 0;
                for (var day in days) {
                  final dateKey = DateTime(day.year, day.month, day.day);
                  final schedules = _schedulesByDate[dateKey] ?? [];
                  if(_memosByDate.containsKey(dateKey) == true) {
                    hasMemo = true;
                  }
                  

                  // 스케줄 개수 + 메모(있으면 1개로 계산)
                  final itemCount = schedules.length;
                  if (itemCount > maxItemCount) {
                    maxItemCount = itemCount;
                  }
                }

                // 스케줄+메모 개수에 따른 카드 영역 높이 계산
                final minHeight = 200.0;
                //final calculatedHeight = 82.0 + (maxItemCount * 59.0) + (hasMemo ? 40.0 : 0);
                final calculatedHeight = 80.0 + (maxItemCount * 53.0) + (hasMemo ? 0 : 0);
                final cardAreaHeight = calculatedHeight.clamp(minHeight, 500.0);

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // 년월 표시 헤더
                      _buildYearMonthHeader(startDate),
                      // 날짜 헤더와 카드 영역 (현재 페이지의 스케줄 수에 따라 크기 조절)
                      SizedBox(
                        height: cardAreaHeight,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) {
                            final offset = index - 1000;
                            final today = DateTime.now();
                            final todayStart = DateTime(today.year, today.month, today.day);
                            final pageStartDate = todayStart.add(Duration(days: offset * 7));
                            final days = _get7Days(pageStartDate);

                            return Column(
                              children: [
                                _buildDateHeader(days),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: days
                                        .map((date) => _buildDayColumn(date, days))
                                        .toList(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      // 하단 스케줄 목록 (높이 자동 조절)
                      _buildSelectedDateSchedules(),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
