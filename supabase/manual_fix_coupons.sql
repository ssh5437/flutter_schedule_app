-- 이 SQL을 Supabase 대시보드 SQL Editor에서 실행하세요

-- 1. 현재 쿠폰 테이블 확인
SELECT * FROM coupons;

-- 2. jscare2026 쿠폰이 없으면 삽입, 있으면 업데이트
INSERT INTO coupons (code, coupon_type, fixed_expiry_date, max_uses, is_active, allow_multiple_uses_per_user)
VALUES ('jscare2026', 'fixed_date', '2026-08-31 23:59:59+00', NULL, TRUE, TRUE)
ON CONFLICT (code) DO UPDATE SET
  coupon_type = 'fixed_date',
  fixed_expiry_date = '2026-08-31 23:59:59+00',
  max_uses = NULL,
  is_active = TRUE,
  allow_multiple_uses_per_user = TRUE,
  updated_at = NOW();

-- 3. MONTH1 샘플 쿠폰도 확인
INSERT INTO coupons (code, coupon_type, duration_months, max_uses, is_active, allow_multiple_uses_per_user)
VALUES ('MONTH1', 'duration', 1, 100, TRUE, FALSE)
ON CONFLICT (code) DO UPDATE SET
  coupon_type = 'duration',
  duration_months = 1,
  fixed_expiry_date = NULL,
  max_uses = 100,
  is_active = TRUE,
  allow_multiple_uses_per_user = FALSE,
  updated_at = NOW();

-- 4. 결과 확인
SELECT
  code,
  coupon_type,
  duration_months,
  fixed_expiry_date,
  max_uses,
  current_uses,
  is_active,
  allow_multiple_uses_per_user,
  created_at,
  updated_at
FROM coupons
ORDER BY created_at DESC;
