# Gemini API 키 보안 관리 가이드

Flutter 앱에서 Gemini API 키를 안전하게 사용하는 여러 가지 방법을 비교합니다.

## 📊 옵션 비교표

| 방법 | 보안 수준 | 구현 난이도 | 비용 | 권장도 |
|------|----------|------------|------|--------|
| **Supabase Edge Functions** | ⭐⭐⭐⭐⭐ 최고 | 중간 | 무료* | ✅ 권장 |
| **Flutter .env + gitignore** | ⭐⭐⭐ 중간 | 쉬움 | 무료 | ⚠️ 개발용 |
| **Native 암호화 저장** | ⭐⭐⭐⭐ 높음 | 어려움 | 무료 | 개인 앱용 |
| **직접 하드코딩** | ⭐ 매우 낮음 | 매우 쉬움 | 무료 | ❌ 절대 비권장 |

*Supabase 무료 플랜: 월 500K Edge Function 호출

---

## 방법 1: Supabase Edge Functions (현재 구현) ⭐ 권장

### 장점
- ✅ **완전한 보안**: API 키가 클라이언트에 절대 노출되지 않음
- ✅ **키 변경 용이**: 앱 재배포 없이 서버에서만 변경
- ✅ **사용량 제어**: 서버에서 rate limiting 가능
- ✅ **추가 검증**: 사용자 인증, 권한 체크 등 추가 가능

### 단점
- ⚠️ 초기 설정 필요 (Supabase CLI)
- ⚠️ 네트워크 레이턴시 약간 증가 (보통 100-300ms)

### 사용 방법

이미 구현되어 있습니다!

```dart
// lib/utils/gemini_helper.dart
final result = await GeminiHelper.extractScheduleInfo("텍스트");
```

내부적으로 Supabase Edge Function을 호출합니다.

**배포 방법**: `supabase/functions/extract-schedule/README.md` 참조

---

## 방법 2: Flutter .env 파일 (개발/테스트용)

### 장점
- ✅ 구현이 간단함
- ✅ Git에 키가 올라가지 않음
- ✅ 직접 Gemini API 호출 (빠름)

### 단점
- ⚠️ APK/IPA 디컴파일 시 키 노출 가능
- ⚠️ 키 변경 시 앱 재배포 필요
- ⚠️ 사용량 제어 불가능

### 구현 방법

#### 1. 패키지 추가

`pubspec.yaml`:
```yaml
dependencies:
  flutter_dotenv: ^5.1.0
  google_generative_ai: ^0.2.0
```

#### 2. .env 파일 생성

프로젝트 루트에 `.env` 파일:
```
GEMINI_API_KEY=AIzaSyDc0CX4HQZac4RxKuWJSEgSed68tZ7CfyU
```

#### 3. pubspec.yaml에 등록

```yaml
flutter:
  assets:
    - .env
```

#### 4. 코드에서 사용

```dart
// lib/utils/gemini_helper_local.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiHelperLocal {
  static Future<void> init() async {
    await dotenv.load(fileName: ".env");
  }

  static Future<Map<String, dynamic>?> extractScheduleInfo(String text) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null) {
      print('GEMINI_API_KEY가 설정되지 않았습니다');
      return null;
    }

    final model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey,
    );

    // ... Gemini API 호출 로직
  }
}
```

#### 5. main.dart에서 초기화

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GeminiHelperLocal.init(); // .env 로드
  runApp(MyApp());
}
```

#### 6. .gitignore 확인

`.gitignore`에 이미 추가되어 있습니다:
```
.env
.env.local
*.env
```

### ⚠️ 주의사항

- `.env` 파일은 **절대 Git에 커밋하지 마세요**
- `.env.example` 파일로 샘플만 제공
- **프로덕션에는 권장하지 않음** (APK 디컴파일로 노출 가능)

---

## 방법 3: Native 암호화 저장 (고급)

### 개요

Android Keystore / iOS Keychain을 사용하여 API 키를 암호화하여 저장합니다.

### 장점
- ✅ 높은 보안 수준 (OS 레벨 암호화)
- ✅ 디컴파일로도 키 추출 어려움

### 단점
- ⚠️ 구현이 복잡함
- ⚠️ 플랫폼별 코드 필요
- ⚠️ 여전히 앱 내부에 키 존재

### 구현 방법

#### 1. 패키지 추가

```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  google_generative_ai: ^0.2.0
```

#### 2. 첫 실행 시 키 저장

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureApiKeyManager {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'gemini_api_key';

  // 첫 실행 시 또는 키가 없을 때 저장
  static Future<void> setApiKey(String apiKey) async {
    await _storage.write(key: _keyName, value: apiKey);
  }

  // API 키 읽기
  static Future<String?> getApiKey() async {
    return await _storage.read(key: _keyName);
  }
}
```

