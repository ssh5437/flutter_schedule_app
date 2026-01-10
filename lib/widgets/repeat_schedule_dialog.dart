import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/repeat_config.dart';

/// 스케줄 반복 설정 다이얼로그
class RepeatScheduleDialog extends StatefulWidget {
  final DateTime initialDate;

  const RepeatScheduleDialog({
    super.key,
    required this.initialDate,
  });

  @override
  State<RepeatScheduleDialog> createState() => _RepeatScheduleDialogState();
}

class _RepeatScheduleDialogState extends State<RepeatScheduleDialog> {
  RepeatType _selectedType = RepeatType.daily;
  int _interval = 1;
  late DateTime _startDate;
  EndType _endType = EndType.date;
  DateTime? _endDate;
  int _repeatCount = 1;
  final Set<int> _selectedWeekdays = {};
  int? _selectedMonthDay;
  MonthlyRepeatType _monthlyType = MonthlyRepeatType.dayOfMonth;
  int? _weekOfMonth;
  int? _dayOfWeek;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // 시작 날짜 설정: 과거 스케줄이면 오늘, 미래 스케줄이면 다음날
    if (widget.initialDate.isBefore(todayDate)) {
      _startDate = todayDate;
    } else {
      _startDate = widget.initialDate.add(const Duration(days: 1));
    }
    _endDate = _startDate; // 종료일을 시작일과 동일하게 설정

