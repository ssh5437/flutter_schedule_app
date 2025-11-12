class Subscription {
  final String productId;
  final String? purchaseId;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final bool isActive;
  final SubscriptionStatus status;
  final bool isTestMode; // 테스트 모드 여부

  Subscription({
    required this.productId,
    this.purchaseId,
    this.purchaseDate,
    this.expiryDate,
    required this.isActive,
    required this.status,
    this.isTestMode = false, // 기본값 false
  });

  // 11일에 구매했으면 다음달 10일까지 유효
  static DateTime calculateExpiryDate(DateTime purchaseDate) {
    // 다음 달의 (구매일 - 1)일 23:59:59까지 유효
    final nextMonth = DateTime(
      purchaseDate.month == 12 ? purchaseDate.year + 1 : purchaseDate.year,
      purchaseDate.month == 12 ? 1 : purchaseDate.month + 1,
      purchaseDate.day - 1,
      23,
      59,
      59,
    );

    // 예외 처리: 다음 달에 해당 일자가 없는 경우 (예: 1/31 -> 2/28)
    if (nextMonth.month != (purchaseDate.month == 12 ? 1 : purchaseDate.month + 1)) {
      // 다음 달의 마지막 날로 설정
      return DateTime(
        purchaseDate.month == 12 ? purchaseDate.year + 1 : purchaseDate.year,
        purchaseDate.month == 12 ? 2 : purchaseDate.month + 2,
        0,
        23,
        59,
        59,
      );
    }

    return nextMonth;
  }

  bool get isExpired {
    if (expiryDate == null) return true;
    return DateTime.now().isAfter(expiryDate!);
  }

  int get remainingDays {
    if (expiryDate == null) return 0;
    final difference = expiryDate!.difference(DateTime.now());
    return difference.inDays > 0 ? difference.inDays : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'purchase_id': purchaseId,
      'purchase_date': purchaseDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'status': status.toString(),
      'is_test_mode': isTestMode ? 1 : 0,
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      productId: map['product_id'] as String,
      purchaseId: map['purchase_id'] as String?,
      purchaseDate: map['purchase_date'] != null
          ? DateTime.parse(map['purchase_date'] as String)
          : null,
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'] as String)
          : null,
      isActive: (map['is_active'] as int) == 1,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => SubscriptionStatus.none,
      ),
      isTestMode: (map['is_test_mode'] as int?) == 1,
    );
  }

  Subscription copyWith({
    String? productId,
    String? purchaseId,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    bool? isActive,
    SubscriptionStatus? status,
    bool? isTestMode,
  }) {
    return Subscription(
      productId: productId ?? this.productId,
      purchaseId: purchaseId ?? this.purchaseId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      isTestMode: isTestMode ?? this.isTestMode,
    );
  }

  static Subscription empty() {
    return Subscription(
      productId: '',
      isActive: false,
      status: SubscriptionStatus.none,
      isTestMode: false,
    );
  }

  // 테스트용 프리미엄 구독 생성
  static Subscription createTestPremium({int daysFromNow = 30}) {
    final now = DateTime.now();
    final expiry = Subscription.calculateExpiryDate(now);

    return Subscription(
      productId: SubscriptionProduct.monthlySubscriptionId,
      purchaseId: 'TEST_${now.millisecondsSinceEpoch}',
      purchaseDate: now,
      expiryDate: expiry,
      isActive: true,
      status: SubscriptionStatus.active,
      isTestMode: true, // 테스트 모드 표시
    );
  }

  // 테스트용 만료된 구독 생성
  static Subscription createTestExpired() {
    final pastDate = DateTime.now().subtract(const Duration(days: 31));
    final expiry = Subscription.calculateExpiryDate(pastDate);

    return Subscription(
      productId: SubscriptionProduct.monthlySubscriptionId,
      purchaseId: 'TEST_EXPIRED_${DateTime.now().millisecondsSinceEpoch}',
      purchaseDate: pastDate,
      expiryDate: expiry,
      isActive: false,
      status: SubscriptionStatus.expired,
      isTestMode: true,
    );
  }
}

enum SubscriptionStatus {
  none,           // 구독 없음
  active,         // 활성 구독
  expired,        // 만료됨
  cancelled,      // 취소됨
  pending,        // 결제 대기중
  error,          // 오류
}

// 구독 상품 정보
class SubscriptionProduct {
  final String id;
  final String title;
  final String description;
  final String price;
  final String currency;
  final int durationMonths;

  const SubscriptionProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    this.durationMonths = 1,
  });

  // Google Play Console에서 설정할 상품 ID
  static const String monthlySubscriptionId = 'bizplan_monthly_subscription';

  static const SubscriptionProduct monthly = SubscriptionProduct(
    id: monthlySubscriptionId,
    title: '월간 멤버십',
    description: 'BizPlan 프리미엄 기능 무제한 사용',
    price: '9,900',
    currency: 'KRW',
    durationMonths: 1,
  );
}
