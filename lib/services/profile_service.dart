import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

class ProfileService {
  static final ProfileService instance = ProfileService._internal();
  ProfileService._internal();

  // Supabase 클라이언트
  final _supabase = Supabase.instance.client;

  // 프로필 생성 또는 업데이트
  Future<UserProfile> upsertProfile({
    required String userId,
    required String email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    String? membershipTier,
    DateTime? membershipExpiresAt,
    bool? isActive,
  }) async {
    try {
      final now = DateTime.now();

      final data = <String, dynamic>{
        'id': userId,
        'email': email,
        'updated_at': now.toIso8601String(),
      };

      if (displayName != null) data['display_name'] = displayName;
      if (phoneNumber != null) data['phone_number'] = phoneNumber;
      if (photoUrl != null) data['photo_url'] = photoUrl;
      if (membershipTier != null) data['membership_tier'] = membershipTier;
      if (membershipExpiresAt != null) {
        data['membership_expires_at'] = membershipExpiresAt.toIso8601String();
      }
      if (isActive != null) data['is_active'] = isActive;

      final response = await _supabase
          .from('profiles')
          .upsert(data)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('프로필 저장 오류: $e');
      rethrow;
    }
  }

  // 프로필 조회
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('프로필 조회 오류: $e');
      return null;
    }
  }

  // 현재 로그인한 사용자의 프로필 가져오기
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return await getProfile(user.id);
  }

  // 멤버십 정보만 업데이트
  Future<void> updateMembership({
    required String userId,
    required String membershipTier,
    DateTime? membershipExpiresAt,
  }) async {
    try {
      await _supabase.from('profiles').update({
        'membership_tier': membershipTier,
        'membership_expires_at': membershipExpiresAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('멤버십 정보 업데이트 완료: $membershipTier');
    } catch (e) {
      debugPrint('멤버십 업데이트 오류: $e');
      rethrow;
    }
  }

  // 프로필 삭제
  Future<void> deleteProfile(String userId) async {
    try {
      await _supabase.from('profiles').delete().eq('id', userId);
      debugPrint('프로필 삭제 완료: $userId');
    } catch (e) {
      debugPrint('프로필 삭제 오류: $e');
      rethrow;
    }
  }
}
