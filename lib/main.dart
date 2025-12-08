import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:upgrader/upgrader.dart';
import 'config/supabase_config.dart';
import 'database/database_helper.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/widget_service.dart';
import 'services/analytics_service.dart';
import 'services/last_seen_service.dart';
import 'providers/subscription_provider.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_view_screen.dart';
import 'screens/completed_schedules_screen.dart';
import 'screens/schedule_form_screen.dart';
import 'screens/schedule_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/statistics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 시작 시간 측정
  final startTime = DateTime.now();
  debugPrint('🚀 App initialization started');

  // Edge-to-edge 활성화 (Android 15+ 권장사항)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 시스템 UI 오버레이 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // 날짜 포맷 초기화 (동기)
  await initializeDateFormatting('ko_KR', null);

  // Firebase 초기화 (Analytics 사용) - 비차단
  Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).then((_) {
    debugPrint('✅ Firebase initialized');
    // Analytics 초기 이벤트 로깅 (Firebase 연결 확인용)
    _logAppStart();
  }).catchError((e) {
    debugPrint('⚠️ Firebase initialization failed: $e');
  });

  // Supabase 초기화 (필수)
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // 나머지 서비스들은 백그라운드에서 초기화
  _initializeServicesInBackground();

  final duration = DateTime.now().difference(startTime);
  debugPrint('✅ App initialization completed in ${duration.inMilliseconds}ms');

  runApp(const MyApp());
}

/// 앱 시작 이벤트 로깅 (Firebase Analytics 연결 확인)
void _logAppStart() {
  Future.microtask(() async {
    try {
      final analytics = AnalyticsService();
      await analytics.logScreenView(screenName: 'app_start');
      await analytics.logFeatureUsed(
        featureName: 'app_opened',
        parameters: {'timestamp': DateTime.now().toIso8601String()},
      );
      debugPrint('📊 Analytics: App start event logged');
    } catch (e) {
      debugPrint('⚠️ Analytics logging error: $e');
    }
  });
}

