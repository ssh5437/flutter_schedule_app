import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/schedule.dart';
import '../database/database_helper.dart';
import '../models/statistics_tab_config.dart';
import '../database/storage_helper.dart';
import 'statistics_tab_settings_screen.dart';
import '../providers/subscription_provider.dart';
import 'membership_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  List<Schedule> _allSchedules = [];
  bool _isLoading = true;
  List<StatisticsTabConfig> _tabConfigs = [];

  // 기간 선택
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    // 기본 기간: 이번 달 1일부터 오늘까지
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    _loadTabConfigs();
  }

  Future<void> _loadTabConfigs() async {
    final configs = await StorageHelper.getStatisticsTabConfig();
    final enabledTabs = configs.where((tab) => tab.isEnabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (mounted) {
      // 기존 TabController dispose
      final oldController = _tabController;

      // 새 TabController 생성
      TabController? newController;
      if (enabledTabs.isNotEmpty) {
        newController = TabController(length: enabledTabs.length, vsync: this);
      }

      setState(() {
        _tabConfigs = enabledTabs;
        _tabController = newController;
      });

      // setState 이후에 이전 컨트롤러 dispose
      oldController?.dispose();

      // 탭 설정이 로드된 후에만 스케줄 로드
      if (_allSchedules.isEmpty) {
        _loadSchedules();
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      // 완료, 확정, 예정 스케줄 모두 가져오기
      final allSchedules = await DatabaseHelper.instance.getSchedulesByStatus(userId, ['완료', '확정', '예정']);

      // 확정일시가 지난 스케줄만 매출 데이터로 필터링
      final now = DateTime.now();
      final completedSchedules = allSchedules.where((schedule) {
        // 확정일자와 시간이 있는 경우
        if (schedule.visitDate != null && schedule.visitTime != null) {
          try {
            final timeParts = schedule.visitTime!.split(':');
            final visitDateTime = DateTime(
              schedule.visitDate!.year,
              schedule.visitDate!.month,
              schedule.visitDate!.day,
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
            );
            // 확정일시가 현재 시간을 지났으면 매출 데이터로 포함
            return visitDateTime.isBefore(now);
          } catch (e) {
            // 시간 파싱 실패 시 제외
            return false;
          }
        }
        // 완료 상태인 경우는 무조건 포함
        return schedule.status == '완료';
      }).toList();

      if (mounted) {
        setState(() {
          _allSchedules = completedSchedules;
          _isLoading = false;
        });

        // 디버깅: 데이터 확인
        debugPrint('총 스케줄 수: ${allSchedules.length}');
        debugPrint('매출 데이터 스케줄 수: ${completedSchedules.length}');
        debugPrint('필터링된 스케줄 수: ${_filteredSchedules.length}');
        if (_filteredSchedules.isNotEmpty) {
          debugPrint('첫 번째 스케줄 가격: ${_filteredSchedules.first.totalPrice}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    }
  }

  // 기간 내 스케줄 필터링
  List<Schedule> get _filteredSchedules {
    return _allSchedules.where((schedule) {
      final date = schedule.visitDate ?? schedule.requestDate;
      return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
             date.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();
  }

  // 총 매출 계산
  int get _totalRevenue {
    return _filteredSchedules.fold(0, (sum, schedule) => sum + schedule.totalPrice);
  }

  // 총 작업 건수
  int get _totalCount {
    return _filteredSchedules.length;
  }

  Future<void> _openTabSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const StatisticsTabSettingsScreen(),
      ),
    );

    // 설정이 저장되었으면 다시 로드
    if (result == true && mounted) {
      await _loadTabConfigs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 38,
        title: const Text('매출 통계', style: TextStyle(fontSize: 18)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF579bf2),
                Color(0xFF7eb3f5),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 22),
            onPressed: _openTabSettings,
            tooltip: '탭 설정',
          ),
        ],
        bottom: _tabConfigs.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    indicatorSize: TabBarIndicatorSize.label,
                    tabAlignment: TabAlignment.start,
                    tabs: _tabConfigs.map((config) => Tab(
                      height: 40,
                      text: config.name,
                    )).toList(),
                  ),
                ),
              ),
      ),
      body: _isLoading || _tabConfigs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPeriodSelector(),
                _buildSummaryCards(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabConfigs.map((config) => _buildTabContent(config.id)).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabContent(String tabId) {
    switch (tabId) {
      case 'overview':
        return _buildOverviewTab();
      case 'period':
        return _buildPeriodTab();
      case 'region':
        return _buildRegionTab();
      case 'workType':
        return _buildWorkTypeTab();
      case 'company':
        return _buildCompanyTab();
      default:
        return Center(child: Text('알 수 없는 탭: $tabId'));
    }
  }

  Widget _buildPeriodSelector() {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final hasActiveSubscription = subscriptionProvider.hasActiveSubscription;

        return Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: hasActiveSubscription ? () => _selectDate(true) : _showMembershipRequiredDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF579bf2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF579bf2)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(_startDate),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('~', style: TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: InkWell(
                  onTap: hasActiveSubscription ? () => _selectDate(false) : _showMembershipRequiredDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF579bf2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF579bf2)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(_endDate),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: hasActiveSubscription ? _setLastMonth : _showMembershipRequiredDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7eb3f5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('지난달', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: hasActiveSubscription ? _setThisYear : _showMembershipRequiredDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF579bf2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('이번년', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setThisYear() {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);

    setState(() {
      _startDate = firstDayOfYear;
      _endDate = now;
    });
  }

  void _setLastMonth() {
    final now = DateTime.now();
    final firstDayOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayOfLastMonth = DateTime(now.year, now.month, 0);

    setState(() {
      _startDate = firstDayOfLastMonth;
      _endDate = lastDayOfLastMonth;
    });
  }

  void _showMembershipRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock, color: Colors.orange[700], size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '프리미엄 기능',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '무료 회원은 기간 변경이 제한됩니다.\n이번 달 매출만 조회 가능합니다.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '프리미엄 회원 혜택',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildBenefitItem('업체 추가 무제한'),
                  _buildBenefitItem('AI 텍스트 추출 무제한'),
                  _buildBenefitItem('매출 통계 기간 변경 가능'),
                  _buildBenefitItem('자동 문자 발송 기능 '),
                  _buildBenefitItem('광고 제거'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MembershipScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '멤버십 보기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[600], size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final now = DateTime.now();
    final dateToShow = isStart ? _startDate : _endDate;

    // initialDate가 lastDate(now)를 초과하지 않도록 clamp
    final initialDate = dateToShow.isAfter(now) ? now : dateToShow;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              '총 매출',
              NumberFormat('#,###').format(_totalRevenue) + '원',
              Icons.monetization_on,
              Colors.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSummaryCard(
              '총 작업',
              '$_totalCount건',
              Icons.work,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    // 월별 매출 데이터 계산
    final monthlyData = <String, int>{};
    for (var schedule in _filteredSchedules) {
      final date = schedule.visitDate ?? schedule.requestDate;
      final monthKey = DateFormat('yyyy-MM').format(date);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + schedule.totalPrice;
    }

    // 최근 12개월 데이터 준비
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final month = DateTime(now.year, now.month - i, 1);
      return DateFormat('yyyy-MM').format(month);
    }).reversed.toList();

    final chartData = months.map((month) {
      return monthlyData[month] ?? 0;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 일별 매출 추이',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildDailyTrendChart(),
          const SizedBox(height: 32),
          const Text(
            '최근 12개월 매출 추이',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: chartData.isEmpty || chartData.every((d) => d == 0)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          '선택한 기간에 매출 데이터가 없습니다',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: (chartData.reduce((a, b) => a > b ? a : b).toDouble() * 1.2).clamp(10000, double.infinity),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const Text('');
                              return Text(
                                '${(value / 10000).toInt()}만',
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < months.length) {
                                final month = months[value.toInt()];
                                return Text(
                                  month.substring(5),
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!),
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            chartData.length,
                            (i) => FlSpot(i.toDouble(), chartData[i].toDouble()),
                          ),
                          isCurved: true,
                          color: const Color(0xFF579bf2),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: const Color(0xFF579bf2),
                                strokeWidth: 1,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF579bf2).withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTrendChart() {
    // 이번 달의 일별 매출 데이터 계산
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final daysInMonth = nextMonth.difference(currentMonth).inDays;

    // 일별 매출 맵 생성
    final dailyData = <int, int>{};
    for (var schedule in _filteredSchedules) {
      final date = schedule.visitDate ?? schedule.requestDate;
      if (date.year == now.year && date.month == now.month) {
        final day = date.day;
        dailyData[day] = (dailyData[day] ?? 0) + schedule.totalPrice;
      }
    }

    // 차트 데이터 생성 (1일부터 말일까지)
    final chartData = List.generate(daysInMonth, (i) {
      final day = i + 1;
      return dailyData[day] ?? 0;
    });

    // 최대값 계산
    final maxValue = chartData.isEmpty || chartData.every((d) => d == 0)
        ? 10000
        : chartData.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 250,
      child: chartData.isEmpty || chartData.every((d) => d == 0)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '이번 달 매출 데이터가 없습니다',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : LineChart(
              LineChartData(
                minY: 0,
                maxY: (maxValue.toDouble() * 1.2).clamp(10000, double.infinity),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxValue / 4).clamp(10000, double.infinity),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Text(
                          '${(value / 10000).toInt()}만',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt() + 1;
                        if (day == 1 || day % 5 == 0 || day == daysInMonth) {
                          return Text(
                            '$day일',
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(color: Colors.grey[300]!),
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      chartData.length,
                      (i) => FlSpot(i.toDouble(), chartData[i].toDouble()),
                    ),
                    isCurved: true,
                    color: const Color(0xFF4ade80),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: const Color(0xFF4ade80),
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF4ade80).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodTab() {
    // 년도별, 월별 매출
    final yearlyData = <int, int>{};
    final monthlyData = <String, int>{};

    for (var schedule in _filteredSchedules) {
      final date = schedule.visitDate ?? schedule.requestDate;
      final year = date.year;
      final monthKey = DateFormat('yyyy-MM').format(date);

      yearlyData[year] = (yearlyData[year] ?? 0) + schedule.totalPrice;
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + schedule.totalPrice;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '년도별 매출',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...yearlyData.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Color(0xFF579bf2)),
              title: Text('${entry.key}년'),
              trailing: Text(
                '${NumberFormat('#,###').format(entry.value)}원',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        const Text(
          '월별 매출',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...(monthlyData.entries.toList()
          ..sort((a, b) => b.key.compareTo(a.key)))
          .take(12)
          .map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.date_range, color: Color(0xFF579bf2)),
                title: Text(entry.key),
                trailing: Text(
                  '${NumberFormat('#,###').format(entry.value)}원',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRegionTab() {
    // 지역별 작업 건수 계산 (주소에서 구/군 + 동 단위 추출)
    final regionData = <String, int>{};

    for (var schedule in _filteredSchedules) {
      final address = schedule.address;
      String region = '기타';

      // 주소를 공백으로 분리
      final parts = address.split(' ');

      // 구/군과 동 단위 추출
      // 주소 형식: "경기 고양시 덕양구 성사동 123-45" 또는 "서울 강남구 역삼동 123-45"
      String? district; // 구/군 (예: "덕양구", "강남구")
      String? dong;     // 동/읍/면/리 (예: "성사동", "역삼동")

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];

        // 구/군 찾기 (마지막 구/군을 저장 - 고양시 덕양구의 경우 덕양구가 저장됨)
        if (part.endsWith('구') || part.endsWith('군')) {
          district = part;
        }

        // 동/읍/면/리 찾기 (구/군 뒤에 나오는 첫 번째 동만 찾음)
        if (district != null && (part.endsWith('동') || part.endsWith('읍') || part.endsWith('면') || part.endsWith('리'))) {
          dong = part;
          break; // 첫 번째 동/읍/면/리를 찾으면 중단
        }
      }

      // 구/군과 동 조합 - 항상 구 + 동 형태로 표시
      if (district != null && dong != null) {
        // 구 + 동 형태 (예: "강남구 역삼동", "송파구 성수동")
        region = '$district $dong';
      } else if (dong != null) {
        // 구 정보가 없는 경우 동만 표시
        region = dong;
      } else if (district != null) {
        // 동 정보가 없는 경우 구만 표시
        region = district;
      }

      regionData[region] = (regionData[region] ?? 0) + 1;
    }

    final sortedRegions = regionData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 차트용 데이터: 5개 초과 시 기타로 묶기
    List<MapEntry<String, int>> chartData = [];
    if (sortedRegions.length <= 5) {
      chartData = sortedRegions;
    } else {
      // 상위 5개
      chartData = sortedRegions.take(5).toList();
      // 나머지는 기타로 묶기
      final etcSum = sortedRegions.skip(5).fold(0, (sum, e) => sum + e.value);
      if (etcSum > 0) {
        chartData.add(MapEntry('기타', etcSum));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '지역별 작업 건수',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: chartData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '선택한 기간에 데이터가 없습니다',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(
                  chartData.length,
                  (i) {
                    final total = chartData.fold(0, (sum, e) => sum + e.value);
                    final percentage = (chartData[i].value / total * 100);
                    final colors = [
                      const Color(0xFF579bf2),
                      const Color(0xFF7eb3f5),
                      const Color(0xFFabd9ff),
                      const Color(0xFF60b0ee),
                      const Color(0xFF4a90e2),
                      const Color(0xFF9ca3af), // 기타용 회색
                    ];

                    return PieChartSectionData(
                      value: chartData[i].value.toDouble(),
                      title: '${percentage.toStringAsFixed(1)}%',
                      color: colors[i % colors.length],
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
        ),
        const SizedBox(height: 24),
        ...sortedRegions.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Color(0xFF579bf2)),
              title: Text(entry.key),
              trailing: Text(
                '${entry.value}건',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWorkTypeTab() {
    // 작업 유형별 매출 계산
    final workTypeData = <String, int>{};

    for (var schedule in _filteredSchedules) {
      for (var workItem in schedule.workItems) {
        // "1way 에어컨 세척 2건" 같은 형식에서 작업명만 추출
        final cleanedItem = workItem.replaceAll(RegExp(r'\s+\d+건$'), '');
        final price = schedule.workPrices[cleanedItem] ?? 0;
        workTypeData[cleanedItem] = (workTypeData[cleanedItem] ?? 0) + price;
      }
    }

    final sortedWorkTypes = workTypeData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 차트용 데이터: 10개 초과 시 기타로 묶기
    List<MapEntry<String, int>> chartData = [];
    if (sortedWorkTypes.length <= 10) {
      chartData = sortedWorkTypes;
    } else {
      // 상위 10개
      chartData = sortedWorkTypes.take(10).toList();
      // 나머지는 기타로 묶기
      final etcSum = sortedWorkTypes.skip(10).fold(0, (sum, e) => sum + e.value);
      if (etcSum > 0) {
        chartData.add(MapEntry('기타', etcSum));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '작업 유형별 매출',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: chartData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '선택한 기간에 데이터가 없습니다',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(
                  chartData.length,
                  (i) {
                    final total = chartData.fold(0, (sum, e) => sum + e.value);
                    final percentage = (chartData[i].value / total * 100);
                    final colors = [
                      const Color(0xFF579bf2),
                      const Color(0xFF7eb3f5),
                      const Color(0xFFabd9ff),
                      const Color(0xFF60b0ee),
                      const Color(0xFF4a90e2),
                      const Color(0xFF3d7ac7),
                      const Color(0xFF93c5fd),
                      const Color(0xFF5096e8),
                      const Color(0xFF2563eb),
                      const Color(0xFF1e40af),
                      const Color(0xFF9ca3af), // 기타용 회색
                    ];

                    return PieChartSectionData(
                      value: chartData[i].value.toDouble(),
                      title: '${percentage.toStringAsFixed(1)}%',
                      color: colors[i % colors.length],
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
        ),
        const SizedBox(height: 24),
        ...sortedWorkTypes.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.build, color: Color(0xFF579bf2)),
              title: Text(entry.key),
              trailing: Text(
                '${NumberFormat('#,###').format(entry.value)}원',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCompanyTab() {
    // 업체별 매출 계산
    final companyData = <String, int>{};

    for (var schedule in _filteredSchedules) {
      final company = schedule.companyName ?? '미지정';
      companyData[company] = (companyData[company] ?? 0) + schedule.totalPrice;
    }

    final sortedCompanies = companyData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '업체별 매출',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: sortedCompanies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '선택한 기간에 데이터가 없습니다',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: sortedCompanies.first.value.toDouble() * 1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value / 10000).toInt()}만',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedCompanies.length) {
                          return Text(
                            sortedCompanies[value.toInt()].key,
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  sortedCompanies.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: sortedCompanies[i].value.toDouble(),
                        color: const Color(0xFF579bf2),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ),
        const SizedBox(height: 24),
        ...sortedCompanies.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.business, color: Color(0xFF579bf2)),
              title: Text(entry.key),
              trailing: Text(
                '${NumberFormat('#,###').format(entry.value)}원',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
