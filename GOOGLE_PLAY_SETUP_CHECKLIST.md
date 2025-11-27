# Google Play 실제 결제 테스트 체크리스트

## 🔴 현재 상태

Edge Function 테스트 결과:
```json
{
  "error": "Invalid Credentials",
  "status": "UNAUTHENTICATED"
}
```

**문제**: Google API 인증이 실패하고 있습니다.

**원인**: Supabase에 Google 서비스 계정 정보(Secrets)가 설정되지 않았거나 잘못 설정되었습니다.

---

## ✅ 실제 결제 테스트를 위한 필수 단계

### 1단계: Google Cloud Console 설정 ⚠️ **필수**

#### 1.1 서비스 계정 생성

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 프로젝트 선택 또는 생성: `bizplan-478009` (이미 있음)
3. **IAM & Admin > Service Accounts** 메뉴
4. 기존 서비스 계정 확인:
   - 이메일: `bizplan-purchase-verifier@bizplan-478009.iam.gserviceaccount.com`
   - 이미 있으면 다음 단계로, 없으면 생성

#### 1.2 서비스 계정 키 확인

현재 `.env.local`에 키가 있습니다:
```
GOOGLE_SERVICE_ACCOUNT_EMAIL=bizplan-purchase-verifier@bizplan-478009.iam.gserviceaccount.com
GOOGLE_PRIVATE_KEY=...
```

**하지만 이 키가 실제로 유효한지 확인 필요!**

**확인 방법**:
1. Google Cloud Console > IAM & Admin > Service Accounts
2. `bizplan-purchase-verifier` 클릭
3. **KEYS** 탭 확인
4. 키가 없거나 오래되었으면 새로 생성:
   - **ADD KEY > Create new key**
   - Type: **JSON**
   - 다운로드된 JSON 파일 확인

#### 1.3 Google Play Android Developer API 활성화

1. Google Cloud Console > **APIs & Services > Library**
2. "Google Play Android Developer API" 검색
3. **ENABLE** 클릭 (이미 활성화되어 있을 수도 있음)

---

### 2단계: Google Play Console 설정 ⚠️ **필수**

#### 2.1 앱 확인

