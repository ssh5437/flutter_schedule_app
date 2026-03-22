import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upgrader/upgrader.dart';
import '../models/schedule.dart';
import '../models/date_memo.dart';
import '../database/database_helper.dart';
import '../services/widget_service.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/memo_dialog.dart';
import 'schedule_detail_screen.dart';
import 'search_screen.dart';
import 'company_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Schedule> _schedules = [];
  Map<String, int> _companyColors = {}; // 업체명 -> 색상 매핑
  Map<DateTime, DateMemo> _memosByDate = {}; // 날짜별 메모
  bool _isLoading = true;
  bool _showPendingSchedules = true; // 미확정 스케줄 표시 여부
  bool _showTodayOnly = false; // 오늘 스케줄만 표시 여부
  Color _pendingColor = const Color(0xFFFAE6BB); // 미확정 스케줄 색상
  Color _confirmedColor = const Color(0xFFFFFFFF); // 확정 스케줄 색상 (흰색)

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 HomeScreen initState called');
    _loadSchedules();
    _loadColors();
    _loadMemos();
  }

  Future<void> _loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pendingColor = Color(prefs.getInt('pending_color') ?? 0xFFFAE6BB);
      _confirmedColor = Color(prefs.getInt('confirmed_color') ?? 0xFFFFFFFF);
    });
  }

  // 메모 로드
  Future<void> _loadMemos() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // 오늘부터 3개월치 메모 로드
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 90));

      final memos = await DatabaseHelper.instance.readMemosByDateRange(
        userId,
        startDate,
        endDate,
      );

      if (!mounted) return;
      setState(() {
        _memosByDate = {
          for (var memo in memos)
            DateTime(memo.date.year, memo.date.month, memo.date.day): memo
        };
      });
    } catch (e) {
      debugPrint('메모 로드 실패: $e');
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

    if (result == true) {
      _loadMemos();
    }
  }

  // 메모 삭제 확인
  Future<void> _deleteMemoWithConfirmation(DateTime date) async {
    final dateKey = DateTime(date.year, date.month, date.day);
    final memo = _memosByDate[dateKey];
    if (memo == null) return;

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
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        await DatabaseHelper.instance.deleteMemo(userId, memo.id!);
        _loadMemos();

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

  Future<void> _loadSchedules() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final schedules = await DatabaseHelper.instance.getSchedulesByStatus(userId, ['예정', '확정']);
      final companies = await DatabaseHelper.instance.readAllCompanies(userId);

      // 업체별 색상 매핑 생성
      final Map<String, int> companyColors = {};
      for (var company in companies) {
        companyColors[company.name] = company.color;
      }

      // 스케줄 정렬
      // 1. 예정(status='예정')이 먼저, 확정(status='확정')이 나중
      // 2. 같은 상태 내에서는 visitDate 오름차순 (visitDate가 없으면 뒤로)
      schedules.sort((a, b) {
        // status 필드로 예정/확정 구분
        final aIsConfirmed = a.status == '확정';
        final bIsConfirmed = b.status == '확정';

        // 예정을 먼저, 확정을 나중에
        if (!aIsConfirmed && bIsConfirmed) return -1;
        if (aIsConfirmed && !bIsConfirmed) return 1;

        // 같은 상태 내에서: visitDate 오름차순 (null은 뒤로)
        if (a.visitDate == null && b.visitDate == null) return 0;
        if (a.visitDate == null) return 1;
        if (b.visitDate == null) return -1;
        final dateCmp = a.visitDate!.compareTo(b.visitDate!);
        if (dateCmp != 0) return dateCmp;
        // 같은 날짜면 visitTime 오름차순 (미정은 뒤로)
        if (a.visitTime == null && b.visitTime == null) return 0;
        if (a.visitTime == null) return 1;
        if (b.visitTime == null) return -1;
        return a.visitTime!.compareTo(b.visitTime!);
      });

      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _companyColors = companyColors;
        _isLoading = false;
      });

      // 위젯 업데이트
      WidgetService.updateWidget();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _schedules = [];
        _companyColors = {};
        _isLoading = false;
      });
    }
  }

  // 업체의 작업 내역이 하나라도 있는지 확인
  Future<bool> _hasAnyWorkItems() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;

      final companies = await DatabaseHelper.instance.readAllCompanies(userId);

      // 모든 업체의 작업 내역을 확인
      for (var company in companies) {
        if (company.workItems.isNotEmpty) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking work items: $e');
      return true; // 오류 시 기본 메시지 표시
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '미정';
    return DateFormat('yyyy-MM-dd(E)', 'ko_KR').format(date);
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAtSameMomentAs(today)) {
      return '${DateFormat('M월 d일 (E)', 'ko_KR').format(date)} • 오늘';
    } else if (dateOnly.isAtSameMomentAs(tomorrow)) {
      return '${DateFormat('M월 d일 (E)', 'ko_KR').format(date)} • 내일';
    } else {
      return DateFormat('M월 d일 (E)', 'ko_KR').format(date);
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

    final Map<String, int> itemCount = {};
    for (var item in workItems) {
      String cleanedItem = item.replaceAll(RegExp(r'\s+\d+건$'), '');
      itemCount[cleanedItem] = (itemCount[cleanedItem] ?? 0) + 1;
    }

    return itemCount.entries.map((e) {
      if (e.value > 1) {
        return '${e.key} ${e.value}건';
      }
      return e.key;
    }).join(', ');
  }

  // 외부에서 호출 가능한 새로고침 메서드
  void refresh() {
    _loadSchedules();
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

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      upgrader: Upgrader(
        durationUntilAlertAgain: const Duration(days: 1),
      ),
      child: Scaffold(
        appBar: GradientAppBar(
        title: '스케줄 목록',
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.business),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CompanyManagementScreen(),
                ),
              );
              // 업체 관리에서 돌아오면 색상 및 스케줄 새로고침
              _loadColors();
              _loadSchedules();
            },
            tooltip: '업체 관리',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 필터 버튼
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 20),
                      const SizedBox(width: 8),
                      const Text('필터:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('미확정 스케줄', style: TextStyle(fontSize: 13)),
                        selected: _showPendingSchedules,
                        onSelected: (value) {
                          setState(() {
                            _showPendingSchedules = value;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('오늘 스케줄', style: TextStyle(fontSize: 13)),
                        selected: _showTodayOnly,
                        onSelected: (value) {
                          setState(() {
                            _showTodayOnly = value;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
                // 스케줄 목록
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadSchedules,
                    child: Builder(
                      builder: (context) {
                        // 필터링된 스케줄 계산
                        final filteredSchedules = _schedules.where((s) {
                          // visitDate가 없는 스케줄은 항상 포함
                          if (s.visitDate == null) {
                            // 미확정 스케줄 필터
                            if (!_showPendingSchedules && s.computedStatus != '확정') return false;
                            return true;
                          }

                          // 오늘 이전 스케줄 필터 (오늘 포함, 이전 제외)
                          final today = DateTime.now();
                          final todayStart = DateTime(today.year, today.month, today.day);
                          final displayDateStart = DateTime(s.visitDate!.year, s.visitDate!.month, s.visitDate!.day);
                          if (displayDateStart.isBefore(todayStart)) return false;

                          // 미확정 스케줄 필터
                          if (!_showPendingSchedules && s.computedStatus != '확정') return false;

                          // 오늘 스케줄 필터
                          if (_showTodayOnly) {
                            if (s.visitDate!.year != today.year ||
                                s.visitDate!.month != today.month ||
                                s.visitDate!.day != today.day) {
                              return false;
                            }
                          }

                          return true;
                        }).toList()
                        ..sort((a, b) {
                          // 1. 상태별 정렬: 예정(요청) 스케줄이 확정 스케줄보다 앞에
                          if (a.computedStatus != b.computedStatus) {
                            if (a.computedStatus == '예정') return -1;
                            if (b.computedStatus == '예정') return 1;
                          }

                          // 2. 같은 상태 내에서 날짜별 정렬 (visitDate 없으면 뒤로)
                          if (a.visitDate == null && b.visitDate == null) return 0;
                          if (a.visitDate == null) return 1;
                          if (b.visitDate == null) return -1;
                          final dateCmp = a.visitDate!.compareTo(b.visitDate!);
                          if (dateCmp != 0) return dateCmp;
                          // 같은 날짜면 visitTime 오름차순 (미정은 뒤로)
                          if (a.visitTime == null && b.visitTime == null) return 0;
                          if (a.visitTime == null) return 1;
                          if (b.visitTime == null) return -1;
                          return a.visitTime!.compareTo(b.visitTime!);
                        });

                        // 스케줄이 없는 경우 메시지 표시
                        if (filteredSchedules.isEmpty) {
                          // 전체 스케줄이 비어있는지 확인
                          if (_schedules.isEmpty) {
                            // 업체의 작업 내역이 있는지 확인
                            return FutureBuilder<bool>(
                              future: _hasAnyWorkItems(),
                              builder: (context, snapshot) {
                                final hasWorkItems = snapshot.data ?? true;

                                return ListView(
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.6,
                                      child: Center(
                                        child: hasWorkItems
                                            ? Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    '등록된 스케줄이 없습니다',
                                                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                                  ),
                                                ],
                                              )
                                            : Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.business, size: 80, color: Colors.blue[300]),
                                                    const SizedBox(height: 24),
                                                    const Text(
                                                      '업체와 작업항목을 등록하고\n스케줄을 등록해보세요!',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF333333),
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 32),
                                                    Container(
                                                      padding: const EdgeInsets.all(16),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue[50],
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: Colors.blue[200]!),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [                                                          
                                                          const SizedBox(width: 8),
                                                          Flexible(
                                                            child: Text(
                                                              '상단의 아이콘을 클릭하시면\n업체 관리 화면으로 이동됩니다',
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: Colors.blue[900],
                                                                height: 1.4,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          } else {
                            // 필터링된 결과가 없는 경우
                            return ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.6,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                                        const SizedBox(height: 16),
                                        Text(
                                          '조건에 맞는 스케줄이 없습니다',
                                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                        }

                        // 날짜별 데이터 그룹화 (메모와 스케줄 포함)
                        final Map<String, List<Schedule>> confirmedByDate = {};
                        final List<Schedule> pendingSchedules = [];

                        for (var schedule in filteredSchedules) {
                          if (schedule.computedStatus == '예정') {
                            pendingSchedules.add(schedule);
                          } else if (schedule.visitDate != null) {
                            final dateKey = DateTime(
                              schedule.visitDate!.year,
                              schedule.visitDate!.month,
                              schedule.visitDate!.day,
                            ).toIso8601String();
                            confirmedByDate.putIfAbsent(dateKey, () => []).add(schedule);
                          }
                        }

                        // 메모만 있는 날짜도 포함
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);

                        for (var dateKey in _memosByDate.keys) {
                          // 오늘 이후의 메모만 표시
                          if (!dateKey.isBefore(today)) {
                            final dateKeyStr = dateKey.toIso8601String();
                            if (!confirmedByDate.containsKey(dateKeyStr)) {
                              confirmedByDate[dateKeyStr] = [];
                            }
                          }
                        }

                        // 날짜별로 정렬
                        final sortedDates = confirmedByDate.keys.toList()..sort();

                        // 스케줄 목록 표시
                        return ListView(
                          children: [
                            // 미확정 스케줄 섹션
                            if (pendingSchedules.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                                  ),
                                ),
                                child: const Text(
                                  '미확정 스케줄',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              ...pendingSchedules.map((schedule) => _buildScheduleCard(schedule, '방문일자')),
                            ],

                            // 확정 스케줄 및 메모 섹션 (날짜별)
                            ...sortedDates.map((dateKeyStr) {
                              final dateKey = DateTime.parse(dateKeyStr);
                              final schedulesForDate = confirmedByDate[dateKeyStr]!;
                              final memo = _memosByDate[dateKey];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 날짜 헤더
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    margin: const EdgeInsets.only(top: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                                      ),
                                    ),
                                    child: Text(
                                      _formatDateHeader(dateKey),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),

                                  // 메모 표시 (있는 경우)
                                  if (memo != null)
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
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
                                              memo.content,
                                              style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => _showMemoDialog(dateKey),
                                            child: const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Icon(Icons.edit, size: 18, color: Color(0xFF579bf2)),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => _deleteMemoWithConfirmation(dateKey),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Icon(Icons.delete, size: 18, color: Colors.red.shade400),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // 해당 날짜의 스케줄들
                                  ...schedulesForDate.map((schedule) => _buildScheduleCard(schedule, '')),
                                ],
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  // 스케줄 카드 빌더
  Widget _buildScheduleCard(Schedule schedule, String dateLabel) {
    final displayDate = schedule.visitDate;

    // 업체별 테두리 색상 가져오기
    final borderColor = _companyColors[schedule.companyName] != null
        ? Color(_companyColors[schedule.companyName]!)
        : Colors.grey;

    // 상태별 배경색 가져오기
    final backgroundColor = _getStatusColor(schedule.computedStatus).withValues(alpha: 1);

    // 배경색 밝기에 따라 텍스트 색상 자동 조정
    final textColor = backgroundColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: 6,
            ),
          ),
        ),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScheduleDetailScreen(schedule: schedule),
              ),
            );
            _loadSchedules();
          },
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜와 업체명
                Row(
                  children: [
                    // 확정 스케줄인 경우 날짜/시간을 파란색 볼드로
                    if (schedule.computedStatus == '확정')
                      Text(
                        '${_formatDate(displayDate)} ${schedule.visitTime ?? '미정'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 3, 66, 117),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (dateLabel.isNotEmpty)
                      Text(
                        '$dateLabel : ${_formatDate(displayDate)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      schedule.companyName.toString() == 'null' ? '' : schedule.companyName.toString(),
                      style: TextStyle(
                        fontSize: 13,
                        color: borderColor,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 고객명과 전화번호
                Row(
                  children: [
                    Text(
                      schedule.customerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatPhoneNumber(schedule.phoneNumber),
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 작업 내용
                Text(
                  _formatWorkItems(schedule.workItems),
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                // 주소
                Text(
                  schedule.address ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                // 비고 (있는 경우만)
                if (schedule.notes != null && schedule.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    schedule.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
