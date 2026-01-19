import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

/// 앱 에러 및 성능 로그를 Supabase에 저장하는 서비스
class ErrorLogService {
  static final ErrorLogService _instance = ErrorLogService._internal();
  factory ErrorLogService() => _instance;
  ErrorLogService._internal();

  final _supabase = Supabase.instance.client;
  String? _appVersion;
  String? _buildNumber;

  /// 앱 버전 정보 초기화
  Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
      debugPrint('📊 ErrorLogService initialized: v$_appVersion+$_buildNumber');
    } catch (e) {
      debugPrint('⚠️ Failed to get package info: $e');
    }
  }

  /// 에러 로그 저장
  Future<void> logError({
    required String errorType,
    required String message,
    String? stackTrace,
    String? screenName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      await _supabase.from('error_logs').insert({
        'user_id': userId,
        'error_type': errorType,
        'message': message,
        'stack_trace': stackTrace,
        'screen_name': screenName,
        'app_version': _appVersion,
        'build_number': _buildNumber,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'additional_data': additionalData,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('📊 Error logged: $errorType - $message');
    } catch (e) {
      // 에러 로깅 실패 시 콘솔에만 출력 (무한 루프 방지)
      debugPrint('⚠️ Failed to log error to Supabase: $e');
    }
  }

  /// 앱 시작 성능 로그
  Future<void> logAppStartup({
    required int durationMs,
    required String stage,
    bool success = true,
    String? errorMessage,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      await _supabase.from('error_logs').insert({
        'user_id': userId,
        'error_type': success ? 'performance' : 'startup_error',
        'message': success
            ? 'App startup completed: $stage in ${durationMs}ms'
            : 'App startup failed at $stage: $errorMessage',
        'screen_name': 'app_startup',
        'app_version': _appVersion,
        'build_number': _buildNumber,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'additional_data': {
          'stage': stage,
          'duration_ms': durationMs,
          'success': success,
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('📊 Startup log: $stage - ${durationMs}ms (${success ? 'success' : 'failed'})');
    } catch (e) {
      debugPrint('⚠️ Failed to log startup: $e');
    }
  }

  /// 느린 로딩 감지 로그 (타임아웃)
  Future<void> logSlowLoading({
    required String operation,
    required int durationMs,
    int thresholdMs = 5000,
    String? screenName,
  }) async {
    if (durationMs < thresholdMs) return; // 임계값 미만이면 로깅 안함

    try {
      final userId = _supabase.auth.currentUser?.id;

      await _supabase.from('error_logs').insert({
        'user_id': userId,
        'error_type': 'slow_loading',
        'message': '$operation took ${durationMs}ms (threshold: ${thresholdMs}ms)',
        'screen_name': screenName,
        'app_version': _appVersion,
        'build_number': _buildNumber,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'additional_data': {
          'operation': operation,
          'duration_ms': durationMs,
          'threshold_ms': thresholdMs,
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('📊 Slow loading logged: $operation - ${durationMs}ms');
    } catch (e) {
      debugPrint('⚠️ Failed to log slow loading: $e');
    }
  }

  /// API 에러 로그
  Future<void> logApiError({
    required String endpoint,
    required String errorMessage,
    int? statusCode,
    String? screenName,
  }) async {
    await logError(
      errorType: 'api_error',
      message: 'API Error: $endpoint - $errorMessage',
      screenName: screenName,
      additionalData: {
        'endpoint': endpoint,
        'status_code': statusCode,
      },
    );
  }

  /// 예외 로그 (try-catch에서 사용)
  Future<void> logException({
    required dynamic exception,
    StackTrace? stackTrace,
    String? screenName,
    String? context,
  }) async {
    await logError(
      errorType: 'exception',
      message: context != null ? '$context: ${exception.toString()}' : exception.toString(),
      stackTrace: stackTrace?.toString(),
      screenName: screenName,
    );
  }
}
