# 간단한 서버 측 검증 테스트 가이드 (Docker 불필요)

## 🚀 빠른 배포 및 테스트 (권장)

Docker 설치 없이 바로 Supabase에 배포하고 테스트하는 방법입니다.

### 1단계: Supabase 프로젝트 연결

```bash
# Supabase 로그인
supabase login

# 프로젝트 연결 (브라우저에서 프로젝트 선택)
cd d:\MyApp\bizPlan
supabase link
```

프로젝트 REF를 모르는 경우:
- Supabase Dashboard → Project Settings → General → Reference ID

### 2단계: Supabase Secrets 설정

Supabase Dashboard에서 설정:

1. **Project Settings > Edge Functions** 메뉴
2. **Secrets** 섹션에서 추가:

```bash
GOOGLE_SERVICE_ACCOUNT_EMAIL
값: bizplan-purchase-verifier@bizplan-478009.iam.gserviceaccount.com

GOOGLE_PRIVATE_KEY
값: (아래 Private Key 전체 복사)
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDkc4bFerxjoM/g
z1RJBcI21ZY7NsxKCEMYzjIMwz2ZFaYPkCaEH4RSCUpm2YmJLjKbNqZgRag/bhaH
sk76qzE5NAvCFlCk64Ee07fLhPmZ8lt0PMXWmAMi1e82NLDErDJlmYGM/iqNHQxz
ZbWKsTInxzSq0p08DvUGuqPc9iQCwllwZ3CYF7ixCMrN92nUKR7OPjGenD4TRNeL
hEpTmKxT9DuZ3DlBE6DgQt/iAv0h+jTv8EAwL3YEU6/CB7ZOM746TIzPPEwkk/OS
byH+vzlMHsTSYKystRxzKknzAVF2Bw7vxGpAHN8KoTmE9RD98ER5GiVYXBTyFDaF
lAxfUPJtAgMBAAECggEAG+BQ+LXyWQHde+Qwt7xhJ4nGjDEymnIJpfQ7PT1xvcVb
fxiq6oJiBhSmJIi09K1TdYckpCi70Amh7CsA4iuTlRRZvvQ0IPuvxNA25Dm0r2lY
aYWk6nugHlcWmnmxfD465BToLwkwrgl2ZHprvaHDqgDv10xd7V8x3QFXT3YljMRp
Wbjpx1xgzakqNaQpYWc9dWQl7n57jwnpZb02MCX37QQuhlH3cp5XPILUH48l1T4a
68ckFGNXnhEtYB1u2fyLeaeUfQsNaUh8dpWHS1JeiPzQ75Zp3+fwDp468mVrKkA7
LB23K0o/G2CaeC5g1516mf9yhJZk3zCM2hnIbNVL4QKBgQD0apePQkn49Dfr5SGM
sS91cKEVsqF8lwsFhbrbkad2ra7ZnoY66BdlQgMLSw1+qRl1wsTffkC0t5fRThKQ
to0o38GYeZNoFj0k+Kd1uKobUzSKYsV5tXjMa5e23dBBDIbRkPpYfexoKK9EHIMT
MrmKNKprnDvCn5fiNiz+JFsreQKBgQDvRzxy6sAjfFhA77z1MQpohWrO0PrqBxxj
LRwvnk7Pb4btDtDEWumrqjhBWqPBPJnuVXh3mUUXXe5OQvQPPA07K2Mor7EzDQem
Q2lu+b6gDsSVqEGdXQou2Ov/fMVTZE1kIC1s7bZbntNDlpRW6lnm4HYchdYy9rnK
gnkwhweNlQKBgQCH0KdRStOSDBr68QLYjCjECIbqaK2FbuUH94yir+gvcUmk0Yrj
Ns6xTKImZ1kjVdG49zawvhY0lYQ+ITT9xwLfgJ6yHHSFtT3aynU7XBbiQjUC5Om4
vNdYOD1Atzcevlg4IWiLPcXdByaFIZbQVzJ0ktlUHKe0eTxLzjDoM8mZeQKBgQDE
tQZv3qcIRS/0amIoHCHXXV86GLk97Yybx7j1OKrHg4MjnVtpIOgatPw8VfxrXpuZ
QHChucH//LttYUNsxsyFyRxilVUSh/Ky75ZcojnhMWLROZp/eL5nVvNkfLln3fx1
hLJza1TQK1i4prDaZxxzXjIbLrex+/0vC2X/y/IcpQKBgQCpjlfiyeV6VQOSWK7Y
OPpGS9ovqIMGsbOcuzQonmBy99sM/wfo3RCQ7vcJkr8E1MxHMRpnah9KMKqu+0YM
HqWw6lwFlnPuK+Kxnd9KVX7EOQwh5pvPBscnybQoQBY2NF41rxpkQ5ZBxwrLN9Mq
r/3Rq5hyvX8vQX803mXKJUiWmg==
-----END PRIVATE KEY-----
```

**중요**: Private Key는 `\n`을 포함한 **전체 내용을 그대로** 복사하세요.

### 3단계: Edge Function 배포

