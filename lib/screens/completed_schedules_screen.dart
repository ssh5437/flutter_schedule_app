import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCompletedSchedules();
  }

  Future<void> _loadCompletedSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await DatabaseHelper.instance.getCompletedSchedules();
      setState(() {
        _completedSchedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading completed schedules: $e');
      setState(() {
        _completedSchedules = [];
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '미정';
    return DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(date);
  }

  // 외부에서 호출 가능한 새로고침 메서드
  void refresh() {
    _loadCompletedSchedules();
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
          : _completedSchedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '완료된 스케줄이 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCompletedSchedules,
                  child: ListView.builder(
                    itemCount: _completedSchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = _completedSchedules[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(schedule.status),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                          title: Text(
                            schedule.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('방문: ${_formatDate(schedule.visitDate)} ${schedule.visitTime ?? ''}'),
                              Text('작업: ${schedule.workItems.join(', ')} (${schedule.workCount}건)'),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScheduleDetailScreen(schedule: schedule),
                              ),
                            );
                            _loadCompletedSchedules();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
