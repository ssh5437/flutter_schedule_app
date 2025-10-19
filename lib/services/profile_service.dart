import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user_profile.dart';

class ProfileService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  // 프로필 생성
  Future<UserProfile> createProfile({
    required String userId,
    required String email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    String membershipTier = 'free',
  }) async {
    try {
      final now = DateTime.now();
      final profileData = {
        'id': userId,
        'email': email,
        'display_name': displayName,
        'phone_number': phoneNumber,
        'photo_url': photoUrl,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'membership_tier': membershipTier,
        'is_active': true,
      };

      final response = await _supabase
          .from('profiles')
          .insert(profileData)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
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
      rethrow;
    }
  }

  // 프로필 업데이트
  Future<UserProfile> updateProfile({
    required String userId,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (displayName != null) updateData['display_name'] = displayName;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (photoUrl != null) updateData['photo_url'] = photoUrl;
      if (metadata != null) updateData['metadata'] = metadata;

      final response = await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // 멤버십 업데이트
  Future<UserProfile> updateMembership({
    required String userId,
    required String membershipTier,
    DateTime? expiresAt,
  }) async {
    try {
      final updateData = {
        'membership_tier': membershipTier,
        'membership_expires_at': expiresAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // 프로필 삭제 (비활성화)
  Future<void> deactivateProfile(String userId) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // 프로필 완전 삭제
  Future<void> deleteProfile(String userId) async {
    try {
      await _supabase.from('profiles').delete().eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // 현재 로그인한 사용자의 프로필 가져오기
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      return await getProfile(user.id);
    } catch (e) {
      rethrow;
    }
  }

  // 프로필 스트림 (실시간 업데이트)
  Stream<UserProfile?> profileStream(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isEmpty) return null;
          return UserProfile.fromJson(data.first);
        });
  }
}
