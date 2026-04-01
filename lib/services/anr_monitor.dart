import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 앱 응답 없음(ANR) 및 비정상 재실행 감지 서비스
class AnrMonitor {
  static final AnrMonitor instance = AnrMonitor._();
  AnrMonitor._();

  static const String _backgroundAtKey = 'anr_monitor_background_at';
  static const String _resumeStartKey  = 'anr_monitor_resume_start';
  static const String _pendingReportKey = 'anr_monitor_pending_report';

  // 앱이 백그라운드로 갈 때 타임스탬프 저장
  Future<void> onBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundAtKey, DateTime.now().toIso8601String());
    debugPrint('🔍 [AnrMonitor] 백그라운드 진입 시간 저장');
  }

  // 앱이 포그라운드로 돌아올 때 시작 시간 저장
  Future<void> onResumeStart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resumeStartKey, DateTime.now().toIso8601String());
  }

  // resume 처리 완료 후 소요 시간 측정 및 이상 감지
  Future<void> onResumeComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final resumeStartStr = prefs.getString(_resumeStartKey);
      final backgroundAtStr = prefs.getString(_backgroundAtKey);
      if (resumeStartStr == null) return;

      final resumeStart = DateTime.parse(resumeStartStr);
      final resumeDuration = DateTime.now().difference(resumeStart);

      // resume 처리에 3초 이상 걸린 경우 이상으로 판단
      if (resumeDuration.inSeconds >= 3) {
        final backgroundAt = backgroundAtStr != null
            ? DateTime.parse(backgroundAtStr)
            : null;
        final backgroundDuration = backgroundAt != null
            ? resumeStart.difference(backgroundAt)
            : null;

        final report = _buildReport(
          type: 'slow_resume',
          resumeDurationMs: resumeDuration.inMilliseconds,
          backgroundDurationMin: backgroundDuration?.inMinutes,
          backgroundAt: backgroundAtStr,
        );

        debugPrint('⚠️ [AnrMonitor] 느린 resume 감지: ${resumeDuration.inMilliseconds}ms');
        await _saveAndLog(report);
      }
    } catch (e) {
      debugPrint('⚠️ [AnrMonitor] onResumeComplete 오류: $e');
    }
  }

  // 앱 시작 시 이전 세션의 비정상 종료 여부 확인
  Future<void> checkPreviousSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backgroundAtStr = prefs.getString(_backgroundAtKey);
      final pendingReport = prefs.getString(_pendingReportKey);

      // 미발송 리포트가 있으면 이번에 전송
      if (pendingReport != null) {
        debugPrint('📋 [AnrMonitor] 이전 세션 비정상 종료 리포트 발견');
        await _uploadPendingReport(pendingReport);
        await prefs.remove(_pendingReportKey);
      }

      // 백그라운드 상태로 남아있다가 새로 시작된 경우 (ANR로 강제 종료 가능성)
      if (backgroundAtStr != null) {
        final backgroundAt = DateTime.parse(backgroundAtStr);
        final gapMinutes = DateTime.now().difference(backgroundAt).inMinutes;

        // 백그라운드 5분 이상 후 새로 시작 → ANR로 닫혔을 가능성
        if (gapMinutes >= 5) {
          final report = _buildReport(
            type: 'possible_anr_restart',
            backgroundAt: backgroundAtStr,
            backgroundDurationMin: gapMinutes,
            resumeDurationMs: null,
          );
          debugPrint('⚠️ [AnrMonitor] 가능한 ANR 재시작 감지 (백그라운드 ${gapMinutes}분)');
          await _saveAndLog(report);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AnrMonitor] checkPreviousSession 오류: $e');
    }
  }

  Map<String, dynamic> _buildReport({
    required String type,
    String? backgroundAt,
    int? backgroundDurationMin,
    int? resumeDurationMs,
  }) {
    return {
      'type': type,
      'background_at': backgroundAt,
      'background_duration_min': backgroundDurationMin,
      'resume_duration_ms': resumeDurationMs,
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _saveAndLog(Map<String, dynamic> report) async {
    try {
      // 1) Firebase Crashlytics에 non-fatal 이벤트로 기록
      await FirebaseCrashlytics.instance.setCustomKey(
        'anr_type', report['type'] as String);
      await FirebaseCrashlytics.instance.setCustomKey(
        'background_duration_min', '${report['background_duration_min'] ?? "unknown"}');
      await FirebaseCrashlytics.instance.setCustomKey(
        'resume_duration_ms', '${report['resume_duration_ms'] ?? 'unknown'}');
      await FirebaseCrashlytics.instance.recordError(
        Exception('ANR Monitor: ${report['type']}'),
        null,
        reason: 'background_duration=${report['background_duration_min']}min, '
                'resume_duration=${report['resume_duration_ms']}ms',
        fatal: false,
        printDetails: true,
      );

      // 2) Supabase error_logs에 기록
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final packageInfo = await PackageInfo.fromPlatform();
      await Supabase.instance.client.from('error_logs').insert({
        'user_id': userId,
        'error_type': report['type'],
        'message': '앱 응답 지연 감지: 백그라운드 ${report['background_duration_min']}분, '
                   'resume 소요 ${report['resume_duration_ms']}ms',
        'screen_name': 'lifecycle',
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'additional_data': report,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ [AnrMonitor] 리포트 저장 완료');
    } catch (e) {
      // Supabase 저장 실패 시 SharedPreferences에 임시 저장
      debugPrint('⚠️ [AnrMonitor] 리포트 저장 실패, 로컬에 임시 저장: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_pendingReportKey, report.toString());
      } catch (_) {}
    }
  }

  Future<void> _uploadPendingReport(String reportStr) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('error_logs').insert({
        'user_id': userId,
        'error_type': 'pending_anr_report',
        'message': '이전 세션 미전송 ANR 리포트',
        'screen_name': 'lifecycle',
        'additional_data': {'raw': reportStr},
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('⚠️ [AnrMonitor] 미전송 리포트 업로드 실패: $e');
    }
  }
}
