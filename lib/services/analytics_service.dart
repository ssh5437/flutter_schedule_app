import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics 서비스 래퍼
/// 사용자 행동 및 이벤트 추적을 중앙화하여 관리
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  // ========== 화면 추적 ==========

  /// 화면 뷰 로깅
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      debugPrint('📊 Analytics: Screen view - $screenName');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ========== 사용자 속성 설정 ==========

  /// 사용자 ID 설정
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
      debugPrint('📊 Analytics: User ID set - $userId');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 사용자 속성 설정
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      debugPrint('📊 Analytics: User property - $name: $value');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ========== 인증 관련 이벤트 ==========

  /// 회원가입 이벤트
  Future<void> logSignUp({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      debugPrint('📊 Analytics: Sign up - $method');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 로그인 이벤트
  Future<void> logLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      debugPrint('📊 Analytics: Login - $method');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ========== 스케줄 관련 이벤트 ==========

  /// 스케줄 생성 이벤트
  Future<void> logScheduleCreated({
    required String companyName,
    required int workItemCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'schedule_created',
        parameters: {
          'company': companyName,
          'work_item_count': workItemCount,
        },
      );
      debugPrint('📊 Analytics: Schedule created - $companyName ($workItemCount items)');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 스케줄 수정 이벤트
  Future<void> logScheduleUpdated({
    required String status,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'schedule_updated',
        parameters: {
          'status': status,
        },
      );
      debugPrint('📊 Analytics: Schedule updated - $status');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 스케줄 삭제 이벤트
  Future<void> logScheduleDeleted() async {
    try {
      await _analytics.logEvent(name: 'schedule_deleted');
      debugPrint('📊 Analytics: Schedule deleted');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ========== 업체 관련 이벤트 ==========

  /// 업체 생성 이벤트
  Future<void> logCompanyCreated({
    required int workItemCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'company_created',
        parameters: {
          'work_item_count': workItemCount,
        },
      );
      debugPrint('📊 Analytics: Company created with $workItemCount work items');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 업체 수정 이벤트
  Future<void> logCompanyUpdated({
    required int workItemCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'company_updated',
        parameters: {
          'work_item_count': workItemCount,
        },
      );
      debugPrint('📊 Analytics: Company updated with $workItemCount work items');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 업체 삭제 이벤트
  Future<void> logCompanyDeleted() async {
    try {
      await _analytics.logEvent(name: 'company_deleted');
      debugPrint('📊 Analytics: Company deleted');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ========== 멤버십 관련 이벤트 ==========

  /// 멤버십 화면 조회 이벤트
  Future<void> logViewMembership() async {
    try {
      await _analytics.logEvent(name: 'view_membership');
      debugPrint('📊 Analytics: Viewed membership screen');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 멤버십 구독 시작 이벤트
  Future<void> logPurchaseInitiated({
    required String productId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'purchase_initiated',
        parameters: {
          'product_id': productId,
        },
      );
      debugPrint('📊 Analytics: Purchase initiated - $productId');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 멤버십 구독 완료 이벤트
  Future<void> logPurchaseCompleted({
    required String productId,
    required double value,
    required String currency,
  }) async {
    try {
      await _analytics.logPurchase(
        value: value,
        currency: currency,
        parameters: {
          'product_id': productId,
        },
      );
      debugPrint('📊 Analytics: Purchase completed - $productId ($value $currency)');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 무료 사용자 제한 도달 이벤트
  Future<void> logFreeLimitReached({
    required String feature,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'free_limit_reached',
        parameters: {
          'feature': feature,
        },
      );
      debugPrint('📊 Analytics: Free limit reached - $feature');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ========== 백업/복구 관련 이벤트 ==========

  /// 백업 이벤트
  Future<void> logBackupCreated({
    required int scheduleCount,
    required int companyCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'backup_created',
        parameters: {
          'schedule_count': scheduleCount,
          'company_count': companyCount,
        },
      );
      debugPrint('📊 Analytics: Backup created - $scheduleCount schedules, $companyCount companies');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 복구 이벤트
  Future<void> logRestoreCompleted({
    required int scheduleCount,
    required int companyCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'restore_completed',
        parameters: {
          'schedule_count': scheduleCount,
          'company_count': companyCount,
        },
      );
      debugPrint('📊 Analytics: Restore completed - $scheduleCount schedules, $companyCount companies');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  // ========== 기능 사용 추적 ==========

  /// 일반 기능 사용 이벤트
  Future<void> logFeatureUsed({
    required String featureName,
    Map<String, Object>? parameters,
  }) async {
    try {
      // Firebase Analytics는 String 또는 num만 허용하므로 boolean을 변환
      final sanitizedParams = <String, Object>{};
      parameters?.forEach((key, value) {
        if (value is bool) {
          sanitizedParams[key] = value ? 'true' : 'false';
        } else {
          sanitizedParams[key] = value;
        }
      });

      await _analytics.logEvent(
        name: 'feature_used',
        parameters: {
          'feature_name': featureName,
          ...sanitizedParams,
        },
      );
      debugPrint('📊 Analytics: Feature used - $featureName');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  /// 오류 이벤트
  Future<void> logError({
    required String errorType,
    required String errorMessage,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'error_message': errorMessage,
        },
      );
      debugPrint('📊 Analytics: Error - $errorType: $errorMessage');
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }
}
