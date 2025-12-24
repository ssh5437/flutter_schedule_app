import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule.dart';
import '../models/company.dart';
import '../models/message_template.dart';
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

  // 메시지 템플릿 선택 및 복사
  Future<void> _showTemplateSelector() async {
    if (_company == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업체 정보를 불러오는 중입니다')),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // 해당 업체의 모든 템플릿 가져오기
    final templates = await DatabaseHelper.instance.readAllMessageTemplates(userId, _company!.id!);

    if (!mounted) return;

    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 메시지 템플릿이 없습니다. 업체관리에서 추가해주세요')),
      );
      return;
    }

    // 템플릿 선택 Bottom Sheet 표시
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildTemplateBottomSheet(templates),
    );
  }

  Widget _buildTemplateBottomSheet(List<MessageTemplate> templates) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '메시지 템플릿 선택',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      template.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      template.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.content_copy, color: Colors.blue),
                    onTap: () {
                      _copyTemplateMessage(template);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _copyTemplateMessage(MessageTemplate template) {
    // 템플릿 변수를 실제 값으로 치환
    final message = template.replaceVariables(
      visitDate: _schedule.visitDate != null ? _formatDate(_schedule.visitDate!) : '미정',
      visitTime: _schedule.visitTime ?? '미정',
      customerName: _schedule.customerName,
      companyName: _schedule.companyName ?? '',
    );

    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${template.name}" 메시지가 복사되었습니다')),
    );

    // Analytics 로그
    AnalyticsService().logFeatureUsed(
      featureName: 'message_copied',
      parameters: {
        'template_name': template.name,
        'company_id': template.companyId,
      },
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
                const SizedBox(height: 40), // 하단 네비게이션 버튼 간섭 방지를 위한 여백
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
            // 스케줄 상태 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _schedule.computedStatus == '확정'
                    ? Colors.blue.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _schedule.computedStatus == '확정'
                        ? Icons.check_circle
                        : Icons.schedule,
                    size: 16,
                    color: _schedule.computedStatus == '확정'
                        ? Colors.blue.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _schedule.computedStatus == '확정' ? '확정 스케줄' : '미확정 스케줄',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _schedule.computedStatus == '확정'
                          ? Colors.blue.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('고객명', _schedule.customerName),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildInfoRow('방문일자', _schedule.visitDate != null ? _formatDate(_schedule.visitDate!) : '미정'),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildInfoRow('방문시간', _schedule.visitTime ?? '미정'),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildPhoneRow('전화번호', _schedule.phoneNumber),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            _buildAddressRow('주소', _schedule.address ?? ''),
            const Divider(height: 2, color: Color(0xFFabd9ff)),
            // 테스트: 지번 주소 표시 (비활성화)
            // _buildInfoRow('지번주소(테스트)', _schedule.jibunAddress ?? '없음'),
            // const Divider(height: 2, color: Color(0xFFabd9ff)),
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
    // 지번 주소가 없으면 경고 표시
    final hasJibunAddress = _schedule.jibunAddress != null && _schedule.jibunAddress!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                if (!hasJibunAddress) ...[
                  const SizedBox(width: 4),
                  const Tooltip(
                    message: '지번 주소 변환 실패',
                    child: Icon(
                      Icons.error,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ],
              ],
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showTemplateSelector,
        icon: const Icon(Icons.message),
        label: const Text('메시지 복사'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
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

    // 초기 날짜는 visitDate가 있으면 visitDate, 없으면 오늘 사용
    final initialDate = _schedule.visitDate ?? DateTime.now();

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
          visitDate: date, // 방문 예정일을 반복 날짜로 설정
          visitTime: _schedule.visitTime, // 원본의 시간 사용
          phoneNumber: _schedule.phoneNumber,
          address: _schedule.address,
          jibunAddress: _schedule.jibunAddress,
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
