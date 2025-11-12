# 서버 측 구매 검증 테스트 가이드

## 테스트 시나리오별 가이드

### 🔧 1. 로컬 Edge Function 테스트 (권장 - 가장 먼저 테스트)

**목적**: Google API 인증과 Edge Function 로직이 제대로 동작하는지 확인

#### 1.1 준비 사항
```bash
# Supabase CLI 설치 확인
supabase --version

# 없으면 설치
npm install -g supabase
```

#### 1.2 환경 변수 설정
`supabase/.env.local` 파일에 실제 값 입력:
```bash
GOOGLE_SERVICE_ACCOUNT_EMAIL=bizplan-purchase-verifier@your-project.iam.gserviceaccount.com
GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

#### 1.3 로컬 실행
```bash
# Edge Function 로컬 서버 시작
cd d:\MyApp\bizPlan
supabase functions serve verify-purchase --env-file ./supabase/.env.local --no-verify-jwt
```

#### 1.4 테스트 요청 (다른 터미널에서)

**테스트 1: 잘못된 토큰으로 에러 테스트**
```bash
curl -i --location --request POST 'http://localhost:54321/functions/v1/verify-purchase' ^
  --header "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\",\"purchaseToken\":\"invalid-token\",\"packageName\":\"com.vividlife.bizplan\"}"
```

**예상 결과**: Google API 에러 (400) - "Purchase token not found" 또는 인증 에러

**테스트 2: 파라미터 누락 테스트**
```bash
curl -i --location --request POST 'http://localhost:54321/functions/v1/verify-purchase' ^
  --header "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\"}"
```

**예상 결과**: 400 에러 - "Missing required parameters"

---

### 🧪 2. Flutter 앱에서 테스트 모드로 테스트

**목적**: 실제 구매 없이 서버 검증 흐름 확인

#### 2.1 디버그 화면에서 테스트 구독 활성화

1. 앱 실행
2. **설정 > 디버그 정보** 이동
3. "테스트: 프리미엄 활성화" 버튼 클릭
4. Supabase 프로필이 업데이트되는지 확인

**검증 포인트**:
- 로컬 DB에 구독 정보 저장됨
- Supabase `profiles` 테이블에서 `membership_tier = 'premium'` 확인
- `membership_expires_at`이 30일 후로 설정됨

#### 2.2 로그 확인
```dart
// Flutter 콘솔에서 확인할 로그:
// ✅ "Supabase 멤버십 동기화 완료: premium"
// ✅ "테스트 프리미엄 구독 활성화: 2025-XX-XX까지"
```

---

### 🛒 3. Google Play Console 테스트 계정으로 실제 구매 테스트

**목적**: 실제 구매 플로우에서 서버 검증까지 전체 흐름 테스트

#### 3.1 사전 준비

1. **Google Play Console 설정**:
   - [SUBSCRIPTION_SETUP.md](SUBSCRIPTION_SETUP.md) 1~2단계 완료
   - 구독 상품(`bizplan_monthly_subscription`) 생성 및 활성화
   - 테스트 계정 추가 (Setup > License testing)

2. **Google Cloud 설정**:
   - [SUBSCRIPTION_SETUP.md](SUBSCRIPTION_SETUP.md) 2단계 완료
   - 서비스 계정 생성 및 키 다운로드
   - Google Play Android Developer API 활성화

3. **Supabase 설정**:
   - Edge Function 배포
   - Secrets 설정 (GOOGLE_SERVICE_ACCOUNT_EMAIL, GOOGLE_PRIVATE_KEY)

#### 3.2 Edge Function 배포
```bash
# Supabase 프로젝트 연결
supabase link --project-ref YOUR_PROJECT_REF

# Edge Function 배포
supabase functions deploy verify-purchase

# 배포 확인
supabase functions list
```

#### 3.3 APK 빌드 및 설치
```bash
# 디버그 빌드 (테스트용)
flutter build apk --debug

