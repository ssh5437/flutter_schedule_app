-- 쿠폰 테이블에 사용자당 중복 사용 허용 필드 추가
ALTER TABLE coupons
ADD COLUMN IF NOT EXISTS allow_multiple_uses_per_user BOOLEAN DEFAULT FALSE;

-- 기존 UNIQUE 제약 조건 제거
-- 이제 애플리케이션 레벨에서 allow_multiple_uses_per_user 값에 따라 중복 체크
ALTER TABLE coupon_redemptions
DROP CONSTRAINT IF EXISTS coupon_redemptions_coupon_id_user_id_key;

-- 인덱스는 유지 (성능을 위해)
CREATE INDEX IF NOT EXISTS idx_coupon_user_redemptions
ON coupon_redemptions(coupon_id, user_id);

-- jscare2026 쿠폰을 여러 사용자가 사용 가능하도록 업데이트
UPDATE coupons
SET allow_multiple_uses_per_user = TRUE
WHERE code = 'jscare2026';

-- MONTH1 쿠폰은 한 사용자당 한 번만 사용 가능하도록 유지
UPDATE coupons
SET allow_multiple_uses_per_user = FALSE
WHERE code = 'MONTH1';

-- 코멘트 추가
COMMENT ON COLUMN coupons.allow_multiple_uses_per_user IS '같은 사용자가 이 쿠폰을 여러 번 사용할 수 있는지 여부. TRUE면 중복 사용 가능, FALSE면 한 번만 사용 가능';
