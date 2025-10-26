# Extract Schedule Edge Function

이 Edge Function은 텍스트에서 스케줄 정보를 추출하기 위해 Gemini API를 안전하게 호출합니다.

## 배포 방법

### 1. Supabase CLI 설치

**Windows (권장: Scoop 사용)**

```powershell
# Scoop 설치 (PowerShell 관리자 권한)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Supabase CLI 설치
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

**Windows (직접 다운로드)**

1. https://github.com/supabase/cli/releases 접속
2. 최신 버전의 `supabase_windows_amd64.zip` 다운로드
3. 압축 해제 후 `supabase.exe`를 원하는 폴더에 저장
4. 시스템 환경 변수 PATH에 해당 폴더 경로 추가

**macOS/Linux**

```bash
# Homebrew (macOS)
brew install supabase/tap/supabase

# Linux (APT)
wget -qO - https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz | tar xz
sudo mv supabase /usr/local/bin/
```

### 2. Supabase 프로젝트 연결

```bash
# 프로젝트 루트에서 실행
cd d:\MyApp\bizPlan

# Supabase 로그인
supabase login

# 프로젝트 연결
supabase link --project-ref <YOUR_PROJECT_REF>
```

프로젝트 REF는 Supabase Dashboard의 Project Settings > General > Reference ID에서 확인할 수 있습니다.

### 3. Gemini API 키 설정

Supabase Dashboard에서:
1. Project Settings > Edge Functions > Secrets 이동
2. 새 secret 추가:
   - Name: `GEMINI_API_KEY`
   - Value: `YOUR_GEMINI_API_KEY`

또는 CLI로 설정:

```bash
supabase secrets set GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

### 4. Edge Function 배포

```bash
# extract-schedule 함수 배포
supabase functions deploy extract-schedule
```

### 5. 함수 테스트

```bash
# 로컬 테스트
supabase functions serve extract-schedule

# 다른 터미널에서 테스트 요청
curl -i --location --request POST 'http://localhost:54321/functions/v1/extract-schedule' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"text":"홍길동 010-1234-5678 서울시 강남구 2025-10-26 14:00"}'
```

## API 사용법

### 요청

```typescript
POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/extract-schedule

Headers:
  - Authorization: Bearer YOUR_ANON_KEY
  - Content-Type: application/json

Body:
{
  "text": "추출할 텍스트"
}
```

### 응답

**성공:**
```json
{
  "data": {
    "name": "홍길동",
    "phone": "01012345678",
    "address": "서울시 강남구 테헤란로 123",
    "date": "2025-10-26",
    "time": "14:00"
  }
}
```

**실패:**
```json
{
  "error": "오류 메시지"
}
```

## Flutter 클라이언트에서 사용

`lib/utils/gemini_helper.dart` 파일이 자동으로 이 Edge Function을 호출하도록 구성되어 있습니다.

```dart
final result = await GeminiHelper.extractScheduleInfo("텍스트");
if (result != null) {
  print(result['name']);
  print(result['phone']);
  // ...
}
```

## 보안

- ✅ Gemini API 키가 클라이언트 코드에 노출되지 않음
- ✅ Supabase Edge Function의 환경 변수로 안전하게 관리
- ✅ CORS 설정으로 허용된 도메인에서만 접근 가능

## 문제 해결

### "GEMINI_API_KEY가 설정되지 않았습니다" 오류

```bash
# Secret이 제대로 설정되었는지 확인
supabase secrets list

# Secret 다시 설정
supabase secrets set GEMINI_API_KEY=YOUR_API_KEY

# 함수 재배포
supabase functions deploy extract-schedule
```

### 함수 로그 확인

```bash
# 실시간 로그 확인
supabase functions logs extract-schedule --tail
```

## 비용 절감 팁

- Gemini 2.0 Flash Exp 모델 사용 (무료 할당량 제공)
- Edge Function은 호출 시에만 비용 발생 (유휴 시간 비용 없음)
- Supabase Edge Functions: 월 500K 요청까지 무료
