import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/widget_service.dart';
import '../widgets/gradient_app_bar.dart';
import 'notification_settings_screen.dart';
import 'membership_screen.dart';
import 'debug_screen.dart';
import '../providers/subscription_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _defaultCalendar = 'monthly'; // 'monthly' 또는 'weekly'
  Color _pendingColor = const Color(0xFFFAE6BB); // 미확정 스케줄 색상 (연한 주황)
  Color _confirmedColor = const Color(0xFFFFFFFF); // 확정 스케줄 색상 (흰색)
  Color _widgetBackgroundColor = const Color(0xFFFFFFFF); // 위젯 배경색 (흰색)

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
      _widgetBackgroundColor = Color(prefs.getInt('widget_background_color') ?? 0xFFFFFFFF);
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

  Future<void> _saveWidgetBackgroundColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = color.toARGB32();
    await prefs.setInt('widget_background_color', colorValue);

    // 디버그: 저장된 값 확인
    debugPrint('위젯 배경색 저장: $colorValue (0x${colorValue.toRadixString(16)})');

    setState(() {
      _widgetBackgroundColor = color;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('위젯 배경색이 변경되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // 위젯 업데이트
    await WidgetService.updateWidget();
  }

  void _showWidgetColorPicker() {
    Color selectedColor = _widgetBackgroundColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위젯 배경색 선택'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _widgetBackgroundColor,
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
              _saveWidgetBackgroundColor(selectedColor);
              Navigator.pop(context);
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
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
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    final hasActiveSubscription = subscriptionProvider.hasActiveSubscription;

    DateTime? startDate;
    DateTime? endDate;

    // 멤버십 상태에 따라 기간 선택 다이얼로그 표시
    if (hasActiveSubscription) {
      // Plus: 기간 선택 또는 전체 백업
      final result = await _showPremiumBackupDialog();
      if (result == null) return; // 취소

      startDate = result['startDate'] as DateTime?;
      endDate = result['endDate'] as DateTime?;
    } else {
      // 무료: 이번 달 1일 이후 데이터 백업 가능
      final now = DateTime.now();
      startDate = DateTime(now.year, now.month, 1); // 이번 달 1일
      endDate = DateTime(now.year, 12, 31); // 올해 12월 31일
    }

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final backupService = BackupService();
      final filePath = await backupService.downloadBackup(
        startDate: startDate,
        endDate: endDate,
      );

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
        await backupService.shareBackup(startDate: startDate, endDate: endDate);
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

  // Plus 사용자 백업 다이얼로그
  Future<Map<String, dynamic>?> _showPremiumBackupDialog() async {
    DateTime? startDate;
    DateTime? endDate;
    bool isAllData = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF579bf2), width: 2),
                  ),
                  child: const Icon(Icons.workspace_premium, color: Color(0xFF579bf2), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Plus 백업',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('전체 데이터 백업'),
                  subtitle: const Text('모든 기간의 데이터를 백업합니다'),
                  value: isAllData,
                  onChanged: (value) {
                    setState(() {
                      isAllData = value;
                      if (value) {
                        startDate = null;
                        endDate = null;
                      }
                    });
                  },
                ),
                if (!isAllData) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '기간 선택',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => startDate = picked);
                            }
                          },
                          child: Text(
                            startDate != null
                                ? DateFormat('yyyy-MM-dd').format(startDate!)
                                : '시작일',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('~'),
                      ),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: startDate ?? DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => endDate = picked);
                            }
                          },
                          child: Text(
                            endDate != null
                                ? DateFormat('yyyy-MM-dd').format(endDate!)
                                : '종료일',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  // 전체 데이터 백업이 아닌 경우, 시작일과 종료일이 필수
                  if (!isAllData && (startDate == null || endDate == null)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('시작일과 종료일을 모두 선택해주세요'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context, {
                    'startDate': startDate,
                    'endDate': endDate,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                ),
                child: const Text('백업 시작'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 백업 복구
  Future<void> _performRestore() async {
    try {
      debugPrint('========================================');
      debugPrint('🔄 백업 복구 프로세스 시작');
      final backupService = BackupService();
      final filePath = await backupService.pickBackupFile();

      debugPrint('선택된 파일 경로: $filePath');

      if (filePath == null) {
        debugPrint('❌ 파일이 선택되지 않음');
        return;
      }

      debugPrint('✅ 파일 선택됨, 복구 다이얼로그 표시');

      if (!mounted) {
        debugPrint('❌ Widget이 unmounted 상태 (파일 선택 후)');
        return;
      }

      // 복구 진행 다이얼로그 표시 (백업 정보 조회부터 복구까지 모두 다이얼로그 내부에서)
      final beforeDialog = DateTime.now();
      debugPrint('🕐 showDialog 호출 직전');

      if (!mounted) return;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _RestoreProgressDialog(
          filePath: filePath,
        ),
      );

      final afterDialog = DateTime.now();
      debugPrint('🕐 showDialog 완료 (${afterDialog.difference(beforeDialog).inMilliseconds}ms)');

      if (result == null) {
        debugPrint('❌ 복구 다이얼로그에서 null 반환');
        return;
      }

      if (!mounted) {
        debugPrint('⚠️ 복구 완료했지만 Widget이 unmounted 상태 - UI 업데이트 생략');
        return;
      }

      // 결과 메시지 생성
      final schedulesSuccess = result['schedules'] as int;
      final companiesSuccess = result['companies'] as int;
      final memosSuccess = result['memos'] as int? ?? 0;
      final templatesSuccess = result['messageTemplates'] as int? ?? 0;
      final schedulesFailed = result['schedulesFailed'] as int;
      final companiesFailed = result['companiesFailed'] as int;
      final memosFailed = result['memosFailed'] as int? ?? 0;
      final templatesFailed = result['templatesFailed'] as int? ?? 0;
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
      if (memosSuccess > 0 || memosFailed > 0) {
        message += '\n메모: $memosSuccess개 성공';
        if (memosFailed > 0) {
          message += ', $memosFailed개 실패';
        }
      }
      if (templatesSuccess > 0 || templatesFailed > 0) {
        message += '\n메시지 템플릿: $templatesSuccess개 성공';
        if (templatesFailed > 0) {
          message += ', $templatesFailed개 실패';
        }
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
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('❌❌❌ 복구 프로세스 에러 발생 ❌❌❌');
      debugPrint('에러: $e');
      debugPrint('스택트레이스: $stackTrace');
      debugPrint('========================================');

      if (!mounted) {
        debugPrint('❌ Widget unmounted 상태에서 에러 발생');
        return;
      }

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
          ListTile(
            leading: const Icon(Icons.card_membership),
            title: const Text('멤버십 관리'),
            subtitle: const Text('Plus 구독 및 혜택'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MembershipScreen()),
              );
            },
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

          // 스케줄 색상 설정
          ListTile(
            leading: Icon(Icons.palette, color: _pendingColor),
            title: const Text('미확정 스케줄 색상'),
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
          
          const Divider(),
          
          ListTile(
            leading: Icon(Icons.widgets, color: _widgetBackgroundColor),
            title: const Text('위젯 배경색'),
            subtitle: const Text('홈 화면 위젯의 배경색을 변경합니다'),
            trailing: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _widgetBackgroundColor,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onTap: _showWidgetColorPicker,
          ),

          // 위젯 새로고침 버튼
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.purple),
            title: const Text('위젯 새로고침'),
            subtitle: const Text('홈 화면 위젯 데이터를 즉시 업데이트합니다'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                debugPrint('====== 수동 위젯 새로고침 시작 ======');
                await WidgetService.updateWidget();
                debugPrint('====== 수동 위젯 새로고침 완료 ======');
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('위젯이 새로고침되었습니다. 로그를 확인하세요.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              } catch (e) {
                debugPrint('위젯 새로고침 에러: $e');
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('위젯 새로고침 실패: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),

          const Divider(),

         

          // 데이터 관리 섹션
          const Padding(
            padding: EdgeInsets.all(10.0),
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
            padding: EdgeInsets.all(10.0),
            child: Text(
              '보안',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

     

          // 디버그 정보 (ssh5437@gmail.com만 접근 가능)
          if (Supabase.instance.client.auth.currentUser?.email == 'ssh5437@gmail.com')
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('디버그 정보'),
              subtitle: const Text('데이터베이스 상태 및 멤버십 테스트'),
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
              final messenger = ScaffoldMessenger.of(context);
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
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('로그아웃 실패: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),

          // 문의 메일 보내기
          ListTile(
            leading: const Icon(Icons.email, color: Colors.blue),
            title: const Text('문의 메일 보내기'),
            subtitle: const Text('앱 사용 중 문의사항이나 건의사항을 보내주세요'),
            onTap: () async {
              final Uri emailUri = Uri(
                scheme: 'mailto',
                path: 'vividlifekr@gmail.com',
                query: 'subject=${Uri.encodeComponent('B-EZ 관리 앱 문의')}',
              );

              try {
                // LaunchMode.externalApplication을 사용하여 외부 앱으로 실행
                final launched = await launchUrl(
                  emailUri,
                  mode: LaunchMode.externalApplication,
                );

                if (!launched && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('메일 앱을 열 수 없습니다.\n이메일: vividlifekr@gmail.com'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('메일 앱을 열 수 없습니다.\n이메일: vividlifekr@gmail.com'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
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

// 복구 진행 다이얼로그 (독립적인 StatefulWidget)
class _RestoreProgressDialog extends StatefulWidget {
  final String filePath;

  const _RestoreProgressDialog({
    required this.filePath,
  });

  @override
  State<_RestoreProgressDialog> createState() => _RestoreProgressDialogState();
}

class _RestoreProgressDialogState extends State<_RestoreProgressDialog> {
  bool _showOptions = true; // 옵션 선택 화면 표시 여부
  String _statusMessage = '백업 정보 조회 중...';
  double _progress = 0.0;
  bool _isComplete = false;
  bool _bypassSignature = false; // 서명 검증 우회 (직접 편집 복구)
  bool _isSignatureError = false; // 서명 오류 여부

  // 백업 정보
  int _schedulesCount = 0;
  int _companiesCount = 0;
  int _memosCount = 0;
  int _messageTemplatesCount = 0;
  DateTime? _exportDate;
  bool _backupInfoLoaded = false;
  Map<String, dynamic>? _cachedBackupData; // 백업 데이터 캐싱

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    try {
      final dialogStartTime = DateTime.now();
      debugPrint('🕐 다이얼로그 _loadBackupInfo 시작');

      final backupService = BackupService();

      // 백업 파일을 읽어서 캐싱 (한 번만 읽음)
      final beforeRead = DateTime.now();
      _cachedBackupData = await backupService.readBackupFile(widget.filePath, bypassSignature: _bypassSignature);
      final afterRead = DateTime.now();
      debugPrint('🕐 readBackupFile 완료 (${afterRead.difference(beforeRead).inMilliseconds}ms)');

      // 백업 정보 추출
      final schedules = _cachedBackupData!['schedules'] as List?;
      final companies = _cachedBackupData!['companies'] as List?;
      final memos = _cachedBackupData!['memos'] as List?;
      final messageTemplates = _cachedBackupData!['messageTemplates'] as List?;
      final exportDate = _cachedBackupData!['exportDate'] as String?;

      if (mounted) {
        setState(() {
          _schedulesCount = schedules?.length ?? 0;
          _companiesCount = companies?.length ?? 0;
          _memosCount = memos?.length ?? 0;
          _messageTemplatesCount = messageTemplates?.length ?? 0;
          _exportDate = exportDate != null ? DateTime.parse(exportDate) : null;
          _backupInfoLoaded = true;
          _statusMessage = '백업 정보 조회 완료';
        });
        final totalTime = DateTime.now().difference(dialogStartTime).inMilliseconds;
        debugPrint('🕐 다이얼로그 _loadBackupInfo 완료 (총 ${totalTime}ms)');
      }
    } catch (e) {
      debugPrint('백업 정보 조회 실패: $e');
      if (mounted) {
        final errorStr = e.toString();
        final isSignatureError = errorStr.contains('서명 불일치') || errorStr.contains('서명') || errorStr.contains('signature');
        setState(() {
          _showOptions = false;
          _isSignatureError = isSignatureError;
          _statusMessage = '파일 읽기 실패\n$errorStr';
          _isComplete = true;
        });
      }
    }
  }

  Future<void> _retryWithBypass() async {
    setState(() {
      _bypassSignature = true;
      _isSignatureError = false;
      _showOptions = true;
      _backupInfoLoaded = false;
      _isComplete = false;
      _statusMessage = '백업 정보 조회 중...';
      _cachedBackupData = null;
    });
    await _loadBackupInfo();
  }

  Future<void> _performRestore(bool replaceAll) async {
    final performRestoreStartTime = DateTime.now();
    debugPrint('🕐 _performRestore 시작 (replaceAll: $replaceAll)');

    setState(() {
      _showOptions = false;
      _statusMessage = replaceAll ? '기존 데이터 삭제 중...' : '데이터 복구 중...';
      _progress = 0.1;
    });

    try {
      final backupService = BackupService();

      // replaceAll일 경우 삭제 진행 중 메시지 표시
      if (replaceAll) {
        await Future.delayed(const Duration(milliseconds: 100)); // UI 업데이트 시간
        setState(() {
          _statusMessage = '데이터 복구 중...';
          _progress = 0.3;
        });
      }

      final beforeRestore = DateTime.now();
      debugPrint('🕐 restoreBackup 호출 직전');

      // 캐싱된 데이터를 사용하므로 파일 읽기 단계 생략
      final result = await backupService.restoreBackup(
        widget.filePath,
        replaceAll: replaceAll,
        bypassSignature: _bypassSignature,
        cachedData: _cachedBackupData,
      );

      final afterRestore = DateTime.now();
      debugPrint('🕐 restoreBackup 완료 (${afterRestore.difference(beforeRestore).inMilliseconds}ms)');
      debugPrint('🕐 _performRestore 총 시간: ${afterRestore.difference(performRestoreStartTime).inMilliseconds}ms');

      setState(() {
        _statusMessage = '복구 완료!';
        _progress = 1.0;
        _isComplete = true;
      });

      // 1초 대기 후 결과 반환
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      debugPrint('복구 다이얼로그 에러: $e');

      if (mounted) {
        setState(() {
          _statusMessage = '복구 실패\n${e.toString()}';
          _isComplete = true;
          // _showOptions = false 는 이미 _performRestore 시작 시 설정됨
        });
        // 자동 닫힘 제거 → 닫기 버튼으로만 닫을 수 있음
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _showOptions, // 옵션 선택 화면에서만 뒤로가기 가능
      child: AlertDialog(
        title: Text(_showOptions ? '백업 복구' : '데이터 복구'),
        content: _showOptions
          ? !_backupInfoLoaded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusMessage),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('백업 일시: ${_exportDate != null ? DateFormat('yyyy-MM-dd HH:mm').format(_exportDate!) : '알 수 없음'}'),
                    Text('스케줄: $_schedulesCount개'),
                    Text('업체: $_companiesCount개'),
                    if (_memosCount > 0) Text('메모: $_memosCount개'),
                    if (_messageTemplatesCount > 0) Text('메시지 템플릿: $_messageTemplatesCount개'),
                    const SizedBox(height: 16),
                    const Text('복구 방법을 선택하세요:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('• 기존 데이터에 추가: 현재 데이터 유지', style: TextStyle(fontSize: 12)),
                    const Text('• 전체 교체: 현재 데이터 삭제 후 복구', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isComplete) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                ] else ...[
                  Icon(
                    _statusMessage.contains('실패') ? Icons.error : Icons.check_circle,
                    color: _statusMessage.contains('실패') ? Colors.red : Colors.green,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                if (!_isComplete) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: _progress),
                ],
              ],
            ),
        actions: _showOptions && _backupInfoLoaded ? [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              debugPrint('✅ 사용자가 "기존 데이터에 추가" 선택');
              _performRestore(false);
            },
            child: const Text('기존 데이터에 추가'),
          ),
          TextButton(
            onPressed: () {
              debugPrint('✅ 사용자가 "전체 교체" 선택');
              _performRestore(true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('전체 교체'),
          ),
        ] : (!_showOptions && _isComplete) ? [
          // 에러 또는 완료 상태에서 닫기 버튼
          if (_isSignatureError &&
              Supabase.instance.client.auth.currentUser?.email == 'ssh5437@gmail.com')
            TextButton(
              onPressed: _retryWithBypass,
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('직접 편집 복구'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('닫기'),
          ),
        ] : null,
      ),
    );
  }
}
