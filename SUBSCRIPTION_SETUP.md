# BizPlan 구독 시스템 설정 가이드

## 목차
1. [시스템 아키텍처](#시스템-아키텍처)
2. [Google Play Console 설정](#1-google-play-console-설정)
3. [Google Cloud 설정](#2-google-cloud-설정)
4. [Supabase 설정](#3-supabase-설정)
5. [Flutter 앱 설정](#4-flutter-앱-설정)
6. [테스트](#5-테스트)
7. [배포](#6-배포)

---

## 시스템 아키텍처

```
┌─────────────┐
│ Flutter App │
└──────┬──────┘
       │
       │ 1. 구매 요청
       ↓
┌─────────────────┐
│ Google Play     │
│ Billing API     │
└──────┬──────────┘
       │
       │ 2. 구매 토큰 반환
       ↓
┌─────────────┐
│ Flutter App │
└──────┬──────┘
       │
       │ 3. 서버 검증 요청
       ↓
┌─────────────────────┐
│ Supabase           │
│ Edge Function      │
└──────┬──────────────┘
       │
       │ 4. 토큰 검증
       ↓
┌─────────────────────┐
│ Google Play        │
│ Developer API      │
└──────┬──────────────┘
       │
       │ 5. 구매 정보 반환
       ↓
┌─────────────────────┐
│ Supabase DB        │
│ (profiles 테이블)  │
└─────────────────────┘
```

### 데이터 흐름
1. 사용자가 앱에서 구독 구매
2. Google Play Billing이 구매 처리
3. 앱이 구매 토큰을 받음
4. 앱이 Supabase Edge Function 호출
5. Edge Function이 Google API로 구매 검증
6. 검증 성공 시 Supabase DB 업데이트
7. 앱이 로컬 DB 업데이트

---

## 1. Google Play Console 설정

### 1.1 구독 상품 생성

1. [Google Play Console](https://play.google.com/console) 접속
2. 앱 선택: **BizPlan** (com.vividlife.bizplan)
3. **Monetize > Subscriptions** 메뉴로 이동
4. **Create subscription** 클릭

#### 구독 정보:
- **Product ID**: `bizplan_monthly_subscription`
- **Name**: BizPlan 월간 프리미엄
- **Description**: 프리미엄 기능 무제한 이용 (월간)

#### 가격 설정:
- **Base plan ID**: `monthly`
- **Billing period**: 1 month
- **Price**: KRW 9,900

#### 무료 체험 (선택사항):
- Free trial: 7 days
- 또는 Intro price: 첫 달 50% 할인

5. **Save** 클릭
6. **Activate** 클릭하여 상품 활성화

### 1.2 테스트 계정 설정

1. **Setup > License testing** 메뉴로 이동
2. **License Testing** 섹션에서:
   - Test purchases: **활성화**
3. **Gmail accounts with testing access** 섹션에서:
   - 테스트용 Gmail 계정 추가
   - 예: `your-test-email@gmail.com`

---

## 2. Google Cloud 설정

### 2.1 프로젝트 설정

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. Play Console과 연결된 프로젝트 선택
3. **APIs & Services > Library** 메뉴로 이동
4. **Google Play Android Developer API** 검색 및 활성화

### 2.2 서비스 계정 생성

1. **IAM & Admin > Service Accounts** 메뉴로 이동
2. **CREATE SERVICE ACCOUNT** 클릭
3. 정보 입력:
   ```
   Name: bizplan-purchase-verifier
   Description: BizPlan 구매 검증용 서비스 계정
   ```
4. **CREATE AND CONTINUE** 클릭
5. 역할: 없음 (Play Console에서 설정)
6. **DONE** 클릭

### 2.3 서비스 계정 키 생성

1. 생성한 서비스 계정 클릭
2. **KEYS** 탭으로 이동
3. **ADD KEY > Create new key** 클릭
4. Key type: **JSON** 선택
5. **CREATE** 클릭
6. **중요**: 다운로드한 JSON 파일을 안전하게 보관

### 2.4 Play Console과 연결

1. Google Play Console로 돌아가기
2. **Users and permissions** 메뉴로 이동
3. **Invite new users** 클릭
4. Email: `bizplan-purchase-verifier@YOUR-PROJECT.iam.gserviceaccount.com`
5. **App permissions** 탭:
   - 앱 선택: BizPlan
   - ✅ View financial data, orders, and cancellation survey responses
6. **Invite user** 클릭

---

## 3. Supabase 설정

### 3.1 Edge Function 배포

#### 사전 준비:
```bash
# Supabase CLI 설치
npm install -g supabase

# Supabase 로그인
supabase login
```

#### 프로젝트 연결:
```bash
# 프로젝트 루트에서
cd d:\MyApp\bizPlan

# Supabase 프로젝트와 연결
supabase link --project-ref YOUR_PROJECT_REF
```

#### 환경 변수 설정:

Supabase Dashboard에서:
1. **Project Settings > Edge Functions** 메뉴
2. **Secrets** 섹션에서 추가:

```bash
# Google 서비스 계정 이메일
GOOGLE_SERVICE_ACCOUNT_EMAIL=bizplan-purchase-verifier@YOUR-PROJECT.iam.gserviceaccount.com

# Google 서비스 계정 Private Key
# JSON 키 파일의 "private_key" 값을 복사 (줄바꿈 포함)
GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...(전체 키)...\n-----END PRIVATE KEY-----\n"
```

**중요**:
- `GOOGLE_PRIVATE_KEY`는 JSON 파일의 `private_key` 값을 **그대로** 복사
- `\n`을 실제 줄바꿈으로 변경하지 마세요

#### Edge Function 배포:
```bash
# 배포
supabase functions deploy verify-purchase

# 배포 확인
supabase functions list
```

#### 배포 후 URL:
```
https://YOUR-PROJECT-REF.supabase.co/functions/v1/verify-purchase
```

### 3.2 RLS (Row Level Security) 설정

Supabase Dashboard에서:

1. **Database > Tables > profiles** 테이블 선택
2. **RLS policies** 탭으로 이동
3. 기존 정책 확인 또는 추가:

```sql
-- 사용자는 자신의 프로필만 조회 가능
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

-- 사용자는 자신의 프로필만 업데이트 가능
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id);
```

---

## 4. Flutter 앱 설정

### 4.1 의존성 확인

`pubspec.yaml`:
```yaml
dependencies:
  in_app_purchase: ^3.2.0
  in_app_purchase_android: ^0.3.0+20
  supabase_flutter: ^2.5.0
  provider: ^6.1.1
```

### 4.2 AndroidManifest.xml 확인

`android/app/src/main/AndroidManifest.xml`:
```xml
<!-- 인앱 결제 권한 -->
<uses-permission android:name="com.android.vending.BILLING" />
```

### 4.3 패키지 이름 확인

모든 곳에서 일관된 패키지 이름 사용:
- `android/app/build.gradle.kts`: `com.vividlife.bizplan`
- AndroidManifest.xml: `com.vividlife.bizplan`
- SubscriptionService: `com.vividlife.bizplan`

---

## 5. 테스트

### 5.1 로컬 Edge Function 테스트

```bash
# Edge Function 로컬 실행
supabase functions serve verify-purchase

# 다른 터미널에서 테스트
curl -i --location --request POST 'http://localhost:54321/functions/v1/verify-purchase' \
  --header 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"productId":"bizplan_monthly_subscription","purchaseToken":"test-token","packageName":"com.vividlife.bizplan"}'
```

### 5.2 Flutter 앱 테스트

#### 테스트 계정으로 로그인:
1. 앱 설치
2. 테스트 계정으로 로그인 (Play Console에서 추가한 계정)
3. 멤버십 화면으로 이동
4. "프리미엄 구독하기" 클릭

#### 테스트 구매:
- 테스트 계정은 실제 결제 없이 구매 가능
- 구매 플로우가 정상적으로 동작하는지 확인

#### 디버그 화면에서 확인:
1. 설정 > 디버그 정보
2. 멤버십 상태 확인
3. 테스트 모드로 전환하여 다양한 시나리오 테스트

---

## 6. 배포

### 6.1 프로덕션 체크리스트

- [ ] Google Play Console에서 구독 상품 활성화됨
- [ ] Google Cloud에서 서비스 계정 설정 완료
- [ ] Play Console에서 서비스 계정 권한 부여됨
- [ ] Supabase Edge Function 배포 완료
- [ ] Supabase Secrets 설정 완료
- [ ] Flutter 앱 빌드 및 테스트 완료
- [ ] 테스트 계정으로 구매 테스트 완료

### 6.2 릴리스 빌드

```bash
# 릴리스 APK 빌드
flutter build apk --release

# 또는 App Bundle (권장)
flutter build appbundle --release
```

### 6.3 Play Console 업로드

1. Google Play Console > **Release > Production**
2. **Create new release** 클릭
3. App bundle 업로드
4. Release notes 작성
5. **Review release** > **Start rollout to Production**

---

## 7. 모니터링 및 유지보수

### 7.1 Supabase 로그 확인

```bash
# Edge Function 로그 확인
supabase functions logs verify-purchase
```

### 7.2 Google Play Console 모니터링

- **Monetize > Subscriptions > Dashboard**: 구독 통계
- **Orders**: 개별 주문 내역
- **Reports > Financial reports**: 재무 보고서

### 7.3 에러 처리

**일반적인 에러**:
- `Invalid purchase token`: 토큰이 만료되었거나 잘못됨
- `Insufficient permissions`: 서비스 계정 권한 확인
- `Invalid grant`: Private Key 또는 이메일 확인

**해결 방법**:
1. Supabase Edge Function 로그 확인
2. Google Cloud Console에서 API 사용량 확인
3. Play Console에서 서비스 계정 상태 확인

---

## 8. 보안 주의사항

1. **Private Key 보호**:
   - Git에 절대 커밋하지 마세요
   - `.gitignore`에 `*.json`, `*.key` 추가
   - Supabase Secrets에만 저장

2. **서비스 계정 권한**:
   - 필요한 최소 권한만 부여
   - 정기적으로 권한 검토

3. **Edge Function 보안**:
   - RLS 활성화
   - 인증된 사용자만 호출 가능

4. **클라이언트 측 검증**:
   - 항상 서버 검증 결과 사용
   - 로컬 데이터는 참고용

---

## 문의 및 지원

- Supabase 문서: https://supabase.com/docs
- Google Play 문서: https://developer.android.com/google/play/billing
- Flutter IAP: https://pub.dev/packages/in_app_purchase
