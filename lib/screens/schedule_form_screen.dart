import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
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
  final _companyNameController = TextEditingController();
  final _workCountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _requestDate = DateTime.now();
  DateTime? _visitDate;
  String? _visitTime;
  Map<String, int> _workItemsWithCount = {}; // 작업 항목과 건수
  String _selectedCompanyType = 'personal'; // samsung, carewon, personal
  String _inputMode = 'manual'; // manual, text_samsung, text_carewon

  // 미리 정의된 작업 항목
  final List<String> _predefinedWorkItems = [
    '1way 에어컨',
    '2way 에어컨',
    '스텐드 에어컨',
    '벽걸이 에어컨',
    '드럼세탁기',
    '통돌이세탁기',
    '냉장고',
    '입주 청소',
    '이사 청소',
    '정기 청소',
  ];

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
    if (widget.schedule != null) {
      _loadScheduleData();
    } else {
      // 새 스케줄 추가 시 작업 건수 기본값 1
      _workCountController.text = '1';
    }
  }

  void _loadScheduleData() {
    final schedule = widget.schedule!;
    _customerNameController.text = schedule.customerName;
    _phoneNumberController.text = schedule.phoneNumber;
    _addressController.text = schedule.address;
    _companyNameController.text = schedule.companyName ?? '';
    _notesController.text = schedule.notes ?? '';
    _requestDate = schedule.requestDate;
    _visitDate = schedule.visitDate;
    _visitTime = schedule.visitTime;

    // 기존 데이터에서 작업 항목 파싱 (형식: "벽걸이 에어컨 1건, 냉장고 2건")
    _workItemsWithCount.clear();
    int totalCount = 0;
    for (var item in schedule.workItems) {
      // 간단하게 1건으로 처리 (기존 데이터 호환)
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
    _companyNameController.dispose();
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
            // 12:00이 중앙에 오도록 스크롤
            final screenHeight = MediaQuery.of(context).size.height;
            final dialogHeight = screenHeight * 0.6; // 다이얼로그 높이의 60%
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

  // 케어원 텍스트 파싱
  Map<String, dynamic> _parseCareWonText(String text) {
    final result = <String, dynamic>{};

    // 고객명 파싱 (케어원 형식에 맞게 수정 필요)
    final nameMatch = RegExp(r'고객명[:\s]*(.+?)(?:\n|전화)').firstMatch(text);
    if (nameMatch != null) {
      result['customerName'] = nameMatch.group(1)?.trim();
    }

    // 전화번호 파싱
    final phoneMatch = RegExp(r'전화번호?[:\s]*(\d{2,3}-\d{3,4}-\d{4})').firstMatch(text);
    if (phoneMatch != null) {
      result['phoneNumber'] = phoneMatch.group(1);
    }

    // 주소 파싱
    final addressMatch = RegExp(r'주소[:\s]*(.+?)(?=\n\n|\n작업|\n날짜)').firstMatch(text);
    if (addressMatch != null) {
      result['address'] = addressMatch.group(1)?.trim().replaceAll('\n', ' ');
    }

    // 작업일자 파싱
    final dateMatch = RegExp(r'(?:작업일|방문일|날짜)[:\s]*(\d{4})[-.년\s]*(\d{1,2})[-.월\s]*(\d{1,2})').firstMatch(text);
    if (dateMatch != null) {
      final year = int.parse(dateMatch.group(1)!);
      final month = int.parse(dateMatch.group(2)!);
      final day = int.parse(dateMatch.group(3)!);

      result['requestDate'] = DateTime(year, month, day);
    }

    // 작업 항목 파싱
    final workItems = <String, int>{};

    if (text.contains('벽걸이') || text.contains('벽걸이 에어컨')) {
      workItems['벽걸이 에어컨'] = 1;
    }
    if (text.contains('스텐드') || text.contains('스텐드 에어컨')) {
      workItems['스텐드 에어컨'] = 1;
    }
    if (text.contains('드럼') || text.contains('드럼세탁기')) {
      workItems['드럼세탁기'] = 1;
    }
    if (text.contains('통돌이') || text.contains('통돌이세탁기')) {
      workItems['통돌이세탁기'] = 1;
    }
    if (text.contains('냉장고')) {
      workItems['냉장고'] = 1;
    }

    if (workItems.isNotEmpty) {
      result['workItems'] = workItems;
    }

    // 업체명
    result['companyName'] = '케어원';

    return result;
  }

  // 삼성케어플러스 텍스트 파싱
  Map<String, dynamic> _parseSamsungCareText(String text) {
    final result = <String, dynamic>{};

    // 고객명 파싱
    final nameMatch = RegExp(r'성명\s*(.+?)(?:\n|전화)').firstMatch(text);
    if (nameMatch != null) {
      result['customerName'] = nameMatch.group(1)?.trim();
    }

    // 전화번호 파싱
    final phoneMatch = RegExp(r'전화\s*(\d{3}-\d{4}-\d{4})').firstMatch(text);
    if (phoneMatch != null) {
      result['phoneNumber'] = phoneMatch.group(1);
    }

    // 주소 파싱
    final addressMatch = RegExp(r'주소\s*(.+?)(?=\n\n|\n판매)').firstMatch(text);
    if (addressMatch != null) {
      result['address'] = addressMatch.group(1)?.trim().replaceAll('\n', ' ');
    }

    // 약속일시 파싱 (요청일자로 설정, 오전/오후는 비고에 추가)
    final dateMatch = RegExp(r'약속일시\s*(\d{4})-(\d{2})-(\d{2})\s*(오전|오후)?').firstMatch(text);
    if (dateMatch != null) {
      final year = int.parse(dateMatch.group(1)!);
      final month = int.parse(dateMatch.group(2)!);
      final day = int.parse(dateMatch.group(3)!);
      final period = dateMatch.group(4);

      result['requestDate'] = DateTime(year, month, day);

      // 오전/오후는 비고에 추가
      if (period != null) {
        result['notes'] = '$period 요청';
      }
    }

    // 작업 항목 파싱
    final workItems = <String, int>{};

    // "벽걸이 에어컨 전문세척" 형태 파싱
    if (text.contains('벽걸이 에어컨')) {
      workItems['벽걸이 에어컨'] = 1;
    }
    if (text.contains('스텐드 에어컨')) {
      workItems['스텐드 에어컨'] = 1;
    }
    if (text.contains('1way 에어컨')) {
      workItems['1way 에어컨'] = 1;
    }
    if (text.contains('2way 에어컨')) {
      workItems['2way 에어컨'] = 1;
    }
    if (text.contains('드럼세탁기') || text.contains('드럼 세탁기')) {
      workItems['드럼세탁기'] = 1;
    }
    if (text.contains('통돌이세탁기') || text.contains('통돌이 세탁기')) {
      workItems['통돌이세탁기'] = 1;
    }
    if (text.contains('냉장고')) {
      workItems['냉장고'] = 1;
    }

    if (workItems.isNotEmpty) {
      result['workItems'] = workItems;
    }

    // 업체명 (삼성케어플러스)
    result['companyName'] = '삼성케어플러스';

    return result;
  }

  void _showWorkItemsDialog() {
    final tempWorkItems = Map<String, int>.from(_workItemsWithCount);
    final customItemController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('작업 내용 및 건수'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // 미리 정의된 항목들
                      ..._predefinedWorkItems.map((item) {
                        return ListTile(
                          dense: true,
                          title: Text(item, style: const TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (tempWorkItems.containsKey(item)) ...[
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () {
                                    setDialogState(() {
                                      if (tempWorkItems[item]! > 1) {
                                        tempWorkItems[item] = tempWorkItems[item]! - 1;
                                      } else {
                                        tempWorkItems.remove(item);
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  '${tempWorkItems[item]}건',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: () {
                                    setDialogState(() {
                                      tempWorkItems[item] = tempWorkItems[item]! + 1;
                                    });
                                  },
                                ),
                              ] else
                                IconButton(
                                  icon: const Icon(Icons.add_circle, size: 20, color: Colors.blue),
                                  onPressed: () {
                                    setDialogState(() {
                                      tempWorkItems[item] = 1;
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                      // 사용자 정의 항목들
                      ...tempWorkItems.entries
                          .where((e) => !_predefinedWorkItems.contains(e.key))
                          .map((entry) {
                        return ListTile(
                          dense: true,
                          title: Text(entry.key, style: const TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    if (entry.value > 1) {
                                      tempWorkItems[entry.key] = entry.value - 1;
                                    } else {
                                      tempWorkItems.remove(entry.key);
                                    }
                                  });
                                },
                              ),
                              Text(
                                '${entry.value}건',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    tempWorkItems[entry.key] = entry.value + 1;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    tempWorkItems.remove(entry.key);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customItemController,
                        decoration: const InputDecoration(
                          labelText: '직접 입력',
                          hintText: '작업 내용 입력',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: () {
                        if (customItemController.text.isNotEmpty) {
                          setDialogState(() {
                            tempWorkItems[customItemController.text] = 1;
                            customItemController.clear();
                          });
                        }
                      },
                    ),
                  ],
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

    if (_workItemsWithCount.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작업 내용을 선택해주세요')),
      );
      return;
    }

    // 상태 자동 설정: 방문일자와 방문시간이 모두 있으면 '확정', 아니면 '예정'
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
      companyName: _companyNameController.text.isEmpty ? null : _companyNameController.text,
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

  void _showInputModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('입력 방식 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('수동 입력 (개인)'),
              onTap: () {
                setState(() {
                  _inputMode = 'manual';
                  _selectedCompanyType = 'personal';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('텍스트 붙여넣기 (삼성케어플러스)'),
              onTap: () {
                setState(() {
                  _inputMode = 'text_samsung';
                  _selectedCompanyType = 'samsung';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('텍스트 붙여넣기 (케어원)'),
              onTap: () {
                setState(() {
                  _inputMode = 'text_carewon';
                  _selectedCompanyType = 'carewon';
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schedule == null ? '스케줄 추가' : '스케줄 수정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (widget.schedule == null)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: _showInputModeDialog,
              tooltip: '입력 방식 변경',
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSchedule,
          ),
        ],
      ),
      body: _inputMode == 'manual' ? _buildManualForm() : _buildTextParsingForm(),
    );
  }

  Widget _buildManualForm() {
    return Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
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
                        decoration: InputDecoration(
                          labelText: '요청일자 *',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                          suffixIcon: const Icon(Icons.calendar_today, size: 20),
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
                              decoration: InputDecoration(
                                labelText: '방문확정일자',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                                suffixIcon: const Icon(Icons.calendar_today, size: 20),
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
                    TextFormField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: '업체명',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showWorkItemsDialog,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: '작업 내용 *',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                          suffixIcon: const Icon(Icons.add, size: 20),
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
      );
  }

  Widget _buildTextParsingForm() {
    final textController = TextEditingController();
    final companyName = _inputMode == 'text_samsung' ? '삼성케어플러스' : '케어원';
    final description = _inputMode == 'text_samsung'
        ? '삼성케어플러스 수임상세 화면의 전체 텍스트를 복사하여 붙여넣으면 자동으로 정보를 추출합니다.'
        : '케어원 작업 정보 화면의 전체 텍스트를 복사하여 붙여넣으면 자동으로 정보를 추출합니다.';

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '복사한 텍스트를 붙여넣으세요 ($companyName)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '여기에 텍스트를 붙여넣으세요...',
                      alignLabelWithHint: true,
                    ),
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final parsedData = _inputMode == 'text_samsung'
                    ? _parseSamsungCareText(textController.text)
                    : _parseCareWonText(textController.text);

                if (parsedData.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('텍스트에서 정보를 찾을 수 없습니다')),
                  );
                  return;
                }

                setState(() {
                  // 파싱된 데이터로 필드 채우기
                  if (parsedData['customerName'] != null) {
                    _customerNameController.text = parsedData['customerName'];
                  }
                  if (parsedData['phoneNumber'] != null) {
                    _phoneNumberController.text = parsedData['phoneNumber'];
                  }
                  if (parsedData['address'] != null) {
                    _addressController.text = parsedData['address'];
                  }
                  if (parsedData['companyName'] != null) {
                    _companyNameController.text = parsedData['companyName'];
                  }
                  if (parsedData['requestDate'] != null) {
                    _requestDate = parsedData['requestDate'];
                  }
                  if (parsedData['notes'] != null) {
                    _notesController.text = parsedData['notes'];
                  }
                  // visitDate와 visitTime은 미정(null)으로 유지
                  if (parsedData['workItems'] != null) {
                    _workItemsWithCount = parsedData['workItems'];
                    int total = _workItemsWithCount.values.fold(0, (sum, count) => sum + count);
                    _workCountController.text = total.toString();
                  }

                  // 수동 입력 모드로 전환
                  _inputMode = 'manual';
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('정보를 추출했습니다. 확인 후 저장해주세요.')),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '정보 추출하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
