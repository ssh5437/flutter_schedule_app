import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';

/// 로컬 SQLite 데이터를 Supabase로 초기 업로드하는 서비스
/// - 최초 1회만 실행 (완료 후 SharedPreferences에 플래그 저장)
/// - 진행 상황을 Stream으로 제공하여 UI에서 표시 가능
class DataMigrationService {
  static final DataMigrationService instance = DataMigrationService._();
  DataMigrationService._();

  static const String _migratedKey = 'supabase_migration_completed_v1';

  SupabaseClient get _client => Supabase.instance.client;

  /// 마이그레이션이 이미 완료됐는지 확인
  Future<bool> isMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migratedKey) ?? false;
  }

  /// 마이그레이션 완료 플래그 저장
  Future<void> _markMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migratedKey, true);
  }

  /// 마이그레이션 완료 플래그 초기화 (재마이그레이션 강제 실행용)
  Future<void> resetMigrationFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migratedKey);
  }

  /// 로컬 → Supabase 전체 마이그레이션
  /// [onProgress] : (현재 단계 이름, 완료 건수, 전체 건수) 콜백
  Future<MigrationResult> migrate(
    String userId, {
    void Function(String step, int done, int total)? onProgress,
  }) async {
    int totalUploaded = 0;
    int totalFailed = 0;

    try {
      // ── 1. 스케줄 ──────────────────────────────
      onProgress?.call('스케줄 업로드 중...', 0, 0);
      final scheduleResult = await _migrateSchedules(userId, onProgress);
      totalUploaded += scheduleResult.uploaded;
      totalFailed += scheduleResult.failed;

      // ── 2. 업체 ────────────────────────────────
      onProgress?.call('업체 업로드 중...', 0, 0);
      final companyResult = await _migrateCompanies(userId, onProgress);
      totalUploaded += companyResult.uploaded;
      totalFailed += companyResult.failed;

      // ── 3. 메시지 템플릿 ───────────────────────
      onProgress?.call('메시지 템플릿 업로드 중...', 0, 0);
      final templateResult = await _migrateMessageTemplates(userId, onProgress);
      totalUploaded += templateResult.uploaded;
      totalFailed += templateResult.failed;

      // ── 4. 날짜 메모 ───────────────────────────
      onProgress?.call('날짜 메모 업로드 중...', 0, 0);
      final memoResult = await _migrateDateMemos(userId, onProgress);
      totalUploaded += memoResult.uploaded;
      totalFailed += memoResult.failed;

      await _markMigrationCompleted();
      onProgress?.call('완료', totalUploaded, totalUploaded + totalFailed);

      debugPrint('✅ [Migration] 완료: 업로드 $totalUploaded건, 실패 $totalFailed건');
      return MigrationResult(
        success: true,
        uploaded: totalUploaded,
        failed: totalFailed,
      );
    } catch (e, stack) {
      debugPrint('❌ [Migration] 오류: $e\n$stack');
      return MigrationResult(
        success: false,
        uploaded: totalUploaded,
        failed: totalFailed,
        error: e.toString(),
      );
    }
  }

  Future<_StepResult> _migrateSchedules(
    String userId,
    void Function(String, int, int)? onProgress,
  ) async {
    int uploaded = 0;
    int failed = 0;

    try {
      final schedules = await DatabaseHelper.instance.readAllSchedules(userId);
      final total = schedules.length;
      debugPrint('📦 [Migration] 스케줄 $total건 마이그레이션 시작');

      // 배치 단위로 업로드 (50건씩)
      const batchSize = 50;
      for (int i = 0; i < schedules.length; i += batchSize) {
        final batch = schedules.skip(i).take(batchSize).toList();
        try {
          final rows = batch
              .where((s) => s.id != null)
              .map((s) => {
                    'id': s.id,
                    'user_id': s.userId,
                    'customer_name': s.customerName,
                    'visit_date': s.visitDate?.toIso8601String().split('T')[0],
                    'visit_time': s.visitTime,
                    'phone_number': s.phoneNumber,
                    'address': s.address,
                    'jibun_address': s.jibunAddress,
                    'company_name': s.companyName,
                    'work_items': s.workItems.join(','),
                    'work_prices': s.workPrices.entries.map((e) => '${e.key}:${e.value}').join('|'),
                    'work_count': s.workCount,
                    'notes': s.notes,
                    'status': s.status,
                    'synced_at': DateTime.now().toIso8601String(),
                  })
              .toList();
          if (rows.isNotEmpty) {
            await _client.from('schedules').upsert(rows);
            uploaded += rows.length;
          }
        } catch (e) {
          debugPrint('⚠️ [Migration] 스케줄 배치 실패: $e');
          failed += batch.length;
        }
        onProgress?.call('스케줄 업로드 중...', uploaded, total);
      }
    } catch (e) {
      debugPrint('❌ [Migration] 스케줄 전체 조회 실패: $e');
    }

    return _StepResult(uploaded, failed);
  }

  Future<_StepResult> _migrateCompanies(
    String userId,
    void Function(String, int, int)? onProgress,
  ) async {
    int uploaded = 0;
    int failed = 0;

    try {
      final companies = await DatabaseHelper.instance.readAllCompanies(userId);
      final total = companies.length;
      debugPrint('📦 [Migration] 업체 $total건 마이그레이션 시작');

      final rows = companies
          .where((c) => c.id != null)
          .map((c) => {
                'id': c.id,
                'user_id': c.userId,
                'name': c.name,
                'work_items': jsonEncode(c.workItems.map((i) => i.toMap()).toList()),
                'color': c.color,
                'display_order': c.displayOrder,
                'synced_at': DateTime.now().toIso8601String(),
              })
          .toList();

      if (rows.isNotEmpty) {
        await _client.from('companies').upsert(rows);
        uploaded = rows.length;
      }
      onProgress?.call('업체 업로드 중...', uploaded, total);
    } catch (e) {
      debugPrint('❌ [Migration] 업체 마이그레이션 실패: $e');
      failed++;
    }

    return _StepResult(uploaded, failed);
  }

  Future<_StepResult> _migrateMessageTemplates(
    String userId,
    void Function(String, int, int)? onProgress,
  ) async {
    int uploaded = 0;
    int failed = 0;

    try {
      final templates = await DatabaseHelper.instance.readAllMessageTemplatesForUser(userId);
      final total = templates.length;
      debugPrint('📦 [Migration] 메시지 템플릿 $total건 마이그레이션 시작');

      final rows = templates
          .where((t) => t.id != null)
          .map((t) => {
                'id': t.id,
                'user_id': t.userId,
                'company_id': t.companyId,
                'name': t.name,
                'content': t.content,
                'display_order': t.displayOrder,
                'created_at': t.createdAt.toIso8601String(),
                'synced_at': DateTime.now().toIso8601String(),
              })
          .toList();

      if (rows.isNotEmpty) {
        await _client.from('message_templates').upsert(rows);
        uploaded = rows.length;
      }
      onProgress?.call('메시지 템플릿 업로드 중...', uploaded, total);
    } catch (e) {
      debugPrint('❌ [Migration] 메시지 템플릿 마이그레이션 실패: $e');
      failed++;
    }

    return _StepResult(uploaded, failed);
  }

  Future<_StepResult> _migrateDateMemos(
    String userId,
    void Function(String, int, int)? onProgress,
  ) async {
    int uploaded = 0;
    int failed = 0;

    try {
      final memos = await DatabaseHelper.instance.readAllMemos(userId);
      final total = memos.length;
      debugPrint('📦 [Migration] 날짜 메모 $total건 마이그레이션 시작');

      final rows = memos
          .where((m) => m.id != null)
          .map((m) => {
                'id': m.id,
                'user_id': m.userId,
                'date': m.date.toIso8601String().split('T')[0],
                'content': m.content,
                'created_at': m.createdAt.toIso8601String(),
                'updated_at': m.updatedAt?.toIso8601String(),
                'synced_at': DateTime.now().toIso8601String(),
              })
          .toList();

      if (rows.isNotEmpty) {
        await _client.from('date_memos').upsert(rows);
        uploaded = rows.length;
      }
      onProgress?.call('날짜 메모 업로드 중...', uploaded, total);
    } catch (e) {
      debugPrint('❌ [Migration] 날짜 메모 마이그레이션 실패: $e');
      failed++;
    }

    return _StepResult(uploaded, failed);
  }
}

class MigrationResult {
  final bool success;
  final int uploaded;
  final int failed;
  final String? error;

  MigrationResult({
    required this.success,
    required this.uploaded,
    required this.failed,
    this.error,
  });
}

class _StepResult {
  final int uploaded;
  final int failed;
  _StepResult(this.uploaded, this.failed);
}
