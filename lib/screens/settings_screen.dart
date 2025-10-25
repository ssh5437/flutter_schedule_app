import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../widgets/gradient_app_bar.dart';
import 'notification_settings_screen.dart';
import 'debug_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _defaultCalendar = 'monthly'; // 'monthly' 또는 'weekly'
  Color _pendingColor = const Color(0xFFFAE6BB); // 예정 스케줄 색상 (연한 주황)
  Color _confirmedColor = const Color(0xFFFFFFFF); // 확정 스케줄 색상 (흰색)

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultCalendar = prefs.getString('default_calendar') ?? 'monthly';
      _pendingColor = Color(prefs.getInt('pending_color') ?? 0xFFFAE6BB);
      _confirmedColor = Color(prefs.getInt('confirmed_color') ?? 0xFFFFFFFF);
    });
  }

  Future<void> _saveDefaultCalendar(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_calendar', value);
    setState(() {
      _defaultCalendar = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('기본 캘린더가 ${value == 'monthly' ? '월간' : '주간'} 캘린더로 설정되었습니다'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveStatusColor(String status, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    if (status == 'pending') {
      await prefs.setInt('pending_color', color.toARGB32());
      setState(() {
        _pendingColor = color;
      });
    } else {
      await prefs.setInt('confirmed_color', color.toARGB32());
      setState(() {
        _confirmedColor = color;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${status == 'pending' ? '예정' : '확정'} 스케줄 색상이 변경되었습니다'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showColorPicker(String status, Color currentColor) {
    Color selectedColor = currentColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${status == 'pending' ? '예정' : '확정'} 스케줄 색상 선택'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              selectedColor = color;
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _saveStatusColor(status, selectedColor);
              Navigator.pop(context);
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  // 백업 실행
  Future<void> _performBackup() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final backupService = BackupService();
      final filePath = await backupService.downloadBackup();

      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      // 공유하기 옵션 표시
      final shouldShare = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('백업 완료'),
          content: Text('백업 파일이 저장되었습니다.\n\n$filePath\n\n다른 기기로 공유하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('닫기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('공유하기'),
            ),
          ],
        ),
      );

      if (shouldShare == true) {
        await backupService.shareBackup();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('백업 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 백업 복구
  Future<void> _performRestore() async {
    try {
      final backupService = BackupService();
      final filePath = await backupService.pickBackupFile();

      if (filePath == null) return;

      // 백업 정보 조회
      final backupInfo = await backupService.getBackupInfo(filePath);
      final exportDate = backupInfo['exportDate'] as DateTime?;
      final schedulesCount = backupInfo['schedulesCount'] as int;
      final companiesCount = backupInfo['companiesCount'] as int;

      if (!mounted) return;

      // 복구 옵션 선택
      final restoreOption = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('백업 복구'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('백업 일시: ${exportDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(exportDate) : '알 수 없음'}'),
              Text('스케줄: $schedulesCount개'),
              Text('업체: $companiesCount개'),
              const SizedBox(height: 16),
              const Text('복구 방법을 선택하세요:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'add'),
              child: const Text('기존 데이터에 추가'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('기존 데이터 삭제 후 복구'),
            ),
          ],
        ),
      );

      if (restoreOption == null) return;

      if (!mounted) return;

      // 최종 확인
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('복구 확인'),
          content: Text(
            restoreOption == 'replace'
                ? '기존 데이터를 모두 삭제하고 백업 데이터로 복구합니다.\n이 작업은 되돌릴 수 없습니다.'
                : '백업 데이터를 기존 데이터에 추가합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: restoreOption == 'replace' ? Colors.red : null,
              ),
              child: const Text('복구'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      if (!mounted) return;

      // 복구 실행
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await backupService.restoreBackup(
        filePath,
        replaceAll: restoreOption == 'replace',
      );

      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      // 결과 메시지 생성
      final schedulesSuccess = result['schedules'] as int;
      final companiesSuccess = result['companies'] as int;
      final schedulesFailed = result['schedulesFailed'] as int;
      final companiesFailed = result['companiesFailed'] as int;
      final errors = result['errors'] as List<String>;

      String message = '복구 완료\n';
      message += '스케줄: $schedulesSuccess개 성공';
      if (schedulesFailed > 0) {
        message += ', $schedulesFailed개 실패';
      }
      message += '\n업체: $companiesSuccess개 성공';
      if (companiesFailed > 0) {
        message += ', $companiesFailed개 실패';
      }

      // 에러가 있으면 상세 정보 다이얼로그 표시
      if (errors.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('복구 완료 (일부 오류 발생)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  const Text('오류 내역:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...errors.take(10).map((error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $error', style: const TextStyle(fontSize: 12)),
                  )),
                  if (errors.length > 10)
                    Text('... 외 ${errors.length - 10}개', style: const TextStyle(fontSize: 12)),
                ],
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // 로딩 닫기
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('복구 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(
        title: '설정',
        toolbarHeight: 40,
      ),
      body: ListView(
        children: [
          // 스케줄 색상 설정
          ListTile(
            leading: Icon(Icons.palette, color: _pendingColor),
            title: const Text('예정 스케줄 색상'),
            trailing: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _pendingColor,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onTap: () => _showColorPicker('pending', _pendingColor),
          ),

          ListTile(
            leading: Icon(Icons.palette, color: _confirmedColor),
            title: const Text('확정 스케줄 색상'),
            trailing: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _confirmedColor,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onTap: () => _showColorPicker('confirmed', _confirmedColor),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.calendar_view_month),
            title: const Text('기본 캘린더'),
            subtitle: Text(_defaultCalendar == 'monthly' ? '월간 캘린더' : '주간 캘린더'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  String selectedCalendar = _defaultCalendar;
                  return StatefulBuilder(
                    builder: (context, setState) => AlertDialog(
                      title: const Text('기본 캘린더 선택'),
                      content: RadioGroup<String>(
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedCalendar = value;
                            });
                            _saveDefaultCalendar(value);
                            Navigator.pop(context);
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<String>(
                              title: const Text('월간 캘린더'),
                              value: 'monthly',
                              selected: selectedCalendar == 'monthly',
                            ),
                            RadioListTile<String>(
                              title: const Text('주간 캘린더'),
                              value: 'weekly',
                              selected: selectedCalendar == 'weekly',
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const Divider(),

          // 데이터 관리 섹션
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '데이터 관리',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // 백업
          ListTile(
            leading: const Icon(Icons.backup, color: Colors.blue),
            title: const Text('데이터 백업'),
            subtitle: const Text('스케줄과 업체 데이터를 백업합니다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _performBackup,
          ),

          // 복구
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.green),
            title: const Text('데이터 복구'),
            subtitle: const Text('백업 파일에서 데이터를 복구합니다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _performRestore,
          ),

          const Divider(),

          // 보안 섹션
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '보안',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // 알림 설정
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('알림 설정'),
            subtitle: const Text('스케줄 알림 시간을 설정합니다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),

          // 디버그 정보
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.orange),
            title: const Text('디버그 정보'),
            subtitle: const Text('데이터베이스 상태를 확인합니다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DebugScreen(),
                ),
              );
            },
          ),

          // 로그아웃
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            subtitle: const Text('현재 계정에서 로그아웃합니다'),
            onTap: () async {
              // 확인 다이얼로그
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('정말 로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('로그아웃'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                try {
                  await AuthService().signOut();
                  // 로그아웃 성공 시 자동으로 로그인 화면으로 이동됨 (StreamBuilder에 의해)
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('로그아웃 실패: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),

          const Divider(),

          // 앱 정보 섹션
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '앱 정보',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          // 버전 정보
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('버전'),
            subtitle: Text('1.0.0'),
          ),

          // 위험 구역 및 모든 데이터 삭제 기능은 숨김 처리
          // const Divider(),
          // const Padding(
          //   padding: EdgeInsets.all(16.0),
          //   child: Text(
          //     '위험 구역',
          //     style: TextStyle(
          //       fontSize: 16,
          //       fontWeight: FontWeight.bold,
          //       color: Colors.red,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
