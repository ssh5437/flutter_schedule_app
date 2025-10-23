import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';

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

        // 현재 사용자의 스케줄 샘플 (최대 3개)
        if (userSchedulesCount.first['count'] as int > 0) {
          final sampleSchedules = await db.query(
            'schedules',
            where: 'userId = ?',
            whereArgs: [user.id],
            limit: 3,
          );

          buffer.writeln('📋 현재 사용자 스케줄 샘플:');
          for (var schedule in sampleSchedules) {
            buffer.writeln('  - ${schedule['customerName']}');
            buffer.writeln('    status: ${schedule['status']}');
            buffer.writeln('    visitDate: ${schedule['visitDate']}');
            buffer.writeln('    visitTime: ${schedule['visitTime']}');
          }
        } else {
          buffer.writeln('❌ 현재 사용자의 스케줄이 없습니다.');

          // 다른 userId의 스케줄이 있는지 확인
          if (allSchedulesCount.first['count'] as int > 0) {
            buffer.writeln('');
            buffer.writeln('⚠️ 다른 userId로 저장된 스케줄이 있습니다.');
            buffer.writeln('   이전에 다른 계정으로 로그인했거나,');
            buffer.writeln('   데이터가 다른 userId로 저장되었을 수 있습니다.');
            buffer.writeln('');
            buffer.writeln('💡 해결 방법:');
            buffer.writeln('   1. 설정 > 백업하기로 데이터 백업');
            buffer.writeln('   2. 앱 재설치 또는 데이터 삭제');
            buffer.writeln('   3. 동일한 이메일로 로그인');
            buffer.writeln('   4. 설정 > 복원하기로 데이터 복원');
          }
        }

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
      appBar: AppBar(
        title: const Text('디버그 정보'),
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
          ],
        ),
      ),
    );
  }
}
