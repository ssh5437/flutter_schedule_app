class UserProfile {
  final String id; // Supabase Auth User ID
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 멤버십 정보
  final String membershipTier; // 'free', 'plus', 'pro'
  final DateTime? membershipExpiresAt;
  final bool isActive;

  // 추가 정보
  final Map<String, dynamic>? metadata; // 추가 커스텀 데이터

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.membershipTier = 'free',
    this.membershipExpiresAt,
    this.isActive = true,
    this.metadata,
  });

  // JSON에서 객체 생성
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      membershipTier: json['membership_tier'] as String? ?? 'free',
      membershipExpiresAt: json['membership_expires_at'] != null
          ? DateTime.parse(json['membership_expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'phone_number': phoneNumber,
      'photo_url': photoUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'membership_tier': membershipTier,
      'membership_expires_at': membershipExpiresAt?.toIso8601String(),
      'is_active': isActive,
      'metadata': metadata,
    };
  }

  // 객체 복사 (일부 필드만 업데이트)
  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? membershipTier,
    DateTime? membershipExpiresAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      membershipTier: membershipTier ?? this.membershipTier,
      membershipExpiresAt: membershipExpiresAt ?? this.membershipExpiresAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  // 멤버십 유효성 확인
  bool get isMembershipValid {
    if (membershipTier == 'free') return true;
    if (membershipExpiresAt == null) return false;
    return membershipExpiresAt!.isAfter(DateTime.now());
  }

  // 유효한 멤버십 티어 반환 (만료되었으면 free)
  String get effectiveMembershipTier {
    return isMembershipValid ? membershipTier : 'free';
  }
}
