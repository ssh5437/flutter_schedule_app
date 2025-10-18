import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../models/company.dart';
import '../database/database_helper.dart';
import '../utils/gemini_helper.dart';

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
  final _phoneNumberFocus = FocusNode();

  DateTime _requestDate = DateTime.now();
  DateTime? _visitDate;
  String? _visitTime;
  Map<String, int> _workItemsWithCount = {}; // 작업 항목과 건수

  List<Company> _companies = [];
  Company? _selectedCompany;
  bool _isLoadingCompanies = true;

  // 전화번호 포맷팅 (000-0000-0000)
  String _formatPhoneNumber(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 11) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 7)}-${digitsOnly.substring(7)}';
    } else if (digitsOnly.length == 10) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    }
    return digitsOnly;
  }

  // 전화번호에서 숫자만 추출
  String _getDigitsOnly(String text) {
    return text.replaceAll(RegExp(r'[^0-9]'), '');
  }

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
    _initializeForm();

    // 전화번호 포커스 리스너
    _phoneNumberFocus.addListener(() {
      if (!_phoneNumberFocus.hasFocus) {
        // 포커스 아웃 시 포맷팅 적용
        final digitsOnly = _getDigitsOnly(_phoneNumberController.text);
        if (digitsOnly.isNotEmpty) {
          _phoneNumberController.text = _formatPhoneNumber(digitsOnly);
        }
      } else {
        // 포커스 인 시 숫자만 표시
        final digitsOnly = _getDigitsOnly(_phoneNumberController.text);
        _phoneNumberController.text = digitsOnly;
        _phoneNumberController.selection = TextSelection.fromPosition(
          TextPosition(offset: digitsOnly.length),
        );
      }
    });
  }

  Future<void> _initializeForm() async {
    await _loadCompanies();
    if (widget.schedule != null) {
      setState(() {
        _loadScheduleData();
      });
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
    if (schedule.companyName != null && _companies.isNotEmpty) {
      try {
        _selectedCompany = _companies.firstWhere(
          (c) => c.name == schedule.companyName,
        );
      } catch (e) {
        // 업체를 찾지 못한 경우 첫 번째 업체 선택
        _selectedCompany = _companies.isNotEmpty ? _companies.first : null;
      }
    } else if (_companies.isNotEmpty) {
      _selectedCompany = _companies.first;
    }

    // 기존 데이터에서 작업 항목 파싱 (중복된 항목 카운팅)
    _workItemsWithCount.clear();
    for (var item in schedule.workItems) {
      _workItemsWithCount[item] = (_workItemsWithCount[item] ?? 0) + 1;
    }
    _workCountController.text = schedule.workCount.toString();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _workCountController.dispose();
    _notesController.dispose();
    _phoneNumberFocus.dispose();
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
                  subtitle: Text('${NumberFormat('#,###').format(workItem.price)}원', style: const TextStyle(fontSize: 12)),
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

  void _showPasteDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('텍스트에서 스케줄 추출'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '스케줄 정보가 포함된 텍스트를 붙여넣으세요.\n(이름, 전화번호, 주소, 날짜, 시간)',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '예시:\n홍길동\n010-1234-5678\n서울시 강남구 테헤란로 123\n2025년 10월 15일 14시',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('텍스트를 입력해주세요')),
                );
                return;
              }

              Navigator.pop(context);
              await _extractScheduleInfo(text);
            },
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('추출하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _extractScheduleInfo(String text) async {
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('정보 추출 중...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await GeminiHelper.extractScheduleInfo(text);

      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정보 추출에 실패했습니다. Gemini API 키를 확인해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 추출된 정보를 폼에 입력
      setState(() {
        if (result['name'] != null && result['name'].toString().isNotEmpty) {
          _customerNameController.text = result['name'].toString();
        }

        if (result['phone'] != null && result['phone'].toString().isNotEmpty) {
          final phone = result['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
          _phoneNumberController.text = _formatPhoneNumber(phone);
        }

        if (result['address'] != null && result['address'].toString().isNotEmpty) {
          _addressController.text = result['address'].toString();
        }

        // 날짜는 요청일자에 넣고, 과거 날짜인 경우 오늘 날짜로 설정
        if (result['date'] != null && result['date'].toString().isNotEmpty) {
          try {
            final extractedDate = DateTime.parse(result['date'].toString());
            final today = DateTime.now();
            final todayDate = DateTime(today.year, today.month, today.day);
            final extractedDateOnly = DateTime(extractedDate.year, extractedDate.month, extractedDate.day);

            // 과거 날짜인 경우 오늘 날짜로, 아니면 추출된 날짜 사용
            if (extractedDateOnly.isBefore(todayDate)) {
              _requestDate = today;
            } else {
              _requestDate = extractedDate;
            }
          } catch (e) {
            // 날짜 파싱 실패 시 무시
          }
        }

        // 방문시간은 미정으로 설정
        _visitTime = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('정보가 추출되었습니다. 내용을 확인하고 수정해주세요.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

    // 작업 항목을 건수만큼 중복하여 리스트로 변환
    final workItemsList = <String>[];
    for (var entry in _workItemsWithCount.entries) {
      for (int i = 0; i < entry.value; i++) {
        workItemsList.add(entry.key);
      }
    }

    // 전화번호는 숫자만 저장
    final phoneNumberDigitsOnly = _getDigitsOnly(_phoneNumberController.text);

    final schedule = Schedule(
      id: widget.schedule?.id,
      customerName: _customerNameController.text,
      requestDate: _requestDate,
      visitDate: _visitDate,
      visitTime: _visitTime,
      phoneNumber: phoneNumberDigitsOnly,
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
        title: Text(
          widget.schedule == null ? '스케줄 추가' : '스케줄 수정',
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            onPressed: _showPasteDialog,
            tooltip: '텍스트에서 추출',
          ),
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
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zㄱ-ㅎ가-힣\s]')),
                            ],
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
                            focusNode: _phoneNumberFocus,
                            decoration: const InputDecoration(
                              labelText: '전화번호 *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
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
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9ㄱ-ㅎ가-힣\s,\-]')),
                            ],
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
                                    : _workItemsWithCount.entries.map((e) => '${e.key} ${e.value}건').join(', '),
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
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                ),
              ],
            ),
    );
  }
}
