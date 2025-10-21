import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule.dart';
import '../database/database_helper.dart';
import 'schedule_detail_screen.dart';

class CompletedSchedulesScreen extends StatefulWidget {
  const CompletedSchedulesScreen({super.key});

  @override
  State<CompletedSchedulesScreen> createState() => CompletedSchedulesScreenState();
}

class CompletedSchedulesScreenState extends State<CompletedSchedulesScreen> {
  List<Schedule> _completedSchedules = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _companyColors = {}; // 업체명 -> 색상 매핑

  // 날짜 범위 관리
  int _loadedMonths = 3; // 기본 3개월
  bool _hasMoreData = true; // 더 불러올 데이터가 있는지

  @override
  void initState() {
    super.initState();
    _loadCompletedSchedules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompletedSchedules() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final companies = await DatabaseHelper.instance.readAllCompanies(userId);

      // 업체별 색상 매핑 생성
      final Map<String, int> companyColors = {};
      for (var company in companies) {
        companyColors[company.name] = company.color;
      }

      // 최근 3개월 데이터만 로드
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - _loadedMonths, now.day);
      final endDate = now;

      final schedules = await DatabaseHelper.instance.getCompletedSchedulesByDateRange(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      setState(() {
        _completedSchedules = schedules;
        _companyColors = companyColors;
        _isLoading = false;
        // 불러온 데이터가 적으면 더 이상 데이터가 없을 수 있음
        _hasMoreData = schedules.isNotEmpty;
      });
    } catch (e) {
      print('Error loading completed schedules: $e');
      setState(() {
        _completedSchedules = [];
        _companyColors = {};
        _isLoading = false;
        _hasMoreData = false;
      });
    }
  }

  Future<void> _loadMoreSchedules() async {
    if (_isLoadingMore || !_hasMoreData || _isSearching) return;

    setState(() => _isLoadingMore = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      // 추가 3개월 로드
      _loadedMonths += 3;
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - _loadedMonths, now.day);
      final endDate = now;

      final schedules = await DatabaseHelper.instance.getCompletedSchedulesByDateRange(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      setState(() {
        _completedSchedules = schedules;
        _isLoadingMore = false;
        // 새로 불러온 데이터와 기존 데이터 개수가 같으면 더 이상 없음
        _hasMoreData = schedules.length > _completedSchedules.length;
      });
    } catch (e) {
      print('Error loading more schedules: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _filterSchedules(String query) async {
    if (query.isEmpty) {
      // 검색어가 비었으면 기본 데이터로 복귀
      setState(() {
        _isSearching = false;
        _loadedMonths = 3;
      });
      _loadCompletedSchedules();
    } else {
      // DB에서 직접 검색
      setState(() => _isSearching = true);
      try {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        final schedules = await DatabaseHelper.instance.searchCompletedSchedules(userId, query);
        setState(() {
          _completedSchedules = schedules;
        });
      } catch (e) {
        print('Error searching schedules: $e');
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '미정';
    return DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(date);
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

  // 외부에서 호출 가능한 새로고침 메서드
  void refresh() {
    _loadCompletedSchedules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('완료 내역', style: TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        toolbarHeight: 40,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 검색 바
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '이름, 전화번호, 업체명으로 검색',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _filterSchedules('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: _filterSchedules,
                  ),
                ),
                // 스케줄 목록
                Expanded(
                  child: _completedSchedules.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? '검색 결과가 없습니다'
                                    : '완료된 스케줄이 없습니다',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _loadCompletedSchedules,
                                child: ListView.builder(
                                  itemCount: _completedSchedules.length,
                                  itemBuilder: (context, index) {
                                    final schedule = _completedSchedules[index];

                              // 업체별 테두리 색상 가져오기
                              final borderColor = _companyColors[schedule.companyName] != null
                                  ? Color(_companyColors[schedule.companyName]!)
                                  : Colors.grey;

                              // 완료 내역은 회색 배경 고정
                              const backgroundColor = Color.fromARGB(255, 100, 99, 99);
                              const textColor = Colors.black87;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                elevation: 2,
                                color: const Color.fromARGB(255, 190, 189, 189),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
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
                                      _loadCompletedSchedules();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 날짜와 업체명
                                          Row(
                                            children: [
                                              Text(
                                                '방문: ${_formatDate(schedule.visitDate)} ${schedule.visitTime ?? ''}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: textColor,
                                                ),
                                              ),
                                              const Spacer(),
                                              if (schedule.companyName != null)
                                                Text(
                                                  schedule.companyName!,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: textColor,
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
                                          // 주소
                                          Text(
                                            schedule.address,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: textColor,
                                            ),
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
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // 더보기 버튼
                      if (!_isSearching && _hasMoreData)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingMore ? null : _loadMoreSchedules,
                            icon: _isLoadingMore
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.expand_more),
                            label: Text(
                              _isLoadingMore
                                  ? '로딩 중...'
                                  : '이전 3개월 더보기 (현재: $_loadedMonths개월)',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