#### 3. Gemini Helper 수정

```dart
class GeminiHelperSecure {
  static Future<Map<String, dynamic>?> extractScheduleInfo(String text) async {
    final apiKey = await SecureApiKeyManager.getApiKey();

    if (apiKey == null) {
      print('API 키가 저장되지 않았습니다');
      return null;
    }

    final model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey,
    );

    // ... Gemini API 호출
  }
}
```

#### 4. 초기 설정 화면

```dart
// 관리자 설정 화면 등에서
await SecureApiKeyManager.setApiKey('YOUR_API_KEY');
```

### ⚠️ 주의사항

- 초기 키 입력을 어떻게 처리할지 고려 필요
- 루팅/탈옥된 기기에서는 여전히 취약
- **완벽한 보안은 아님** - 서버 측 관리가 가장 안전

---

## 방법 4: 직접 하드코딩 ❌ 절대 비권장

```dart
// ❌ 절대 하지 마세요!
static const String _apiKey = 'AIzaSyDc0CX4HQZac4RxKuWJSEgSed68tZ7CfyU';
```

### 문제점
- ❌ Git 히스토리에 영구 저장
- ❌ APK 디컴파일로 즉시 노출
- ❌ 공개 저장소에 올리면 봇이 자동으로 탐지하여 악용
- ❌ Google이 키를 자동으로 비활성화할 수 있음

---

## 🎯 권장 사항

### 프로덕션 앱 (실제 사용자 대상)
→ **Supabase Edge Functions** 사용 (현재 구현)

### 개인 앱 / 소규모 프로젝트
→ **Flutter Secure Storage** 또는 **.env 파일**

### 개발 / 테스트
→ **.env 파일** (간단하고 빠름)

### 절대 하지 말 것
→ **직접 하드코딩** ❌

---

## 🔄 현재 구현에서 .env로 전환하려면?

현재는 Supabase Edge Functions을 사용 중입니다. 로컬 개발 시 .env를 사용하고 싶다면:

### 1. 환경 변수 추가

```dart
// lib/utils/gemini_helper.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiHelper {
  static bool get useEdgeFunction =>
      dotenv.env['USE_EDGE_FUNCTION'] == 'true';

  static Future<Map<String, dynamic>?> extractScheduleInfo(String text) async {
    if (useEdgeFunction) {
      // Supabase Edge Function 호출 (프로덕션)
      return _callEdgeFunction(text);
    } else {
      // 직접 Gemini API 호출 (개발용)
      return _callGeminiDirectly(text);
    }
  }

  // ... 구현
}
```

### 2. .env 파일

```
USE_EDGE_FUNCTION=false
GEMINI_API_KEY=your_api_key_here
```

### 3. 프로덕션 빌드

```bash
# .env에서 설정
USE_EDGE_FUNCTION=true

# 또는 빌드 시 플래그로
flutter build apk --dart-define=USE_EDGE_FUNCTION=true
```

---

## 📝 결론

**가장 안전한 방법은 Supabase Edge Functions (현재 구현)**입니다.

초기 설정이 조금 번거롭지만, 한 번만 설정하면:
- API 키 완전 보호
- 사용량 모니터링 가능
- 키 변경 시 앱 재배포 불필요
- 추가 보안 기능 구현 가능

개발 편의를 위해 .env를 사용하고 싶다면, **개발 환경에서만** 사용하고 프로덕션에서는 Edge Functions를 사용하는 하이브리드 방식도 좋습니다.
