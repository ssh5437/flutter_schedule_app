-- ============================================================
-- 로컬 SQLite → Supabase 동기화용 테이블 생성
-- 로컬 DB가 기본이고, Supabase는 클라우드 백업 + 웹 버전용
-- ============================================================

-- schedules 테이블
CREATE TABLE IF NOT EXISTS schedules (
  id BIGINT PRIMARY KEY,
  user_id TEXT NOT NULL,
  customer_name TEXT NOT NULL,
  visit_date TEXT,
  visit_time TEXT,
  phone_number TEXT NOT NULL,
  address TEXT,
  jibun_address TEXT,
  company_name TEXT,
  work_items TEXT NOT NULL,
  work_prices TEXT NOT NULL DEFAULT '',
  work_count INTEGER NOT NULL DEFAULT 1,
  notes TEXT,
  status TEXT NOT NULL DEFAULT '예정',
  synced_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "schedules_user_policy"
    ON schedules FOR ALL
    USING (user_id = auth.uid()::text)
    WITH CHECK (user_id = auth.uid()::text);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_schedules_user_id ON schedules(user_id);
CREATE INDEX IF NOT EXISTS idx_schedules_visit_date ON schedules(user_id, visit_date);
CREATE INDEX IF NOT EXISTS idx_schedules_status ON schedules(user_id, status);

-- companies 테이블
CREATE TABLE IF NOT EXISTS companies (
  id BIGINT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  work_items TEXT NOT NULL,
  color BIGINT NOT NULL DEFAULT 4283215411,
  display_order INTEGER NOT NULL DEFAULT 0,
  synced_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "companies_user_policy"
    ON companies FOR ALL
    USING (user_id = auth.uid()::text)
    WITH CHECK (user_id = auth.uid()::text);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_companies_user_id ON companies(user_id);

-- message_templates 테이블
CREATE TABLE IF NOT EXISTS message_templates (
  id BIGINT PRIMARY KEY,
  user_id TEXT NOT NULL,
  company_id BIGINT NOT NULL,
  name TEXT NOT NULL,
  content TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  synced_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE message_templates ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "message_templates_user_policy"
    ON message_templates FOR ALL
    USING (user_id = auth.uid()::text)
    WITH CHECK (user_id = auth.uid()::text);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_message_templates_user_company ON message_templates(user_id, company_id);

-- date_memos 테이블
CREATE TABLE IF NOT EXISTS date_memos (
  id BIGINT PRIMARY KEY,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  synced_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE date_memos ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "date_memos_user_policy"
    ON date_memos FOR ALL
    USING (user_id = auth.uid()::text)
    WITH CHECK (user_id = auth.uid()::text);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_date_memos_user_date ON date_memos(user_id, date);
