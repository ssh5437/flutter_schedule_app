import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_view_screen.dart';
import 'screens/completed_schedules_screen.dart';
import 'screens/schedule_form_screen.dart';
// 비밀번호 기능 임시 비활성화 (테스트용)
// import 'screens/password_setup_screen.dart';
// import 'screens/password_unlock_screen.dart';
// import 'utils/encryption_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '현장 서비스 스케줄 관리',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // 비밀번호 기능 비활성화 - 바로 메인 화면으로 이동
      home: const MainScreen(),
      // 비밀번호 기능 활성화 시 아래 주석 해제
      // home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================================
// 비밀번호 기능 (테스트용 비활성화)
// 필요 시 아래 주석을 해제하고 상단 import도 해제하세요
// ============================================================
/*
// 앱 초기화 및 비밀번호 확인
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isChecking = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkPasswordStatus();
  }

  Future<void> _checkPasswordStatus() async {
    // 비밀번호 설정 여부 확인
    final hasPassword = await EncryptionHelper.hasUserPassword();

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _targetScreen = hasPassword
          ? const PasswordUnlockScreen()
          : const PasswordSetupScreen();
    });
  }

  void _onAuthSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // 로딩 화면
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                '현장 서비스 스케줄 관리',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    // 비밀번호 화면 표시
    return PopScope(
      canPop: false, // 뒤로가기 방지
      child: _targetScreen is PasswordSetupScreen
          ? PasswordSetupWrapper(onSuccess: _onAuthSuccess)
          : PasswordUnlockWrapper(onSuccess: _onAuthSuccess),
    );
  }
}

// 비밀번호 설정 래퍼
class PasswordSetupWrapper extends StatelessWidget {
  final VoidCallback onSuccess;

  const PasswordSetupWrapper({required this.onSuccess, super.key});

  @override
  Widget build(BuildContext context) {
    return PasswordSetupScreen(onSuccess: onSuccess);
  }
}

// 비밀번호 잠금 해제 래퍼
class PasswordUnlockWrapper extends StatelessWidget {
  final VoidCallback onSuccess;

  const PasswordUnlockWrapper({required this.onSuccess, super.key});

  @override
  Widget build(BuildContext context) {
    return PasswordUnlockScreen(onSuccess: onSuccess);
  }
}
*/
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<CalendarViewScreenState> _calendarKey = GlobalKey<CalendarViewScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeKey),
      CalendarViewScreen(key: _calendarKey),
      const CompletedSchedulesScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: '스케줄 목록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '캘린더',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: '완료 내역',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ScheduleFormScreen(),
            ),
          );

          if (result != null) {
            // 스케줄이 추가/수정되면 모든 화면 새로고침
            _homeKey.currentState?.refresh();
            _calendarKey.currentState?.refresh();
            setState(() {});
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
