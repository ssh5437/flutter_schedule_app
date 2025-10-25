import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company.dart';
import '../database/database_helper.dart';
import '../widgets/gradient_app_bar.dart';
import 'message_template_screen.dart';

class CompanyEditScreen extends StatefulWidget {
  final Company? company;

  const CompanyEditScreen({super.key, this.company});

  @override
  State<CompanyEditScreen> createState() => _CompanyEditScreenState();
}

class _CompanyEditScreenState extends State<CompanyEditScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _confirmMessageController;
  late TextEditingController _absenceMessageController;
  late List<WorkItem> _workItems;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCompanyData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _confirmMessageController.dispose();
    _absenceMessageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 데이터 새로고침
    if (state == AppLifecycleState.resumed) {
      _reloadCompanyData();
    }
  }

  void _loadCompanyData() {
    _nameController = TextEditingController(text: widget.company?.name);
    _confirmMessageController = TextEditingController(text: widget.company?.confirmMessage ?? '');
    _absenceMessageController = TextEditingController(text: widget.company?.absenceMessage ?? '');
    _workItems = widget.company?.workItems.map((item) => WorkItem(name: item.name, price: item.price)).toList() ?? [];
    _selectedColor = widget.company != null ? Color(widget.company!.color) : const Color(0xFF2196F3);
  }

  Future<void> _reloadCompanyData() async {
    // 기존 업체가 있는 경우에만 DB에서 최신 데이터 로드
    if (widget.company?.id != null) {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final companies = await DatabaseHelper.instance.readAllCompanies(userId);
      final updatedCompany = companies.firstWhere(
        (c) => c.id == widget.company!.id,
        orElse: () => widget.company!,
      );

      if (mounted) {
        setState(() {
          _nameController.text = updatedCompany.name;
          _confirmMessageController.text = updatedCompany.confirmMessage;
          _absenceMessageController.text = updatedCompany.absenceMessage;
          _workItems = updatedCompany.workItems.map((item) => WorkItem(name: item.name, price: item.price)).toList();
          _selectedColor = Color(updatedCompany.color);
        });
      }
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('색상 선택'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (Color color) {
              setState(() {
                _selectedColor = color;
              });
            },
            pickerAreaHeightPercent: 0.8,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
            labelTypes: const [],
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWorkItemDialog({WorkItem? workItem, int? index}) async {
    final nameController = TextEditingController(text: workItem?.name);
    final priceController = TextEditingController(
text: workItem != null ? NumberFormat('#,###').format(workItem.price) : '0'
);
    final priceFocusNode = FocusNode();

    // 포커스 이벤트 리스너 추가
    priceFocusNode.addListener(() {
      if (priceFocusNode.hasFocus) {
        // 포커스 받을 때: 쉼표 제거
        final text = priceController.text.replaceAll(',', '');
        priceController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      } else {
        // 포커스 잃을 때: 쉼표 추가
        final value = int.tryParse(priceController.text.replaceAll(',', '')) ?? 0;
        final formattedText = NumberFormat('#,###').format(value);
        priceController.value = TextEditingValue(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length),
        );
      }
    });

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(workItem == null ? '작업 항목 추가' : '작업 항목 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '작업 항목명',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              focusNode: priceFocusNode,
              decoration: const InputDecoration(
                labelText: '금액',
                border: OutlineInputBorder(),
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              priceFocusNode.dispose();
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newItem = WorkItem(
                  name: nameController.text,
                  price: int.tryParse(priceController.text.replaceAll(',', '')) ?? 0,
                );
                final navigator = Navigator.of(context);

                setState(() {
                  if (index != null) {
                    _workItems[index] = newItem;
                  } else {
                    _workItems.add(newItem);
                  }
                });

                // 업체가 이미 존재하는 경우 바로 데이터베이스에 저장
                if (widget.company != null) {
                  final userId = Supabase.instance.client.auth.currentUser!.id;
                  final updatedCompany = Company(
                    id: widget.company!.id,
                    userId: userId,
                    name: _nameController.text,
                    workItems: _workItems,
                    color: _selectedColor.toARGB32(),
                    confirmMessage: _confirmMessageController.text,
                    absenceMessage: _absenceMessageController.text,
                  );

                  try {
                    await DatabaseHelper.instance.updateCompany(updatedCompany);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('저장 실패: $e')),
                      );
                    }
                  }
                }

                priceFocusNode.dispose();
                if (mounted) {
                  navigator.pop();
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );

    // 다이얼로그가 닫힌 후 데이터 새로고침
    await _reloadCompanyData();
  }

  // 메시지 템플릿 설정 화면으로 이동
  Future<void> _navigateToMessageTemplate() async {
    if (widget.company == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업체를 먼저 저장해주세요')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageTemplateScreen(company: widget.company!),
      ),
    );

    // 템플릿이 업데이트되면 화면 새로고침
    if (result == true) {
      await _reloadCompanyData();
    }
  }

  Future<void> _saveCompany() async {
    if (_formKey.currentState!.validate()) {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final company = Company(
        id: widget.company?.id,
        userId: userId,
        name: _nameController.text,
        workItems: _workItems,
        color: _selectedColor.toARGB32(),
        confirmMessage: _confirmMessageController.text,
        absenceMessage: _absenceMessageController.text,
      );

      try {
        if (widget.company == null) {
          await DatabaseHelper.instance.createCompany(company);
        } else {
          await DatabaseHelper.instance.updateCompany(company);
        }

        if (mounted) {
          Navigator.pop(context, true); // true를 반환하여 목록 새로고침 트리거
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 실패: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: widget.company == null ? '업체 추가' : '업체 수정',
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveCompany,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 업체명
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '업체명',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              maxLength: 10,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '업체명을 입력해주세요';
                }
                if (value.length > 10) {
                  return '업체명은 10자 이내로 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 색상 선택
            Card(
              child: ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('업체 색상'),
                trailing: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                ),
                onTap: _showColorPicker,
              ),
            ),
            const SizedBox(height: 24),

            // 메시지 템플릿 설정 버튼
            Card(
              child: ListTile(
                leading: const Icon(Icons.message),
                title: const Text('메시지 템플릿'),
                subtitle: Text(
                  _confirmMessageController.text.isEmpty && _absenceMessageController.text.isEmpty
                      ? '확정/부재 메시지 템플릿 미설정'
                      : '확정/부재 메시지 템플릿 설정됨',
                  style: TextStyle(
                    fontSize: 12,
                    color: _confirmMessageController.text.isEmpty && _absenceMessageController.text.isEmpty
                        ? Colors.grey
                        : Colors.green,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _navigateToMessageTemplate,
              ),
            ),
            const SizedBox(height: 24),

            // 작업 항목 섹션
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '작업 항목',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showWorkItemDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 작업 항목 리스트
            if (_workItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      '작업 항목이 없습니다',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _workItems.length,
                onReorder: (oldIndex, newIndex) async {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _workItems.removeAt(oldIndex);
                    _workItems.insert(newIndex, item);
                  });

                  // 업체가 이미 존재하는 경우 바로 데이터베이스에 저장
                  if (widget.company != null) {
                    final userId = Supabase.instance.client.auth.currentUser!.id;
                    final updatedCompany = Company(
                      id: widget.company!.id,
                      userId: userId,
                      name: _nameController.text,
                      workItems: _workItems,
                      color: _selectedColor.toARGB32(),
                      confirmMessage: _confirmMessageController.text,
                      absenceMessage: _absenceMessageController.text,
                    );

                    try {
                      await DatabaseHelper.instance.updateCompany(updatedCompany);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('저장 실패: $e')),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (context, index) {
                  final item = _workItems[index];
                  return Card(
                    key: ValueKey(item.name + index.toString()),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.drag_handle, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: _selectedColor.withValues(alpha: 0.2),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(color: _selectedColor),
                            ),
                          ),
                        ],
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        '${NumberFormat('#,###').format(item.price)}원',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showWorkItemDialog(workItem: item, index: index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);

                              setState(() {
                                _workItems.removeAt(index);
                              });

                              // 업체가 이미 존재하는 경우 바로 데이터베이스에 저장
                              if (widget.company != null) {
                                final userId = Supabase.instance.client.auth.currentUser!.id;
                                final updatedCompany = Company(
                                  id: widget.company!.id,
                                  userId: userId,
                                  name: _nameController.text,
                                  workItems: _workItems,
                                  color: _selectedColor.toARGB32(),
                                  confirmMessage: _confirmMessageController.text,
                                  absenceMessage: _absenceMessageController.text,
                                );

                                try {
                                  await DatabaseHelper.instance.updateCompany(updatedCompany);
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('저장 실패: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