# 에뮬레이터 또는 실제 기기에 설치
adb install build/app/outputs/flutter-apk/app-debug.apk
```

**중요**: Google Play Console에 업로드하지 않고 직접 설치하는 경우, 인앱 구매가 작동하지 않을 수 있습니다. 내부 테스트 트랙에 업로드하는 것을 권장합니다.

#### 3.4 내부 테스트 트랙 사용 (권장)

```bash
# App Bundle 빌드
flutter build appbundle --release

# Google Play Console > Release > Testing > Internal testing
# - App Bundle 업로드
# - 테스트 계정 이메일 추가
# - 테스트 링크로 앱 설치
```

#### 3.5 구매 테스트 실행

1. 테스트 계정으로 기기 로그인
2. Play Store에서 내부 테스트 앱 설치
3. 앱 실행 > Supabase 로그인
4. **멤버십 관리** > **프리미엄 구독하기** 클릭
5. Google Play 결제 화면에서 테스트 구매 진행

**테스트 계정의 경우**: "테스트 결제 - 실제 청구 없음" 메시지 표시

#### 3.6 검증 포인트

**Flutter 로그 확인**:
```
✅ 구매 상태: PurchaseStatus.purchased
✅ 서버 검증 중...
✅ 구독 저장 완료 (서버 검증됨): 2025-XX-XX ~ 2025-XX-XX
✅ Supabase 멤버십 동기화 완료: premium
```

**Supabase Dashboard 확인**:
1. **Database > profiles 테이블**:
   - `membership_tier`: `'premium'`
   - `membership_expires_at`: 1개월 후 날짜
   - `updated_at`: 방금 시간

2. **Edge Functions > Logs**:
   ```bash
   supabase functions logs verify-purchase --tail
   ```
   - 검증 요청 로그 확인
   - Google API 호출 로그 확인
   - 성공/실패 로그 확인

**로컬 DB 확인** (디버그 화면에서):
- 구독 정보가 `subscriptions` 테이블에 저장됨
- `is_active = 1`, `status = 'active'`
- `expiry_date`가 올바른 날짜로 설정됨

---

### 🔍 4. 구매 복원 테스트

**목적**: 다른 기기 또는 재설치 후 구독 복원 확인

#### 4.1 시나리오 1: 앱 재설치

1. 앱 삭제
2. 앱 재설치
3. 같은 계정으로 로그인 (Supabase + Google Play)
4. **멤버십 관리** > **구매 복원** 클릭
5. 구독이 복원되는지 확인

#### 4.2 시나리오 2: 다른 기기

1. 다른 기기에서 앱 설치
2. 같은 Google Play 계정 로그인
3. Supabase 로그인
4. **구매 복원** 클릭
5. 서버 검증 후 구독 복원 확인

#### 4.3 검증 포인트

**Flutter 로그**:
```
✅ 구매 상태: PurchaseStatus.restored
✅ 서버 검증 중...
✅ 구독 저장 완료 (서버 검증됨)
✅ Supabase에서 멤버십 정보 로드 완료
```

---

### 🚨 5. 에러 시나리오 테스트

#### 5.1 잘못된 서비스 계정 테스트

**Supabase Dashboard**에서 `GOOGLE_PRIVATE_KEY`를 임의의 값으로 변경:
```bash
GOOGLE_PRIVATE_KEY="invalid-key"
```

**예상 결과**:
- Edge Function 로그: "Invalid grant" 또는 "Failed to create JWT"
- Flutter 로그: "구매 검증 실패: Server configuration error"
- 사용자에게 에러 다이얼로그 표시

#### 5.2 네트워크 끊김 테스트

1. 비행기 모드 활성화
2. 구매 시도
3. 예상 결과: "네트워크 연결을 확인하세요" 메시지

#### 5.3 만료된 구독 테스트

**디버그 화면**에서:
1. "테스트: 만료된 구독" 버튼 클릭
2. 멤버십 화면에서 "만료됨" 상태 확인
3. 프리미엄 기능 접근 시 차단 확인

---

### 📊 6. 프로덕션 환경 모니터링

#### 6.1 Supabase Edge Function 로그

```bash
# 실시간 로그 확인
supabase functions logs verify-purchase --tail

