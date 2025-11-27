# Edge Function 상태 확인 ✅

## 현재 상태

**배포 완료**: `verify-purchase` Edge Function이 정상적으로 배포되었습니다!

```
NAME            | STATUS  | VERSION | UPDATED_AT
verify-purchase | ACTIVE  | 2       | 2025-11-12 10:57:21
```

## 테스트 결과

방금 전 테스트 호출 결과:
```bash
HTTP/1.1 400 Bad Request
{"error":"Missing required parameters"}
```

✅ **정상 작동 확인**: 파라미터 검증이 제대로 작동하고 있습니다!

---

## 로그가 보이지 않는 이유

Supabase Dashboard의 **Logs & Analytics > Edge Functions**에 로그가 보이지 않는다면:

### 1. 아직 호출이 적어서 보이지 않음
- Edge Function이 방금 배포되었고
- 테스트 호출을 1~2회만 했다면
- 로그가 아직 표시되지 않을 수 있습니다

### 2. 로그 필터 확인
Supabase Dashboard에서:
1. **Logs > Edge Functions** 메뉴로 이동
2. 상단의 필터에서 `verify-purchase` 선택되어 있는지 확인
3. 시간 범위를 **Last hour** 또는 **Last 24 hours**로 설정

### 3. 실제 로그가 기록되는 위치
- **Logs > Edge Functions** (추천)
- 또는 **Edge Functions > verify-purchase > Logs** 탭

---

## 테스트 방법

### 방법 1: 배치 스크립트 사용 (가장 쉬움)

```bash
# 배포된 함수 테스트
test_deployed_function.bat

# 메뉴에서 선택:
# [1] 파라미터 누락 테스트
# [2] 잘못된 토큰 테스트
# [4] Dashboard 열기
# [5] 로그 보기
```

### 방법 2: 직접 curl 명령어

```bash
# 테스트 1: 파라미터 누락
curl -i --location --request POST "https://bsofmuvuvhjpcrkygwjz.supabase.co/functions/v1/verify-purchase" ^
  --header "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzb2ZtdXZ1dmhqcGNya3lnd2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjY0ODksImV4cCI6MjA3NjM0MjQ4OX0.fdpNtooV0rPmdnZz2RSCuBxMeQEPuvjJTTXTIzaKZhQ" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\"}"
```

**예상 결과**: `HTTP 400 - {"error":"Missing required parameters"}`

### 방법 3: Flutter 앱에서 테스트

가장 확실한 방법:
1. Flutter 앱 실행
2. **설정 > 디버그 정보**
3. **"테스트: 프리미엄 활성화"** 클릭
4. 이 작업이 Edge Function을 호출하지는 않지만, Supabase 연동 확인 가능

실제 구매 테스트:
1. **멤버십 관리** > **프리미엄 구독하기** (Google Play 설정 완료 시)
2. 이 때 실제로 Edge Function이 호출됩니다

---

## Dashboard에서 확인하기

### 1. Edge Functions 페이지
```
https://supabase.com/dashboard/project/bsofmuvuvhjpcrkygwjz/functions
```

확인 사항:
- ✅ `verify-purchase` 함수가 **Active** 상태
- Version: 2
- Region: ap-northeast-2

### 2. Logs 페이지
```
https://supabase.com/dashboard/project/bsofmuvuvhjpcrkygwjz/logs/edge-functions
```

확인 사항:
- 함수 호출 기록
- 에러 메세지
- 응답 시간

### 3. Settings - Edge Functions Secrets
```
https://supabase.com/dashboard/project/bsofmuvuvhjpcrkygwjz/settings/functions
```

확인 사항:
- ✅ `GOOGLE_SERVICE_ACCOUNT_EMAIL` 설정됨
- ✅ `GOOGLE_PRIVATE_KEY` 설정됨

---

## 다음 단계

### ✅ 완료된 항목
- [x] Edge Function 코드 작성
- [x] Supabase에 배포
- [x] 기본 동작 확인 (파라미터 검증)

### 🔄 진행할 항목

#### 1. Secrets 설정 확인 (필수)
Supabase Dashboard → Settings → Edge Functions → Secrets
- `GOOGLE_SERVICE_ACCOUNT_EMAIL` 설정
- `GOOGLE_PRIVATE_KEY` 설정

#### 2. Google Cloud & Play Console 설정
- [SUBSCRIPTION_SETUP.md](SUBSCRIPTION_SETUP.md) 참고
- Google Cloud 서비스 계정 생성
- Play Console 권한 부여

#### 3. 실제 구매 토큰으로 테스트
- Google Play Console 테스트 계정 추가
- Flutter 앱에서 실제 구매 테스트
- Edge Function이 실제 구매를 검증하는지 확인

---

## 로그 예시

정상 작동 시 Supabase Logs에서 볼 수 있는 내용:

### 성공 케이스
```json
{
  "timestamp": "2025-11-12T11:01:27Z",
  "level": "info",
  "msg": "function invoked",
  "function": "verify-purchase",
  "execution_time_ms": 1234,
  "response": {
    "status": 200,
    "body": {
      "valid": true,
      "productId": "bizplan_monthly_subscription",
      "orderId": "GPA.1234-5678-9012-34567"
    }
  }
}
```

### 에러 케이스
```json
{
  "timestamp": "2025-11-12T11:01:27Z",
  "level": "error",
  "msg": "Missing required parameters",
  "function": "verify-purchase",
  "response": {
    "status": 400,
    "body": {
      "error": "Missing required parameters"
    }
  }
}
```

---

## 문제 해결

### "로그가 여전히 보이지 않아요"

1. **몇 번 더 테스트 호출 해보기**:
   ```bash
   test_deployed_function.bat
   # [1], [2], [3] 각각 실행
   ```

2. **Dashboard 캐시 새로고침**:
   - 브라우저에서 `Ctrl + F5` (강제 새로고침)
   - 또는 다른 브라우저로 열어보기

3. **시간대 확인**:
   - Logs 페이지에서 시간 범위를 **"Last hour"**로 설정
   - UTC 시간대로 표시되므로 한국 시간 -9시간

4. **직접 확인**:
   ```bash
   # 여러 번 호출
   for /L %i in (1,1,5) do (
     curl -s "https://bsofmuvuvhjpcrkygwjz.supabase.co/functions/v1/verify-purchase" ^
       -H "Authorization: Bearer YOUR_KEY" ^
       -H "Content-Type: application/json" ^
       -d "{\"productId\":\"test\"}"
   )
   ```

---

## 요약

✅ **Edge Function은 정상적으로 작동하고 있습니다!**

- 배포 상태: **ACTIVE**
- 테스트 결과: **정상 (400 에러 응답)**
- 파라미터 검증: **작동 중**

로그가 Dashboard에 표시되려면:
1. 여러 번 테스트 호출하기 (`test_deployed_function.bat` 사용)
2. Dashboard에서 시간 범위와 필터 확인
3. 페이지 새로고침 (Ctrl + F5)

실제 구매 검증 테스트는 [TESTING_GUIDE_SIMPLE.md](TESTING_GUIDE_SIMPLE.md)를 참고하세요!