/// 백그라운드에서 서비스 초기화 (앱 로딩 차단 방지)
void _initializeServicesInBackground() {
  Future.microtask(() async {
    try {
      debugPrint('📦 Initializing background services...');

      // 알림 서비스 초기화
      await NotificationService.instance.initialize();

      // 알림 설정 (로그인된 사용자에 대해서만 실행됨)
      await NotificationService.instance.setupDailyNotifications();

      // 백그라운드 서비스 초기화
      await BackgroundService.initialize();

      // 백그라운드 작업 등록
      await BackgroundService.registerDailyTask();

      // 위젯 서비스 초기화
      await WidgetService.initialize();

      debugPrint('✅ All background services initialized');
    } catch (e) {
      debugPrint('⚠️ Background service initialization error: $e');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _handleDeepLinks();
  }

  // Deep Link 처리
  void _handleDeepLinks() {
    // 앱이 종료된 상태에서 deep link로 열린 경우
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleAuthCallback(uri);
      }
    });

    // 앱이 실행 중일 때 deep link를 받는 경우
    _appLinks.uriLinkStream.listen((uri) {
      _handleAuthCallback(uri);
    });
  }

  Future<void> _handleAuthCallback(Uri uri) async {
    debugPrint('Deep Link received: $uri');

    // OAuth 콜백 처리
    if (uri.host == 'login-callback') {
      try {
        // Supabase가 URL의 토큰을 파싱하고 세션을 생성합니다
        // supabase_flutter 2.x에서는 자동으로 처리됨
        debugPrint('OAuth callback processed successfully');
      } catch (e) {
        debugPrint('Error processing OAuth callback: $e');
      }
    }
  }

  // 사용자 프로필 확인 및 생성
  Future<void> _ensureUserProfile(String userId, String? email) async {
    try {
      // 프로필이 존재하는지 확인
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // 프로필이 없으면 생성
      if (response == null) {
        await Supabase.instance.client.from('profiles').insert({
          'id': userId,
          'email': email ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('Profile created for user: $userId');
      }
    } catch (e) {
      debugPrint('Error ensuring user profile: $e');
    }
  }

  // 사용자의 기본 업체 초기화
  Future<void> _initializeDefaultCompanies(String userId, String? email) async {
    try {
      // 0. 먼저 프로필이 존재하는지 확인하고 없으면 생성
      await _ensureUserProfile(userId, email);

      // 1. 먼저 legacy_user 데이터를 현재 사용자에게 마이그레이션
      await DatabaseHelper.instance.migrateLegacyDataToUser(userId);

      // 2. 기본 업체 초기화 (새 사용자인 경우에만)
      await DatabaseHelper.instance.initializeDefaultCompaniesForUser(userId);

      // Note: 알림 설정 및 백그라운드 작업은 _initializeServicesInBackground()에서 처리됨
    } catch (e) {
      debugPrint('Failed to initialize default companies: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: MaterialApp(
        title: '비도 관리',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          scaffoldBackgroundColor: const Color(0xFFFAFAFA),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFFFAFAFA),
          ),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ko', 'KR'),
        home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // 로딩 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // 인증 상태 확인
          final session = snapshot.hasData ? snapshot.data!.session : null;

          // 로그인 여부에 따라 화면 분기
          if (session != null) {
            // 로그인 상태 - 기본 업체 초기화 후 메인 화면으로
            return FutureBuilder(
              future: _initializeDefaultCompanies(session.user.id, session.user.email),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return const MainScreen();
              },
            );
          } else {
            // 비로그인 상태 - 로그인 화면으로
            return const LoginScreen();
          }
        },
      ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<CalendarViewScreenState> _calendarKey = GlobalKey<CalendarViewScreenState>();
  static const platform = MethodChannel('com.vividlife.bizplan/widget');

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeKey),
      CalendarViewScreen(key: _calendarKey),
      const CompletedSchedulesScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];
    _setupMethodChannel();
    _checkForWidgetScheduleId();

    // 빌드 완료 후 구독 상태 초기화 및 last_seen 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSubscription();
      _updateLastSeen();
    });
  }

  // 구독 상태 초기화
  Future<void> _initializeSubscription() async {
    if (!mounted) return;
    final subscriptionProvider = context.read<SubscriptionProvider>();
    await subscriptionProvider.initialize();
    debugPrint('✅ 멤버십 구독 상태 초기화 완료');
  }

  // Last seen 업데이트 (하루에 한 번)
  Future<void> _updateLastSeen() async {
    await LastSeenService.updateLastSeenIfNeeded();
  }

  // MethodChannel 설정 - Android에서 보내는 메시지 수신
  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'openSchedule') {
        final int? scheduleId = call.arguments as int?;
        debugPrint('Received openSchedule call with scheduleId: $scheduleId');
        if (scheduleId != null && scheduleId > 0 && mounted) {
          // 약간의 지연 후 상세보기 화면으로 이동
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _navigateToScheduleDetail(scheduleId);
            }
          });
        }
      }
    });
  }

  // 위젯에서 전달된 스케줄 ID 확인 및 상세보기로 이동
  Future<void> _checkForWidgetScheduleId() async {
    try {
      // 앱 시작 시 pending schedule ID 확인
      final int? scheduleId = await platform.invokeMethod('getScheduleId');
      debugPrint('Initial getScheduleId returned: $scheduleId');
      if (scheduleId != null && scheduleId > 0 && mounted) {
        // 약간의 지연 후 상세보기 화면으로 이동 (UI가 완전히 로드된 후)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _navigateToScheduleDetail(scheduleId);
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to get schedule ID from widget: $e');
    }
  }

  // 스케줄 상세보기로 이동
  Future<void> _navigateToScheduleDetail(int scheduleId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // 스케줄 데이터 가져오기
    final schedules = await DatabaseHelper.instance.readAllSchedules(userId);
    final schedule = schedules.firstWhere(
      (s) => s.id == scheduleId,
      orElse: () => schedules.first, // 못 찾으면 첫 번째 스케줄로
    );

    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleDetailScreen(schedule: schedule),
        ),
      );

      if (result != null) {
        // 상세보기에서 돌아온 후 새로고침
        _homeKey.currentState?.refresh();
        _calendarKey.currentState?.refresh();
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      upgrader: Upgrader(
        durationUntilAlertAgain: const Duration(days: 1),
      ),
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFFAFAFA),
          selectedItemColor: const Color(0xFF579bf2),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: '매출 분석',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: '설정',
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
          backgroundColor: const Color.fromARGB(255, 220, 232, 248),
          child: const Icon(Icons.add, color: Color.fromARGB(255, 53, 48, 48)),
        ),
      ),
    );
  }
}
