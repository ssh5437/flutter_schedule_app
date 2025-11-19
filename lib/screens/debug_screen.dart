import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/schedule.dart';
import '../widgets/gradient_app_bar.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _debugInfo = '로딩 중...';
  bool _hasLegacyData = false;
  bool _isGeneratingTestData = false;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    try {
      final buffer = StringBuffer();

      // 사용자 정보
      final user = Supabase.instance.client.auth.currentUser;
      buffer.writeln('🔐 사용자 정보');
      buffer.writeln('User ID: ${user?.id ?? "없음"}');
      buffer.writeln('Email: ${user?.email ?? "없음"}');
      buffer.writeln('');

      if (user != null) {
        // 데이터베이스 정보
        final db = await DatabaseHelper.instance.database;

        // 전체 스케줄 수 (userId 무관)
        final allSchedulesCount = await db.rawQuery('SELECT COUNT(*) as count FROM schedules');
        buffer.writeln('📊 전체 스케줄 수: ${allSchedulesCount.first['count']}');

        // 현재 사용자 스케줄 수
        final userSchedulesCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM schedules WHERE userId = ?',
          [user.id]
        );
        buffer.writeln('📅 현재 사용자 스케줄 수: ${userSchedulesCount.first['count']}');
        buffer.writeln('');

        // 데이터베이스의 모든 userId 목록
        final userIds = await db.rawQuery('SELECT DISTINCT userId FROM schedules');
        buffer.writeln('👥 데이터베이스의 userId 목록:');
        if (userIds.isEmpty) {
          buffer.writeln('  (없음)');
        } else {
          for (var row in userIds) {
            final dbUserId = row['userId'] as String?;
            if (dbUserId == null) {
              buffer.writeln('  ⚠️ NULL (userId가 없는 데이터)');
              continue;
            }
            final count = await db.rawQuery(
              'SELECT COUNT(*) as count FROM schedules WHERE userId = ?',
              [dbUserId]
            );
            final isCurrentUser = dbUserId == user.id;
            final isLegacy = dbUserId == 'legacy_user';
            final marker = isCurrentUser ? "✅" : (isLegacy ? "⏳" : "  ");
            buffer.writeln('  $marker $dbUserId (${count.first['count']}개)');
            if (isLegacy) {
              buffer.writeln('     (이전 버전 데이터 - 마이그레이션 필요)');
            }
          }
        }
        buffer.writeln('');


        // 업체 정보
        buffer.writeln('');
        final companiesCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM companies WHERE userId = ?',
          [user.id]
        );
        buffer.writeln('🏢 현재 사용자 업체 수: ${companiesCount.first['count']}');

        // legacy_user 데이터 확인
        final legacyCount = await db.rawQuery(
          "SELECT COUNT(*) as count FROM schedules WHERE userId = 'legacy_user'"
        );
        final hasLegacy = (legacyCount.first['count'] as int) > 0;

        setState(() {
          _debugInfo = buffer.toString();
          _hasLegacyData = hasLegacy;
        });
      } else {
        setState(() {
          _debugInfo = buffer.toString();
          _hasLegacyData = false;
        });
      }
    } catch (e) {
      setState(() {
        _debugInfo = '❌ 에러 발생: $e';
        _hasLegacyData = false;
      });
    }
  }

  Future<void> _generateTestSchedules() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 로그인이 필요합니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 기존 스케줄 확인
      final existingSchedules = await DatabaseHelper.instance.readAllSchedules(user.id);
      if (existingSchedules.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 최소 1개 이상의 스케줄이 필요합니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('테스트 데이터 생성'),
          content: const Text(
            '3000개의 테스트 스케줄을 생성합니다.\n'
            '(2023년 11월 ~ 2025년 9월, 하루 0~8개 랜덤)\n\n'
            '이 작업은 시간이 걸릴 수 있습니다.\n계속하시겠습니까?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('확인'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() {
        _isGeneratingTestData = true;
      });

      // 로딩 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('테스트 데이터 생성 중...\n잠시만 기다려주세요.'),
              ],
            ),
          ),
        );
      }

      final random = Random();
      const targetCount = 3000;
      int createdCount = 0;

      // 2023년 11월 1일부터 2025년 9월 30일까지
      final startDate = DateTime(2023, 11, 1);
      final endDate = DateTime(2025, 9, 30);
      final totalDays = endDate.difference(startDate).inDays + 1;

      // 샘플 데이터
      final customerNames = ['김철수', '이영희', '박민수', '정수진', '최동욱', '강미경', '윤서준', '임지원', '조현우', '송지은'];
      final workTypes = [
        ['문짝교체', '방충망교체'],
        ['문짝교체'],
        ['방충망교체'],
        ['창틀보수', '방충망교체'],
        ['유리교체', '창틀보수'],
        ['유리교체'],
        ['문짝수리'],
        ['손잡이교체'],
      ];
      final companies = ['메인업체', '서브업체A', '서브업체B', '협력업체'];
      final regions = ['서울', '경기', '인천', '부산', '대전', '대구', '광주', '울산'];

      for (int dayOffset = 0; dayOffset < totalDays && createdCount < targetCount; dayOffset++) {
        final currentDate = startDate.add(Duration(days: dayOffset));

        // 하루에 0~8개 랜덤 생성
        final schedulesForDay = random.nextInt(9);

        for (int i = 0; i < schedulesForDay && createdCount < targetCount; i++) {
          // 랜덤 시간 생성 (09:00 ~ 18:00)
          final hour = 9 + random.nextInt(10);
          final minute = random.nextInt(60);
          final visitTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

          // 랜덤 가격 (50000 ~ 200000)
          final basePrice = 50000 + random.nextInt(150000);
          final workItemsList = workTypes[random.nextInt(workTypes.length)];
          final prices = <String, int>{};
          for (var item in workItemsList) {
            prices[item] = basePrice + random.nextInt(50000);
          }

          final newSchedule = Schedule(
            userId: user.id,
            customerName: customerNames[random.nextInt(customerNames.length)],
            requestDate: currentDate.subtract(Duration(days: random.nextInt(5) + 1)),
            visitDate: currentDate,
            visitTime: visitTime,
            phoneNumber: '010-${1000 + random.nextInt(9000)}-${1000 + random.nextInt(9000)}',
            address: '${regions[random.nextInt(regions.length)]} ${random.nextInt(100) + 1}번지 ${random.nextInt(50) + 1}호',
            companyName: companies[random.nextInt(companies.length)],
            workItems: workItemsList,
            workPrices: prices,
            workCount: workItemsList.length,
            notes: random.nextBool() ? '테스트 데이터' : null,
            status: '완료',
          );

          await DatabaseHelper.instance.createSchedule(newSchedule);
          createdCount++;
        }
      }

      setState(() {
        _isGeneratingTestData = false;
      });

      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $createdCount개의 테스트 스케줄이 생성되었습니다!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // 정보 새로고침
      await _loadDebugInfo();
    } catch (e) {
      setState(() {
        _isGeneratingTestData = false;
      });

      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 생성 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _migrateLegacyData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('데이터 마이그레이션'),
          content: const Text(
            'legacy_user 데이터를 현재 사용자 계정으로 이동합니다.\n\n'
            '이 작업은 되돌릴 수 없습니다. 계속하시겠습니까?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('확인'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final db = await DatabaseHelper.instance.database;

      // 스케줄 데이터 마이그레이션
      await db.update(
        'schedules',
        {'userId': user.id},
        where: "userId = 'legacy_user'",
      );

      // 업체 데이터 마이그레이션
      await db.update(
        'companies',
        {'userId': user.id},
        where: "userId = 'legacy_user'",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 데이터 마이그레이션이 완료되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 정보 새로고침
      await _loadDebugInfo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 마이그레이션 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(
        title: '디버그 정보',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _debugInfo,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadDebugInfo,
                icon: const Icon(Icons.refresh),
                label: const Text('새로고침'),
              ),
            ),
            if (_hasLegacyData) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _migrateLegacyData,
                  icon: const Icon(Icons.upload),
                  label: const Text('legacy_user 데이터 마이그레이션'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildTestDataSection(),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildMembershipTestSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🧪 테스트 데이터',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingTestData ? null : _generateTestSchedules,
            icon: _isGeneratingTestData
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
            label: Text(_isGeneratingTestData ? '생성 중...' : '테스트 스케줄 3000개 생성'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.purple[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '2023년 11월 ~ 2025년 9월 데이터를 생성합니다. 하루에 0~8개씩 랜덤으로 생성되며, 매출 통계 성능 테스트에 사용됩니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple[900],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipTestSection() {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final subscription = subscriptionProvider.subscription;
        final hasActive = subscriptionProvider.hasActiveSubscription;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧪 멤버십 테스트',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasActive ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasActive ? Colors.green : Colors.grey,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 상태: ${hasActive ? "✅ Plus" : "❌ 무료"}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasActive ? Colors.green[900] : Colors.grey[700],
                    ),
                  ),
                  if (subscription.isTestMode) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '🧪 테스트 모드',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                  if (hasActive) ...[
                    const SizedBox(height: 8),
                    Text(
                      '만료일: ${_formatDate(subscription.expiryDate)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '남은 기간: ${subscription.remainingDays}일',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _enableTestPremium(subscriptionProvider),
                icon: const Icon(Icons.star),
                label: const Text('테스트 Plus 활성화'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _enableTestExpired(subscriptionProvider),
                icon: const Icon(Icons.timer_off),
                label: const Text('테스트 만료 설정'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _clearTestSubscription(subscriptionProvider),
                icon: const Icon(Icons.delete_outline),
                label: const Text('테스트 구독 제거'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '테스트 모드는 실제 구글 플레이 구매 없이 Plus 기능을 테스트할 수 있습니다. 로컬 DB와 Supabase에 모두 동기화됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  Future<void> _enableTestPremium(SubscriptionProvider provider) async {
    try {
      await SubscriptionService().enableTestPremium(daysFromNow: 30);
      await provider.refreshSubscription();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 테스트 Plus가 활성화되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _enableTestExpired(SubscriptionProvider provider) async {
    try {
      await SubscriptionService().enableTestExpired();
      await provider.refreshSubscription();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 테스트 만료 구독이 설정되었습니다!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearTestSubscription(SubscriptionProvider provider) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('테스트 구독 제거'),
          content: const Text(
            '테스트 구독을 제거하시겠습니까?\n\n'
            '로컬 DB와 Supabase의 멤버십 정보가 모두 초기화됩니다.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('제거'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await SubscriptionService().clearTestSubscription();
      await provider.refreshSubscription();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 테스트 구독이 제거되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
