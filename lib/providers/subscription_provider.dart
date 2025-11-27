import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();

  Subscription _subscription = Subscription.empty();
  Subscription get subscription => _subscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isProcessingPurchase = false;
  bool get isProcessingPurchase => _isProcessingPurchase;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  bool _isInitialized = false;
  StreamSubscription? _subscriptionStreamSubscription;

  bool get hasActiveSubscription =>
      _subscription.isActive && !_subscription.isExpired;

  bool get isExpiringSoon {
    if (!hasActiveSubscription) return false;
    return _subscription.remainingDays <= 7;
  }

  // 초기화
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Provider already initialized, skipping');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _subscriptionService.initialize();

      // 구독 스트림 리스닝 - 구독 변경 시 자동 업데이트
      _subscriptionStreamSubscription = _subscriptionService.subscriptionStream.listen((subscription) {
        debugPrint('🔔 구독 상태 변경 감지: isActive=${subscription.isActive}, isExpired=${subscription.isExpired}, status=${subscription.status}');
        _subscription = subscription;
        _isLoading = false;

        // 구독이 활성화되면 처리 중 상태 해제
        if (subscription.isActive && !subscription.isExpired) {
          _isProcessingPurchase = false;
          debugPrint('✅ 구독 처리 완료 - 로딩 해제');
        }

        // 에러 상태면 처리 중 상태 해제
        if (subscription.status == SubscriptionStatus.error) {
          _isProcessingPurchase = false;
          _errorMessage = '구독 검증에 실패했습니다. 다시 시도해주세요.';
          debugPrint('❌ 구독 검증 오류 - 로딩 해제');
        }

        notifyListeners();
      });

      // 현재 구독 상태 로드
      _subscription = _subscriptionService.currentSubscription;
      _errorMessage = null;
      _isInitialized = true;

      // 서버에서 구독 상태 검증 (해지 여부 확인)
      await _subscriptionService.verifySubscriptionStatus();

      debugPrint('✅ SubscriptionProvider initialized: hasActive=$hasActiveSubscription');
    } catch (e) {
      _errorMessage = '구독 정보를 불러오는데 실패했습니다: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscriptionStreamSubscription?.cancel();
    super.dispose();
  }

  // 구독 구매
  Future<bool> purchaseSubscription() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _subscriptionService.purchaseSubscription();

      if (!success) {
        _errorMessage = '구독 구매에 실패했습니다.';
        _isProcessingPurchase = false;
        return false;
      }

      // 구매 시작 성공 - 처리 중 상태로 전환
      _isProcessingPurchase = true;
      debugPrint('💳 구매 처리 시작 - 로딩 표시');
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = '구독 구매 중 오류가 발생했습니다: $e';
      _isProcessingPurchase = false;
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 구매 복원
  Future<bool> restorePurchases() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // 복원 전 구독 상태 저장
      final hadSubscriptionBefore = _subscription.isActive;

      await _subscriptionService.restoreSubscription();

      // 복원 후 상태 확인을 위해 잠시 대기
      await Future.delayed(const Duration(seconds: 2));

      // 최신 구독 상태 다시 로드
      _subscription = _subscriptionService.currentSubscription;

      // 복원 결과 확인
      if (_subscription.isActive && !_subscription.isExpired) {
        _successMessage = '구독이 성공적으로 복원되었습니다!';
        _errorMessage = null;
        return true;
      } else if (hadSubscriptionBefore) {
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = '복원할 구독 내역이 없습니다.\n이전에 구매한 기록이 있다면 잠시 후 다시 시도해주세요.';
        return false;
      }
    } catch (e) {
      _errorMessage = '구매 복원 중 오류가 발생했습니다.\n네트워크 연결을 확인하고 다시 시도해주세요.';
      debugPrint('구매 복원 오류: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 구독 상태 새로고침
  Future<void> refreshSubscription({bool forceVerify = false}) async {
    debugPrint('🔄 구독 상태 새로고침 중... (강제검증: $forceVerify)');

    try {
      // 서버에서 구독 상태 검증 (캐시 사용, forceVerify=true이면 강제 검증)
      await _subscriptionService.verifySubscriptionStatus(forceVerify: forceVerify);

      // Supabase에서 최신 멤버십 정보 먼저 확인
      await _subscriptionService.loadFromSupabase();

      // DB에서 최신 구독 정보 로드
      await _subscriptionService.loadSubscription();

      // 현재 구독 정보 가져오기
      _subscription = _subscriptionService.currentSubscription;

      debugPrint('📊 새로고침 결과: isActive=${_subscription.isActive}, isExpired=${_subscription.isExpired}');

      if (_subscription.isActive && !_subscription.isExpired) {
        debugPrint('✅ 활성 구독 확인됨!');
        _successMessage = '구독이 활성화되었습니다!';
        _errorMessage = null;
      } else if (!_subscription.isActive && _subscription.isExpired) {
        _errorMessage = '구독이 만료되었습니다.';
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = '구독 정보 갱신 중 오류가 발생했습니다: $e';
      debugPrint('❌ 새로고침 오류: $_errorMessage');
      notifyListeners();
    }
  }

  // 만료 확인 (주기적으로 호출 가능)
  Future<void> checkExpiration() async {
    if (_subscription.isExpired && _subscription.isActive) {
      await refreshSubscription();
    }
  }

  // 에러 메세지 클리어
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 성공 메세지 클리어
  void clearSuccess() {
    _successMessage = null;
    notifyListeners();
  }

  // 모든 메세지 클리어
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
