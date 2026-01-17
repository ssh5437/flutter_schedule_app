import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/coupon.dart';
import '../models/subscription.dart';
import '../database/database_helper.dart';

class CouponService {
  static final CouponService _instance = CouponService._internal();
  factory CouponService() => _instance;
  CouponService._internal();

  final _supabase = Supabase.instance.client;

  /// 쿠폰 코드로 쿠폰 정보 조회 (대소문자 구분)
  Future<Coupon?> getCouponByCode(String code) async {
    try {
      debugPrint('🎫 쿠폰 조회: $code');

      // 대소문자 구분하여 정확히 일치하는 쿠폰만 조회
      final response = await _supabase
          .from('coupons')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ 쿠폰을 찾을 수 없습니다');
        debugPrint('   조회한 코드: $code');
        return null;
      }

      final coupon = Coupon.fromMap(response);
      debugPrint('✅ 쿠폰 조회 성공: ${coupon.code}');

      return coupon;
    } catch (e, stackTrace) {
      debugPrint('❌ 쿠폰 조회 오류: $e');
      debugPrint('   스택 트레이스: $stackTrace');
      return null;
    }
  }

  /// 사용자가 이미 해당 쿠폰을 사용했는지 확인
  Future<bool> hasUserUsedCoupon(String couponId, String userId) async {
    try {
      final response = await _supabase
          .from('coupon_redemptions')
          .select()
          .eq('coupon_id', couponId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ 쿠폰 사용 기록 확인 오류: $e');
      return false;
    }
  }

  /// 쿠폰 사용 (멤버십 적용)
  Future<CouponRedemptionResult> redeemCoupon(String code) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return CouponRedemptionResult(
          success: false,
          message: '로그인이 필요합니다',
        );
      }

      debugPrint('🎫 쿠폰 사용 시작: $code (사용자: $userId)');

      // 1. 쿠폰 조회
      final coupon = await getCouponByCode(code);
      if (coupon == null) {
        return CouponRedemptionResult(
          success: false,
          message: '유효하지 않은 쿠폰 코드입니다',
        );
      }

      // 2. 쿠폰 사용 가능 여부 확인
      if (!coupon.canUse) {
        if (!coupon.isActive) {
          return CouponRedemptionResult(
            success: false,
            message: '만료된 쿠폰입니다',
          );
        } else if (coupon.maxUses != null && coupon.currentUses >= coupon.maxUses!) {
          return CouponRedemptionResult(
            success: false,
            message: '사용 가능 횟수를 초과한 쿠폰입니다',
          );
        }
      }

      // 3. 이미 사용한 쿠폰인지 확인 (중복 사용이 허용되지 않는 경우만)
      if (!coupon.allowMultipleUsesPerUser) {
        final hasUsed = await hasUserUsedCoupon(coupon.id, userId);
        if (hasUsed) {
          return CouponRedemptionResult(
            success: false,
            message: '이미 사용한 쿠폰입니다',
          );
        }
      }

      // 4. 만료일 계산
      final expiryDate = coupon.calculateExpiryDate();
      debugPrint('📅 계산된 만료일: $expiryDate');

      // 5. 쿠폰 사용 기록 추가 (Supabase)
      await _supabase.from('coupon_redemptions').insert({
        'coupon_id': coupon.id,
        'user_id': userId,
        'expiry_date': expiryDate.toIso8601String(),
      });

      // 6. 쿠폰 사용 횟수 증가
      await _supabase
          .from('coupons')
          .update({'current_uses': coupon.currentUses + 1})
          .eq('id', coupon.id);

      // 7. Supabase profiles 테이블의 membership_expires_at 업데이트
      await _supabase
          .from('profiles')
          .update({'membership_expires_at': expiryDate.toIso8601String()})
          .eq('id', userId);

      debugPrint('✅ Supabase 프로필 업데이트 완료: membership_expires_at = $expiryDate');

      // 8. 로컬 DB에 구독 정보 저장
      final subscription = Subscription(
        productId: SubscriptionProduct.monthlySubscriptionId,
        purchaseId: 'COUPON_${coupon.code}_${DateTime.now().millisecondsSinceEpoch}',
        purchaseDate: DateTime.now(),
        expiryDate: expiryDate,
        isActive: true,
        status: SubscriptionStatus.active,
        isTestMode: false,
      );

      await DatabaseHelper.instance.saveSubscription(userId, subscription);

      debugPrint('✅ 쿠폰 사용 완료');

      return CouponRedemptionResult(
        success: true,
        message: '쿠폰이 등록되었습니다!\n멤버십이 ${_formatDate(expiryDate)}까지 활성화됩니다.',
        expiryDate: expiryDate,
      );
    } catch (e) {
      debugPrint('❌ 쿠폰 사용 오류: $e');
      return CouponRedemptionResult(
        success: false,
        message: '쿠폰 등록 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// 사용자의 쿠폰 사용 기록 조회
  Future<List<CouponRedemption>> getUserRedemptions(String userId) async {
    try {
      final response = await _supabase
          .from('coupon_redemptions')
          .select()
          .eq('user_id', userId)
          .order('redeemed_at', ascending: false);

      return (response as List)
          .map((item) => CouponRedemption.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('❌ 쿠폰 사용 기록 조회 오류: $e');
      return [];
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
}

class CouponRedemptionResult {
  final bool success;
  final String message;
  final DateTime? expiryDate;

  const CouponRedemptionResult({
    required this.success,
    required this.message,
    this.expiryDate,
  });
}