1. [Google Play Console](https://play.google.com/console) 접속
2. 앱 선택: **BizPlan** (`com.vividlife.bizplan`)
3. 앱이 Play Console에 등록되어 있는지 확인

#### 2.2 서비스 계정 권한 부여

1. **Users and permissions** 메뉴
2. **Invite new users** 클릭
3. Email 입력:
   ```
   bizplan-purchase-verifier@bizplan-478009.iam.gserviceaccount.com
   ```
4. **App permissions** 탭:
   - 앱 선택: **BizPlan**
   - 권한 선택:
     - ✅ **View financial data, orders, and cancellation survey responses**
5. **Invite user** 클릭
6. 초대 수락 (이메일 확인 필요할 수 있음)

#### 2.3 구독 상품 생성

1. **Monetize > Subscriptions** 메뉴
2. **Create subscription** 클릭
3. 구독 정보 입력:
   - **Product ID**: `bizplan_monthly_subscription` (코드와 일치해야 함!)
   - **Name**: BizPlan 월간 프리미엄
   - **Description**: 프리미엄 기능 무제한 이용
4. **Base plan** 설정:
   - **Base plan ID**: `monthly`
   - **Billing period**: 1 month
   - **Price**: KRW 9,900 (또는 원하는 금액)
5. **Save** → **Activate** 클릭

#### 2.4 테스트 계정 추가

1. **Setup > License testing** 메뉴
2. **License Testing** 섹션:
   - **Test purchases**: 활성화
3. **Gmail accounts with testing access**:
   - 테스트용 Gmail 계정 추가 (실제 결제 없이 테스트 가능)
   - 예: `your-test-email@gmail.com`

---

### 3단계: Supabase Secrets 설정 ⚠️ **필수** (현재 미설정)

#### 3.1 Google 서비스 계정 JSON 키 확인

Google Cloud Console에서 다운로드한 JSON 파일 열기:
```json
{
  "type": "service_account",
  "project_id": "bizplan-478009",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "bizplan-purchase-verifier@bizplan-478009.iam.gserviceaccount.com",
  ...
}
```

#### 3.2 Supabase Dashboard에서 Secrets 설정

1. [Supabase Dashboard](https://supabase.com/dashboard/project/bsofmuvuvhjpcrkygwjz/settings/functions) 접속
2. **Project Settings > Edge Functions** 메뉴
3. **Secrets** 섹션에서 추가:

**Secret 1:**
- Name: `GOOGLE_SERVICE_ACCOUNT_EMAIL`
- Value: `bizplan-purchase-verifier@bizplan-478009.iam.gserviceaccount.com`

**Secret 2:**
- Name: `GOOGLE_PRIVATE_KEY`
- Value: (JSON 파일의 `private_key` 값 **전체** 복사)
  ```
  -----BEGIN PRIVATE KEY-----
  MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDkc4bFerxjoM/g
  ...전체 내용...
  r/3Rq5hyvX8vQX803mXKJUiWmg==
  -----END PRIVATE KEY-----
  ```

**주의사항**:
- `\n`을 실제 줄바꿈으로 변경하지 말고 **그대로** 복사
- 또는 Supabase가 자동으로 줄바꿈 처리하므로 전체를 한 줄로 붙여넣기
- 앞뒤 공백 제거

#### 3.3 Secrets 저장 후 Edge Function 재배포 (선택)

Secrets 변경 후에는 자동 적용되지만, 확실하게 하려면:
```bash
supabase functions deploy verify-purchase
```

---

### 4단계: 설정 검증 테스트

#### 4.1 Secrets 설정 확인

```bash
# PowerShell에서 실행
curl -s "https://bsofmuvuvhjpcrkygwjz.supabase.co/functions/v1/verify-purchase" `
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzb2ZtdXZ1dmhqcGNya3lnd2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjY0ODksImV4cCI6MjA3NjM0MjQ4OX0.fdpNtooV0rPmdnZz2RSCuBxMeQEPuvjJTTXTIzaKZhQ" `
  -H "Content-Type: application/json" `
  -d '{"productId":"bizplan_monthly_subscription","purchaseToken":"test-invalid-token","packageName":"com.vividlife.bizplan"}'
```

**예상 결과**:
- ❌ **이전** (Secrets 미설정): `"Invalid Credentials"` 또는 `"UNAUTHENTICATED"`
- ✅ **이후** (Secrets 설정 완료): `"Purchase verification failed"` 또는 `"Purchase token not found"`

**설명**: "Purchase token not found"는 정상입니다! Google API 인증은 성공했지만 테스트 토큰이 유효하지 않아서 나오는 에러입니다.

---

### 5단계: 실제 구매 테스트

#### 5.1 앱 빌드 및 업로드

**방법 1: 내부 테스트 트랙 (권장)**

```bash
# App Bundle 빌드
flutter build appbundle --release

# Google Play Console > Release > Testing > Internal testing
# 1. App Bundle 업로드: build/app/outputs/bundle/release/app-release.aab
# 2. 테스트 계정 추가
# 3. 테스트 링크로 앱 설치
```

**방법 2: 직접 APK 설치 (인앱 결제 제한적)**

```bash
# 디버그 APK 빌드
flutter build apk --debug

# 기기에 설치
adb install build/app/outputs/flutter-apk/app-debug.apk
```

**중요**: 직접 설치한 APK는 인앱 결제가 작동하지 않을 수 있습니다. 내부 테스트 트랙 사용을 권장합니다.

#### 5.2 테스트 계정으로 구매

1. 테스트 기기에 테스트 Gmail 계정으로 로그인
2. Play Store에서 내부 테스트 앱 설치
3. 앱 실행 → Supabase 로그인
4. **멤버십 관리** > **프리미엄 구독하기** 클릭
5. Google Play 결제 화면에서:
   - 테스트 계정: "테스트 결제 - 실제 청구 없음" 메세지 표시
   - 구매 진행

#### 5.3 검증 확인

**Flutter 로그**:
```
✅ 구매 상태: PurchaseStatus.purchased
✅ 서버 검증 중...
✅ 구독 저장 완료 (서버 검증됨): 2025-XX-XX ~ 2025-XX-XX
```

**Supabase Dashboard**:
1. **Database > profiles** 테이블:
   - `membership_tier = 'premium'`
   - `membership_expires_at`: 1개월 후 날짜

2. **Edge Functions > Logs**:
   ```json
   {
     "valid": true,
     "productId": "bizplan_monthly_subscription",
     "orderId": "GPA.1234-5678-9012-34567"
   }
   ```

---

## 🔍 현재 필요한 작업 (우선순위)

### 1. ⚠️ **즉시 필요**: Supabase Secrets 설정

**현재 문제**: Google API 인증 실패 (`UNAUTHENTICATED`)

**해결 방법**:
1. Google Cloud Console에서 서비스 계정 JSON 키 다운로드
2. Supabase Dashboard → Settings → Edge Functions → Secrets
3. `GOOGLE_SERVICE_ACCOUNT_EMAIL`과 `GOOGLE_PRIVATE_KEY` 추가

**확인 스크립트**:
```bash
test_deployed_function.bat
# [2] 선택하여 테스트
```

### 2. ⚠️ **필수**: Google Play Console 설정

- [ ] 서비스 계정 권한 부여 (Financial data)
- [ ] 구독 상품 생성 (`bizplan_monthly_subscription`)
- [ ] 테스트 계정 추가

### 3. 📱 앱 업로드 및 테스트

- [ ] 내부 테스트 트랙에 App Bundle 업로드
- [ ] 테스트 계정으로 앱 설치
- [ ] 실제 구매 테스트

---

## 📋 빠른 설정 가이드

### A. Supabase Secrets만 설정하고 싶다면:

1. [Supabase Dashboard](https://supabase.com/dashboard/project/bsofmuvuvhjpcrkygwjz/settings/functions) 접속
2. Secrets 섹션에서 2개 추가 (위 3단계 참고)
3. 테스트:
   ```bash
   test_deployed_function.bat
   # [2] 선택
   ```
4. 결과: "Purchase token not found" 나오면 성공! ✅

### B. Google Play Console 전체 설정:

[SUBSCRIPTION_SETUP.md](SUBSCRIPTION_SETUP.md) 전체 가이드 참고

### C. 앱에서 바로 테스트 (Google 설정 없이):

1. Flutter 앱 실행
2. **설정 > 디버그 정보**
3. **"테스트: 프리미엄 활성화"** 클릭
4. Supabase DB에 premium 저장되는지 확인

**주의**: 이 방법은 서버 검증을 거치지 않습니다. 실제 구매 흐름을 테스트하려면 위 A, B 단계가 필요합니다.

---

## 🎯 요약

**실제 Google Play 결제 테스트를 하려면**:

1. ✅ Edge Function 배포 완료 (이미 완료)
2. ⚠️ **Supabase Secrets 설정 필요** (현재 미설정)
3. ⚠️ **Google Play Console 설정 필요** (서비스 계정 권한, 구독 상품)
4. 📱 앱을 내부 테스트 트랙에 업로드
5. 🧪 테스트 계정으로 구매 테스트

**현재 상태**: 2번 Secrets 설정이 안 되어 있어서 Google API 인증에 실패하고 있습니다.

**다음 단계**: Supabase Dashboard에서 Secrets를 설정하세요!
