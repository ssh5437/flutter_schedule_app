import 'package:shared_preferences/shared_preferences.dart';

class TextExtractionLimitHelper {
  static const String _usageCountKey = 'text_extraction_usage_count';
  static const String _lastResetDateKey = 'text_extraction_last_reset_date';
  static const int monthlyLimit = 10;

  /// 이번 달 남은 사용 가능 횟수 반환
  static Future<int> getRemainingCount() async {
    await _resetIfNewMonth();
    final prefs = await SharedPreferences.getInstance();
    final usageCount = prefs.getInt(_usageCountKey) ?? 0;
    return monthlyLimit - usageCount;
  }

  /// 사용 횟수 증가 (성공 시 true, 제한 초과 시 false 반환)
  static Future<bool> incrementUsage() async {
    await _resetIfNewMonth();
    final prefs = await SharedPreferences.getInstance();
    final usageCount = prefs.getInt(_usageCountKey) ?? 0;

    if (usageCount >= monthlyLimit) {
      return false; // 제한 초과
    }

    await prefs.setInt(_usageCountKey, usageCount + 1);
    return true;
  }

  /// 이번 달의 총 사용 횟수 반환
  static Future<int> getUsageCount() async {
    await _resetIfNewMonth();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_usageCountKey) ?? 0;
  }

  /// 새로운 달이 되었으면 사용 횟수 초기화
  static Future<void> _resetIfNewMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month}';
    final lastResetDate = prefs.getString(_lastResetDateKey);

    if (lastResetDate != currentMonthKey) {
      // 새로운 달이므로 초기화
      await prefs.setInt(_usageCountKey, 0);
      await prefs.setString(_lastResetDateKey, currentMonthKey);
    }
  }

  /// 테스트용: 사용 횟수 초기화
  static Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_usageCountKey, 0);
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month}';
    await prefs.setString(_lastResetDateKey, currentMonthKey);
  }
}
