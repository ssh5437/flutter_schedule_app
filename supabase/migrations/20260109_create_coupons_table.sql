-- 쿠폰 테이블 생성
CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) UNIQUE NOT NULL,
  coupon_type VARCHAR(20) NOT NULL, -- 'fixed_date' or 'duration'
  duration_months INTEGER, -- coupon_type이 'duration'일 때 사용 (예: 1개월)
  fixed_expiry_date TIMESTAMP WITH TIME ZONE, -- coupon_type이 'fixed_date'일 때 사용
  max_uses INTEGER DEFAULT 1, -- 최대 사용 가능 횟수 (NULL이면 무제한)
  current_uses INTEGER DEFAULT 0, -- 현재 사용된 횟수
  is_active BOOLEAN DEFAULT TRUE, -- 쿠폰 활성화 여부
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 쿠폰 사용 기록 테이블
CREATE TABLE IF NOT EXISTS coupon_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id UUID NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  redeemed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expiry_date TIMESTAMP WITH TIME ZONE NOT NULL, -- 이 쿠폰으로 획득한 멤버십 만료일
  UNIQUE(coupon_id, user_id) -- 같은 사용자는 같은 쿠폰을 한 번만 사용 가능
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_user_id ON coupon_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_coupon_id ON coupon_redemptions(coupon_id);

-- RLS (Row Level Security) 활성화
ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupon_redemptions ENABLE ROW LEVEL SECURITY;

-- 쿠폰 테이블 정책: 모든 인증된 사용자가 읽기 가능
CREATE POLICY "Anyone can read active coupons" ON coupons
  FOR SELECT
  USING (is_active = TRUE);

-- 쿠폰 사용 기록 정책: 자신의 기록만 읽기 가능
CREATE POLICY "Users can read own redemptions" ON coupon_redemptions
  FOR SELECT
  USING (auth.uid() = user_id);

-- 쿠폰 사용 기록 정책: 자신의 기록만 생성 가능
CREATE POLICY "Users can create own redemptions" ON coupon_redemptions
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 초기 쿠폰 데이터 삽입
INSERT INTO coupons (code, coupon_type, fixed_expiry_date, max_uses, is_active)
VALUES
  ('jscare2026', 'fixed_date', '2026-08-31 23:59:59+00', NULL, TRUE)
ON CONFLICT (code) DO NOTHING;

-- 1개월 쿠폰 샘플 (필요시 사용)
INSERT INTO coupons (code, coupon_type, duration_months, max_uses, is_active)
VALUES
  ('MONTH1', 'duration', 1, 100, TRUE)
ON CONFLICT (code) DO NOTHING;

-- updated_at 자동 업데이트 트리거 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 트리거 생성
CREATE TRIGGER update_coupons_updated_at
  BEFORE UPDATE ON coupons
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
