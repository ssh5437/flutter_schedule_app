/// 반복 유형 enum
enum RepeatType {
  daily,   // 일 단위
  weekly,  // 주 단위
  monthly, // 월 단위
}

extension RepeatTypeExtension on RepeatType {
  String get displayName {
    switch (this) {
      case RepeatType.daily:
        return '일 단위';
      case RepeatType.weekly:
        return '주 단위';
      case RepeatType.monthly:
        return '월 단위';
    }
  }
}

/// 종료 타입 enum
enum EndType {
  none,  // 종료 없음
  date,  // 날짜로 종료
  count, // 횟수로 종료
}

extension EndTypeExtension on EndType {
  String get displayName {
    switch (this) {
      case EndType.none:
        return '없음';
      case EndType.date:
        return '날짜';
      case EndType.count:
        return '횟수';
    }
  }
}

/// 월 단위 반복 타입 enum
enum MonthlyRepeatType {
  dayOfMonth,  // 매월 특정 일자 (예: 매월 15일)
  weekOfMonth, // 매월 특정 주차의 요일 (예: 매월 2번째 수요일)
}

extension MonthlyRepeatTypeExtension on MonthlyRepeatType {
  String get displayName {
    switch (this) {
      case MonthlyRepeatType.dayOfMonth:
        return '날짜';
      case MonthlyRepeatType.weekOfMonth:
        return '요일';
    }
  }
}

/// 스케줄 반복 설정 모델
class RepeatConfig {
  final RepeatType type;
  final int interval; // 반복 주기 (예: 2주마다, 3일마다)
  final DateTime startDate;
  final EndType endType; // 종료 타입 (날짜 또는 횟수)
  final DateTime? endDate; // 종료 날짜 (endType이 date일 때)
  final int? repeatCount; // 반복 횟수 (endType이 count일 때)
  final List<int>? weekdays; // 주 단위일 때 선택된 요일 (1=월요일, 7=일요일)
  final int? monthDay; // 월 단위일 때 날짜 (1-31)
  final MonthlyRepeatType? monthlyType; // 월 단위 반복 타입
  final int? weekOfMonth; // 월 단위 요일 반복일 때 몇 번째 주인지 (1-5)
  final int? dayOfWeek; // 월 단위 요일 반복일 때 요일 (1=월요일, 7=일요일)

  RepeatConfig({
    required this.type,
    this.interval = 1,
    required this.startDate,
    required this.endType,
    this.endDate,
    this.repeatCount,
    this.weekdays,
    this.monthDay,
    this.monthlyType,
    this.weekOfMonth,
    this.dayOfWeek,
  });

  /// 반복 설정에 따라 생성될 날짜 목록 반환
  List<DateTime> generateDates() {
    final dates = <DateTime>[];
    var current = startDate;
    int count = 0;

    while (true) {
      // 종료 조건 체크
      if (endType == EndType.date) {
        if (endDate != null && current.isAfter(endDate!)) break;
      } else if (endType == EndType.count) {
        if (repeatCount != null && count >= repeatCount!) break;
      }
      // EndType.none인 경우 최대 365개까지만 생성
      else if (endType == EndType.none && dates.length >= 365) {
        break;
      }

      bool shouldAdd = false;

      switch (type) {
        case RepeatType.daily:
          shouldAdd = true;
          break;

        case RepeatType.weekly:
          if (weekdays != null && weekdays!.contains(current.weekday)) {
            shouldAdd = true;
          }
          break;

        case RepeatType.monthly:
          if (monthlyType == MonthlyRepeatType.dayOfMonth) {
            // 날짜 기반 반복 (예: 매월 15일)
            if (monthDay != null && current.day == monthDay) {
              shouldAdd = true;
            }
          } else if (monthlyType == MonthlyRepeatType.weekOfMonth) {
            // 요일 기반 반복 (예: 매월 2번째 수요일)
            if (weekOfMonth != null && dayOfWeek != null) {
              if (current.weekday == dayOfWeek && RepeatConfig._getWeekOfMonth(current) == weekOfMonth) {
                shouldAdd = true;
              }
            }
          }
          break;
      }

      if (shouldAdd) {
        dates.add(current);
        count++;
      }

      // 다음 날짜로 이동
      switch (type) {
        case RepeatType.daily:
          current = current.add(Duration(days: interval));
          break;

        case RepeatType.weekly:
          current = current.add(const Duration(days: 1));
          break;

        case RepeatType.monthly:
          if (monthlyType == MonthlyRepeatType.dayOfMonth && monthDay != null && current.day == monthDay) {
            // 날짜 기반: 다음 달로 이동
            if (current.month == 12) {
              current = DateTime(current.year + interval, 1, monthDay!);
            } else {
              int newMonth = current.month + interval;
              int newYear = current.year;
              while (newMonth > 12) {
                newMonth -= 12;
                newYear++;
              }
              current = DateTime(newYear, newMonth, monthDay!);
            }
          } else if (monthlyType == MonthlyRepeatType.weekOfMonth &&
                     weekOfMonth != null &&
                     dayOfWeek != null &&
                     current.weekday == dayOfWeek &&
                     RepeatConfig._getWeekOfMonth(current) == weekOfMonth) {
            // 요일 기반: 다음 달 같은 주차의 같은 요일로 이동
            current = RepeatConfig._getNextMonthSameWeekday(current, interval, weekOfMonth!, dayOfWeek!);
          } else {
            current = current.add(const Duration(days: 1));
          }
          break;
      }

      // 무한 루프 방지
      if (dates.length > 1000) break;
    }

    return dates;
  }

