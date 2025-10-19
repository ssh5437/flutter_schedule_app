import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import '../utils/encryption_helper.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _defaultCalendar = 'monthly'; // 'monthly' 또는 'weekly'
  Color _pendingColor = const Color(0xFFFAE6BB); // 예정 스케줄 색상 (연한 주황)
  Color _confirmedColor = const Color(0xFFC7EAFA); // 확정 스케줄 색상 (연한 파랑)

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
      _confirmedColor = Color(prefs.getInt('confirmed_color') ?? 0xFFC7EAFA);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${status == 'pending' ? '예정' : '확정'} 스케줄 색상 선택'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              _saveStatusColor(status, color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '복구 완료\n스케줄: ${result['schedules']}개, 업체: ${result['companies']}개',
          ),
          backgroundColor: Colors.green,
        ),
      );
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
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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

          // 비밀번호 변경
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('비밀번호 변경'),
            subtitle: const Text('앱 보안 비밀번호를 변경합니다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
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

// 비밀번호 변경 화면
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('새 비밀번호가 일치하지 않습니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await EncryptionHelper.changePassword(
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('비밀번호가 성공적으로 변경되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('현재 비밀번호가 올바르지 않습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 변경', style: TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        toolbarHeight: 40,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 현재 비밀번호
            TextFormField(
              controller: _oldPasswordController,
              obscureText: _obscureOld,
              decoration: InputDecoration(
                labelText: '현재 비밀번호',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOld ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureOld = !_obscureOld;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '현재 비밀번호를 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 새 비밀번호
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: '새 비밀번호',
                hintText: '최소 6자 이상',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNew = !_obscureNew;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '새 비밀번호를 입력해주세요';
                }
                if (value.length < 6) {
                  return '비밀번호는 최소 6자 이상이어야 합니다';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 새 비밀번호 확인
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: '새 비밀번호 확인',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '새 비밀번호를 다시 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // 변경 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
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
                      '비밀번호 변경',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
