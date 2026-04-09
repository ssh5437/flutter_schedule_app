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
  static Future<void> openNavigation({
    required BuildContext context,
    required String fromAddress,
    required String fromName,
    required String toAddress,
    required String toName,
  }) async {
    await openMultiNavigation(
      context: context,
      stops: [
        (address: fromAddress, name: fromName),
        (address: toAddress, name: toName),
      ],
    );
  }

  /// 다중 경유지 네이버 지도 길 안내 열기
  /// stops[0] = 출발지, stops[last] = 도착지, 중간 = 경유지 (최대 5개)
  static Future<void> openMultiNavigation({
    required BuildContext context,
    required List<({String address, String name})> stops,
  }) async {
    if (stops.length < 2) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('경로를 불러오는 중...'),
        duration: Duration(seconds: 3),
      ),
    );

    final coords = await Future.wait(stops.map((s) => _geocode(s.address)));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // 좌표 조회 실패 확인
    for (int i = 0; i < coords.length; i++) {
      if (coords[i] == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('주소를 찾을 수 없습니다: ${stops[i].name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final start = coords.first!;
    final dest = coords.last!;
    final waypoints = coords.sublist(1, coords.length - 1);

    // nmap URL 조립
    final sb = StringBuffer(
      'nmap://route/car'
      '?slat=${start.lat}&slng=${start.lng}&sname=${Uri.encodeComponent(stops.first.name)}',
    );
    for (int i = 0; i < waypoints.length; i++) {
      final w = waypoints[i]!;
      final n = i + 1;
      sb.write('&v${n}lat=${w.lat}&v${n}lng=${w.lng}&v${n}name=${Uri.encodeComponent(stops[i + 1].name)}');
    }
    sb.write('&dlat=${dest.lat}&dlng=${dest.lng}&dname=${Uri.encodeComponent(stops.last.name)}');
    sb.write('&appname=$_appPackage');

    final appUrl = Uri.parse(sb.toString());
    final storeUrl = Uri.parse('market://details?id=com.nhn.android.nmap');

    if (await canLaunchUrl(appUrl)) {
      await launchUrl(appUrl);
    } else {
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
