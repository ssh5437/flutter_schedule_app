import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';

class WidgetService {
  static const String _widgetName = 'ScheduleWidgetProvider';

  /// 위젯 업데이트
  static Future<void> updateWidget() async {
    try {
      // 오늘 날짜 가져오기
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 사용자 ID 가져오기 (Supabase에서)
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        await _clearWidget();
        return;
      }

      // 오늘과 내일 스케줄 가져오기
      final allSchedules = await DatabaseHelper.instance.readAllSchedules(userId);

      // 오늘 스케줄 필터링
      final todaySchedules = allSchedules.where((s) {
        final displayDate = s.computedStatus == '확정' && s.visitDate != null
            ? s.visitDate!
            : s.requestDate;
        final scheduleDate = DateTime(displayDate.year, displayDate.month, displayDate.day);
        return scheduleDate.isAtSameMomentAs(today);
      }).toList();

      // 상태별, 날짜별 정렬
      todaySchedules.sort((a, b) {
        // 1. 상태별 정렬
        if (a.computedStatus != b.computedStatus) {
          if (a.computedStatus == '예정') return -1;
          if (b.computedStatus == '예정') return 1;
        }

        // 2. 시간별 정렬 (visitTime이 있는 경우)
        if (a.visitTime != null && b.visitTime != null) {
          return a.visitTime!.compareTo(b.visitTime!);
        }

        return 0;
      });

      // 위젯 데이터 저장
      await HomeWidget.saveWidgetData<String>('current_month', DateFormat('M월', 'ko_KR').format(now));
      await HomeWidget.saveWidgetData<String>('current_date', DateFormat('d', 'ko_KR').format(now));
      await HomeWidget.saveWidgetData<String>('current_day', DateFormat('EEEE', 'ko_KR').format(now));

      // 큰 위젯용 데이터
      await HomeWidget.saveWidgetData<String>('calendar_month', DateFormat('yyyy년 M월', 'ko_KR').format(now));
      await HomeWidget.saveWidgetData<String>('selected_date_text', DateFormat('M월 d일 (E)', 'ko_KR').format(now));
      await HomeWidget.saveWidgetData<int>('schedule_count', todaySchedules.length);

      // 이번 달 스케줄 있는 날짜들 저장
      final scheduleDates = <int>[];

      for (var schedule in allSchedules) {
        final displayDate = schedule.computedStatus == '확정' && schedule.visitDate != null
            ? schedule.visitDate!
            : schedule.requestDate;

        if (displayDate.year == now.year && displayDate.month == now.month) {
          if (!scheduleDates.contains(displayDate.day)) {
            scheduleDates.add(displayDate.day);
          }
        }
      }

      // 스케줄이 있는 날짜들을 쉼표로 구분된 문자열로 저장 (작은 위젯용)
      await HomeWidget.saveWidgetData<String>('schedule_dates', scheduleDates.join(','));

      // 큰 위젯용: 한 줄 포맷
      if (scheduleDates.isEmpty) {
        await HomeWidget.saveWidgetData<String>('schedule_dates_formatted', '이번 달 스케줄 없음');
      } else {
        final sortedDates = scheduleDates..sort();
        final formatted = sortedDates.map((d) => '$d일').join(', ');
        await HomeWidget.saveWidgetData<String>('schedule_dates_formatted', '스케줄: $formatted');
      }

      // 스케줄 데이터 저장 (최대 3개)
      for (int i = 0; i < 3; i++) {
        if (i < todaySchedules.length) {
          final schedule = todaySchedules[i];

          // 작업 내용 파싱 (JSON 배열)
          String workItemsText = '';
          try {
            final workItemsList = (schedule.workItems as List).cast<String>();
            workItemsText = workItemsList.join(', ');
          } catch (e) {
            workItemsText = schedule.workItems.toString();
          }

          await HomeWidget.saveWidgetData<String>('schedule_${i}_time', schedule.visitTime ?? '시간 미정');
          await HomeWidget.saveWidgetData<String>('schedule_${i}_title', workItemsText);
          await HomeWidget.saveWidgetData<String>('schedule_${i}_status', schedule.computedStatus);
          await HomeWidget.saveWidgetData<String>('schedule_${i}_company', schedule.companyName);
          await HomeWidget.saveWidgetData<int>('schedule_${i}_id', schedule.id ?? 0);
        } else {
          // 빈 슬롯은 null로 설정
          await HomeWidget.saveWidgetData<String>('schedule_${i}_time', '');
          await HomeWidget.saveWidgetData<String>('schedule_${i}_title', '');
          await HomeWidget.saveWidgetData<String>('schedule_${i}_status', '');
          await HomeWidget.saveWidgetData<String>('schedule_${i}_company', '');
          await HomeWidget.saveWidgetData<int>('schedule_${i}_id', 0);
        }
      }

      // 위젯 업데이트 (작은 위젯)
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
        iOSName: 'ScheduleWidget',
      );

      // 큰 위젯 업데이트
      await HomeWidget.updateWidget(
        name: 'ScheduleWidgetLargeProvider',
        androidName: 'ScheduleWidgetLargeProvider',
        iOSName: 'ScheduleWidget',
      );
    } catch (e) {
      print('Widget update error: $e');
    }
  }

  /// 위젯 데이터 초기화
  static Future<void> _clearWidget() async {
    await HomeWidget.saveWidgetData<String>('current_month', '');
    await HomeWidget.saveWidgetData<String>('current_date', '');
    await HomeWidget.saveWidgetData<String>('current_day', '');
    await HomeWidget.saveWidgetData<int>('schedule_count', 0);

    for (int i = 0; i < 3; i++) {
      await HomeWidget.saveWidgetData<String>('schedule_${i}_time', '');
      await HomeWidget.saveWidgetData<String>('schedule_${i}_title', '');
      await HomeWidget.saveWidgetData<String>('schedule_${i}_status', '');
      await HomeWidget.saveWidgetData<String>('schedule_${i}_company', '');
    }

    await HomeWidget.updateWidget(
      name: _widgetName,
      androidName: _widgetName,
      iOSName: 'ScheduleWidget',
    );
  }

  /// 위젯 클릭 이벤트 처리를 위한 초기화
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId('group.com.example.flutter_schedule_app');
  }

  /// 위젯에서 앱으로 이동 (위젯 클릭 시 앱 실행)
  static Future<void> registerInteractivityCallback(Future<void> Function(Uri?) callback) async {
    await HomeWidget.registerInteractivityCallback(callback);
  }
}
