# Google Play 구매 검증 서버 설정 가이드

## 1. Google Cloud Console 설정

### 1.1 서비스 계정 생성

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 프로젝트 선택 (또는 새로 생성)
3. **IAM & Admin > Service Accounts** 메뉴로 이동
4. **CREATE SERVICE ACCOUNT** 클릭
5. 서비스 계정 정보 입력:
   - Name: `bizplan-purchase-verifier`
   - Description: `BizPlan 앱 구매 검증용 서비스 계정`
6. **CREATE AND CONTINUE** 클릭
7. 역할 선택: **없음** (Google Play Console에서 따로 설정)
8. **DONE** 클릭

### 1.2 서비스 계정 키 생성

1. 생성한 서비스 계정 클릭
2. **KEYS** 탭으로 이동
3. **ADD KEY > Create new key** 클릭
4. Key type: **JSON** 선택
5. **CREATE** 클릭
6. JSON 키 파일 다운로드 및 안전하게 보관

JSON 파일 내용 예시:
```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "bizplan-purchase-verifier@your-project.iam.gserviceaccount.com",
  "client_id": "...",
  ...
}
```

### 1.3 Google Play Android Developer API 활성화

1. Google Cloud Console에서 **APIs & Services > Library** 메뉴로 이동
2. "Google Play Android Developer API" 검색
3. API 선택 후 **ENABLE** 클릭

## 2. Google Play Console 설정

### 2.1 서비스 계정 연결

1. [Google Play Console](https://play.google.com/console) 접속
2. **Users and permissions** 메뉴로 이동
3. **Invite new users** 클릭
4. Email: 위에서 생성한 서비스 계정 이메일 입력
   - 예: `bizplan-purchase-verifier@your-project.iam.gserviceaccount.com`
5. **App permissions** 탭에서 앱 선택
6. **Financial data** 권한 체크:
   - ✅ View financial data, orders, and cancellation survey responses
7. **Invite user** 클릭
8. 이메일로 전송된 초대 수락 (필요한 경우)

## 3. Supabase Edge Function 배포

### 3.1 Supabase CLI 설치

```bash
# npm으로 설치
npm install -g supabase

# 로그인
supabase login
```

### 3.2 환경 변수 설정

Supabase 대시보드에서:

1. **Project Settings > Edge Functions** 메뉴로 이동
2. **Secrets** 섹션에서 다음 환경 변수 추가:

```bash
# Google 서비스 계정 이메일
GOOGLE_SERVICE_ACCOUNT_EMAIL=bizplan-purchase-verifier@your-project.iam.gserviceaccount.com

# Google 서비스 계정 Private Key (JSON 파일의 private_key 값)
GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

**중요**: `GOOGLE_PRIVATE_KEY`는 JSON 파일에서 `private_key` 값을 그대로 복사하세요. `\n`을 실제 줄바꿈으로 변경하지 마세요.

### 3.3 Edge Function 배포

프로젝트 루트에서:

```bash
# Supabase 프로젝트와 연결
supabase link --project-ref your-project-ref

# Edge Function 배포
supabase functions deploy verify-purchase

# 배포 확인
supabase functions list
```

## 4. 테스트

### 4.1 로컬 테스트

```bash
# Edge Function 로컬 실행
supabase functions serve verify-purchase --env-file ./supabase/.env.local

# 다른 터미널에서 테스트 요청
curl -i --location --request POST 'http://localhost:54321/functions/v1/verify-purchase' \
  --header 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"productId":"bizplan_monthly_subscription","purchaseToken":"test-token","packageName":"com.vividlife.bizplan"}'
```

### 4.2 프로덕션 테스트

```bash
curl -i --location --request POST 'https://your-project-ref.supabase.co/functions/v1/verify-purchase' \
  --header 'Authorization: Bearer YOUR_ACCESS_TOKEN' \
  --header 'Content-Type: application/json' \
  --data '{"productId":"bizplan_monthly_subscription","purchaseToken":"actual-purchase-token","packageName":"com.vividlife.bizplan"}'
```

## 5. 보안 주의사항

1. **Private Key 보호**:
   - Private Key는 절대 Git에 커밋하지 마세요
   - `.gitignore`에 `*.json` 추가
   - Supabase Secrets에만 저장

2. **서비스 계정 권한 최소화**:
   - Google Play Console에서 필요한 최소 권한만 부여
   - 정기적으로 권한 검토

3. **Edge Function URL 보호**:
   - Supabase RLS (Row Level Security) 활성화
   - 클라이언트에서만 호출 가능하도록 제한

## 6. 트러블슈팅

### 에러: "Invalid grant"
- 서비스 계정 이메일이 정확한지 확인
- Private Key가 올바르게 설정되었는지 확인
- Google Play Console에서 서비스 계정 초대가 수락되었는지 확인

### 에러: "The current user has insufficient permissions"
- Google Play Console에서 Financial data 권한이 부여되었는지 확인
- 서비스 계정이 올바른 앱에 연결되었는지 확인

### 에러: "Purchase token not found"
- 구매 토큰이 유효한지 확인
- packageName이 정확한지 확인 (`com.vividlife.bizplan`)

## 7. Edge Function URL

배포 후 Edge Function URL:
```
https://your-project-ref.supabase.co/functions/v1/verify-purchase
```

이 URL을 Flutter 앱에서 사용합니다.
