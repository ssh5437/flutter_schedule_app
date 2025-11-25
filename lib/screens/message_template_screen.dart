import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company.dart';
import '../models/message_template.dart';
import '../database/database_helper.dart';
import '../widgets/gradient_app_bar.dart';

class MessageTemplateScreen extends StatefulWidget {
  final Company company;

  const MessageTemplateScreen({super.key, required this.company});

  @override
  State<MessageTemplateScreen> createState() => _MessageTemplateScreenState();
}

class _MessageTemplateScreenState extends State<MessageTemplateScreen> {
  List<MessageTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final templates = await DatabaseHelper.instance.readAllMessageTemplates(userId, widget.company.id!);
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('템플릿 불러오기 실패: $e')),
        );
      }
    }
  }

  Future<void> _addTemplate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageTemplateFormScreen(
          company: widget.company,
        ),
      ),
    );

    if (result == true) {
      _loadTemplates();
    }
  }

  Future<void> _editTemplate(MessageTemplate template) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageTemplateFormScreen(
          company: widget.company,
          template: template,
        ),
      ),
    );

    if (result == true) {
      _loadTemplates();
    }
  }

  Future<void> _deleteTemplate(MessageTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('템플릿 삭제'),
        content: Text('"${template.name}" 템플릿을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        await DatabaseHelper.instance.deleteMessageTemplate(userId, template.id!);
        _loadTemplates();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('템플릿이 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _reorderTemplates(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _templates.removeAt(oldIndex);
      _templates.insert(newIndex, item);
    });

    // 순서 업데이트
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await DatabaseHelper.instance.updateMessageTemplatesOrder(userId, widget.company.id!, _templates);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('순서 저장 실패: $e')),
        );
      }
      _loadTemplates(); // 실패하면 다시 로드
    }
  }

  // 변수 복사 버튼 위젯
  Widget _buildVariableChip(String variable) {
    return ActionChip(
      label: Text(
        variable,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.blue.shade300),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: variable));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$variable 복사되었습니다'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: '${widget.company.name} 메시지 템플릿',
        toolbarHeight: 40,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 안내 카드
                Card(
                  margin: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
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
                        const SizedBox(height: 8),
                        const Text(
                          '• #{일자} - 방문 날짜\n'
                          '• #{시간} - 방문 시간\n'
                          '• #{고객명} - 고객 이름\n'
                          '• #{업체명} - 업체 이름',
                          style: TextStyle(fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          '변수 복사하기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildVariableChip('#{일자}'),
                            _buildVariableChip('#{시간}'),
                            _buildVariableChip('#{고객명}'),
                            _buildVariableChip('#{업체명}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 템플릿 목록
                Expanded(
                  child: _templates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.message_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                '등록된 메시지 템플릿이 없습니다',
                                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '아래 버튼을 눌러 새 템플릿을 추가하세요',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _templates.length,
                          onReorder: _reorderTemplates,
                          itemBuilder: (context, index) {
                            final template = _templates[index];
                            return Card(
                              key: ValueKey(template.id),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: const Icon(Icons.drag_handle, color: Colors.grey),
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _editTemplate(template),
                                      tooltip: '편집',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteTemplate(template),
                                      tooltip: '삭제',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTemplate,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// 메시지 템플릿 추가/편집 화면
class MessageTemplateFormScreen extends StatefulWidget {
  final Company company;
  final MessageTemplate? template;

  const MessageTemplateFormScreen({
    super.key,
    required this.company,
    this.template,
  });

  @override
  State<MessageTemplateFormScreen> createState() => _MessageTemplateFormScreenState();
}

class _MessageTemplateFormScreenState extends State<MessageTemplateFormScreen> {
  late TextEditingController _nameController;
  late TextEditingController _contentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _contentController = TextEditingController(text: widget.template?.content ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('템플릿 이름을 입력해주세요')),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메시지 내용을 입력해주세요')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      if (widget.template == null) {
        // 새 템플릿 추가
        final newTemplate = MessageTemplate(
          userId: userId,
          companyId: widget.company.id!,
          name: _nameController.text.trim(),
          content: _contentController.text.trim(),
          displayOrder: 0,
          createdAt: DateTime.now(),
        );
        await DatabaseHelper.instance.createMessageTemplate(newTemplate);
      } else {
        // 기존 템플릿 수정
        final updatedTemplate = widget.template!.copyWith(
          name: _nameController.text.trim(),
          content: _contentController.text.trim(),
        );
        await DatabaseHelper.instance.updateMessageTemplate(updatedTemplate);
      }

      if (mounted) {
        Navigator.pop(context, true);
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

  // 변수 삽입 버튼
  void _insertVariable(String variable) {
    final currentText = _contentController.text;
    final selection = _contentController.selection;
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      variable,
    );
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + variable.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: widget.template == null ? '새 템플릿' : '템플릿 편집',
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
              onPressed: _save,
              tooltip: '저장',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 템플릿 이름
            const Text(
              '템플릿 이름',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '예: 확정 안내, 일정 변경, 부재 알림',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 24),

            // 변수 삽입 버튼
            const Text(
              '변수 삽입',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('#{일자}'),
                  onPressed: () => _insertVariable('#{일자}'),
                ),
                ActionChip(
                  label: const Text('#{시간}'),
                  onPressed: () => _insertVariable('#{시간}'),
                ),
                ActionChip(
                  label: const Text('#{고객명}'),
                  onPressed: () => _insertVariable('#{고객명}'),
                ),
                ActionChip(
                  label: const Text('#{업체명}'),
                  onPressed: () => _insertVariable('#{업체명}'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 메시지 내용
            const Text(
              '메시지 내용',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: '예:\n#{고객명}님, #{업체명} #{일자} #{시간} 방문 확정되었습니다.\n확인 부탁드립니다.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              minLines: 8,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
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
