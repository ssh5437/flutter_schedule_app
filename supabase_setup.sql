-- ============================================================
-- Supabase 프로필 테이블 설정 SQL
-- ============================================================
--
-- 사용 방법:
-- 1. Supabase Dashboard 접속 (https://app.supabase.com)
-- 2. 프로젝트 선택
-- 3. SQL Editor 이동
-- 4. 아래 SQL 전체를 복사해서 실행
--
-- ============================================================

-- 1. profiles 테이블 생성
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    phone_number TEXT,
    photo_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 멤버십 정보
    membership_tier TEXT NOT NULL DEFAULT 'free' CHECK (membership_tier IN ('free', 'plus', 'pro')),
    membership_expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- 추가 메타데이터
    metadata JSONB DEFAULT '{}'::jsonb,

    -- 인덱스를 위한 제약조건
    CONSTRAINT profiles_email_key UNIQUE (email)
);

-- 2. 인덱스 생성 (쿼리 성능 향상)
CREATE INDEX IF NOT EXISTS profiles_email_idx ON public.profiles(email);
CREATE INDEX IF NOT EXISTS profiles_membership_tier_idx ON public.profiles(membership_tier);
CREATE INDEX IF NOT EXISTS profiles_is_active_idx ON public.profiles(is_active);

-- 3. RLS (Row Level Security) 활성화
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. RLS 정책 생성

-- 사용자는 자신의 프로필을 조회할 수 있음
CREATE POLICY "Users can view their own profile"
    ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

-- 사용자는 자신의 프로필을 업데이트할 수 있음
CREATE POLICY "Users can update their own profile"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 사용자는 자신의 프로필을 삽입할 수 있음
CREATE POLICY "Users can insert their own profile"
    ON public.profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- 5. updated_at 자동 업데이트 트리거 함수
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. updated_at 트리거 생성
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- 7. 회원가입 시 자동으로 프로필 생성하는 트리거 (선택사항)
-- 이 트리거를 사용하면 Flutter 코드에서 수동으로 프로필을 생성할 필요가 없습니다.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        NOW(),
        NOW()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. auth.users 테이블에 트리거 연결
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 9. 프로필 삭제 시 관련 데이터도 함께 삭제 (Cascade는 이미 설정됨)
-- 추가 정리 작업이 필요한 경우 여기에 트리거 추가

-- ============================================================
-- 테스트 쿼리
-- ============================================================

-- 모든 프로필 조회 (관리자용)
-- SELECT * FROM public.profiles ORDER BY created_at DESC;

-- 특정 사용자 프로필 조회
-- SELECT * FROM public.profiles WHERE id = 'USER_ID';

-- 멤버십별 사용자 수 조회
-- SELECT membership_tier, COUNT(*) as count
-- FROM public.profiles
-- WHERE is_active = true
-- GROUP BY membership_tier;

-- ============================================================
-- 완료!
-- ============================================================
--
-- 이제 Flutter 앱에서 회원가입하면 자동으로 profiles 테이블에
-- 사용자 정보가 저장됩니다.
--
-- ============================================================
