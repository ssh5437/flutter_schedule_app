import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class NaverNavigationHelper {
  static const String _clientId = 'rx7kr4kzw2';
  static const String _clientSecret = 'lUPTbH9hFmIEZ1AYrBky006ZPcPScZgvSuMcbKGG';
  static const String _appPackage = 'com.vividlifekr.bizplan';

  // 주소 → 좌표 캐시 (앱 내 공유)
  static final Map<String, _LatLng?> _geocodeCache = {};

  /// 주소를 위도/경도로 변환
  static Future<_LatLng?> _geocode(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    if (_geocodeCache.containsKey(trimmed)) return _geocodeCache[trimmed];

    try {
      final uri = Uri.parse(
        'https://maps.apigw.ntruss.com/map-geocode/v2/geocode?query=${Uri.encodeComponent(trimmed)}',
      );
      final response = await http.get(uri, headers: {
        'X-NCP-APIGW-API-KEY-ID': _clientId,
        'X-NCP-APIGW-API-KEY': _clientSecret,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addresses = data['addresses'] as List?;
        if (addresses != null && addresses.isNotEmpty) {
          final lat = double.parse(addresses[0]['y'].toString());
          final lng = double.parse(addresses[0]['x'].toString());
          final result = _LatLng(lat, lng);
          _geocodeCache[trimmed] = result;
          return result;
        }
      }
    } catch (e) {
      debugPrint('Geocoding 오류 ("$trimmed"): $e');
    }
    _geocodeCache[trimmed] = null;
    return null;
  }

  /// 두 주소 간 네이버 지도 길 안내 열기
  /// [context] - 로딩 표시 및 오류 안내용
  /// [fromAddress] - 출발지 주소
  /// [fromName] - 출발지 표시명
  /// [toAddress] - 도착지 주소
  /// [toName] - 도착지 표시명
  static Future<void> openNavigation({
    required BuildContext context,
    required String fromAddress,
    required String fromName,
    required String toAddress,
    required String toName,
  }) async {
    // 로딩 스낵바
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('경로를 불러오는 중...'),
        duration: Duration(seconds: 2),
      ),
    );

    // 출발지/도착지 좌표 동시 조회
    final results = await Future.wait([
      _geocode(fromAddress),
      _geocode(toAddress),
    ]);

    final from = results[0];
    final to = results[1];

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (from == null || to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(from == null
              ? '출발지 주소를 찾을 수 없습니다: $fromName'
              : '도착지 주소를 찾을 수 없습니다: $toName'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 네이버 지도 앱 URL scheme
    final appUrl = Uri.parse(
      'nmap://route/car'
      '?slat=${from.lat}&slng=${from.lng}&sname=${Uri.encodeComponent(fromName)}'
      '&dlat=${to.lat}&dlng=${to.lng}&dname=${Uri.encodeComponent(toName)}'
      '&appname=$_appPackage',
    );

    // 앱 미설치 시 스토어 링크
    final storeUrl = Uri.parse(
      'market://details?id=com.nhn.android.nmap',
    );

    if (await canLaunchUrl(appUrl)) {
      await launchUrl(appUrl);
    } else {
      // 네이버 지도 앱 미설치 → Play Store로 이동 안내
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('네이버 지도 앱 필요'),
            content: const Text('길 안내를 위해 네이버 지도 앱이 필요합니다.\n지금 설치하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
                },
                child: const Text('설치하기'),
              ),
            ],
          ),
        );
      }
    }
  }
}

class _LatLng {
  final double lat;
  final double lng;
  const _LatLng(this.lat, this.lng);
}