# 최근 100개 로그 확인
supabase functions logs verify-purchase --limit 100
```

**확인 사항**:
- 검증 요청 빈도
- 성공/실패 비율
- Google API 에러 발생 여부

#### 6.2 Google Play Console 모니터링

1. **Monetize > Subscriptions > Dashboard**:
   - 활성 구독자 수
   - 신규 구독자 수
   - 취소율

2. **Orders**:
   - 개별 주문 내역
   - 환불 요청 확인

#### 6.3 Supabase Database 모니터링

정기적으로 실행할 SQL 쿼리:

```sql
-- 활성 프리미엄 회원 수
SELECT COUNT(*)
FROM profiles
WHERE membership_tier = 'premium'
  AND membership_expires_at > NOW();

-- 만료 예정 회원 (7일 이내)
SELECT email, membership_expires_at
FROM profiles
WHERE membership_tier = 'premium'
  AND membership_expires_at BETWEEN NOW() AND NOW() + INTERVAL '7 days'
ORDER BY membership_expires_at;

-- 최근 24시간 구독 변경
SELECT email, membership_tier, membership_expires_at, updated_at
FROM profiles
WHERE updated_at > NOW() - INTERVAL '24 hours'
ORDER BY updated_at DESC;
```

---

## 체크리스트

### 개발 단계
- [ ] 로컬 Edge Function 테스트 완료
- [ ] 환경 변수 올바르게 설정
- [ ] Google API 인증 성공 확인
- [ ] Flutter 앱에서 테스트 모드 동작 확인

### 베타 테스트 단계
- [ ] Google Play Console 테스트 계정 설정
- [ ] 내부 테스트 트랙에 앱 업로드
- [ ] 테스트 계정으로 실제 구매 테스트
- [ ] 서버 검증 로그 확인
- [ ] 구매 복원 기능 테스트
- [ ] 에러 시나리오 테스트

### 프로덕션 배포 전
- [ ] Supabase Secrets 프로덕션 환경에 설정
- [ ] Edge Function 프로덕션 배포
- [ ] Google Play Console 서비스 계정 권한 확인
- [ ] 릴리스 빌드로 최종 테스트
- [ ] 모니터링 쿼리 및 알림 설정

---

## 트러블슈팅

### 문제: "Invalid grant" 에러
**원인**: Private Key가 잘못되었거나 서비스 계정 이메일이 틀림
**해결**:
1. JSON 키 파일에서 `private_key` 값을 정확히 복사
2. `\n`을 실제 줄바꿈으로 변경하지 마세요
3. 서비스 계정 이메일이 정확한지 확인

### 문제: "Insufficient permissions" 에러
**원인**: Google Play Console에서 권한이 부여되지 않음
**해결**:
1. Play Console > Users and permissions
2. 서비스 계정 이메일 확인
3. "View financial data, orders..." 권한 확인
4. 초대를 수락했는지 확인

### 문제: 구매는 성공했지만 서버 검증 실패
**원인**: Edge Function 또는 Supabase 연결 문제
**해결**:
1. Edge Function 로그 확인: `supabase functions logs verify-purchase`
2. Supabase 프로젝트가 활성 상태인지 확인
3. Flutter 앱의 Supabase 초기화 확인

### 문제: 테스트 구매가 실제 결제됨
**원인**: 테스트 계정이 아닌 실제 계정 사용
**해결**:
1. Google Play Console > Setup > License testing
2. 테스트 Gmail 계정 추가 확인
3. 기기에서 테스트 계정으로 로그인 확인

---

## 참고 문서

- [SUBSCRIPTION_SETUP.md](SUBSCRIPTION_SETUP.md) - 전체 시스템 설정 가이드
- [supabase/functions/verify-purchase/SETUP.md](supabase/functions/verify-purchase/SETUP.md) - Edge Function 설정
- [Google Play Billing 테스트](https://developer.android.com/google/play/billing/test)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
