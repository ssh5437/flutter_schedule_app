import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import 'schedule_form_screen.dart';

class ScheduleDetailScreen extends StatefulWidget {
  final Schedule schedule;

  const ScheduleDetailScreen({super.key, required this.schedule});

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  late Schedule _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '미정';
    return DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(date);
  }

  // 작업별 금액 포맷팅 (금액 정보 포함)
  String _formatWorkItemsWithPrices(List<String> workItems, Map<String, int> workPrices) {
    if (workItems.isEmpty) return '-';

    // 작업 항목별 건수 카운팅
    final Map<String, int> itemCount = {};
    for (var item in workItems) {
      String cleanedItem = item.replaceAll(RegExp(r'\s+\d+건$'), '');
      itemCount[cleanedItem] = (itemCount[cleanedItem] ?? 0) + 1;
    }

    // 금액 정보가 있으면 "항목명 건수 (금액)" 형식으로 변환
    return itemCount.entries.map((e) {
      final price = workPrices[e.key];
      if (price != null && price > 0) {
        return '${e.key} ${e.value}건 (${NumberFormat('#,###').format(price)}원)';
      }
      return '${e.key} ${e.value}건';
    }).join('\n');
  }

  Future<void> _sendSMS() async {
    final uri = Uri(scheme: 'sms', path: _schedule.phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _copyConfirmationMessage() {
    final message = '${_schedule.customerName}님, 요청하신 ${_schedule.workItems.join(', ')} 작업이 '
        '${_formatDate(_schedule.visitDate)} ${_schedule.visitTime ?? ''}으로 확정되었습니다. '
        '방문 전 다시 연락드리겠습니다.';

    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('확정 메시지가 클립보드에 복사되었습니다')),
    );
  }

  void _copyAbsentMessage() {
    final message = '${_schedule.customerName}님, ${_schedule.workItems.join(', ')} 건으로 연락드렸으나 '
        '부재중이셔서 문자 남깁니다. 확인 후 연락 부탁드립니다.';

    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('부재시 메시지가 클립보드에 복사되었습니다')),
    );
  }

  Future<void> _deleteSchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스케줄 삭제'),
        content: const Text('이 스케줄을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await DatabaseHelper.instance.deleteSchedule(userId, _schedule.id!);

      // 스케줄이 삭제되었으므로 알림 다시 설정
      await NotificationService.instance.setupDailyNotifications();

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스케줄 상세', style: TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScheduleFormScreen(schedule: _schedule),
                ),
              );
              // 수정 화면에서 돌아온 후 최신 데이터 다시 불러오기
              if (mounted) {
                final userId = Supabase.instance.client.auth.currentUser!.id;
                final updatedSchedule = await DatabaseHelper.instance.readSchedule(userId, _schedule.id!);
                if (updatedSchedule != null && mounted) {
                  setState(() {
                    _schedule = updatedSchedule;
                  });
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSchedule,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('고객명', _schedule.customerName),
            const Divider(height: 2),
            _buildInfoRow('요청일자', _formatDate(_schedule.requestDate)),
            const Divider(height: 2),
            _buildInfoRow('방문확정일자', _formatDate(_schedule.visitDate)),
            const Divider(height: 2),
            _buildInfoRow('방문확정시간', _schedule.visitTime ?? '미정'),
            const Divider(height: 2),
            _buildPhoneRow('전화번호', _schedule.phoneNumber),
            const Divider(height: 2),
            _buildInfoRow('주소', _schedule.address),
            const Divider(height: 2),
            _buildInfoRow('업체명', _schedule.companyName ?? '-'),
            const Divider(height: 2),
            _buildInfoRow('작업내용', _formatWorkItemsWithPrices(_schedule.workItems, _schedule.workPrices)),
            const Divider(height: 2),
            _buildInfoRow('작업건수', '${_schedule.workCount}건'),
            const Divider(height: 2),
            // 총 금액 표시 (금액 정보가 있는 경우에만)
            if (_schedule.workPrices.isNotEmpty && _schedule.totalPrice > 0) ...[
              _buildPriceRow('총 금액', _schedule.totalPrice),
              const Divider(height: 2),
            ],
            _buildInfoRow('비고', _schedule.notes ?? '-'),
            const Divider(height: 2),
            _buildInfoRow('상태', _schedule.status),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, int price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${NumberFormat('#,###').format(price)}원',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _sendSMS,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _copyConfirmationMessage,
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('확정 메시지', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _copyAbsentMessage,
            icon: const Icon(Icons.message, size: 18),
            label: const Text('부재시 메시지', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

}
