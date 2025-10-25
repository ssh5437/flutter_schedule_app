import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company.dart';
import '../database/database_helper.dart';
import '../widgets/gradient_app_bar.dart';

class MessageTemplateScreen extends StatefulWidget {
  final Company company;

  const MessageTemplateScreen({super.key, required this.company});

  @override
  State<MessageTemplateScreen> createState() => _MessageTemplateScreenState();
}

class _MessageTemplateScreenState extends State<MessageTemplateScreen> {
  late TextEditingController _confirmMessageController;
  late TextEditingController _absenceMessageController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _confirmMessageController = TextEditingController(text: widget.company.confirmMessage);
    _absenceMessageController = TextEditingController(text: widget.company.absenceMessage);
  }

  @override
  void dispose() {
    _confirmMessageController.dispose();
    _absenceMessageController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplates() async {
    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final updatedCompany = Company(
        id: widget.company.id,
        userId: userId,
        name: widget.company.name,
        workItems: widget.company.workItems,
        color: widget.company.color,
        confirmMessage: _confirmMessageController.text,
        absenceMessage: _absenceMessageController.text,
        displayOrder: widget.company.displayOrder,
      );

      await DatabaseHelper.instance.updateCompany(updatedCompany);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메시지 템플릿이 저장되었습니다')),
        );
        Navigator.pop(context, true); // true를 반환하여 업데이트 알림
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '메시지 템플릿 설정',
        toolbarHeight: 40,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveTemplates,
              tooltip: '저장',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내 카드
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '사용 가능한 변수',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• #{일자} - 방문 날짜\n'
                      '• #{시간} - 방문 시간\n'
                      '• #{고객명} - 고객 이름\n'
                      '• #{업체명} - 업체 이름',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 확정 메시지 템플릿
            const Text(
              '확정 메시지 템플릿',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '스케줄 확정 시 사용할 메시지 템플릿입니다',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmMessageController,
              decoration: InputDecoration(
                hintText: '예시:\n#{고객명}님, #{업체명} #{일자} #{시간} 방문 확정되었습니다.\n확인 부탁드립니다.',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.check_circle_outline, color: Colors.green),
                filled: true,
                fillColor: Colors.green.shade50,
              ),
              maxLines: 8,
              minLines: 6,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 32),

            // 부재 메시지 템플릿
            const Text(
              '부재 메시지 템플릿',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '고객 부재 시 사용할 메시지 템플릿입니다',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _absenceMessageController,
              decoration: InputDecoration(
                hintText: '예시:\n#{고객명}님, #{업체명} #{일자} #{시간} 방문 예정이었으나 부재중이셨습니다.\n확인 후 연락 부탁드립니다.',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.cancel_outlined, color: Colors.orange),
                filled: true,
                fillColor: Colors.orange.shade50,
              ),
              maxLines: 8,
              minLines: 6,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveTemplates,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? '저장 중...' : '저장'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