```bash
cd d:\MyApp\bizPlan

# 배포
supabase functions deploy verify-purchase

# 배포 확인
supabase functions list
```

**예상 결과**:
```
┌──────────────────┬────────┬─────────┬──────────────────────┐
│      NAME        │ STATUS │ VERSION │     CREATED AT       │
├──────────────────┼────────┼─────────┼──────────────────────┤
│ verify-purchase  │ ACTIVE │    1    │ 2025-01-XX XX:XX:XX │
└──────────────────┴────────┴─────────┴──────────────────────┘
```

### 4단계: 배포된 함수 테스트

#### 테스트 1: 잘못된 파라미터로 에러 테스트

```bash
# Supabase Anon Key 가져오기 (Dashboard → Project Settings → API)
set SUPABASE_URL=https://your-project-ref.supabase.co
set SUPABASE_ANON_KEY=your-anon-key

# 테스트 요청
curl -i --location --request POST "%SUPABASE_URL%/functions/v1/verify-purchase" ^
  --header "Authorization: Bearer %SUPABASE_ANON_KEY%" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\"}"
```

**예상 결과**: 400 에러 - "Missing required parameters"

#### 테스트 2: 잘못된 토큰으로 Google API 에러 테스트

```bash
curl -i --location --request POST "%SUPABASE_URL%/functions/v1/verify-purchase" ^
  --header "Authorization: Bearer %SUPABASE_ANON_KEY%" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\",\"purchaseToken\":\"invalid-token-12345\",\"packageName\":\"com.vividlife.bizplan\"}"
```

**예상 결과**: Google API 에러 (400) - "Purchase verification failed"

### 5단계: 로그 확인

```bash
# Edge Function 로그 확인
supabase functions logs verify-purchase --tail
```

또는 Supabase Dashboard에서:
- **Edge Functions > verify-purchase > Logs**

---

## 📱 Flutter 앱에서 테스트

이제 Edge Function이 배포되었으니, 앱에서 바로 테스트할 수 있습니다.

### 테스트 모드로 빠른 테스트

1. Flutter 앱 실행
2. **설정 > 디버그 정보**
3. **"테스트: 프리미엄 활성화"** 클릭
4. Supabase Dashboard에서 확인:
   - **Database > profiles** 테이블
   - `membership_tier = 'premium'` 확인

### 실제 구매 흐름 테스트 (선택)

Google Play Console 설정이 완료된 경우:
1. 앱에서 **멤버십 관리** > **프리미엄 구독하기**
2. 구매 진행
3. 서버 검증 자동 실행
4. 로그와 DB 확인

---

## 🔍 문제 해결

### 에러: "Missing Google service account credentials"

**원인**: Supabase Secrets가 제대로 설정되지 않음

**해결**:
1. Supabase Dashboard → Project Settings → Edge Functions → Secrets
2. `GOOGLE_SERVICE_ACCOUNT_EMAIL`과 `GOOGLE_PRIVATE_KEY` 재확인
3. Private Key에 `\n`이 포함되어 있는지 확인

### 에러: "Invalid grant" 또는 "Failed to create JWT"

**원인**: Private Key가 잘못됨

**해결**:
1. Google Cloud Console에서 서비스 계정 키 재다운로드
2. JSON 파일의 `private_key` 값을 **정확히** 복사
3. Supabase Secrets에 다시 설정

### 에러: "The current user has insufficient permissions"

**원인**: Google Play Console에서 서비스 계정 권한 미부여

**해결**:
1. [SUBSCRIPTION_SETUP.md](SUBSCRIPTION_SETUP.md) 2.4단계 참고
2. Play Console → Users and permissions
3. 서비스 계정에 "View financial data" 권한 부여

---

## 💡 Docker를 사용하려는 경우

로컬에서 테스트하고 싶다면:

### Docker Desktop 설치

1. [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) 다운로드
2. 설치 후 Docker Desktop 실행
3. 시스템 트레이에서 Docker 아이콘 확인 (실행 중)
4. 다시 명령어 실행:

```bash
supabase functions serve verify-purchase --env-file ./supabase/.env.local --no-verify-jwt
```

---

## 📊 배포 확인 체크리스트

- [ ] `supabase link` 완료
- [ ] Supabase Secrets 설정 (GOOGLE_SERVICE_ACCOUNT_EMAIL, GOOGLE_PRIVATE_KEY)
- [ ] `supabase functions deploy verify-purchase` 성공
- [ ] `supabase functions list`에서 ACTIVE 상태 확인
- [ ] curl로 테스트 요청 성공 (400 에러라도 함수 실행됨)
- [ ] `supabase functions logs verify-purchase`에서 로그 확인
- [ ] Flutter 앱의 테스트 모드로 Supabase 동기화 확인

---

## 다음 단계

✅ Edge Function 배포 완료 후:
1. Google Play Console에서 구독 상품 생성 ([SUBSCRIPTION_SETUP.md](SUBSCRIPTION_SETUP.md) 참고)
2. 테스트 계정 추가
3. Flutter 앱에서 실제 구매 테스트
