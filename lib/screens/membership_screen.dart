import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription.dart';
import '../widgets/gradient_app_bar.dart';
// import '../widgets/subscription_processing_overlay.dart'; // 낙관적 업데이트 방식으로 변경되어 비활성화

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  bool _previousSubscriptionStatus = false;
  SubscriptionProvider? _subscriptionProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscriptionProvider = context.read<SubscriptionProvider>();
      _subscriptionProvider!.initialize();

      // 멤버십 화면 진입 시 서버에서 최신 상태 강제 검증
      _subscriptionProvider!.refreshSubscription(forceVerify: true);

      // 구독 상태 변경 리스닝
      _subscriptionProvider!.addListener(_onSubscriptionChanged);
    });
  }

  @override
  void dispose() {
    _subscriptionProvider?.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (_subscriptionProvider == null) return;

    final currentStatus = _subscriptionProvider!.hasActiveSubscription;

    debugPrint('📢 구독 상태 변경 감지: 이전=$_previousSubscriptionStatus, 현재=$currentStatus');

    // 구독 상태가 false → true로 변경되었을 때만 알림 표시
    if (!_previousSubscriptionStatus && currentStatus) {
      debugPrint('🎉 구독 활성화 확인! 성공 다이얼로그 표시');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSuccessDialog(
            '구독이 완료되었습니다!',
            'Plus 기능을 무제한으로 이용하실 수 있습니다.',
          );
        }
      });
    }

    _previousSubscriptionStatus = currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: '멤버십 관리'),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              // 메인 컨텐츠
              if (provider.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSubscriptionCard(provider),
                      const SizedBox(height: 24),
                      _buildBenefitsSection(),
                      const SizedBox(height: 24),
                      _buildActionButtons(provider),
                    ],
                  ),
                ),

              // 구독 처리 중 오버레이 (낙관적 업데이트 방식으로 변경되어 비활성화)
              // if (provider.isProcessingPurchase)
              //   const Positioned.fill(
              //     child: SubscriptionProcessingOverlay(),
              //   ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionCard(SubscriptionProvider provider) {
    final hasActive = provider.hasActiveSubscription;
    final subscription = provider.subscription;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: hasActive
              ? const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: hasActive ? null : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hasActive ? 'Plus 멤버십' : '무료 플랜',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: hasActive ? Colors.white : Colors.black87,
                  ),
                ),
                if (hasActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '활성',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasActive) ...[
              _buildInfoRow(
                '구매일',
                _formatDate(subscription.purchaseDate),
                Colors.white70,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                '만료일',
                _formatDate(subscription.expiryDate),
                Colors.white70,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                '남은 기간',
                '${subscription.remainingDays}일',
                provider.isExpiringSoon ? Colors.orange : Colors.white70,
              ),
              if (provider.isExpiringSoon) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '멤버십이 곧 만료됩니다. 갱신을 고려해주세요.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              Text(
                'Plus 멤버십을 구독하고\n모든 기능을 무제한으로 이용하세요!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: valueColor.withValues(alpha: 0.8),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plus 혜택',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildBenefitItem(
              Icons.business_center,
              '업체 추가 무제한',
              '원하는 만큼 업체를 등록하고 관리',
            ),
            _buildBenefitItem(
              Icons.text_fields,
              'AI 텍스트 추출 무제한',
              '사진에서 텍스트를 무제한으로 추출',
            ),
            _buildBenefitItem(
              Icons.bar_chart,
              '매출 분석 기간 변경 가능',
              '원하는 기간을 설정해서 통계 및 분석',
            ),
            _buildBenefitItem(
              Icons.date_range,
              '백업 기간 지정 가능',
              '과거의 스케줄까지 백업 가능',
            ),
            _buildBenefitItem(
              Icons.message,
              '메시지 템플릿 무제한',
              '자주 사용하는 메시지들을 등록',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '월 ${SubscriptionProduct.monthly.price}${SubscriptionProduct.monthly.currency}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue[700], size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(SubscriptionProvider provider) {
    final hasActive = provider.hasActiveSubscription;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasActive)
          ElevatedButton.icon(
            onPressed: provider.isLoading
                ? null
                : () async {
                    provider.clearMessages();
                    debugPrint('💳 구독 구매 시작...');

                    final success = await provider.purchaseSubscription();

                    if (mounted) {
                      if (!success) {
                        // 구매 시작 실패 시에만 에러 표시
                        _showErrorDialog(
                          '구독 실패',
                          provider.errorMessage ?? '구독 상품을 불러올 수 없습니다.\n네트워크 연결을 확인하고 다시 시도해주세요.',
                        );
                      }
                      // 구매가 시작되면 결제 화면으로 이동
                      // 결제 완료 후 스트림을 통해 자동으로 UI 업데이트됨
                    }
                  },
            icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.shopping_cart),
            label: Text(
              provider.isLoading ? '처리 중...' : 'Plus 구독하기',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: provider.isLoading
              ? null
              : () async {
                  provider.clearMessages();
                  final success = await provider.restorePurchases();
                  if (mounted) {
                    if (success) {
                      if (provider.successMessage != null) {
                        _showSuccessDialog('복원 완료', provider.successMessage!);
                      }
                    } else {
                      _showInfoDialog(
                        '구매 복원',
                        provider.errorMessage ?? '복원할 구독 내역이 없습니다.',
                      );
                    }
                  }
                },
          icon: provider.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.restore),
          label: Text(
            provider.isLoading ? '복원 중...' : '구매 복원',
            style: const TextStyle(fontSize: 16),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(
              color: provider.isLoading
                  ? Colors.grey
                  : const Color(0xFF1976D2),
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildRestoreInfoCard(),
      ],
    );
  }

  Widget _buildRestoreInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '앱을 재설치하셨나요? "구매 복원" 버튼을 눌러 이전에 구매한 구독을 복구하세요.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[900],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green[700], size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '확인',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.red[700], size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '확인',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.info_outline, color: Colors.blue[700], size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '확인',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy년 MM월 dd일').format(date);
  }
}
