import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../utils/encryption_helper.dart';

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
          // 캘린더 설정 섹션
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '캘린더',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

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
                builder: (context) => AlertDialog(
                  title: const Text('기본 캘린더 선택'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        title: const Text('월간 캘린더'),
                        value: 'monthly',
                        groupValue: _defaultCalendar,
                        onChanged: (value) {
                          if (value != null) {
                            _saveDefaultCalendar(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('주간 캘린더'),
                        value: 'weekly',
                        groupValue: _defaultCalendar,
                        onChanged: (value) {
                          if (value != null) {
                            _saveDefaultCalendar(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
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
