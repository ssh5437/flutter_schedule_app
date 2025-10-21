import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart';
import '../models/schedule.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  // 알림 초기화
  Future<void> initialize() async {
    try {
      // 타임존 초기화
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      debugPrint('Timezone initialized: Asia/Seoul');

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      debugPrint('Notification plugin initialized: $initialized');

      // Android에서 알림 권한 및 정확한 알람 권한 요청
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidImpl != null) {
          // 알림 권한 요청 (Android 13+)
          final notificationPermission = await androidImpl.requestNotificationsPermission();
          debugPrint('Notification permission granted: $notificationPermission');

          // 정확한 알람 권한 요청 (Android 12+)
          final exactAlarmPermission = await androidImpl.requestExactAlarmsPermission();
          debugPrint('Exact alarm permission granted: $exactAlarmPermission');
        }
      }

      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
      rethrow;
    }
  }

  // 알림 탭 했을 때 처리
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  // 알림 설정 저장
  Future<void> saveNotificationSettings({
    required bool enablePreviousDay,
    required bool enableSameDay,
    required int previousDayHour,
    required int previousDayMinute,
    required int sameDayHour,
    required int sameDayMinute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enable_previous_day', enablePreviousDay);
    await prefs.setBool('notification_enable_same_day', enableSameDay);
    await prefs.setInt('notification_previous_day_hour', previousDayHour);
    await prefs.setInt('notification_previous_day_minute', previousDayMinute);
    await prefs.setInt('notification_same_day_hour', sameDayHour);
    await prefs.setInt('notification_same_day_minute', sameDayMinute);
  }

  // 알림 설정 불러오기
  Future<Map<String, dynamic>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enablePreviousDay': prefs.getBool('notification_enable_previous_day') ?? true,
      'enableSameDay': prefs.getBool('notification_enable_same_day') ?? true,
      'previousDayHour': prefs.getInt('notification_previous_day_hour') ?? 20,
      'previousDayMinute': prefs.getInt('notification_previous_day_minute') ?? 0,
      'sameDayHour': prefs.getInt('notification_same_day_hour') ?? 8,
      'sameDayMinute': prefs.getInt('notification_same_day_minute') ?? 0,
    };
  }

  // 매일 반복되는 알림 설정 (알림 설정 저장 시 호출)
  Future<void> setupDailyNotifications() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ User not logged in, skipping notification setup');
        return;
      }

      debugPrint('');
      debugPrint('========================================');
      debugPrint('🔄 Setting up daily notifications...');
      debugPrint('========================================');

      // 기존 알림 모두 취소
      await _notifications.cancelAll();
      debugPrint('🗑️  Cancelled all existing notifications');

      final settings = await getNotificationSettings();
      debugPrint('⚙️  Settings loaded:');
      debugPrint('   - Enable previous day: ${settings['enablePreviousDay']}');
      debugPrint('   - Previous day time: ${settings['previousDayHour']}:${settings['previousDayMinute']}');
      debugPrint('   - Enable same day: ${settings['enableSameDay']}');
      debugPrint('   - Same day time: ${settings['sameDayHour']}:${settings['sameDayMinute']}');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // 모든 스케줄 한 번만 조회
      final schedules = await DatabaseHelper.instance.readAllSchedules(userId);

      // 오늘 스케줄 확인 (당일 알림용)
      if (settings['enableSameDay'] as bool) {
        final todaySchedules = schedules.where((s) {
          if (s.visitDate == null) return false;
          final visitDate = DateTime(s.visitDate!.year, s.visitDate!.month, s.visitDate!.day);
          return visitDate.isAtSameMomentAs(today);
        }).toList();

        if (todaySchedules.isNotEmpty) {
          final notificationTime = tz.TZDateTime(
            tz.local,
            today.year,
            today.month,
            today.day,
            settings['sameDayHour'] as int,
            settings['sameDayMinute'] as int,
          );

          // 아직 시간이 지나지 않았으면 예약
          if (notificationTime.isAfter(tz.TZDateTime.now(tz.local))) {
            final body = _buildNotificationBody(todaySchedules);
            await _scheduleOneTimeNotification(
              id: 1,
              title: '오늘 작업 스케줄 ${todaySchedules.length}건',
              body: body,
              scheduledTime: notificationTime,
            );
            debugPrint('✅ 당일 알림 예약: $notificationTime');
            debugPrint('   ${todaySchedules.length}건: $body');
          }
        } else {
          debugPrint('ℹ️  오늘 스케줄 없음 - 당일 알림 예약 안 함');
        }
      }

      // 내일 스케줄 확인 (전날 알림용)
      if (settings['enablePreviousDay'] as bool) {
        final tomorrowSchedules = schedules.where((s) {
          if (s.visitDate == null) return false;
          final visitDate = DateTime(s.visitDate!.year, s.visitDate!.month, s.visitDate!.day);
          return visitDate.isAtSameMomentAs(tomorrow);
        }).toList();

        if (tomorrowSchedules.isNotEmpty) {
          final notificationTime = tz.TZDateTime(
            tz.local,
            today.year,
            today.month,
            today.day,
            settings['previousDayHour'] as int,
            settings['previousDayMinute'] as int,
          );

          // 아직 시간이 지나지 않았으면 예약
          if (notificationTime.isAfter(tz.TZDateTime.now(tz.local))) {
            final body = _buildNotificationBody(tomorrowSchedules);
            await _scheduleOneTimeNotification(
              id: 2,
              title: '내일 작업 스케줄 ${tomorrowSchedules.length}건',
              body: body,
              scheduledTime: notificationTime,
            );
            debugPrint('✅ 전날 알림 예약: $notificationTime');
            debugPrint('   ${tomorrowSchedules.length}건: $body');
          }
        } else {
          debugPrint('ℹ️  내일 스케줄 없음 - 전날 알림 예약 안 함');
        }
      }

      debugPrint('');
      debugPrint('========================================');
      debugPrint('✅ Daily notifications setup completed!');
      debugPrint('   오늘/내일 스케줄만 확인하여 알림 예약');
      debugPrint('========================================');
    } catch (e) {
      debugPrint('');
      debugPrint('========================================');
      debugPrint('❌ Error setting up daily notifications: $e');
      debugPrint('========================================');
      rethrow;
    }
  }

  // 스케줄 목록에서 알림 본문 생성
  String _buildNotificationBody(List<Schedule> schedules) {
    if (schedules.isEmpty) return '스케줄이 없습니다.';
    if (schedules.length == 1) {
      final s = schedules.first;
      final time = s.visitTime != null && s.visitTime != '미정' ? '${s.visitTime} ' : '';
      final work = s.workItems.isNotEmpty ? s.workItems.first : '작업';
      return '$time${s.customerName} - $work';
    }

    // 2건 이상인 경우
    final first = schedules.first;
    final time = first.visitTime != null && first.visitTime != '미정' ? '${first.visitTime} ' : '';
    final work = first.workItems.isNotEmpty ? first.workItems.first : '작업';
    return '$time${first.customerName} - $work 외 ${schedules.length - 1}건';
  }

  // 일회성 알림 예약 (특정 날짜/시간에 한 번만)
  Future<void> _scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'schedule_notifications',
        '스케줄 알림',
        channelDescription: '스케줄 알림',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling one-time notification: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // 알림 모두 취소
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // 테스트 알림 (즉시 발송)
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_notifications',
      '테스트 알림',
      channelDescription: '알림 테스트',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      '테스트 알림',
      '알림이 정상적으로 작동합니다.',
      details,
    );
  }

  // 1분 후 테스트 알림 (예약 테스트)
  Future<void> scheduleTestNotificationAfterOneMinute() async {
    final scheduledDateTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

    debugPrint('🧪 Test notification scheduled for: $scheduledDateTime');

    const androidDetails = AndroidNotificationDetails(
      'test_notifications',
      '테스트 알림',
      channelDescription: '알림 테스트',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      999, // 테스트용 고유 ID
      '1분 후 테스트 알림',
      '예약 알림이 정상적으로 작동합니다! 현재 시간: ${DateTime.now().hour}:${DateTime.now().minute}',
      scheduledDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('🧪 Test notification scheduled successfully');
  }

  // 예약된 알림 목록 확인
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    final pendingNotifications = await _notifications.pendingNotificationRequests();
    debugPrint('📋 Total pending notifications: ${pendingNotifications.length}');
    for (var notification in pendingNotifications) {
      debugPrint('  - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
    }
    return pendingNotifications;
  }

  // 모든 필요한 권한 확인 및 요청
  Future<Map<String, bool>> checkAndRequestPermissions() async {
    final results = <String, bool>{};

    if (defaultTargetPlatform == TargetPlatform.android) {
      // 알림 권한 (Android 13+)
      final notificationStatus = await Permission.notification.status;
      debugPrint('🔔 Notification permission: $notificationStatus');
      if (!notificationStatus.isGranted) {
        final result = await Permission.notification.request();
        results['notification'] = result.isGranted;
        debugPrint('🔔 Notification permission requested: ${result.isGranted}');
      } else {
        results['notification'] = true;
      }

      // 정확한 알람 권한 (Android 12+)
      final scheduleStatus = await Permission.scheduleExactAlarm.status;
      debugPrint('⏰ Schedule exact alarm permission: $scheduleStatus');
      if (!scheduleStatus.isGranted) {
        final result = await Permission.scheduleExactAlarm.request();
        results['scheduleExactAlarm'] = result.isGranted;
        debugPrint('⏰ Schedule exact alarm permission requested: ${result.isGranted}');
      } else {
        results['scheduleExactAlarm'] = true;
      }

      // 배터리 최적화 무시 권한
      final ignoreBatteryStatus = await Permission.ignoreBatteryOptimizations.status;
      debugPrint('🔋 Ignore battery optimizations: $ignoreBatteryStatus');
      if (!ignoreBatteryStatus.isGranted) {
        final result = await Permission.ignoreBatteryOptimizations.request();
        results['ignoreBatteryOptimizations'] = result.isGranted;
        debugPrint('🔋 Ignore battery optimizations requested: ${result.isGranted}');
      } else {
        results['ignoreBatteryOptimizations'] = true;
      }
    }

    return results;
  }

  // 권한 상태 확인만 (요청하지 않음)
  Future<Map<String, bool>> getPermissionStatus() async {
    final results = <String, bool>{};

    if (defaultTargetPlatform == TargetPlatform.android) {
      results['notification'] = await Permission.notification.isGranted;
      results['scheduleExactAlarm'] = await Permission.scheduleExactAlarm.isGranted;
      results['ignoreBatteryOptimizations'] = await Permission.ignoreBatteryOptimizations.isGranted;
    }

    return results;
  }
}
