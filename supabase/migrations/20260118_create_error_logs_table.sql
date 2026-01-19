-- 에러 로그 테이블 생성
CREATE TABLE IF NOT EXISTS error_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  error_type VARCHAR(50) NOT NULL, -- 'exception', 'api_error', 'slow_loading', 'performance', 'startup_error'
  message TEXT NOT NULL,
  stack_trace TEXT,
  screen_name VARCHAR(100),
  app_version VARCHAR(20),
  build_number VARCHAR(20),
  platform VARCHAR(20), -- 'android', 'ios', 'web', 'windows', 'macos', 'linux'
  platform_version TEXT,
  additional_data JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 인덱스 생성 (조회 성능 최적화)
CREATE INDEX IF NOT EXISTS idx_error_logs_user_id ON error_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_error_logs_error_type ON error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_logs_app_version ON error_logs(app_version);

-- RLS (Row Level Security) 활성화
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;

-- 에러 로그 정책: 인증된 사용자는 자신의 로그를 생성할 수 있음
CREATE POLICY "Users can insert own error logs" ON error_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- 에러 로그 정책: 자신의 로그만 조회 가능 (선택적)
CREATE POLICY "Users can view own error logs" ON error_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- 코멘트 추가
COMMENT ON TABLE error_logs IS '앱 에러 및 성능 로그 테이블';
COMMENT ON COLUMN error_logs.error_type IS '에러 유형: exception, api_error, slow_loading, performance, startup_error';
COMMENT ON COLUMN error_logs.additional_data IS 'JSON 형태의 추가 데이터 (duration_ms, endpoint 등)';
