import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule.dart';
import '../database/database_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Schedule> _allSchedules = [];
  bool _isLoading = true;

  // 기간 선택
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1); // 올해 1월 1일
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        print('총 스케줄 수: ${allSchedules.length}');
        print('매출 데이터 스케줄 수: ${completedSchedules.length}');
        print('필터링된 스케줄 수: ${_filteredSchedules.length}');
        if (_filteredSchedules.isNotEmpty) {
          print('첫 번째 스케줄 가격: ${_filteredSchedules.first.totalPrice}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('매출 관리'),
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '개요'),
            Tab(text: '기간별'),
            Tab(text: '지역별'),
            Tab(text: '작업유형별'),
            Tab(text: '업체별'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPeriodSelector(),
                _buildSummaryCards(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildPeriodTab(),
                      _buildRegionTab(),
                      _buildWorkTypeTab(),
                      _buildCompanyTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _selectDate(true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF579bf2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF579bf2)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('yyyy-MM-dd').format(_startDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('~'),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _selectDate(false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF579bf2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF579bf2)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('yyyy-MM-dd').format(_endDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
      padding: const EdgeInsets.all(16),
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
          const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      gridData: const FlGridData(show: true),
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
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            chartData.length,
                            (i) => FlSpot(i.toDouble(), chartData[i].toDouble()),
                          ),
                          isCurved: true,
                          color: const Color(0xFF579bf2),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
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
        }).toList(),
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
    // 지역별 작업 건수 계산 (주소에서 시/구 추출)
    final regionData = <String, int>{};

    for (var schedule in _filteredSchedules) {
      // 주소에서 첫 번째 공백 전까지를 지역으로 간주
      final address = schedule.address;
      String region = '기타';

      if (address.contains('서울')) {
        region = '서울';
      } else if (address.contains('경기')) {
        region = '경기';
      } else if (address.contains('인천')) {
        region = '인천';
      } else if (address.contains('부산')) {
        region = '부산';
      } else if (address.contains('대구')) {
        region = '대구';
      } else if (address.contains('대전')) {
        region = '대전';
      } else if (address.contains('광주')) {
        region = '광주';
      } else if (address.contains('울산')) {
        region = '울산';
      } else if (address.contains('세종')) {
        region = '세종';
      } else {
        // 더 세밀한 지역 분류
        final parts = address.split(' ');
        if (parts.isNotEmpty) {
          region = parts[0];
        }
      }

      regionData[region] = (regionData[region] ?? 0) + 1;
    }

    final sortedRegions = regionData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          child: sortedRegions.isEmpty
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
                maxY: sortedRegions.first.value.toDouble() * 1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
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
                        if (value.toInt() >= 0 && value.toInt() < sortedRegions.length) {
                          return Text(
                            sortedRegions[value.toInt()].key,
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
                  sortedRegions.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: sortedRegions[i].value.toDouble(),
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
        }).toList(),
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
          child: sortedWorkTypes.isEmpty
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
                  sortedWorkTypes.take(5).length,
                  (i) {
                    final total = sortedWorkTypes.fold(0, (sum, e) => sum + e.value);
                    final percentage = (sortedWorkTypes[i].value / total * 100);
                    final colors = [
                      const Color(0xFF579bf2),
                      const Color(0xFF7eb3f5),
                      const Color(0xFFabd9ff),
                      const Color(0xFF60b0ee),
                      const Color(0xFF4a90e2),
                    ];

                    return PieChartSectionData(
                      value: sortedWorkTypes[i].value.toDouble(),
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
        }).toList(),
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
        }).toList(),
      ],
    );
  }
}
