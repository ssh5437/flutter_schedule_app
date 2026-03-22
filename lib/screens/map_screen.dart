import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/schedule.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _clientId = 'rx7kr4kzw2';
  static const String _clientSecret = 'lUPTbH9hFmIEZ1AYrBky006ZPcPScZgvSuMcbKGG';

  bool _isRangeMode = false;
  DateTime _selectedDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 6));

  List<Schedule> _filteredSchedules = [];
  bool _isLoading = false;
  bool _isGeocoding = false;
  NaverMapController? _mapController;
  bool _mapReady = false;

  // 초기 지도 위치 (현재 위치 또는 서울 기본값)
  NLatLng _initialCameraTarget = const NLatLng(37.5666102, 126.9783881);
  bool _locationReady = false;

  // 현재 지도에 표시된 마커 위치 목록
  final List<NLatLng> _markerPositions = [];

  // 주소 → 좌표 캐시
  static final Map<String, NLatLng?> _geocodeCache = {};

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      // 위치 서비스 활성화 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationReady = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchedules());
        return;
      }

      // 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationReady = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchedules());
        return;
      }

      // 현재 위치 가져오기 (빠른 응답용으로 낮은 정확도)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (mounted) {
        setState(() {
          _initialCameraTarget = NLatLng(position.latitude, position.longitude);
          _locationReady = true;
        });
      }
    } catch (e) {
      debugPrint('현재 위치 가져오기 실패: $e');
      if (mounted) setState(() => _locationReady = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchedules());
  }

  Future<NLatLng?> _geocode(String address) async {
    if (_geocodeCache.containsKey(address)) return _geocodeCache[address];

    try {
      final uri = Uri.parse(
        'https://maps.apigw.ntruss.com/map-geocode/v2/geocode?query=${Uri.encodeComponent(address)}',
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
          _geocodeCache[address] = NLatLng(lat, lng);
          return _geocodeCache[address];
        }
      }
    } catch (e) {
      debugPrint('Geocoding 오류 ("$address"): $e');
    }
    _geocodeCache[address] = null;
    return null;
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final allSchedules = await DatabaseHelper.instance.readAllSchedules(userId);

      final start = _isRangeMode ? _startDate : _selectedDate;
      final end = _isRangeMode ? _endDate : _selectedDate;
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

      final filtered = allSchedules.where((s) {
        if (s.visitDate == null) return false;
        if (s.address == null || s.address!.trim().isEmpty) return false;
        return !s.visitDate!.isBefore(startDay) && !s.visitDate!.isAfter(endDay);
      }).toList();

      setState(() {
        _filteredSchedules = filtered;
        _isLoading = false;
      });

      if (_mapReady) await _updateMapMarkers();
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('스케줄 로드 오류: $e');
    }
  }

  Future<void> _updateMapMarkers() async {
    if (_mapController == null) return;

    setState(() => _isGeocoding = true);

    await _mapController!.clearOverlays();

    final List<NLatLng> positions = [];

    for (final schedule in _filteredSchedules) {
      final address = schedule.address ?? '';
      if (address.isEmpty) continue;

      final latLng = await _geocode(address);
      if (latLng == null) continue;

      positions.add(latLng);

      final markerColor = _dayOfWeekColor(schedule.visitDate!.weekday);
      final captionText = _workItemCaption(schedule.workItems);

      // 커스텀 원형 마커 아이콘 생성
      if (!mounted) break;
      final markerIcon = await NOverlayImage.fromWidget(
        context: context,
        widget: _ColoredMarker(color: markerColor),
        size: const Size(22, 22),
      );

      final marker = NMarker(
        id: '${schedule.id}',
        position: latLng,
        icon: markerIcon,
        caption: NOverlayCaption(
          text: captionText,
          textSize: 13,
          color: Colors.black87,
          haloColor: Colors.white,
        ),
        subCaption: NOverlayCaption(
          text: schedule.visitTime ?? '시간 미정',
          textSize: 11,
          color: Colors.black54,
          haloColor: Colors.white,
        ),
      );

      marker.setOnTapListener((_) {
        _showScheduleBottomSheet(schedule);
      });

        await _mapController!.addOverlay(marker);
    }

    // 마커 위치 저장 (현재 위치 포함 전체 보기 버튼에서 사용)
    _markerPositions
      ..clear()
      ..addAll(positions);

    // 마커 위치에 맞게 카메라 이동 (최대 zoom 13 = 약 1km 축척)
    const double maxAutoZoom = 13.0;
    if (positions.isNotEmpty) {
      if (positions.length == 1) {
        await _mapController!.updateCamera(
          NCameraUpdate.withParams(target: positions.first, zoom: maxAutoZoom),
        );
      } else {
        final minLat = positions.map((p) => p.latitude).reduce(min);
        final maxLat = positions.map((p) => p.latitude).reduce(max);
        final minLng = positions.map((p) => p.longitude).reduce(min);
        final maxLng = positions.map((p) => p.longitude).reduce(max);
        final bounds = NLatLngBounds(
          southWest: NLatLng(minLat, minLng),
          northEast: NLatLng(maxLat, maxLng),
        );
        await _mapController!.updateCamera(
          NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(80)),
        );
        // fitBounds가 너무 가깝게 확대될 경우 최대 zoom 제한
        final pos = await _mapController!.getCameraPosition();
        if (pos.zoom > maxAutoZoom) {
          await _mapController!.updateCamera(
            NCameraUpdate.withParams(zoom: maxAutoZoom),
          );
        }
      }
    }

    setState(() => _isGeocoding = false);
  }

  // 현재 위치 + 스케줄 마커를 모두 포함하여 지도 화면에 맞추기
  Future<void> _fitToCurrentLocationAndMarkers() async {
    if (_mapController == null) return;

    NLatLng? currentLatLng;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      currentLatLng = NLatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('현재 위치 가져오기 실패: $e');
    }

    final allPoints = [
      if (currentLatLng != null) currentLatLng,
      ..._markerPositions,
    ];

    if (allPoints.isEmpty) return;

    if (allPoints.length == 1) {
      await _mapController!.updateCamera(
        NCameraUpdate.withParams(target: allPoints.first, zoom: 13),
      );
      return;
    }

    final minLat = allPoints.map((p) => p.latitude).reduce(min);
    final maxLat = allPoints.map((p) => p.latitude).reduce(max);
    final minLng = allPoints.map((p) => p.longitude).reduce(min);
    final maxLng = allPoints.map((p) => p.longitude).reduce(max);
    final bounds = NLatLngBounds(
      southWest: NLatLng(minLat, minLng),
      northEast: NLatLng(maxLat, maxLng),
    );
    await _mapController!.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(80)),
    );
    final pos = await _mapController!.getCameraPosition();
    if (pos.zoom > 13) {
      await _mapController!.updateCamera(NCameraUpdate.withParams(zoom: 13));
    }
  }

  // 현재 위치로만 이동
  Future<void> _goToCurrentLocation() async {
    if (_mapController == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      await _mapController!.updateCamera(
        NCameraUpdate.withParams(
          target: NLatLng(position.latitude, position.longitude),
          zoom: 13,
        ),
      );
    } catch (e) {
      debugPrint('현재 위치 이동 실패: $e');
    }
  }

  void _showScheduleBottomSheet(Schedule schedule) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    schedule.customerName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(schedule.computedStatus).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    schedule.computedStatus,
                    style: TextStyle(
                      color: _statusColor(schedule.computedStatus),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (schedule.companyName != null && schedule.companyName!.isNotEmpty)
              _infoRow(Icons.business, schedule.companyName!),
            _infoRow(
              Icons.calendar_today,
              '${DateFormat('M월 d일 (E)', 'ko_KR').format(schedule.visitDate!)}  '
              '${schedule.visitTime ?? '시간 미정'}',
            ),
            _infoRow(Icons.location_on, schedule.address ?? ''),
            if (schedule.phoneNumber.isNotEmpty)
              _infoRow(Icons.phone, schedule.phoneNumber),
            if (schedule.workItems.isNotEmpty)
              _infoRow(Icons.work_outline, schedule.workItems.take(3).join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  // 요일별 마커 색상: 일(빨) 월(주황) 화(노) 수(초) 목(파) 금(남) 토(보라)
  Color _dayOfWeekColor(int weekday) {
    switch (weekday) {
      case DateTime.sunday:    return const Color(0xFFE53935); // 빨
      case DateTime.monday:    return const Color(0xFFFF7043); // 주황
      case DateTime.tuesday:   return const Color(0xFFFFB300); // 노
      case DateTime.wednesday: return const Color(0xFF43A047); // 초
      case DateTime.thursday:  return const Color(0xFF1E88E5); // 파
      case DateTime.friday:    return const Color(0xFF3949AB); // 남
      case DateTime.saturday:  return const Color(0xFF8E24AA); // 보
      default:                 return const Color(0xFF1E88E5);
    }
  }

  // 작업항목 캡션: 1개면 그대로, 2개 이상이면 "첫번째항목 외 N개"
  String _workItemCaption(List<String> workItems) {
    if (workItems.isEmpty) return '작업 미정';
    if (workItems.length == 1) return workItems.first;
    return '${workItems.first} 외 ${workItems.length - 1}개';
  }

  Color _statusColor(String status) {
    switch (status) {
      case '완료': return Colors.green;
      case '취소': return Colors.red;
      default: return const Color(0xFF579bf2);
    }
  }

  // 하루 선택 → 선택 즉시 조회
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    _loadSchedules();
  }

  // 기간 선택 (달력 하나에서 시작일~종료일 한 번에) → 선택 즉시 조회
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF579bf2),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
    _loadSchedules();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지도로 보기'),
        backgroundColor: const Color(0xFF579bf2),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // 날짜 선택 영역
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 하루 / 기간 토글
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('하루'), icon: Icon(Icons.today, size: 16)),
                    ButtonSegment(value: true, label: Text('기간'), icon: Icon(Icons.date_range, size: 16)),
                  ],
                  selected: {_isRangeMode},
                  onSelectionChanged: (v) => setState(() => _isRangeMode = v.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return const Color(0xFF579bf2);
                      return null;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return Colors.white;
                      return null;
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                // 날짜 선택
                if (!_isRangeMode)
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 17, color: Color(0xFF579bf2)),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_selectedDate),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, size: 17, color: Color(0xFF579bf2)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${DateFormat('M월 d일 (E)', 'ko_KR').format(_startDate)}  →  ${DateFormat('M월 d일 (E)', 'ko_KR').format(_endDate)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _isLoading || _isGeocoding ? null : _loadSchedules,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF579bf2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('조회', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          // 결과 수 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                if (_isGeocoding) ...[
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 8),
                  const Text('위치 변환 중...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ] else if (_isLoading)
                  const Text('로딩 중...', style: TextStyle(fontSize: 13, color: Colors.grey))
                else ...[
                  Icon(Icons.place, size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    _filteredSchedules.isEmpty
                        ? '해당 기간에 주소가 등록된 스케줄이 없습니다'
                        : '${_filteredSchedules.length}개 스케줄 (마커를 탭하면 상세 정보)',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          // 지도
          Expanded(
            child: Stack(
              children: [
                if (!_locationReady)
                  const Center(child: CircularProgressIndicator())
                else
                NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: _initialCameraTarget,
                      zoom: 13,
                    ),
                    mapType: NMapType.basic,
                    activeLayerGroups: const [NLayerGroup.building, NLayerGroup.transit],
                    logoAlign: NLogoAlign.leftBottom,
                  ),
                  onMapReady: (controller) async {
                    _mapController = controller;
                    _mapReady = true;
                    // 현재 위치 마커 표시 (카메라는 이동하지 않음)
                    controller.setLocationTrackingMode(NLocationTrackingMode.noFollow);
                    if (_filteredSchedules.isNotEmpty) {
                      await _updateMapMarkers();
                    }
                  },
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
                // 버튼 두 개: 현재 위치 이동 + 전체 보기
                if (_locationReady)
                  Positioned(
                    right: 12,
                    bottom: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'fit_all',
                          onPressed: _fitToCurrentLocationAndMarkers,
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF579bf2),
                          tooltip: '현재 위치 + 스케줄 전체 보기',
                          child: const Icon(Icons.zoom_out_map),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'go_location',
                          onPressed: _goToCurrentLocation,
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF579bf2),
                          tooltip: '현재 위치로 이동',
                          child: const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 요일별 색상이 적용된 원형 마커 위젯
class _ColoredMarker extends StatelessWidget {
  final Color color;
  const _ColoredMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}
