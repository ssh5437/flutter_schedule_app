import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../database/database_helper.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await DatabaseHelper.instance.getSchedulesByStatus(['예정', '확정']);
      final companies = await DatabaseHelper.instance.readAllCompanies();

      // 업체별 색상 매핑 생성
      final Map<String, int> companyColors = {};
      for (var company in companies) {
        companyColors[company.name] = company.color;
      }

      setState(() {
        _schedules = schedules;
        _companyColors = companyColors;
        _isLoading = false;
      });
    } catch (e) {
      //print('Error loading schedules: $e');
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

  String _formatPhoneNumber(String phone) {
    // 전화번호 포맷팅 (010-1234-5678)
    if (phone.length == 11) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 7)}-${phone.substring(7)}';
    } else if (phone.length == 10) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}';
    }
    return phone;
  }

  // 외부에서 호출 가능한 새로고침 메서드
  void refresh() {
    _loadSchedules();
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

  // 배경색의 밝기에 따라 적절한 텍스트 색상 반환 (검정 또는 흰색)
  Color _getTextColorForBackground(Color backgroundColor) {
    // 색상의 상대 휘도(relative luminance) 계산
    final double luminance = backgroundColor.computeLuminance();
    // 휘도가 0.5보다 크면 어두운 텍스트, 작으면 밝은 텍스트
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스케줄 목록', style: TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
          : _schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '등록된 스케줄이 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSchedules,
                  child: ListView.builder(
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _schedules[index];
                      // 확정 스케줄은 방문확정일자, 그 외에는 요청일자 표시
                      final displayDate = schedule.status == '확정' && schedule.visitDate != null
                          ? schedule.visitDate!
                          : schedule.requestDate;
                      final dateLabel = schedule.status == '확정' && schedule.visitDate != null
                          ? '방문확정일자'
                          : '요청일자';

                      // 업체별 배경색 가져오기
                      final backgroundColor = _companyColors[schedule.companyName] != null
                          ? Color(_companyColors[schedule.companyName]!)
                          : Colors.white;

                      // 배경색에 맞는 텍스트 색상 계산
                      final textColor = _getTextColorForBackground(backgroundColor);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 2,
                        color: backgroundColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
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
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 상태와 날짜
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(schedule.status),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        schedule.status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$dateLabel : ${_formatDate(displayDate)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // 고객명과 전화번호
                                Row(
                                  children: [
                                    Text(
                                      '이름',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
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
                                const SizedBox(height: 6),
                                // 작업 내용
                                Text(
                                  schedule.workItems.join(', '),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // 주소
                                Text(
                                  schedule.address,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor.withValues(alpha: 0.7),
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
                      );
                    },
                  ),
                ),
    );
  }
}
