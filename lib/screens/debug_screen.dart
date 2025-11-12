import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
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
            _buildMembershipTestSection(),
          ],
        ),
      ),
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
                    '현재 상태: ${hasActive ? "✅ 프리미엄" : "❌ 무료"}',
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
                label: const Text('테스트 프리미엄 활성화'),
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
                      '테스트 모드는 실제 구글 플레이 구매 없이 프리미엄 기능을 테스트할 수 있습니다. 로컬 DB와 Supabase에 모두 동기화됩니다.',
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
            content: Text('✅ 테스트 프리미엄이 활성화되었습니다!'),
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
