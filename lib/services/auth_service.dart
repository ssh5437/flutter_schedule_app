import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // 현재 사용자 가져오기
  supabase.User? get currentUser => _supabase.auth.currentUser;

  // 인증 상태 스트림
  Stream<supabase.AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // 로그인 여부 확인
  bool get isLoggedIn => currentUser != null;

  // 회원가입
  Future<supabase.AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null, // 이메일 인증 리다이렉트 비활성화
      );

      // 회원가입 성공 시 프로필 생성 (로그아웃 전에 완료)
      if (response.user != null) {
        debugPrint('User created successfully: ${response.user!.id}');

        // 프로필 생성을 즉시 시도하고 완료될 때까지 대기
        await _ensureProfileCreated(response.user!.id, email);
      }

      return response;
    } catch (e) {
      debugPrint('SignUp error: $e');
      rethrow;
    }
  }

  // 프로필 생성 보장 (트리거 또는 수동)
  Future<void> _ensureProfileCreated(String userId, String email) async {
    try {
      // 트리거가 프로필을 생성할 때까지 대기
      await Future.delayed(const Duration(milliseconds: 1500));

      // 프로필이 생성되었는지 확인
      final profileCheck = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileCheck == null) {
        // 트리거가 실패했으므로 수동으로 프로필 생성 시도
        debugPrint('Trigger failed, attempting manual profile creation');

        final profileData = {
          'id': userId,
          'email': email,
          'created_at': DateTime.now().toIso8601String(),
        };

        await _supabase.from('profiles').insert(profileData);
        debugPrint('Manual profile creation successful');
      } else {
        debugPrint('Profile already exists (created by trigger)');
      }
    } catch (e) {
      debugPrint('Error ensuring profile creation: $e');

      // PostgrestException인 경우 상세 정보 출력
      if (e is supabase.PostgrestException) {
        debugPrint('Postgrest error code: ${e.code}');
        debugPrint('Postgrest error message: ${e.message}');
        debugPrint('Postgrest error details: ${e.details}');
        debugPrint('Postgrest error hint: ${e.hint}');
      }

      // 프로필 생성 실패해도 계속 진행 (로그만 남김)
      debugPrint('Profile creation failed, but user auth is successful');
    }
  }

  // 로그인
  Future<supabase.AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Google 로그인
  Future<bool> signInWithGoogle() async {
    try {
      // Supabase Native Google Sign-In 사용
      await _supabase.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: 'com.vividlife.bizplan://login-callback',
      );

      // OAuth 로그인은 브라우저에서 진행되므로
      // 실제 인증은 Deep Link 콜백에서 처리됨
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Kakao 로그인
  Future<bool> signInWithKakao() async {
    try {
      // Supabase Native Kakao Sign-In 사용
      await _supabase.auth.signInWithOAuth(
        supabase.OAuthProvider.kakao,
        redirectTo: 'com.vividlife.bizplan://login-callback',
      );

      // OAuth 로그인은 브라우저에서 진행되므로
      // 실제 인증은 Deep Link 콜백에서 처리됨
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // 비밀번호 재설정 이메일 보내기
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }
}
