class Coupon {
  final String id;
  final String code;
  final CouponType couponType;
  final int? durationMonths; // 기간 쿠폰일 때 사용
  final DateTime? fixedExpiryDate; // 고정 날짜 쿠폰일 때 사용
  final int? maxUses; // 최대 사용 횟수 (null이면 무제한)
  final int currentUses; // 현재 사용된 횟수
  final bool isActive;
  final bool allowMultipleUsesPerUser; // 같은 사용자가 여러 번 사용 가능한지 여부
  final DateTime createdAt;
  final DateTime updatedAt;

  const Coupon({
    required this.id,
    required this.code,
    required this.couponType,
    this.durationMonths,
    this.fixedExpiryDate,
    this.maxUses,
    required this.currentUses,
    required this.isActive,
    this.allowMultipleUsesPerUser = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // 쿠폰이 사용 가능한지 확인
  bool get canUse {
    if (!isActive) return false;
    if (maxUses != null && currentUses >= maxUses!) return false;
    return true;
  }

  // 쿠폰 사용 시 만료일 계산
  DateTime calculateExpiryDate() {
    if (couponType == CouponType.fixedDate && fixedExpiryDate != null) {
      return fixedExpiryDate!;
    } else if (couponType == CouponType.duration && durationMonths != null) {
      final now = DateTime.now();
      return DateTime(
        now.month + durationMonths! > 12 ? now.year + 1 : now.year,
        now.month + durationMonths! > 12 ? now.month + durationMonths! - 12 : now.month + durationMonths!,
        now.day - 1,
        23,
        59,
        59,
      );
    }
    throw Exception('Invalid coupon configuration');
  }

  factory Coupon.fromMap(Map<String, dynamic> map) {
    return Coupon(
      id: map['id'] as String,
      code: map['code'] as String,
      couponType: map['coupon_type'] == 'fixed_date'
          ? CouponType.fixedDate
          : CouponType.duration,
      durationMonths: map['duration_months'] as int?,
      fixedExpiryDate: map['fixed_expiry_date'] != null
          ? DateTime.parse(map['fixed_expiry_date'] as String)
          : null,
      maxUses: map['max_uses'] as int?,
      currentUses: map['current_uses'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      allowMultipleUsesPerUser: map['allow_multiple_uses_per_user'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'coupon_type': couponType == CouponType.fixedDate ? 'fixed_date' : 'duration',
      'duration_months': durationMonths,
      'fixed_expiry_date': fixedExpiryDate?.toIso8601String(),
      'max_uses': maxUses,
      'current_uses': currentUses,
      'is_active': isActive,
      'allow_multiple_uses_per_user': allowMultipleUsesPerUser,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

enum CouponType {
  fixedDate, // 고정 날짜까지 유효 (예: 2026-08-31까지)
  duration, // N개월 추가 (예: 1개월 추가)
}

class CouponRedemption {
  final String id;
  final String couponId;
  final String userId;
  final DateTime redeemedAt;
  final DateTime expiryDate;

  const CouponRedemption({
    required this.id,
    required this.couponId,
    required this.userId,
    required this.redeemedAt,
    required this.expiryDate,
  });

  factory CouponRedemption.fromMap(Map<String, dynamic> map) {
    return CouponRedemption(
      id: map['id'] as String,
      couponId: map['coupon_id'] as String,
      userId: map['user_id'] as String,
      redeemedAt: DateTime.parse(map['redeemed_at'] as String),
      expiryDate: DateTime.parse(map['expiry_date'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'coupon_id': couponId,
      'user_id': userId,
      'redeemed_at': redeemedAt.toIso8601String(),
      'expiry_date': expiryDate.toIso8601String(),
    };
  }
}
