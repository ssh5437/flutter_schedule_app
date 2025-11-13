import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';
import '../database/database_helper.dart';
import 'profile_service.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  final _subscriptionController = StreamController<Subscription>.broadcast();
  Stream<Subscription> get subscriptionStream => _subscriptionController.stream;

  Subscription _currentSubscription = Subscription.empty();
  Subscription get currentSubscription => _currentSubscription;

  bool _isInitialized = false;
  bool get isAvailable => _isInitialized;

  // 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 인앱 구매 사용 가능 여부 확인
    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      debugPrint('인앱 구매를 사용할 수 없습니다.');
      return;
    }

    // Android 특화 설정 (더 이상 필요하지 않음 - Google Play가 자동으로 처리)

    // 구매 상태 변경 리스너 설정
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: _onPurchaseDone,
      onError: _onPurchaseError,
    );

    // 저장된 구독 정보 로드
    await _loadSubscription();

    // Supabase에서 멤버십 정보 로드 (다른 기기에서 구독한 경우)
    await loadFromSupabase();

    // 자동 복원은 제거 - 사용자가 수동으로 "구매 복원" 버튼을 클릭해야 함

    _isInitialized = true;
    debugPrint('구독 서비스 초기화 완료');
  }

  // 상품 정보 조회
  Future<ProductDetails?> getSubscriptionProduct() async {
    if (!_isInitialized) {
      await initialize();
    }

    final productIds = <String>{SubscriptionProduct.monthlySubscriptionId};
    final response = await _inAppPurchase.queryProductDetails(productIds);

    if (response.error != null) {
      debugPrint('상품 조회 오류: ${response.error}');
      return null;
    }

    if (response.productDetails.isEmpty) {
      debugPrint('상품을 찾을 수 없습니다.');
      return null;
    }

    return response.productDetails.first;
  }

  // 구독 구매
  Future<bool> purchaseSubscription() async {
    try {
      final product = await getSubscriptionProduct();
      if (product == null) {
        debugPrint('구독 상품을 찾을 수 없습니다.');
        return false;
      }

      final purchaseParam = PurchaseParam(productDetails: product);

      final success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      return success;
    } catch (e) {
      debugPrint('구독 구매 오류: $e');
      return false;
    }
  }

  // 구매 복원
  Future<void> restoreSubscription() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint('구매 복원 오류: $e');
    }
  }

  // 구독 상태 확인
  Future<bool> hasActiveSubscription() async {
    await _loadSubscription();
    return _currentSubscription.isActive && !_currentSubscription.isExpired;
  }

  // === 테스트 모드 기능 ===

  // 테스트용 프리미엄 구독 활성화
  Future<void> enableTestPremium({int daysFromNow = 30}) async {
    final testSubscription = Subscription.createTestPremium(daysFromNow: daysFromNow);
    await _saveSubscription(testSubscription);
    await _syncToSupabase(testSubscription);

    _currentSubscription = testSubscription;
    _subscriptionController.add(testSubscription);

    debugPrint('테스트 프리미엄 구독 활성화: ${testSubscription.expiryDate}까지');
  }

  // 테스트용 만료된 구독 설정
  Future<void> enableTestExpired() async {
    final testSubscription = Subscription.createTestExpired();
    await _saveSubscription(testSubscription);
    await _syncToSupabase(testSubscription);

    _currentSubscription = testSubscription;
    _subscriptionController.add(testSubscription);

    debugPrint('테스트 만료 구독 설정 완료');
  }

  // 테스트 구독 제거
  Future<void> clearTestSubscription() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('subscriptions');

    _currentSubscription = Subscription.empty();
    _subscriptionController.add(_currentSubscription);

    // Supabase도 초기화
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await ProfileService.instance.updateMembership(
        userId: user.id,
        membershipTier: 'free',
        membershipExpiresAt: null,
      );
    }

    debugPrint('테스트 구독 제거 완료');
  }

  // 구매 업데이트 처리
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      await _handlePurchase(purchaseDetails);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    debugPrint('구매 상태: ${purchaseDetails.status}');

    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      // 구매 완료 또는 복원됨
      await _verifyAndSavePurchase(purchaseDetails);
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      // 구매 오류
      debugPrint('구매 오류: ${purchaseDetails.error}');
      _updateSubscriptionStatus(SubscriptionStatus.error);
    } else if (purchaseDetails.status == PurchaseStatus.pending) {
      // 구매 대기중
      _updateSubscriptionStatus(SubscriptionStatus.pending);
    }

    // 구매 완료 처리
    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  // 구매 검증 및 저장
  Future<void> _verifyAndSavePurchase(PurchaseDetails purchaseDetails) async {
    try {
      // 서버에서 구매 검증
      final verificationResult = await _verifyPurchaseWithServer(purchaseDetails);

      if (!verificationResult['valid']) {
        debugPrint('구매 검증 실패: ${verificationResult['error']}');
        _updateSubscriptionStatus(SubscriptionStatus.error);
        return;
      }

      // 검증된 정보로 구독 생성
      final purchaseDate = DateTime.parse(verificationResult['purchaseDate']);
      final expiryDateStr = verificationResult['expiryDate'];

      if (expiryDateStr == null) {
        debugPrint('구매 검증 실패: 만료 날짜가 없습니다.');
        _updateSubscriptionStatus(SubscriptionStatus.error);
        return;
      }

      final expiryDate = DateTime.parse(expiryDateStr);

      final subscription = Subscription(
        productId: purchaseDetails.productID,
        purchaseId: verificationResult['orderId'] ?? purchaseDetails.purchaseID,
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        isActive: true,
        status: SubscriptionStatus.active,
      );

      await _saveSubscription(subscription);

      // Supabase는 서버 검증 시 이미 업데이트되었지만, 로컬과 동기화 확인
      await _syncToSupabase(subscription);

      _currentSubscription = subscription;
      _subscriptionController.add(subscription);

      debugPrint('구독 저장 완료 (서버 검증됨): $purchaseDate ~ $expiryDate');
    } catch (e) {
      debugPrint('구매 저장 오류: $e');
      _updateSubscriptionStatus(SubscriptionStatus.error);
    }
  }

  // 서버에서 구매 검증
  Future<Map<String, dynamic>> _verifyPurchaseWithServer(PurchaseDetails purchaseDetails) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return {'valid': false, 'error': 'User not authenticated'};
      }

      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
      if (accessToken == null) {
        return {'valid': false, 'error': 'No access token'};
      }

      // Supabase Edge Function 호출
      final response = await Supabase.instance.client.functions.invoke(
        'verify-purchase',
        body: {
          'productId': purchaseDetails.productID,
          'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
          'packageName': 'com.vividlife.bizplan',
        },
      );

      if (response.status != 200) {
        debugPrint('서버 검증 실패: ${response.data}');
        return {'valid': false, 'error': response.data.toString()};
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('서버 검증 오류: $e');
      return {'valid': false, 'error': e.toString()};
    }
  }

  // 구독 정보 저장
  Future<void> _saveSubscription(Subscription subscription) async {
    final db = await DatabaseHelper.instance.database;

    // 기존 구독 정보 삭제
    await db.delete('subscriptions');

    // 새 구독 정보 저장
    await db.insert('subscriptions', subscription.toMap());
  }

  // 구독 정보 로드
  Future<void> _loadSubscription() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'subscriptions',
        orderBy: 'purchase_date DESC',
        limit: 1,
      );

      if (result.isNotEmpty) {
        _currentSubscription = Subscription.fromMap(result.first);

        // 만료 확인 및 자동 업데이트
        await _checkAndUpdateExpiredSubscription();

        _subscriptionController.add(_currentSubscription);
      }
    } catch (e) {
      debugPrint('구독 정보 로드 오류: $e');
    }
  }

  // 만료된 구독 확인 및 업데이트
  Future<void> _checkAndUpdateExpiredSubscription() async {
    if (_currentSubscription.isExpired && _currentSubscription.isActive) {
      debugPrint('구독이 만료되었습니다. 상태를 업데이트합니다.');

      // 로컬 DB 업데이트
      _currentSubscription = _currentSubscription.copyWith(
        isActive: false,
        status: SubscriptionStatus.expired,
      );
      await _saveSubscription(_currentSubscription);

      // Supabase에 만료 상태 동기화
      await _syncToSupabase(_currentSubscription);

      _subscriptionController.add(_currentSubscription);
    }
  }


  // 구독 상태 업데이트
  void _updateSubscriptionStatus(SubscriptionStatus status) {
    _currentSubscription = _currentSubscription.copyWith(status: status);
    _subscriptionController.add(_currentSubscription);
  }

  void _onPurchaseDone() {
    debugPrint('구매 스트림 종료');
  }

  void _onPurchaseError(error) {
    debugPrint('구매 오류: $error');
    _updateSubscriptionStatus(SubscriptionStatus.error);
  }

  // Supabase에 멤버십 정보 동기화
  Future<void> _syncToSupabase(Subscription subscription) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('로그인된 사용자가 없어 Supabase 동기화를 건너뜁니다.');
        return;
      }

      // 멤버십 티어 결정
      String membershipTier = 'free';
      if (subscription.isActive && !subscription.isExpired) {
        membershipTier = 'premium';
      }

      await ProfileService.instance.updateMembership(
        userId: user.id,
        membershipTier: membershipTier,
        membershipExpiresAt: subscription.expiryDate,
      );

      debugPrint('Supabase 멤버십 동기화 완료: $membershipTier');
    } catch (e) {
      debugPrint('Supabase 동기화 오류: $e');
      // 동기화 실패해도 로컬 구독은 유지
    }
  }

  // Supabase에서 멤버십 정보 로드
  Future<void> loadFromSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('로그인된 사용자가 없어 Supabase에서 로드를 건너뜁니다.');
        return;
      }

      final profile = await ProfileService.instance.getProfile(user.id);
      if (profile == null) return;

      // Supabase의 멤버십 정보가 더 최신이면 로컬에 반영
      if (profile.membershipTier == 'premium' &&
          profile.membershipExpiresAt != null) {

        // 로컬 구독과 비교
        if (_currentSubscription.expiryDate == null ||
            profile.membershipExpiresAt!.isAfter(_currentSubscription.expiryDate!)) {

          final subscription = Subscription(
            productId: SubscriptionProduct.monthlySubscriptionId,
            purchaseDate: profile.membershipExpiresAt!.subtract(const Duration(days: 30)),
            expiryDate: profile.membershipExpiresAt,
            isActive: profile.isMembershipValid,
            status: profile.isMembershipValid
                ? SubscriptionStatus.active
                : SubscriptionStatus.expired,
          );

          await _saveSubscription(subscription);
          _currentSubscription = subscription;
          _subscriptionController.add(subscription);

          debugPrint('Supabase에서 멤버십 정보 로드 완료');
        }
      }
    } catch (e) {
      debugPrint('Supabase에서 로드 오류: $e');
    }
  }

  // 정리
  void dispose() {
    _subscription.cancel();
    _subscriptionController.close();
  }
}
