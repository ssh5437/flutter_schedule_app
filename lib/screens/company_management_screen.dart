import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company.dart';
import '../database/database_helper.dart';
import 'company_edit_screen.dart';
import '../widgets/gradient_app_bar.dart';

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
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final companies = await DatabaseHelper.instance.readAllCompanies(userId);
    setState(() {
      _companies = companies;
      _isLoading = false;
    });
  }

  Future<void> _navigateToEditScreen({Company? company}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyEditScreen(company: company),
      ),
    );

    // 편집 화면에서 저장했으면 목록 새로고침
    if (result == true) {
      _loadCompanies();
    }
  }

  Future<void> _deleteCompany(Company company) async {
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
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await DatabaseHelper.instance.deleteCompany(userId, company.id!);
      _loadCompanies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(
        title: '업체 관리',
        toolbarHeight: 40,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _companies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_center, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        '등록된 업체가 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '하단의 + 버튼을 눌러 업체를 추가하세요',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _companies.length,
                  onReorder: (oldIndex, newIndex) async {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final company = _companies.removeAt(oldIndex);
                      _companies.insert(newIndex, company);
                    });

                    // DB에 순서 저장
                    final userId = Supabase.instance.client.auth.currentUser!.id;
                    await DatabaseHelper.instance.updateCompaniesOrder(userId, _companies);
                  },
                  itemBuilder: (context, index) {
                    final company = _companies[index];
                    return Card(
                      key: ValueKey(company.id),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _navigateToEditScreen(company: company),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // 드래그 핸들
                              Icon(
                                Icons.drag_handle,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 8),
                              // 색상 표시
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Color(company.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // 업체 정보
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      company.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '작업 항목: ${company.workItems.length}개',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 삭제 버튼
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCompany(company),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToEditScreen(),
        icon: const Icon(Icons.add),
        label: const Text('업체 추가'),
      ),
    );
  }
}
