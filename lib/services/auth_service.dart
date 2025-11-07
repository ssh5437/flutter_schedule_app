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
      );

      return response;
    } catch (e) {
      rethrow;
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
