import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LastSeenService {
  static const String _lastSeenKey = 'last_seen_date';

  /// 앱 실행 시 last_seen 업데이트 (하루에 한 번만)
  static Future<void> updateLastSeenIfNeeded() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ [LastSeen] User not logged in, skipping');
        return;
      }

      // SharedPreferences에서 마지막 업데이트 날짜 확인
      final prefs = await SharedPreferences.getInstance();
      final lastSeenDateStr = prefs.getString(_lastSeenKey);
      final today = _getTodayString();

      // 오늘 이미 업데이트했으면 스킵
      if (lastSeenDateStr == today) {
        debugPrint('ℹ️ [LastSeen] Already updated today, skipping');
        return;
      }

      // Supabase에 업데이트 (날짜만, 시간은 제외)
      await Supabase.instance.client
          .from('profiles')
          .update({'last_seen_at': today})
          .eq('id', userId);

      // SharedPreferences에 오늘 날짜 저장
      await prefs.setString(_lastSeenKey, today);

      debugPrint('✅ [LastSeen] Updated to $today');
    } catch (e) {
      debugPrint('❌ [LastSeen] Failed to update: $e');
      // 실패해도 앱 실행에는 영향 없도록
    }
  }

  /// 오늘 날짜를 YYYY-MM-DD 형식으로 반환
  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 테스트용: 저장된 날짜 초기화
  static Future<void> resetLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSeenKey);
    debugPrint('🔄 [LastSeen] Reset complete');
  }
}
