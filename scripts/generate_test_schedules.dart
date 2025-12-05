import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/models/schedule.dart';
import '../lib/database/database_helper.dart';

/// 테스트용 스케줄 3000개를 생성하는 스크립트
/// 2025년 10월 이전 날짜로, 하루에 랜덤으로 0~8개씩 생성
Future<void> main() async {
  print('테스트 스케줄 생성 시작...');

  // Supabase 초기화 (실제 프로젝트의 설정값 사용)
  // TODO: 실제 Supabase URL과 키로 교체 필요
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    print('오류: 로그인된 사용자가 없습니다.');
    return;
  }

  // 기존 스케줄 샘플 데이터 가져오기
  final existingSchedules = await DatabaseHelper.instance.readAllSchedules(userId);
  if (existingSchedules.isEmpty) {
    print('오류: 기존 스케줄 데이터가 없습니다. 최소 1개 이상의 스케줄이 필요합니다.');
    return;
  }

  print('기존 스케줄 ${existingSchedules.length}개 발견');

  final random = Random();
  final targetCount = 3000;
  int createdCount = 0;

  // 2025년 1월 1일부터 2025년 9월 30일까지
  final startDate = DateTime(2025, 1, 1);
  final endDate = DateTime(2025, 9, 30);
  final totalDays = endDate.difference(startDate).inDays + 1;

  // 고객명 샘플
  final customerNames = ['김철수', '이영희', '박민수', '정수진', '최동욱', '강미경', '윤서준', '임지원'];

  // 작업 항목 샘플
  final workTypes = [
    ['문짝교체', '방충망교체'],
    ['문짝교체'],
    ['방충망교체'],
    ['창틀보수', '방충망교체'],
    ['유리교체', '창틀보수'],
    ['유리교체'],
  ];

  // 업체명 샘플
  final companies = ['메인업체', '서브업체A', '서브업체B'];

  // 지역 샘플
  final regions = ['서울', '경기', '인천', '부산', '대전', '대구', '광주'];

  print('날짜별 랜덤 스케줄 생성 중...');

  for (int dayOffset = 0; dayOffset < totalDays && createdCount < targetCount; dayOffset++) {
    final currentDate = startDate.add(Duration(days: dayOffset));

    // 하루에 0~8개 랜덤 생성
    final schedulesForDay = random.nextInt(9); // 0~8

    for (int i = 0; i < schedulesForDay && createdCount < targetCount; i++) {
      // 기존 스케줄 중 하나를 랜덤으로 선택해서 템플릿으로 사용
      final template = existingSchedules[random.nextInt(existingSchedules.length)];

      // 랜덤 시간 생성 (09:00 ~ 18:00)
      final hour = 9 + random.nextInt(10);
      final minute = random.nextInt(60);
      final visitTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

      // 랜덤 데이터로 새 스케줄 생성
      final newSchedule = Schedule(
        userId: userId,
        customerName: customerNames[random.nextInt(customerNames.length)],
        visitDate: currentDate,
        visitTime: visitTime,
        phoneNumber: '010-${1000 + random.nextInt(9000)}-${1000 + random.nextInt(9000)}',
        address: '${regions[random.nextInt(regions.length)]} ${random.nextInt(100) + 1}번지',
        companyName: companies[random.nextInt(companies.length)],
        workItems: workTypes[random.nextInt(workTypes.length)],
        workPrices: {}, // 가격 정보는 선택적
        workCount: random.nextInt(3) + 1, // 1~3건
        notes: random.nextBool() ? '테스트 데이터' : null,
        status: '완료', // 과거 날짜이므로 완료 상태
      );

      try {
        await DatabaseHelper.instance.createSchedule(newSchedule);
        createdCount++;

        // 진행률 표시 (100개마다)
        if (createdCount % 100 == 0) {
          print('진행: $createdCount / $targetCount 개 생성됨 (${(createdCount / targetCount * 100).toStringAsFixed(1)}%)');
        }
      } catch (e) {
        print('오류: 스케줄 생성 실패 - $e');
      }
    }
  }

  print('완료! 총 $createdCount개의 테스트 스케줄이 생성되었습니다.');
}
