import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import '../models/company.dart';
import '../database/database_helper.dart';

class CompanyEditScreen extends StatefulWidget {
  final Company? company;

  const CompanyEditScreen({super.key, this.company});

  @override
  State<CompanyEditScreen> createState() => _CompanyEditScreenState();
}

class _CompanyEditScreenState extends State<CompanyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late List<WorkItem> _workItems;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.company?.name);
    _workItems = widget.company?.workItems.map((item) => WorkItem(name: item.name, price: item.price)).toList() ?? [];
    _selectedColor = widget.company != null ? Color(widget.company!.color) : const Color(0xFF2196F3);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  void _showWorkItemDialog({WorkItem? workItem, int? index}) {
    final nameController = TextEditingController(text: workItem?.name);
    final priceController = TextEditingController(
text: workItem != null ? NumberFormat('#,###').format(workItem.price) : '0'
);

    showDialog(
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
              decoration: const InputDecoration(
                labelText: '금액',
                border: OutlineInputBorder(),
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  final newItem = WorkItem(
                    name: nameController.text,
                    price: int.tryParse(priceController.text) ?? 0,
                  );
                  if (index != null) {
                    _workItems[index] = newItem;
                  } else {
                    _workItems.add(newItem);
                  }
                });
                Navigator.pop(context);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCompany() async {
    if (_formKey.currentState!.validate()) {
      final company = Company(
        id: widget.company?.id,
        name: _nameController.text,
        workItems: _workItems,
        color: _selectedColor.toARGB32(),
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
      appBar: AppBar(
        title: Text(
          widget.company == null ? '업체 추가' : '업체 수정',
          style: const TextStyle(fontSize: 18),
        ),
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '업체명을 입력해주세요';
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _workItems.length,
                itemBuilder: (context, index) {
                  final item = _workItems[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _selectedColor.withValues(alpha: 0.2),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: _selectedColor),
                        ),
                      ),
                      title: Text(item.name),
                      subtitle: Text('${item.price}원'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showWorkItemDialog(workItem: item, index: index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _workItems.removeAt(index);
                              });
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
