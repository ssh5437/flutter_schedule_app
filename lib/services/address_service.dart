import 'dart:convert';
import 'package:http/http.dart' as http;

class AddressService {
  static const String _confmKey = 'U01TX0FVVEgyMDI1MTEyMjA5MTQxMDExNjQ4MjI=';
  static const String _baseUrl = 'https://business.juso.go.kr/addrlink/addrLinkApi.do';

  /// 도로명 주소를 지번 주소로 변환
  ///
  /// [roadAddress] 도로명 주소 (예: "성남시 정자일로 177")
  ///
  /// 반환값: 지번 주소 (예: "경기도 성남시 분당구 정자동 178-1")
  /// 변환 실패 시 null 반환
  static Future<String?> convertToJibunAddress(String roadAddress) async {
    if (roadAddress.trim().isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'confmKey': _confmKey,
          'keyword': roadAddress,
          'resultType': 'json',
          'countPerPage': '1', // 첫 번째 결과만 가져오기
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // API 응답 구조: results.juso[0].jibunAddr
        final results = jsonData['results'];
        if (results == null) return null;

        final common = results['common'];
        if (common != null) {
          final errorCode = common['errorCode'];
          // 0: 정상, 그 외: 오류
          if (errorCode != '0') {
            return null;
          }
        }

        final juso = results['juso'];
        if (juso != null && juso is List && juso.isNotEmpty) {
          final firstResult = juso[0];
          final jibunAddr = firstResult['jibunAddr'];

          if (jibunAddr != null && jibunAddr.toString().trim().isNotEmpty) {
            return jibunAddr.toString();
          }
        }
      }
    } catch (e) {
      // 네트워크 오류 등은 무시하고 null 반환
      return null;
    }

    return null;
  }
}