    // 주간 반복과 월간 반복 설정은 원본 스케줄 날짜 기준
    _selectedWeekdays.add(widget.initialDate.weekday);
    _selectedMonthDay = widget.initialDate.day;
    _dayOfWeek = widget.initialDate.weekday;
    _weekOfMonth = _getWeekOfMonth(widget.initialDate);
    _endType = EndType.date; // 기본값을 날짜로 변경
  }

  int _getWeekOfMonth(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final daysDifference = date.difference(firstDayOfMonth).inDays;
    return (daysDifference / 7).floor() + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              Row(
                children: [
                  const Icon(Icons.repeat, color: Color(0xFF579bf2)),
                  const SizedBox(width: 8),
                  const Text(
                    '스케줄 반복 등록',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: Colors.grey.shade700,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 반복 유형 및 주기
              _buildRepeatTypeAndIntervalSelector(),
              const SizedBox(height: 20),

              // 반복 유형별 추가 옵션
              if (_selectedType == RepeatType.weekly) ...[
                const Text(
                  '반복 요일',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _buildWeekdaySelector(),
                const SizedBox(height: 20),
              ],

              if (_selectedType == RepeatType.monthly) ...[
                const Text(
                  '매월 반복 날짜',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _buildMonthDaySelector(),
                const SizedBox(height: 20),
              ],

              // 종료 설정
              const Text(
                '종료',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _buildEndTypeSelector(),
              const SizedBox(height: 20),

              // 미리보기
              _buildPreview(),
              const SizedBox(height: 24),

              // 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _canConfirm() ? _onConfirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF579bf2),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('등록'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatTypeAndIntervalSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 반복 주기 조절
          IconButton(
            onPressed: () {
              if (_interval > 1) {
                setState(() {
                  _interval--;
                });
              }
            },
            icon: const Icon(Icons.remove_circle_outline),
            color: const Color(0xFF579bf2),
            iconSize: 24,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 15,
            child: TextField(
              controller: TextEditingController(text: _interval.toString()),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                final number = int.tryParse(value);
                if (number != null && number > 0) {
                  setState(() {
                    _interval = number;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {
              setState(() {
                _interval++;
              });
            },
            icon: const Icon(Icons.add_circle_outline),
            color: const Color(0xFF579bf2),
            iconSize: 24,
          ),
          const SizedBox(width: 5),
          // 반복 유형 선택
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RepeatType>(
                  value: _selectedType,
                  isExpanded: true,
                  items: RepeatType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaySelector() {
    const weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

    return Row(
      children: List.generate(7, (index) {
        final weekday = index + 1;
        final isSelected = _selectedWeekdays.contains(weekday);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == 6 ? 0 : 4,
            ),
            child: FilterChip(
              label: Text(
                weekdayNames[index],
                style: const TextStyle(fontSize: 14),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedWeekdays.add(weekday);
                  } else {
                    if (_selectedWeekdays.length > 1) {
                      _selectedWeekdays.remove(weekday);
                    }
                  }
                });
              },
              selectedColor: const Color(0xFF579bf2).withValues(alpha: 0.3),
              checkmarkColor: const Color(0xFF579bf2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              labelPadding: EdgeInsets.zero,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMonthDaySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('날짜'),
            leading: Radio<MonthlyRepeatType>(
              value: MonthlyRepeatType.dayOfMonth,
              groupValue: _monthlyType,
              toggleable: false,
              activeColor: const Color(0xFF579bf2),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _monthlyType = value;
                  });
                }
              },
            ),
            selected: _monthlyType == MonthlyRepeatType.dayOfMonth,
            selectedTileColor: const Color(0xFF579bf2).withValues(alpha: 0.05),
            onTap: () {
              setState(() {
                _monthlyType = MonthlyRepeatType.dayOfMonth;
              });
            },
          ),
            if (_monthlyType == MonthlyRepeatType.dayOfMonth)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '매월 $_selectedMonthDay일에 반복',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Slider(
                      value: _selectedMonthDay!.toDouble(),
                      min: 1,
                      max: 31,
                      divisions: 30,
                      label: '$_selectedMonthDay일',
                      onChanged: (value) {
                        setState(() {
                          _selectedMonthDay = value.toInt();
                        });
                      },
                      activeColor: const Color(0xFF579bf2),
                    ),
                  ],
                ),
              ),
          const Divider(height: 1),
          ListTile(
            title: const Text('요일'),
            leading: Radio<MonthlyRepeatType>(
              value: MonthlyRepeatType.weekOfMonth,
              groupValue: _monthlyType,
              toggleable: false,
              activeColor: const Color(0xFF579bf2),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _monthlyType = value;
                  });
                }
              },
            ),
            selected: _monthlyType == MonthlyRepeatType.weekOfMonth,
            selectedTileColor: const Color(0xFF579bf2).withValues(alpha: 0.05),
            onTap: () {
              setState(() {
                _monthlyType = MonthlyRepeatType.weekOfMonth;
              });
            },
          ),
          if (_monthlyType == MonthlyRepeatType.weekOfMonth)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('매월', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _weekOfMonth,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('첫째')),
                          DropdownMenuItem(value: 2, child: Text('둘째')),
                          DropdownMenuItem(value: 3, child: Text('셋째')),
                          DropdownMenuItem(value: 4, child: Text('넷째')),
                          DropdownMenuItem(value: 5, child: Text('다섯째')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _weekOfMonth = value;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _dayOfWeek,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('월요일')),
                          DropdownMenuItem(value: 2, child: Text('화요일')),
                          DropdownMenuItem(value: 3, child: Text('수요일')),
                          DropdownMenuItem(value: 4, child: Text('목요일')),
                          DropdownMenuItem(value: 5, child: Text('금요일')),
                          DropdownMenuItem(value: 6, child: Text('토요일')),
                          DropdownMenuItem(value: 7, child: Text('일요일')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _dayOfWeek = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildEndTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('날짜'),
            leading: Radio<EndType>(
              value: EndType.date,
              groupValue: _endType,
              toggleable: false,
              activeColor: const Color(0xFF579bf2),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _endType = value;
                  });
                }
              },
            ),
            selected: _endType == EndType.date,
            selectedTileColor: const Color(0xFF579bf2).withValues(alpha: 0.05),
            onTap: () {
              setState(() {
                _endType = EndType.date;
              });
            },
          ),
            if (_endType == EndType.date)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  children: [
                    _buildDatePickerRow(
                      '시작일',
                      _startDate,
                      (date) => setState(() {
                        _startDate = date;
                        if (_endDate != null && _endDate!.isBefore(date)) {
                          _endDate = date;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                    _buildDatePickerRow(
                      '종료일',
                      _endDate ?? _startDate,
                      (date) => setState(() => _endDate = date),
                    ),
                  ],
                ),
              ),
          const Divider(height: 1),
          ListTile(
            title: const Text('횟수'),
            leading: Radio<EndType>(
              value: EndType.count,
              groupValue: _endType,
              toggleable: false,
              activeColor: const Color(0xFF579bf2),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _endType = value;
                  });
                }
              },
            ),
            selected: _endType == EndType.count,
            selectedTileColor: const Color(0xFF579bf2).withValues(alpha: 0.05),
            onTap: () {
              setState(() {
                _endType = EndType.count;
              });
            },
          ),
          if (_endType == EndType.count)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  _buildDatePickerRow(
                    '시작일',
                    _startDate,
                    (date) => setState(() => _startDate = date),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('반복 횟수'),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: TextEditingController(text: _repeatCount.toString()),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onChanged: (value) {
                            final number = int.tryParse(value);
                            if (number != null && number > 0) {
                              setState(() {
                                _repeatCount = number;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('회'),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDatePickerRow(
    String label,
    DateTime date,
    Function(DateTime) onDateSelected,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: widget.initialDate,
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              locale: const Locale('ko', 'KR'),
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          icon: const Icon(Icons.calendar_today, size: 18, color: Colors.black87),
          label: Text(
            DateFormat('yyyy년 M월 d일').format(date),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.black26),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    if (!_canConfirm()) {
      return const SizedBox.shrink();
    }

    final config = _buildRepeatConfig();
    final summaryText = config.getSummaryText();
    final dates = config.generateDates();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: Color(0xFF579bf2)),
              const SizedBox(width: 8),
              const Text(
                '반복 설정 요약',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF579bf2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summaryText,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '총 ${dates.length}개의 스케줄이 생성됩니다.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  bool _canConfirm() {
    if (_selectedType == RepeatType.weekly && _selectedWeekdays.isEmpty) {
      return false;
    }
    if (_endType == EndType.date) {
      if (_endDate == null) return false;
      if (_endDate!.isBefore(_startDate)) return false;
    }
    if (_endType == EndType.count && _repeatCount <= 0) return false;
    return true;
  }

  RepeatConfig _buildRepeatConfig() {
    List<int>? weekdaysList;
    if (_selectedType == RepeatType.weekly) {
      weekdaysList = _selectedWeekdays.toList()..sort();
    }

    return RepeatConfig(
      type: _selectedType,
      interval: _interval,
      startDate: _startDate,
      endType: _endType,
      endDate: _endType == EndType.date ? _endDate : null,
      repeatCount: _endType == EndType.count ? _repeatCount : null,
      weekdays: weekdaysList,
      monthDay: _selectedType == RepeatType.monthly && _monthlyType == MonthlyRepeatType.dayOfMonth
          ? _selectedMonthDay
          : null,
      monthlyType: _selectedType == RepeatType.monthly ? _monthlyType : null,
      weekOfMonth: _selectedType == RepeatType.monthly && _monthlyType == MonthlyRepeatType.weekOfMonth
          ? _weekOfMonth
          : null,
      dayOfWeek: _selectedType == RepeatType.monthly && _monthlyType == MonthlyRepeatType.weekOfMonth
          ? _dayOfWeek
          : null,
    );
  }

  void _onConfirm() {
    Navigator.pop(context, _buildRepeatConfig());
  }
}
