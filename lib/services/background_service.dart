import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

// 백그라운드 작업 핸들러 (반드시 top-level 함수여야 함)
@pragma('vm:entry-point')
Future<bool> callbackDispatcher(String task, Map<String, dynamic>? inputData) async {
  try {
    debugPrint('========================================');
    debugPrint('🌙 Background task started: $task');
    debugPrint('========================================');

    // Supabase 초기화 (백그라운드에서도 필요)
    if (Supabase.instance.client.auth.currentUser == null) {
      debugPrint('⚠️  User not logged in, skipping notification setup');
      return true;
    }

    // 알림 서비스 초기화
    await NotificationService.instance.initialize();

    // 매일 알림 재설정
    await NotificationService.instance.setupDailyNotifications();

    debugPrint('========================================');
    debugPrint('✅ Background task completed successfully');
    debugPrint('========================================');

    return true;
  } catch (e) {
    debugPrint('========================================');
    debugPrint('❌ Background task failed: $e');
    debugPrint('========================================');
    return false;
  }
}

class BackgroundService {
  static const String dailyNotificationTask = 'daily_notification_refresh';

  // 백그라운드 서비스 초기화
  static Future<void> initialize() async {
    try {
      debugPrint('🔧 Initializing background service...');

      await Workmanager().initialize(
        callbackDispatcher,
      );

      debugPrint('✅ Background service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize background service: $e');
    }
  }

  // 매일 자정에 실행되는 작업 등록
  static Future<void> registerDailyTask() async {
    try {
      debugPrint('📅 Registering daily notification refresh task...');

      // 기존 작업 취소
      await Workmanager().cancelByUniqueName(dailyNotificationTask);

      // 매일 자정에 실행되는 작업 등록
      await Workmanager().registerPeriodicTask(
        dailyNotificationTask,
        dailyNotificationTask,
        frequency: const Duration(hours: 24),
        initialDelay: _getDelayUntilMidnight(),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      debugPrint('✅ Daily task registered successfully');
      debugPrint('   Next run: Midnight (${_getDelayUntilMidnight().inHours}h ${_getDelayUntilMidnight().inMinutes.remainder(60)}m from now)');
    } catch (e) {
      debugPrint('❌ Failed to register daily task: $e');
    }
  }

  // 자정까지 남은 시간 계산
  static Duration _getDelayUntilMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  // 모든 백그라운드 작업 취소
  static Future<void> cancelAll() async {
    try {
      await Workmanager().cancelAll();
      debugPrint('✅ All background tasks cancelled');
    } catch (e) {
      debugPrint('❌ Failed to cancel background tasks: $e');
    }
  }
}
