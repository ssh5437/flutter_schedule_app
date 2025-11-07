// ProfileService는 Supabase의 profiles 테이블을 사용하던 서비스입니다.
// 현재는 사용하지 않으므로 주석 처리합니다.

/*
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class ProfileService {
  // Supabase 클라이언트
  final _supabase = Supabase.instance.client;

  // 프로필 생성
  Future<UserProfile> createProfile({
    required String userId,
    required String email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    String membershipTier = 'free',
  }) async {
    // TODO: Supabase profiles 테이블 구현 필요
    throw UnimplementedError('Supabase profiles 테이블 구현 필요');
  }

  // 프로필 조회
  Future<UserProfile?> getProfile(String userId) async {
    // TODO: Supabase profiles 테이블 구현 필요
    throw UnimplementedError('Supabase profiles 테이블 구현 필요');
  }

  // 현재 로그인한 사용자의 프로필 가져오기
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    // TODO: Supabase에서 프로필 가져오기
    throw UnimplementedError('Supabase profiles 테이블 구현 필요');
  }
}
*/
