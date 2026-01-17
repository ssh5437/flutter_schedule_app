-- jscare2026 쿠폰이 존재하는지 확인하고, 없으면 삽입
INSERT INTO coupons (code, coupon_type, fixed_expiry_date, max_uses, is_active, allow_multiple_uses_per_user)
VALUES
  ('jscare2026', 'fixed_date', '2026-08-31 23:59:59+00', NULL, TRUE, TRUE)
ON CONFLICT (code) DO UPDATE SET
  allow_multiple_uses_per_user = TRUE,
  is_active = TRUE;

-- MONTH1 쿠폰도 확인
INSERT INTO coupons (code, coupon_type, duration_months, max_uses, is_active, allow_multiple_uses_per_user)
VALUES
  ('MONTH1', 'duration', 1, 100, TRUE, FALSE)
ON CONFLICT (code) DO UPDATE SET
  allow_multiple_uses_per_user = FALSE,
  is_active = TRUE;
