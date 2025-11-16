# Firebase Analytics 설정 가이드

이 앱은 Firebase Analytics를 사용하여 사용자 행동 데이터를 수집합니다.

## 🔥 Firebase 프로젝트 설정

### 1. Firebase 콘솔에서 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/)에 접속
2. "프로젝트 추가" 클릭
3. 프로젝트 이름: `bizplan-app-2025` (또는 원하는 이름)
4. Google Analytics 사용 설정: **예**
5. 프로젝트 생성 완료

### 2. Android 앱 추가

1. Firebase 콘솔에서 "Android" 아이콘 클릭
2. Android 패키지 이름: `com.vividlife.bizplan`
3. 앱 닉네임: BizPlan (선택사항)
4. SHA-1 인증서 지문: (선택사항, 나중에 추가 가능)
   ```bash
   # Debug 키 SHA-1 확인 (Windows)
   cd android
   ./gradlew signingReport
   ```
5. **google-services.json 다운로드**
6. 다운로드한 파일을 `android/app/` 폴더에 복사

### 3. FlutterFire CLI 설치 및 설정

```bash
# FlutterFire CLI 설치
dart pub global activate flutterfire_cli

# Firebase 프로젝트 설정
flutterfire configure --project=bizplan-app-2025
```

이 명령어가:
- `lib/firebase_options.dart` 파일을 자동 생성
- 모든 플랫폼 설정 자동 구성

### 4. 확인

앱을 실행하면 다음 로그가 표시되어야 합니다:
```
✅ Firebase initialized
```

만약 실패하면:
```
⚠️ Firebase initialization failed
```

## 📊 수집되는 Analytics 이벤트

### 자동 수집
- 화면 조회 (screen_view)
- 앱 시작 (app_open)
- 앱 업데이트 (app_update)
- 첫 오픈 (first_open)

### 커스텀 이벤트

#### 인증
- `sign_up` - 회원가입 (email/google/kakao)
- `login` - 로그인 (email/google/kakao)

#### 스케줄
- `schedule_created` - 스케줄 생성
- `schedule_updated` - 스케줄 수정
- `schedule_deleted` - 스케줄 삭제

#### 업체
- `company_created` - 업체 추가
- `company_updated` - 업체 수정
- `company_deleted` - 업체 삭제

#### 멤버십
- `view_membership` - 멤버십 화면 조회
- `purchase_initiated` - 구독 시작
- `purchase` - 구독 완료
- `free_limit_reached` - 무료 사용자 제한 도달

#### 백업/복구
- `backup_created` - 백업 생성
- `restore_completed` - 복구 완료

#### 기타
- `feature_used` - 기능 사용
- `app_error` - 앱 오류

## 🔍 Analytics 데이터 확인

1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 선택
3. 좌측 메뉴에서 "Analytics" → "이벤트" 클릭
4. 실시간 데이터는 "DebugView"에서 확인 가능

### DebugView 활성화 (개발 중)

```bash
# Android
adb shell setprop debug.firebase.analytics.app com.vividlife.bizplan
adb shell setprop log.tag.FA VERBOSE
adb shell setprop log.tag.FA-SVC VERBOSE

# 비활성화
adb shell setprop debug.firebase.analytics.app .none.
```

## ⚠️ 주의사항

- **프로덕션**: Firebase Analytics는 자동으로 수집을 시작합니다
- **개인정보**: 사용자 식별 정보는 수집하지 않습니다
- **GDPR**: 필요시 Analytics 비활성화 옵션 추가 가능

## 📱 Firebase 설정 파일 위치

```
android/app/google-services.json  ← 여기에 파일 복사
lib/firebase_options.dart          ← flutterfire configure로 자동 생성
```

## 🚫 문제 해결

### google-services.json 오류
```
File google-services.json is missing
```
→ Firebase Console에서 다운로드하여 `android/app/` 에 복사

### Firebase 초기화 실패
```
⚠️ Firebase initialization failed
```
→ `flutterfire configure` 다시 실행

### Analytics 데이터가 표시되지 않음
- 실시간 데이터는 24시간 이내에 표시됨
- DebugView를 활성화하여 즉시 확인 가능
