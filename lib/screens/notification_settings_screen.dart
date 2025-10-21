import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _enablePreviousDay = true;
  bool _enableSameDay = true;
  int _previousDayHour = 20;
  int _previousDayMinute = 0;
  int _sameDayHour = 8;
  int _sameDayMinute = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await NotificationService.instance.getNotificationSettings();
    setState(() {
      _enablePreviousDay = settings['enablePreviousDay'] as bool;
      _enableSameDay = settings['enableSameDay'] as bool;
      _previousDayHour = settings['previousDayHour'] as int;
      _previousDayMinute = settings['previousDayMinute'] as int;
      _sameDayHour = settings['sameDayHour'] as int;
      _sameDayMinute = settings['sameDayMinute'] as int;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('=== 알림 설정 저장 시작 ===');
      debugPrint('전날 알림: $_enablePreviousDay ($_previousDayHour:$_previousDayMinute)');
      debugPrint('당일 알림: $_enableSameDay ($_sameDayHour:$_sameDayMinute)');

      await NotificationService.instance.saveNotificationSettings(
        enablePreviousDay: _enablePreviousDay,
        enableSameDay: _enableSameDay,
        previousDayHour: _previousDayHour,
        previousDayMinute: _previousDayMinute,
        sameDayHour: _sameDayHour,
        sameDayMinute: _sameDayMinute,
      );

      debugPrint('✅ 알림 설정 저장 완료');

      // 매일 반복되는 알림 예약
      debugPrint('🔔 매일 반복 알림 설정 시작...');
      await NotificationService.instance.setupDailyNotifications();
      debugPrint('✅ 매일 반복 알림 설정 완료');

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림 설정이 저장되었습니다.\n매일 설정한 시간에 스케줄을 확인합니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('!!! 알림 설정 저장 실패 !!!');
      debugPrint('에러: $e');
      debugPrint('스택 트레이스: $stackTrace');

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('설정 저장 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _selectTime(BuildContext context, bool isPreviousDay) async {
    final currentHour = isPreviousDay ? _previousDayHour : _sameDayHour;
    final currentMinute = isPreviousDay ? _previousDayMinute : _sameDayMinute;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isPreviousDay) {
          _previousDayHour = picked.hour;
          _previousDayMinute = picked.minute;
        } else {
          _sameDayHour = picked.hour;
          _sameDayMinute = picked.minute;
        }
      });
    }
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? '오후' : '오전';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$period ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _testNotification() async {
    await NotificationService.instance.showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('테스트 알림이 전송되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _scheduleTestNotification() async {
    await NotificationService.instance.scheduleTestNotificationAfterOneMinute();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('1분 후 테스트 알림이 예약되었습니다.\n알림이 오는지 확인하세요!'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showPendingNotifications() async {
    final pendingNotifications = await NotificationService.instance.getPendingNotifications();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('예약된 알림 목록 (${pendingNotifications.length}개)'),
        content: pendingNotifications.isEmpty
            ? const Text('예약된 알림이 없습니다.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: pendingNotifications.map((notification) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID: ${notification.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            notification.title ?? '제목 없음',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            notification.body ?? '내용 없음',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const Divider(),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissions() async {
    final permissions = await NotificationService.instance.getPermissionStatus();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 권한 상태'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPermissionRow('알림 권한', permissions['notification'] ?? false),
            const SizedBox(height: 8),
            _buildPermissionRow('정확한 알람', permissions['scheduleExactAlarm'] ?? false),
            const SizedBox(height: 8),
            _buildPermissionRow('배터리 최적화 제외', permissions['ignoreBatteryOptimizations'] ?? false),
            const SizedBox(height: 16),
            const Text(
              '모든 권한이 허용되어야 알림이 정상적으로 작동합니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestPermissions();
            },
            child: const Text('권한 요청'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String label, bool granted) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: granted ? Colors.black : Colors.red,
            ),
          ),
        ),
        Text(
          granted ? '허용됨' : '거부됨',
          style: TextStyle(
            fontSize: 12,
            color: granted ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _requestPermissions() async {
    final results = await NotificationService.instance.checkAndRequestPermissions();

    if (!mounted) return;

    final allGranted = results.values.every((granted) => granted);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allGranted
            ? '모든 권한이 허용되었습니다!'
            : '일부 권한이 거부되었습니다. 알림이 제대로 작동하지 않을 수 있습니다.',
        ),
        backgroundColor: allGranted ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 설정', style: TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        toolbarHeight: 40,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            '스케줄이 있는 날짜에 알림을 보냅니다.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // 전날 알림 설정
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '전날 알림',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '스케줄 하루 전에 알림',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enablePreviousDay,
                        onChanged: (value) {
                          setState(() {
                            _enablePreviousDay = value;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_enablePreviousDay) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectTime(context, true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('알림 시간'),
                            Row(
                              children: [
                                Text(
                                  _formatTime(_previousDayHour, _previousDayMinute),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.access_time, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 당일 알림 설정
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '당일 알림',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '스케줄 당일에 알림',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableSameDay,
                        onChanged: (value) {
                          setState(() {
                            _enableSameDay = value;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_enableSameDay) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectTime(context, false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('알림 시간'),
                            Row(
                              children: [
                                Text(
                                  _formatTime(_sameDayHour, _sameDayMinute),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.access_time, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 권한 확인 버튼
          ElevatedButton.icon(
            onPressed: _checkPermissions,
            icon: const Icon(Icons.security),
            label: const Text('알림 권한 확인'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          // 즉시 테스트 알림 버튼
          OutlinedButton.icon(
            onPressed: _testNotification,
            icon: const Icon(Icons.notification_add),
            label: const Text('즉시 테스트 알림 보내기'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          const SizedBox(height: 12),

          // 1분 후 테스트 알림 버튼
          OutlinedButton.icon(
            onPressed: _scheduleTestNotification,
            icon: const Icon(Icons.schedule),
            label: const Text('1분 후 테스트 알림 예약'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.blue,
            ),
          ),

          const SizedBox(height: 12),

          // 예약된 알림 확인 버튼
          OutlinedButton.icon(
            onPressed: _showPendingNotifications,
            icon: const Icon(Icons.list_alt),
            label: const Text('예약된 알림 목록 확인'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          const SizedBox(height: 16),

          // 저장 버튼
          ElevatedButton(
            onPressed: _isLoading ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '저장',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
