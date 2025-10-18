import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class GeminiHelper {
  static const String _apiKey = 'AIzaSyDc0CX4HQZac4RxKuWJSEgSed68tZ7CfyU';

  static Future<Map<String, dynamic>?> extractScheduleInfo(String text) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: _apiKey,
      );

      final prompt = '''
다음 텍스트에서 스케줄 정보를 추출해주세요. 추출할 정보는 다음과 같습니다:
- 고객명 (name)
- 전화번호 (phone) - 숫자만 추출
- 주소 (address)
- 날짜 (date) - YYYY-MM-DD 형식
- 시간 (time) - HH:MM 형식 (24시간제)

JSON 형식으로만 응답해주세요. 값을 찾을 수 없는 경우 null을 사용하세요.
형식 예시:
{
  "name": "홍길동",
  "phone": "01012345678",
  "address": "서울시 강남구 테헤란로 123",
  "date": "2025-10-15",
  "time": "14:00"
}

텍스트:
$text

JSON 응답:
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text == null) {
        return null;
      }

      // JSON 추출 (마크다운 코드 블록 제거)
      String jsonText = response.text!.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      } else if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      // JSON 파싱
      final data = json.decode(jsonText) as Map<String, dynamic>;
      return data;
    } catch (e) {
      print('Gemini API 오류: $e');
      return null;
    }
  }
}