  /// 해당 날짜가 그 달의 몇 번째 주인지 계산 (1-5)
  static int _getWeekOfMonth(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final daysDifference = date.difference(firstDayOfMonth).inDays;
    return (daysDifference / 7).floor() + 1;
  }

  /// 다음 달의 같은 주차, 같은 요일 날짜 찾기
  static DateTime _getNextMonthSameWeekday(DateTime current, int monthInterval, int targetWeek, int targetWeekday) {
    int newYear = current.year;
    int newMonth = current.month + monthInterval;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }

    // 새 달의 첫날
    final firstDayOfNewMonth = DateTime(newYear, newMonth, 1);

    // 새 달의 첫 번째 targetWeekday 찾기
    int daysToAdd = (targetWeekday - firstDayOfNewMonth.weekday + 7) % 7;
    DateTime firstTargetWeekday = firstDayOfNewMonth.add(Duration(days: daysToAdd));

    // targetWeek 번째 해당 요일 계산
    DateTime targetDate = firstTargetWeekday.add(Duration(days: 7 * (targetWeek - 1)));

    // 해당 날짜가 여전히 같은 달인지 확인
    if (targetDate.month != newMonth) {
      // 5번째 주가 없는 경우, 마지막 주로 설정
      targetDate = targetDate.subtract(const Duration(days: 7));
    }

    return targetDate;
  }

  /// 설정 요약 텍스트 반환
  String getSummaryText() {
    final buffer = StringBuffer();

    // 반복 유형 및 주기
    if (interval == 1) {
      buffer.write(type.displayName);
    } else {
      switch (type) {
        case RepeatType.daily:
          buffer.write('$interval일마다');
          break;
        case RepeatType.weekly:
          buffer.write('$interval주마다');
          break;
        case RepeatType.monthly:
          buffer.write('$interval개월마다');
          break;
      }
    }

    // 요일 정보 (주 단위인 경우)
    if (type == RepeatType.weekly && weekdays != null && weekdays!.isNotEmpty) {
      const weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
      final selectedDays = weekdays!.map((day) => weekdayNames[day - 1]).join(', ');
      buffer.write(' ($selectedDays)');
    }

    // 날짜 정보 (월 단위인 경우)
    if (type == RepeatType.monthly) {
      if (monthlyType == MonthlyRepeatType.dayOfMonth && monthDay != null) {
        buffer.write(' (매월 $monthDay일)');
      } else if (monthlyType == MonthlyRepeatType.weekOfMonth && weekOfMonth != null && dayOfWeek != null) {
        const weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];
        const weekNames = ['첫째', '둘째', '셋째', '넷째', '다섯째'];
        buffer.write(' (매월 ${weekNames[weekOfMonth! - 1]} ${weekdayNames[dayOfWeek! - 1]}요일)');
      }
    }

    buffer.write(' 반복');

    // 종료 정보
    if (endType == EndType.date && endDate != null) {
      buffer.write(', ${endDate!.year}년 ${endDate!.month}월 ${endDate!.day}일까지');
    } else if (endType == EndType.count && repeatCount != null) {
      buffer.write(', $repeatCount회');
    } else if (endType == EndType.none) {
      buffer.write(', 종료 없음');
    }

    return buffer.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'interval': interval,
      'startDate': startDate.toIso8601String(),
      'endType': endType.toString(),
      'endDate': endDate?.toIso8601String(),
      'repeatCount': repeatCount,
      'weekdays': weekdays,
      'monthDay': monthDay,
      'monthlyType': monthlyType?.toString(),
      'weekOfMonth': weekOfMonth,
      'dayOfWeek': dayOfWeek,
    };
  }

  factory RepeatConfig.fromJson(Map<String, dynamic> json) {
    return RepeatConfig(
      type: RepeatType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      interval: json['interval'] ?? 1,
      startDate: DateTime.parse(json['startDate']),
      endType: EndType.values.firstWhere(
        (e) => e.toString() == json['endType'],
      ),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      repeatCount: json['repeatCount'],
      weekdays: json['weekdays'] != null
          ? List<int>.from(json['weekdays'])
          : null,
      monthDay: json['monthDay'],
      monthlyType: json['monthlyType'] != null
          ? MonthlyRepeatType.values.firstWhere(
              (e) => e.toString() == json['monthlyType'],
            )
          : null,
      weekOfMonth: json['weekOfMonth'],
      dayOfWeek: json['dayOfWeek'],
    );
  }
}
