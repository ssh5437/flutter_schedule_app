import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../models/company.dart';
import '../database/database_helper.dart';

class ScheduleFormScreen extends StatefulWidget {
  final Schedule? schedule;

  const ScheduleFormScreen({super.key, this.schedule});

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _workCountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _requestDate = DateTime.now();
  DateTime? _visitDate;
  String? _visitTime;
  Map<String, int> _workItemsWithCount = {}; // 작업 항목과 건수

  List<Company> _companies = [];
  Company? _selectedCompany;
  bool _isLoadingCompanies = true;

  // 방문시간 옵션 (5:00 ~ 23:00, 30분 단위)
  List<String> get _timeOptions {
    List<String> times = [];
    for (int hour = 5; hour <= 23; hour++) {
      times.add('${hour.toString().padLeft(2, '0')}:00');
      if (hour < 23) {
        times.add('${hour.toString().padLeft(2, '0')}:30');
      }
    }
    return times;
  }

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    if (widget.schedule != null) {
      _loadScheduleData();
    } else {
      // 새 스케줄 추가 시 작업 건수 기본값 1
      _workCountController.text = '1';
    }
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoadingCompanies = true);
    final companies = await DatabaseHelper.instance.readAllCompanies();
    setState(() {
      _companies = companies;
      _isLoadingCompanies = false;
      // 기본값으로 첫 번째 업체 선택 (보통 "개인")
      if (_companies.isNotEmpty && _selectedCompany == null) {
        _selectedCompany = _companies.first;
      }
    });
  }

  void _loadScheduleData() {
    final schedule = widget.schedule!;
    _customerNameController.text = schedule.customerName;
    _phoneNumberController.text = schedule.phoneNumber;
    _addressController.text = schedule.address;
    _notesController.text = schedule.notes ?? '';
    _requestDate = schedule.requestDate;
    _visitDate = schedule.visitDate;
    _visitTime = schedule.visitTime;

    // 업체명으로 업체 찾기
    if (schedule.companyName != null) {
      _selectedCompany = _companies.firstWhere(
        (c) => c.name == schedule.companyName,
        orElse: () => _companies.first,
      );
    }

    // 기존 데이터에서 작업 항목 파싱
    _workItemsWithCount.clear();
    int totalCount = 0;
    for (var item in schedule.workItems) {
      _workItemsWithCount[item] = 1;
      totalCount += 1;
    }
    _workCountController.text = totalCount.toString();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _workCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectRequestDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _requestDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _requestDate = picked;
      });
    }
  }

  Future<void> _selectVisitDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visitDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  void _showTimePickerMenu(BuildContext context) {
    final scrollController = ScrollController();
    final allTimeOptions = ['미정', ..._timeOptions];

    // 12:00의 인덱스 계산
    final noonIndex = allTimeOptions.indexOf('12:00');
    final itemHeight = 48.0;

    showDialog(
      context: context,
      builder: (context) {
        // 다이얼로그가 열린 후 12:00으로 스크롤
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            final screenHeight = MediaQuery.of(context).size.height;
            final dialogHeight = screenHeight * 0.6;
            final targetOffset = (noonIndex * itemHeight) - (dialogHeight / 2) + (itemHeight / 2);

            scrollController.jumpTo(
              targetOffset.clamp(0.0, scrollController.position.maxScrollExtent),
            );
          }
        });

        return AlertDialog(
          title: const Text('방문시간 선택'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: ListView.builder(
              controller: scrollController,
              itemCount: allTimeOptions.length,
              itemBuilder: (context, index) {
                final time = allTimeOptions[index];
                final isSelected = (time == '미정' && _visitTime == null) || time == _visitTime;

                return ListTile(
                  dense: true,
                  title: Text(
                    time,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _visitTime = time == '미정' ? null : time;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  void _showWorkItemsDialog() {
    if (_selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 업체를 선택해주세요')),
      );
      return;
    }

    if (_selectedCompany!.workItems.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('작업 항목 없음'),
          content: const Text('업체 관리에서 작업 항목을 추가해주세요'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    final tempWorkItems = Map<String, int>.from(_workItemsWithCount);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${_selectedCompany!.name} - 작업 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _selectedCompany!.workItems.map((workItem) {
                return ListTile(
                  dense: true,
                  title: Text(workItem.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text('${workItem.price}원', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tempWorkItems.containsKey(workItem.name)) ...[
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () {
                            setDialogState(() {
                              if (tempWorkItems[workItem.name]! > 1) {
                                tempWorkItems[workItem.name] = tempWorkItems[workItem.name]! - 1;
                              } else {
                                tempWorkItems.remove(workItem.name);
                              }
                            });
                          },
                        ),
                        Text(
                          '${tempWorkItems[workItem.name]}건',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () {
                            setDialogState(() {
                              tempWorkItems[workItem.name] = tempWorkItems[workItem.name]! + 1;
                            });
                          },
                        ),
                      ] else
                        IconButton(
                          icon: const Icon(Icons.add_circle, size: 20, color: Colors.blue),
                          onPressed: () {
                            setDialogState(() {
                              tempWorkItems[workItem.name] = 1;
                            });
                          },
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _workItemsWithCount = tempWorkItems;
                  // 총 건수 자동 계산
                  int total = _workItemsWithCount.values.fold(0, (sum, count) => sum + count);
                  _workCountController.text = total.toString();
                });
                Navigator.pop(context);
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업체를 선택해주세요')),
      );
      return;
    }

    if (_workItemsWithCount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작업 내용을 선택해주세요')),
      );
      return;
    }

    // 상태 자동 설정
    final autoStatus = (_visitDate != null && _visitTime != null) ? '확정' : '예정';

    // 작업 항목을 "항목명 건수" 형식으로 변환
    final workItemsList = _workItemsWithCount.entries
        .map((e) => '${e.key} ${e.value}건')
        .toList();

    final schedule = Schedule(
      id: widget.schedule?.id,
      customerName: _customerNameController.text,
      requestDate: _requestDate,
      visitDate: _visitDate,
      visitTime: _visitTime,
      phoneNumber: _phoneNumberController.text,
      address: _addressController.text,
      companyName: _selectedCompany!.name,
      workItems: workItemsList,
      workCount: int.parse(_workCountController.text),
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      status: autoStatus,
    );

    if (widget.schedule == null) {
      await DatabaseHelper.instance.createSchedule(schedule);
    } else {
      await DatabaseHelper.instance.updateSchedule(schedule);
    }

    if (mounted) {
      Navigator.pop(context, schedule);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schedule == null ? '스케줄 추가' : '스케줄 수정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSchedule,
          ),
        ],
      ),
      body: _isLoadingCompanies
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        children: [
                          // 업체 선택 드롭다운
                          DropdownButtonFormField<Company>(
                            initialValue: _selectedCompany,
                            decoration: const InputDecoration(
                              labelText: '업체 *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            items: _companies.map((company) {
                              return DropdownMenuItem(
                                value: company,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Color(company.color),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(company.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (Company? newValue) {
                              setState(() {
                                _selectedCompany = newValue;
                                // 업체 변경 시 작업 항목 초기화
                                _workItemsWithCount.clear();
                                _workCountController.text = '0';
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return '업체를 선택해주세요';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _customerNameController,
                            decoration: const InputDecoration(
                              labelText: '고객명 *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '고객명을 입력해주세요';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectRequestDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '요청일자 *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                                suffixIcon: Icon(Icons.calendar_today, size: 20),
                              ),
                              child: Text(
                                DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(_requestDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _selectVisitDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: '방문확정일자',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      isDense: true,
                                      suffixIcon: Icon(Icons.calendar_today, size: 20),
                                    ),
                                    child: Text(
                                      _visitDate != null
                                          ? DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(_visitDate!)
                                          : '미정',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _showTimePickerMenu(context),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: '방문시간',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                    child: Text(
                                      _visitTime ?? '미정',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneNumberController,
                            decoration: const InputDecoration(
                              labelText: '전화번호 *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '전화번호를 입력해주세요';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: '주소 *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '주소를 입력해주세요';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _showWorkItemsDialog,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '작업 내용 *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                                suffixIcon: Icon(Icons.add, size: 20),
                              ),
                              child: Text(
                                _workItemsWithCount.isEmpty
                                    ? '선택된 항목 없음'
                                    : _workItemsWithCount.entries
                                        .map((e) => '${e.key} ${e.value}건')
                                        .join(', '),
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _workCountController,
                            decoration: const InputDecoration(
                              labelText: '총 작업 건수',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                              filled: true,
                              fillColor: Color(0xFFF5F5F5),
                            ),
                            readOnly: true,
                            enabled: false,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: '비고',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSchedule,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        widget.schedule == null ? '스케줄 추가' : '수정 완료',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
