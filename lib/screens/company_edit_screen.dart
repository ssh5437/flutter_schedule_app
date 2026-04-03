import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/company.dart';
import '../database/database_helper.dart';
import '../widgets/gradient_app_bar.dart';
import '../providers/subscription_provider.dart';
import '../services/analytics_service.dart';
import 'message_template_screen.dart';
import 'membership_screen.dart';

class CompanyEditScreen extends StatefulWidget {
  final Company? company;

  const CompanyEditScreen({super.key, this.company});

  @override
  State<CompanyEditScreen> createState() => _CompanyEditScreenState();
}

class _CompanyEditScreenState extends State<CompanyEditScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late List<WorkItem> _workItems;
  late Color _selectedColor;
  late String _originalCompanyName;
  bool _updateScheduleCompanyNames = false;

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadCompanyData();
    }
  }

  void _loadCompanyData() {
    _nameController = TextEditingController(text: widget.company?.name);
    _originalCompanyName = widget.company?.name ?? '';
    _workItems = widget.company?.workItems.map((item) => WorkItem(name: item.name, price: item.price)).toList() ?? [];
    _selectedColor = widget.company != null ? Color(widget.company!.color) : const Color(0xFF2196F3);
  }

  Future<void> _reloadCompanyData() async {
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

  void _handleAddWorkItem() {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final hasActiveSubscription = subscriptionProvider.hasActiveSubscription;

    const freeUserLimit = 15;

    if (!hasActiveSubscription && _workItems.length >= freeUserLimit) {
      _showUpgradeDialog();
      return;
    }

    _showWorkItemDialog();
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber[700]),
            const SizedBox(width: 8),
            const Text('Plus 기능'),
          ],
        ),
        content: const Text(
          '작업 항목은 최대 15개까지만 추가할 수 있습니다.\n\n'
          'Plus 멤버십으로 업그레이드하면 무제한으로 추가할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MembershipScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF579bf2),
              foregroundColor: Colors.white,
            ),
            child: const Text('멤버십 보기'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWorkItemDialog({WorkItem? workItem, int? index}) async {
    final nameController = TextEditingController(text: workItem?.name);
    final priceController = TextEditingController(
      text: workItem != null ? NumberFormat('#,###').format(workItem.price) : '0',
    );
    final priceFocusNode = FocusNode();

    priceFocusNode.addListener(() {
      if (priceFocusNode.hasFocus) {
        final text = priceController.text.replaceAll(',', '');
        priceController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      } else {
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            if (workItem != null) ...[
              const SizedBox(height: 12),
              const Text(
                '* 기존 스케줄에 등록된 작업 항목명은 바뀌지 않습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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

                if (widget.company != null) {
                  final userId = Supabase.instance.client.auth.currentUser!.id;
                  final updatedCompany = Company(
                    id: widget.company!.id,
                    userId: userId,
                    name: _nameController.text,
                    workItems: _workItems,
                    color: _selectedColor.toARGB32(),
                    displayOrder: widget.company!.displayOrder,
                  );

                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await DatabaseHelper.instance.updateCompany(updatedCompany);

                    if (index == null) {
                      await AnalyticsService().logFeatureUsed(
                        featureName: 'work_item_added',
                        parameters: {
                          'company_id': widget.company!.id!,
                          'work_item_name': newItem.name,
                          'work_item_price': newItem.price,
                        },
                      );
                    } else {
                      await AnalyticsService().logFeatureUsed(
                        featureName: 'work_item_edited',
                        parameters: {
                          'company_id': widget.company!.id!,
                          'work_item_name': newItem.name,
                        },
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
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

    await _reloadCompanyData();
  }

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
        displayOrder: widget.company?.displayOrder ?? 0,
      );

      try {
        if (widget.company == null) {
          await DatabaseHelper.instance.createCompany(company);
          await AnalyticsService().logCompanyCreated(workItemCount: _workItems.length);
        } else {
          await DatabaseHelper.instance.updateCompany(company);
          await AnalyticsService().logCompanyUpdated(workItemCount: _workItems.length);

          if (_updateScheduleCompanyNames && _originalCompanyName.isNotEmpty && _originalCompanyName != _nameController.text) {
            final updatedCount = await DatabaseHelper.instance.updateScheduleCompanyNames(
              userId,
              _originalCompanyName,
              _nameController.text,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('업체명 변경 완료 (스케줄 $updatedCount개 업데이트)')),
              );
            }
          }
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '업체명',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              maxLength: 10,
              validator: (value) {
                if (value == null || value.isEmpty) return '업체명을 입력해주세요';
                if (value.length > 10) return '업체명은 10자 이내로 입력해주세요';
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _updateScheduleCompanyNames = false;
                });
              },
            ),

            if (widget.company != null &&
                _originalCompanyName.isNotEmpty &&
                _nameController.text != _originalCompanyName)
              CheckboxListTile(
                title: const Text('기존 스케줄의 업체명도 모두 변경', style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                  '체크하면 이 업체로 등록된 모든 스케줄의 업체명이 변경됩니다',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _updateScheduleCompanyNames,
                onChanged: (value) {
                  setState(() {
                    _updateScheduleCompanyNames = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 8),

            // 색상 선택
            Card(
              child: ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('업체 색상'),
                subtitle: const Text(
                  '스케줄 내역에 선택한 색상이 표현됩니다. ',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
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
            const SizedBox(height: 8),

            // 메시지 템플릿 설정 버튼
            Card(
              child: ListTile(
                leading: const Icon(Icons.message),
                title: const Text('메시지 템플릿'),
                subtitle: const Text(
                  '자주 사용하는 메시지를 저장해두세요',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
                const Text('작업 항목', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _handleAddWorkItem(),
                  icon: const Icon(Icons.add),
                  label: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_workItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('작업 항목이 없습니다', style: TextStyle(color: Colors.grey)),
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
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _workItems.removeAt(oldIndex);
                    _workItems.insert(newIndex, item);
                  });

                  if (widget.company != null) {
                    final userId = Supabase.instance.client.auth.currentUser!.id;
                    final updatedCompany = Company(
                      id: widget.company!.id,
                      userId: userId,
                      name: _nameController.text,
                      workItems: _workItems,
                      color: _selectedColor.toARGB32(),
                      displayOrder: widget.company!.displayOrder,
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await DatabaseHelper.instance.updateCompany(updatedCompany);
                      if (!mounted) return;
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
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
                            child: Text('${index + 1}', style: TextStyle(color: _selectedColor)),
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

                              if (widget.company != null) {
                                final userId = Supabase.instance.client.auth.currentUser!.id;
                                final updatedCompany = Company(
                                  id: widget.company!.id,
                                  userId: userId,
                                  name: _nameController.text,
                                  workItems: _workItems,
                                  color: _selectedColor.toARGB32(),
                                  displayOrder: widget.company!.displayOrder,
                                );

                                try {
                                  await DatabaseHelper.instance.updateCompany(updatedCompany);
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveCompany,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color.fromARGB(255, 20, 137, 226),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  widget.company == null ? '업체 추가' : '수정 완료',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
