import 'package:flutter/material.dart';

class SubscriptionProcessingOverlay extends StatelessWidget {
  const SubscriptionProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 로딩 애니메이션
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF579bf2)),
                  ),
                ),
                const SizedBox(height: 24),

                // 메인 메세지
                const Text(
                  '구독 처리 중',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF579bf2),
                  ),
                ),
                const SizedBox(height: 12),

                // 설명 텍스트
                Text(
                  '결제를 진행중 입니다.\n잠시만 기다려주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),

                // 추가 안내
                Text(
                  '보통 2-3초 정도 소요됩니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
