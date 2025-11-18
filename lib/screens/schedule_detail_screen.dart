import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule.dart';
import '../models/company.dart';
import '../models/repeat_config.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../services/analytics_service.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/repeat_schedule_dialog.dart';
import 'schedule_form_screen.dart';

class ScheduleDetailScreen extends StatefulWidget {
  final Schedule schedule;

  const ScheduleDetailScreen({super.key, required this.schedule});

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  late Schedule _schedule;
  Company? _company;

  @override
  void initState() {
    super.initState();
    _schedule = widget.schedule;
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final companies = await DatabaseHelper.instance.readAllCompanies(userId);
      final company = companies.firstWhere(
        (c) => c.name == _schedule.companyName,
        orElse: () => companies.first,
      );
      if (mounted) {
        setState(() {
          _company = company;
        });
      }
    } catch (e) {
      // 업체 정보를 가져오지 못한 경우 무시
    }
  }

  // 템플릿 변수를 실제 값으로 치환
  String _replaceTemplateVariables(String? template) {
    if (template == null || template.isEmpty) return '';

    final date = _formatDate(_schedule.visitDate ?? _schedule.requestDate);
    final time = _schedule.visitTime ?? '미정';
    final customerName = _schedule.customerName;
    final companyName = _schedule.companyName ?? '';

    return template
        .replaceAll('#{일자}', date)
        .replaceAll('#{시간}', time)
        .replaceAll('#{고객명}', customerName)
        .replaceAll('#{업체명}', companyName);
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
    String message;

    // 업체에 확정 메시지 템플릿이 있으면 사용, 없으면 기본 메시지
    if (_company != null && _company!.confirmMessage.isNotEmpty) {
      message = _replaceTemplateVariables(_company!.confirmMessage);
    } else {
      // 기본 메시지
      message = '${_schedule.customerName}님, 요청하신 ${_schedule.workItems.join(', ')} 작업이 '
          '${_formatDate(_schedule.visitDate)} ${_schedule.visitTime ?? ''}으로 확정되었습니다. '
          '방문 전 다시 연락드리겠습니다.';
    }

    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('확정 메시지가 클립보드에 복사되었습니다')),
    );
  }

  void _copyAbsentMessage() {
    String message;

    // 업체에 부재 메시지 템플릿이 있으면 사용, 없으면 기본 메시지
    if (_company != null && _company!.absenceMessage.isNotEmpty) {
      message = _replaceTemplateVariables(_company!.absenceMessage);
    } else {
      // 기본 메시지
      message = '${_schedule.customerName}님, ${_schedule.workItems.join(', ')} 건으로 연락드렸으나 '
          '부재중이셔서 문자 남깁니다. 확인 후 연락 부탁드립니다.';
    }

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

      // 위젯 업데이트
      await WidgetService.updateWidget();

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _openMap(String address) async {
    // 안드로이드에서는 geo: URI를 사용하여 앱 선택기를 띄웁니다
    // q 파라미터에 주소를 넣으면 다양한 지도/네비게이션 앱에서 처리 가능
    final uri = Uri.parse('geo:0,0?q=${Uri.encodeComponent(address)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 외부 앱으로 실행
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('지도 앱을 열 수 없습니다')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '스케줄 상세',
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
              // 방문확정일자와 시간이 있는 경우에만 반복 등록 버튼 표시
              if (_schedule.visitDate != null && _schedule.visitTime != null) ...[
                const SizedBox(height: 12),
                _buildRepeatButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: const Color.fromARGB(255, 255, 255, 255),
      
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('고객명', _schedule.customerName),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildInfoRow('요청일자', _formatDate(_schedule.requestDate)),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildInfoRow('방문확정일자', _formatDate(_schedule.visitDate)),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildInfoRow('방문확정시간', _schedule.visitTime ?? '미정'),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildPhoneRow('전화번호', _schedule.phoneNumber),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildAddressRow('주소', _schedule.address),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildInfoRow('업체명', _schedule.companyName ?? '-'),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildInfoRow('작업내용', _formatWorkItemsWithPrices(_schedule.workItems, _schedule.workPrices)),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildInfoRow('작업건수', '${_schedule.workCount}건'),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            // 총 금액 표시 (금액 정보가 있는 경우에만)
            if (_schedule.workPrices.isNotEmpty && _schedule.totalPrice > 0) ...[
              _buildPriceRow('총 금액', _schedule.totalPrice),
              const Divider(height: 2, color: Color(0xFFabd9ff)),
            ],
            _buildInfoRow('비고', _schedule.notes ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
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
      padding: const EdgeInsets.symmetric(vertical: 12.0),
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
      padding: const EdgeInsets.symmetric(vertical: 12.0),
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

  Widget _buildAddressRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
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
          IconButton(
            icon: const Icon(Icons.map, color: Colors.blue, size: 24),
            onPressed: () => _openMap(value),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: '지도에서 보기',
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

  Widget _buildRepeatButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showRepeatDialog,
        icon: const Icon(Icons.repeat),
        label: const Text('스케줄 반복 등록'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF579bf2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFF579bf2)),
        ),
      ),
    );
  }

  Future<void> _showRepeatDialog() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // 초기 날짜는 visitDate가 있으면 visitDate, 없으면 requestDate 사용
    final initialDate = _schedule.visitDate ?? _schedule.requestDate;

    final result = await showDialog<RepeatConfig>(
      context: context,
      builder: (context) => RepeatScheduleDialog(
        initialDate: initialDate,
      ),
    );

    if (result == null || !mounted) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final dates = result.generateDates();
      int successCount = 0;

      for (final date in dates) {
        // 원본 스케줄을 복사하여 새로운 날짜로 생성
        final newSchedule = Schedule(
          userId: userId,
          customerName: _schedule.customerName,
          requestDate: DateTime.now(), // 요청일은 현재
          visitDate: date, // 방문 예정일을 반복 날짜로 설정
          visitTime: _schedule.visitTime, // 원본의 시간 사용
          phoneNumber: _schedule.phoneNumber,
          address: _schedule.address,
          companyName: _schedule.companyName,
          workItems: _schedule.workItems,
          workPrices: _schedule.workPrices,
          workCount: _schedule.workCount,
          notes: _schedule.notes,
          status: '예정', // 반복 등록된 스케줄은 기본적으로 '예정' 상태
        );

        await DatabaseHelper.instance.createSchedule(newSchedule);
        successCount++;
      }

      // 위젯 업데이트
      await WidgetService.updateWidget();

      // 알림 재설정
      await NotificationService.instance.setupDailyNotifications();

      // Analytics 로그
      await AnalyticsService().logFeatureUsed(
        featureName: 'repeat_schedule',
        parameters: {
          'repeat_type': result.type.toString(),
          'count': dates.length,
        },
      );

      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기

        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount개의 스케줄이 등록되었습니다.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('스케줄 등록 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}
