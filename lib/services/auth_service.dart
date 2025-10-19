import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'profile_service.dart';

class AuthService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  final ProfileService _profileService = ProfileService();

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

      // 회원가입 성공 시 프로필 자동 생성
      if (response.user != null) {
        try {
          await _profileService.createProfile(
            userId: response.user!.id,
            email: email,
          );
        } catch (profileError) {
          // 프로필 생성 실패해도 회원가입은 성공으로 처리
          // 나중에 로그인 시 프로필이 없으면 자동 생성하도록 처리
          print('프로필 생성 실패: $profileError');
        }
      }

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
  Future<supabase.AuthResponse> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: 'YOUR_WEB_CLIENT_ID', // Supabase Console에서 가져온 Web Client ID
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google 로그인이 취소되었습니다');
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Google 인증 토큰을 가져올 수 없습니다');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // OAuth 로그인 시 프로필이 없으면 자동 생성
      if (response.user != null) {
        await _ensureProfileExists(
          userId: response.user!.id,
          email: response.user!.email ?? '',
          displayName: googleUser.displayName,
          photoUrl: googleUser.photoUrl,
        );
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Kakao 로그인
  Future<supabase.AuthResponse> signInWithKakao() async {
    try {
      // 카카오톡 설치 여부 확인
      bool isInstalled = await isKakaoTalkInstalled();

      OAuthToken token;
      if (isInstalled) {
        // 카카오톡으로 로그인
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        // 카카오 계정으로 로그인
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      // Supabase에 Kakao 토큰으로 로그인
      final response = await _supabase.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.kakao,
        idToken: token.idToken!,
        accessToken: token.accessToken,
      );

      // OAuth 로그인 시 프로필이 없으면 자동 생성
      if (response.user != null) {
        // Kakao 사용자 정보 가져오기
        try {
          final kakaoUser = await UserApi.instance.me();
          await _ensureProfileExists(
            userId: response.user!.id,
            email: response.user!.email ?? kakaoUser.kakaoAccount?.email ?? '',
            displayName: kakaoUser.kakaoAccount?.profile?.nickname,
            photoUrl: kakaoUser.kakaoAccount?.profile?.profileImageUrl,
          );
        } catch (kakaoError) {
          // Kakao 사용자 정보 가져오기 실패 시 기본 정보로 생성
          await _ensureProfileExists(
            userId: response.user!.id,
            email: response.user!.email ?? '',
          );
        }
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  // 프로필 존재 여부 확인 후 없으면 생성
  Future<void> _ensureProfileExists({
    required String userId,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      // 프로필이 이미 있는지 확인
      final existingProfile = await _profileService.getProfile(userId);

      // 프로필이 없으면 생성
      if (existingProfile == null) {
        await _profileService.createProfile(
          userId: userId,
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
        );
      }
    } catch (e) {
      // 프로필 생성 실패는 무시 (로그인은 성공)
      // ignore: avoid_print
      print('프로필 확인/생성 실패: $e');
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
