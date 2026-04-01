import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/data_migration_service.dart';

/// 로컬 데이터를 Supabase로 초기 업로드하는 화면
/// - 첫 로그인 후 1회만 표시됨
/// - 완료/건너뛰기 후 홈 화면으로 이동
class DataMigrationScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const DataMigrationScreen({super.key, required this.onComplete});

  @override
  State<DataMigrationScreen> createState() => _DataMigrationScreenState();
}

class _DataMigrationScreenState extends State<DataMigrationScreen> {
  _MigrationState _state = _MigrationState.idle;
  String _stepMessage = '';
  int _done = 0;
  int _total = 0;
  String? _errorMessage;

  Future<void> _startMigration() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      widget.onComplete();
      return;
    }

    setState(() {
      _state = _MigrationState.running;
      _stepMessage = '준비 중...';
      _done = 0;
      _total = 0;
      _errorMessage = null;
    });

    final result = await DataMigrationService.instance.migrate(
      userId,
      onProgress: (step, done, total) {
        if (mounted) {
          setState(() {
            _stepMessage = step;
            _done = done;
            _total = total;
          });
        }
      },
    );

    if (!mounted) return;

    if (result.success) {
      setState(() => _state = _MigrationState.done);
    } else {
      setState(() {
        _state = _MigrationState.error;
        _errorMessage = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              _buildIcon(),
              const SizedBox(height: 32),
              _buildTitle(),
              const SizedBox(height: 16),
              _buildDescription(),
              const SizedBox(height: 40),
              if (_state == _MigrationState.running) _buildProgress(),
              if (_state == _MigrationState.error) _buildError(),
              const Spacer(),
              _buildButtons(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (_state == _MigrationState.done) {
      return const Icon(Icons.cloud_done_rounded, size: 72, color: Color(0xFF4CAF50));
    }
    if (_state == _MigrationState.error) {
      return const Icon(Icons.cloud_off_rounded, size: 72, color: Color(0xFFF44336));
    }
    return const Icon(Icons.cloud_upload_rounded, size: 72, color: Color(0xFF2196F3));
  }

  Widget _buildTitle() {
    final text = switch (_state) {
      _MigrationState.idle => '클라우드 백업 설정',
      _MigrationState.running => '데이터 업로드 중...',
      _MigrationState.done => '백업 완료!',
      _MigrationState.error => '업로드 실패',
    };
    return Text(
      text,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescription() {
    final text = switch (_state) {
      _MigrationState.idle =>
        '기존 데이터를 클라우드에 백업합니다.\n이후 스케줄 등록/수정 시 자동으로 동기화됩니다.\n\n웹 버전과 데이터를 공유할 수 있습니다.',
      _MigrationState.running => _stepMessage,
      _MigrationState.done => '모든 데이터가 클라우드에 안전하게 저장되었습니다.\n이제 자동으로 동기화됩니다.',
      _MigrationState.error => '일부 데이터 업로드에 실패했습니다.\n나중에 설정에서 다시 시도할 수 있습니다.',
    };
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Colors.grey[600],
        height: 1.6,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildProgress() {
    final progress = _total > 0 ? _done / _total : null;
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          color: const Color(0xFF2196F3),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 12),
        if (_total > 0)
          Text(
            '$_done / $_total건',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Text(
        _errorMessage ?? '알 수 없는 오류',
        style: const TextStyle(fontSize: 13, color: Color(0xFFC62828)),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildButtons() {
    if (_state == _MigrationState.done) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: widget.onComplete,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('시작하기', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    if (_state == _MigrationState.running) {
      return const SizedBox(height: 52);
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _startMigration,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _state == _MigrationState.error ? '다시 시도' : '백업 시작',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            // 건너뛰기: 완료 플래그는 저장하지 않고 화면만 넘어감
            // (다음 앱 실행 시 다시 표시됨 — 원하면 아래처럼 완료 처리 가능)
            await DataMigrationService.instance.resetMigrationFlag();
            widget.onComplete();
          },
          child: Text(
            '나중에 하기',
            style: TextStyle(fontSize: 15, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }
}

enum _MigrationState { idle, running, done, error }
