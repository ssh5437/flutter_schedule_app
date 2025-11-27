import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule.dart';
import '../database/database_helper.dart';
import '../services/widget_service.dart';
import '../widgets/gradient_app_bar.dart';
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
  bool _isLoading = true;
  bool _showPendingSchedules = true; // 요청 스케줄 표시 여부
  bool _showTodayOnly = false; // 오늘 스케줄만 표시 여부
  Color _pendingColor = const Color(0xFFFAE6BB); // 예정 스케줄 색상
  Color _confirmedColor = const Color(0xFFFFFFFF); // 확정 스케줄 색상 (흰색)

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 HomeScreen initState called');
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
      // 2. 예정 내에서는 requestDate 오름차순
      // 3. 확정 내에서는 visitDate 오름차순
      schedules.sort((a, b) {
        // status 필드로 예정/확정 구분
        final aIsConfirmed = a.status == '확정';
        final bIsConfirmed = b.status == '확정';

        // 예정을 먼저, 확정을 나중에
        if (!aIsConfirmed && bIsConfirmed) return -1;
        if (aIsConfirmed && !bIsConfirmed) return 1;

        // 둘 다 예정인 경우: requestDate 오름차순
        if (!aIsConfirmed && !bIsConfirmed) {
          return a.requestDate.compareTo(b.requestDate);
        }

        // 둘 다 확정인 경우: visitDate 오름차순 (visitDate가 없으면 requestDate 사용)
        final aDate = a.visitDate ?? a.requestDate;
        final bDate = b.visitDate ?? b.requestDate;
        return aDate.compareTo(bDate);
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
    return Scaffold(
      appBar: GradientAppBar(
        title: '스케줄 목록',
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.business),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CompanyManagementScreen(),
                ),
              );
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
                        label: const Text('요청 스케줄', style: TextStyle(fontSize: 13)),
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
                          // 오늘 이전 스케줄 필터 (오늘 포함, 이전 제외)
                          final today = DateTime.now();
                          final todayStart = DateTime(today.year, today.month, today.day);
                          final displayDate = s.computedStatus == '확정' && s.visitDate != null
                              ? s.visitDate!
                              : s.requestDate;
                          final displayDateStart = DateTime(displayDate.year, displayDate.month, displayDate.day);
                          if (displayDateStart.isBefore(todayStart)) return false;

                          // 요청 스케줄 필터
                          if (!_showPendingSchedules && s.computedStatus != '확정') return false;

                          // 오늘 스케줄 필터
                          if (_showTodayOnly) {
                            if (displayDate.year != today.year ||
                                displayDate.month != today.month ||
                                displayDate.day != today.day) {
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

                          // 2. 같은 상태 내에서 날짜별 정렬
                          final dateA = a.computedStatus == '확정' && a.visitDate != null
                              ? a.visitDate!
                              : a.requestDate;
                          final dateB = b.computedStatus == '확정' && b.visitDate != null
                              ? b.visitDate!
                              : b.requestDate;
                          return dateA.compareTo(dateB);
                        });

                        // 스케줄이 없는 경우 메세지 표시
                        if (filteredSchedules.isEmpty) {
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
                                        _schedules.isEmpty
                                            ? '등록된 스케줄이 없습니다'
                                            : '조건에 맞는 스케줄이 없습니다',
                                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        // 스케줄 목록 표시
                        return ListView.builder(
                          itemCount: filteredSchedules.length,
                          itemBuilder: (context, index) {
                            final schedule = filteredSchedules[index];

                            debugPrint(schedule.companyName);
                            // 확정 스케줄은 방문확정일자, 그 외에는 요청일자 표시
                            final displayDate = schedule.computedStatus == '확정' && schedule.visitDate != null
                                ? schedule.visitDate!
                                : schedule.requestDate;
                            final dateLabel = schedule.computedStatus == '확정' && schedule.visitDate != null
                                ? '방문확정일자'
                                : '요청일자';

                            // 날짜 섹션 헤더 표시 여부 확인
                            bool showDateHeader = false;
                            String headerText = '';

                            if (schedule.computedStatus == '예정') {
                              // 요청 스케줄: 첫 번째 요청 스케줄일 때만 헤더 표시
                              if (index == 0) {
                                showDateHeader = true;
                                headerText = '요청 스케줄';
                              } else {
                                final prevSchedule = filteredSchedules[index - 1];
                                if (prevSchedule.computedStatus != '예정') {
                                  showDateHeader = true;
                                  headerText = '요청 스케줄';
                                }
                              }
                            } else if (schedule.computedStatus == '확정') {
                              // 확정 스케줄: 날짜별로 헤더 표시
                              if (index == 0) {
                                showDateHeader = true;
                                headerText = _formatDateHeader(displayDate);
                              } else {
                                final prevSchedule = filteredSchedules[index - 1];
                                if (prevSchedule.computedStatus == '예정') {
                                  // 이전이 요청 스케줄이면 무조건 헤더 표시
                                  showDateHeader = true;
                                  headerText = _formatDateHeader(displayDate);
                                } else {
                                  // 이전도 확정 스케줄이면 날짜가 다를 때만 헤더 표시
                                  final prevDate = prevSchedule.visitDate ?? prevSchedule.requestDate;
                                  final prevDateOnly = DateTime(prevDate.year, prevDate.month, prevDate.day);
                                  final currentDateOnly = DateTime(displayDate.year, displayDate.month, displayDate.day);

                                  if (!prevDateOnly.isAtSameMomentAs(currentDateOnly)) {
                                    showDateHeader = true;
                                    headerText = _formatDateHeader(displayDate);
                                  }
                                }
                              }
                            }

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

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 날짜 섹션 헤더
                                if (showDateHeader)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    margin: EdgeInsets.only(top: index == 0 ? 8 : 16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                                      ),
                                    ),
                                    child: Text(
                                      headerText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),

                                // 스케줄 카드
                                Card(
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
                                                else
                                                  Text(
                                                    '$dateLabel : ${_formatDate(displayDate)}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                const Spacer(),
                                                Text(
                                                  schedule.companyName.toString() == 'null'  ? '' : schedule.companyName.toString(),
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
                                              schedule.address,
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
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
