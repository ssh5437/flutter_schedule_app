import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeminiHelper {
  static Future<Map<String, dynamic>?> extractScheduleInfo(String text, {List<String>? availableWorkItems}) async {
    try {
      debugPrint('🚀 [GeminiHelper] Calling Edge Function...');

      // Supabase Edge Function 호출
      final response = await Supabase.instance.client.functions.invoke(
        'extract-schedule',
        body: {
          'text': text,
          'availableWorkItems': availableWorkItems,
        },
      );

      debugPrint('✅ [GeminiHelper] Edge Function response received');

      if (response.data == null) {
        debugPrint('Edge Function 응답 없음');
        return null;
      }

      // Edge Function 응답 파싱
      final data = response.data as Map<String, dynamic>;

      if (data.containsKey('error')) {
        debugPrint('Edge Function 오류: ${data['error']}');
        return null;
      }

      if (data.containsKey('data')) {
        return data['data'] as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('텍스트 추출 오류: $e');
      return null;
    }
  }
}
