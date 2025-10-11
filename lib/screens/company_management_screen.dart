import 'package:flutter/material.dart';
import '../models/company.dart';
import '../database/database_helper.dart';

class CompanyManagementScreen extends StatefulWidget {
  const CompanyManagementScreen({super.key});

  @override
  State<CompanyManagementScreen> createState() => _CompanyManagementScreenState();
}

class _CompanyManagementScreenState extends State<CompanyManagementScreen> {
  List<Company> _companies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    final companies = await DatabaseHelper.instance.readAllCompanies();
    setState(() {
      _companies = companies;
      _isLoading = false;
    });
  }

  void _showCompanyDialog({Company? company}) {
    final nameController = TextEditingController(text: company?.name);
    final typeController = TextEditingController(text: company?.type ?? 'personal');
    List<WorkItem> workItems = company?.workItems.map((item) => WorkItem(name: item.name, price: item.price)).toList() ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(company == null ? '업체 추가' : '업체 수정'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '업체명',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: '업체 타입 (samsung/carewon/personal)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('작업 항목 및 금액', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: workItems.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          title: Text(workItems[index].name),
                          subtitle: Text('${workItems[index].price}원'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                workItems.removeAt(index);
                              });
                            },
                          ),
                          onTap: () {
                            _showWorkItemDialog(
                              context,
                              workItem: workItems[index],
                              onSave: (name, price) {
                                setDialogState(() {
                                  workItems[index] = WorkItem(name: name, price: price);
                                });
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    _showWorkItemDialog(
                      context,
                      onSave: (name, price) {
                        setDialogState(() {
                          workItems.add(WorkItem(name: name, price: price));
                        });
                      },
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('작업 항목 추가'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('업체명을 입력해주세요')),
                    );
                  }
                  return;
                }

                final newCompany = Company(
                  id: company?.id,
                  name: nameController.text,
                  type: typeController.text,
                  workItems: workItems,
                );

                if (company == null) {
                  await DatabaseHelper.instance.createCompany(newCompany);
                } else {
                  await DatabaseHelper.instance.updateCompany(newCompany);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
                _loadCompanies();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkItemDialog(
    BuildContext context, {
    WorkItem? workItem,
    required Function(String name, int price) onSave,
  }) {
    final nameController = TextEditingController(text: workItem?.name);
    final priceController = TextEditingController(text: workItem?.price.toString() ?? '0');

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
                labelText: '작업명',
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
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('작업명을 입력해주세요')),
                );
                return;
              }

              onSave(
                nameController.text,
                int.tryParse(priceController.text) ?? 0,
              );
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('업체 관리'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _companies.length,
              itemBuilder: (context, index) {
                final company = _companies[index];
                return Card(
                  child: ExpansionTile(
                    title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('타입: ${company.type} | 작업 항목: ${company.workItems.length}개'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...company.workItems.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(item.name),
                                      Text('${item.price}원', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showCompanyDialog(company: company),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('수정'),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('업체 삭제'),
                                        content: Text('${company.name}을(를) 삭제하시겠습니까?'),
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

                                    if (confirm == true) {
                                      await DatabaseHelper.instance.deleteCompany(company.id!);
                                      _loadCompanies();
                                    }
                                  },
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                  label: const Text('삭제', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCompanyDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
