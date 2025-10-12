import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/schedule.dart';
import '../database/storage_helper.dart';
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
      await StorageHelper.deleteSchedule(_schedule.id!);
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
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScheduleFormScreen(schedule: _schedule),
                ),
              );
              if (result != null && mounted) {
                setState(() {
                  _schedule = result;
                });
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('고객명', _schedule.customerName),
            const Divider(),
            _buildInfoRow('요청일자', _formatDate(_schedule.requestDate)),
            const Divider(),
            _buildInfoRow('방문확정일자', _formatDate(_schedule.visitDate)),
            const Divider(),
            _buildInfoRow('방문확정시간', _schedule.visitTime ?? '미정'),
            const Divider(),
            _buildPhoneRow('전화번호', _schedule.phoneNumber),
            const Divider(),
            _buildInfoRow('주소', _schedule.address),
            const Divider(),
            _buildInfoRow('업체명', _schedule.companyName ?? '-'),
            const Divider(),
            _buildInfoRow('작업내용', _schedule.workItems.join(', ')),
            const Divider(),
            _buildInfoRow('작업건수', '${_schedule.workCount}건'),
            const Divider(),
            _buildInfoRow('비고', _schedule.notes ?? '-'),
            const Divider(),
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

  Widget _buildPhoneRow(String label, String value) {
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
