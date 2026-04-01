import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';

/// Supabase → 로컬 SQLite 단방향 Pull 서비스
/// 웹에서 수정된 데이터를 앱 로컬 DB에 반영
class PullService {
  static final PullService instance = PullService._();
  PullService._();

  static const String _lastPullKey = 'last_pull_at';
  static const int _minIntervalMinutes = 5;

  SupabaseClient get _client => Supabase.instance.client;

  /// 마지막 pull 로부터 5분 이상 지난 경우에만 pull 실행
  /// 반환값: 업데이트된 스케줄 수 (스킵 시 0)
  Future<int> pullIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPullStr = prefs.getString(_lastPullKey);

    if (lastPullStr != null) {
      final lastPull = DateTime.parse(lastPullStr);
      final elapsed = DateTime.now().difference(lastPull).inMinutes;
      if (elapsed < _minIntervalMinutes) {
        debugPrint('⏭️ [Pull] 마지막 pull로부터 $elapsed분 경과 - 스킵');
        return 0;
      }
    }

    return pull();
  }

  /// Supabase에서 변경된 스케줄을 로컬 DB에 반영
  /// 반환값: 업데이트된 스케줄 수
  Future<int> pull() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final prefs = await SharedPreferences.getInstance();
    final lastPullStr = prefs.getString(_lastPullKey) ?? '2020-01-01T00:00:00.000Z';

    int updatedCount = 0;

    try {
      debugPrint('🔽 [Pull] 변경 데이터 조회 중 (last_pull: $lastPullStr)');

      final rows = await _client
          .from('schedules')
          .select()
          .eq('user_id', userId)
          .gt('synced_at', lastPullStr);

      if (rows.isEmpty) {
        debugPrint('✅ [Pull] 변경된 데이터 없음');
      } else {
        debugPrint('🔽 [Pull] 변경된 스케줄 ${rows.length}건 발견');
        for (final row in rows) {
          await DatabaseHelper.instance.upsertScheduleFromSupabase(row);
          updatedCount++;
        }
        debugPrint('✅ [Pull] $updatedCount건 로컬 DB 반영 완료');
      }

      // 성공 시 last_pull_at 업데이트
      await prefs.setString(_lastPullKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('⚠️ [Pull] 실패 (non-critical): $e');
    }

    return updatedCount;
  }

  /// 마지막 pull 타임스탬프 초기화 (재동기화 강제 실행용)
  Future<void> resetPullTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPullKey);
    debugPrint('🔄 [Pull] 타임스탬프 초기화됨');
  }
}
