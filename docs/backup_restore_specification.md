# 백업 및 복구 기능 정의서

## 목차
1. [개요](#개요)
2. [백업 기능](#백업-기능)
3. [복구 기능](#복구-기능)
4. [데이터 구조](#데이터-구조)
5. [보안](#보안)
6. [오류 처리](#오류-처리)
7. [성능 최적화](#성능-최적화)

---

## 개요

### 목적
사용자의 스케줄, 업체, 날짜별 메모 데이터를 안전하게 백업하고 복구할 수 있는 기능을 제공합니다.

### 주요 기능
- 전체 데이터 백업 (JSON 형식)
- 기간별 백업 (특정 날짜 범위의 스케줄만)
- 백업 파일 공유 (문자, 이메일 등)
- 백업 파일 다운로드 (로컬 저장소)
- 백업 파일 복구 (기존 데이터 유지 / 전체 교체)

### 지원 플랫폼
- Android
- iOS
- Windows
- macOS
- Linux
- Web

---

## 백업 기능

### 1. 백업 생성

#### 1.1 전체 백업
**위치**: 설정 > 백업 및 복구 > 백업 생성

**동작 방식**:
```dart
// BackupService.createBackupData()
1. 현재 사용자의 모든 데이터 조회
   - 모든 스케줄 (readAllSchedules)
   - 모든 업체 (readAllCompanies)
   - 모든 날짜별 메모 (readAllMemos)

2. JSON 데이터 생성
   {
     "version": "1.1",
     "exportDate": "2026-01-07T10:30:00.000Z",
     "schedules": [...],
     "companies": [...],
     "memos": [...]
   }

3. 디지털 서명 추가
   - HMAC-SHA256 알고리즘 사용
   - 앱 전용 비밀 키로 서명

4. JSON 파일 생성 및 저장
```

**파일명 형식**:
```
schedule_backup_YYYY-MM-DD_HH-MM-SS.json
예: schedule_backup_2026-01-07_10-30-45.json
```

#### 1.2 기간별 백업
**위치**: 설정 > 백업 및 복구 > 기간별 백업

**동작 방식**:
```dart
// BackupService.createBackupData(startDate, endDate)
1. 날짜 범위 필터링
   - visitDate가 startDate ~ endDate 범위 내인 스케줄만 선택
   - visitDate가 null인 스케줄은 제외

2. 나머지는 전체 백업과 동일
```

**사용 사례**:
- 특정 월/분기의 스케줄만 백업
- 프로젝트별 데이터 분리
- 백업 파일 크기 최소화

### 2. 백업 내보내기

#### 2.1 파일 공유
**위치**: 설정 > 백업 및 복구 > 백업 공유

**동작 방식**:
```dart
// BackupService.shareBackup()
1. 백업 파일 생성 (임시 디렉토리)
2. 시스템 공유 시트 표시
3. 사용자가 공유 방법 선택
   - 문자 메시지
   - 이메일
   - 클라우드 드라이브 (Google Drive, iCloud)
   - 메신저 (카카오톡, 텔레그램 등)
```

**특징**:
- 네이티브 공유 기능 활용 (share_plus 패키지)
- 플랫폼별 최적화된 UI
- 대용량 파일 지원

#### 2.2 파일 다운로드
**위치**: 설정 > 백업 및 복구 > 백업 다운로드

**동작 방식**:
```dart
// BackupService.downloadBackup()
1. 백업 파일 생성
2. 플랫폼별 저장 경로 결정
   - Android: /storage/emulated/0/Download/
   - iOS: Files 앱 접근 가능한 위치
   - Windows/macOS/Linux: ~/Downloads/
   - Web: 브라우저 다운로드

3. 파일 저장
4. 성공 메시지 표시 (저장 경로 포함)
```

**저장 경로**:
- Android: `내 파일 > Downloads > schedule_backup_*.json`
- iOS: `파일 > 다운로드 > schedule_backup_*.json`
- Desktop: `다운로드 폴더`

---

## 복구 기능

### 1. 복구 프로세스

#### 1.1 파일 선택
**위치**: 설정 > 백업 및 복구 > 백업 복구

**동작 방식**:
```dart
// BackupService.pickBackupFile()
1. 파일 선택 다이얼로그 표시
   - 허용 확장자: .json
   - 파일 타입 필터: JSON 파일만

2. 파일 경로 반환
```

**지원 위치**:
- 로컬 저장소
- 클라우드 드라이브 (플랫폼별 연동)
- 최근 파일

#### 1.2 백업 정보 조회
**다이얼로그 표시 내용**:
```
백업 복구
━━━━━━━━━━━━━━━━━━━━━
백업 일시: 2026-01-07 10:30
스케줄: 278개
업체: 5개
메모: 12개

복구 방법을 선택하세요:
• 기존 데이터에 추가: 현재 데이터 유지
• 전체 교체: 현재 데이터 삭제 후 복구

[취소] [기존 데이터에 추가] [전체 교체]
```

**동작 방식**:
```dart
// BackupService.readBackupFile()
1. JSON 파일 읽기
2. 파일 유효성 검증
   - version 필드 존재 확인
   - 디지털 서명 검증 (선택적)
3. 백업 정보 추출
   - 스케줄 개수
   - 업체 개수
   - 메모 개수
   - 백업 생성 일시
```

#### 1.3 복구 모드 선택

##### 모드 1: 기존 데이터에 추가 (Merge)
**특징**:
- 현재 데이터 유지
- 백업 데이터 추가
- 중복 데이터 처리:
  - **스케줄**: 모두 추가 (ID 자동 생성)
  - **업체**: 같은 이름이 있으면 기존 유지, 색상/작업항목 업데이트
  - **메모**: 같은 날짜가 있으면 기존 유지

**사용 사례**:
- 다른 기기에서 백업한 데이터 병합
- 삭제된 데이터만 복구
- 부분 백업 파일 복구

##### 모드 2: 전체 교체 (Replace)
**특징**:
- 기존 데이터 완전 삭제
- 백업 데이터로 교체
- 클린 복구

**동작 방식**:
```dart
1. 기존 데이터 삭제
   - 모든 스케줄 삭제
   - 모든 업체 삭제 (단, "개인" 업체는 제외)
   - 모든 메모 삭제

2. 백업 데이터 복구
```

**사용 사례**:
- 새 기기로 데이터 이동
- 데이터 초기화 후 복구
- 전체 백업 파일 복구

**경고 메시지**:
```
⚠️ 주의: 현재 데이터가 모두 삭제됩니다!
현재 스케줄, 업체, 메모가 모두 삭제되고
백업 파일의 데이터로 완전히 교체됩니다.

계속하시겠습니까?
```

### 2. 복구 실행

#### 2.1 복구 프로세스 (Merge 모드)
```dart
// BackupService.restoreBackup(replaceAll: false)

1. 백업 데이터 로드 (캐싱된 데이터 사용)

2. 업체 복구
   For each company in backup:
     - userId를 현재 사용자로 변경
     - 같은 이름의 업체가 있는지 확인
     - 없으면: 새로 생성
     - 있으면: 색상/작업항목 업데이트

3. 스케줄 복구
   For each schedule in backup:
     - requestDate 제거 (구 버전 호환)
     - userId를 현재 사용자로 변경
     - ID 제거 (자동 생성되도록)
     - null 값 처리 (visitTime, notes, address, jibunAddress 등)
     - workItems 형식 변환 (List → String)
     - workPrices 형식 변환 (Map → String)
     - Schedule 생성 및 저장

4. 메모 복구
   For each memo in backup:
     - userId를 현재 사용자로 변경
     - ID 제거
     - 같은 날짜의 메모가 있는지 확인
     - 없으면: 새로 생성
     - 있으면: 건너뛰기

5. 결과 반환
   {
     'schedules': 성공한 스케줄 수,
     'companies': 성공한 업체 수,
     'memos': 성공한 메모 수,
     'schedulesFailed': 실패한 스케줄 수,
     'companiesFailed': 실패한 업체 수,
     'memosFailed': 실패한 메모 수,
     'errors': 오류 메시지 리스트
   }
```

#### 2.2 복구 프로세스 (Replace 모드)
```dart
// BackupService.restoreBackup(replaceAll: true)

1. 백업 데이터 로드

2. 기존 데이터 삭제
   - 모든 스케줄 삭제 (50개마다 진행률 로그)
   - 모든 업체 삭제 ("개인" 제외)
   - 모든 메모 삭제

3. 업체 복구
   For each company in backup:
     - userId를 현재 사용자로 변경
     - 새로 생성

4. 스케줄 복구 (Merge와 동일)

5. 메모 복구
   For each memo in backup:
     - userId를 현재 사용자로 변경
     - ID 제거
     - 새로 생성 (중복 체크 불필요)

6. 결과 반환
```

#### 2.3 진행 상황 표시
**다이얼로그 UI**:
```
데이터 복구
━━━━━━━━━━━━━━━━━━━━━
[회전하는 원형 인디케이터]

기존 데이터 삭제 중...
━━━━━━━━━━━━━━━ 10%

[취소 불가 - 진행 중]
```

**단계별 메시지**:
1. "백업 정보 조회 중..."
2. "기존 데이터 삭제 중..." (Replace 모드만)
3. "데이터 복구 중..."
4. "복구 완료!"

#### 2.4 복구 결과 표시
**성공 시**:
```
복구 완료
━━━━━━━━━━━━━━━━━━━━━
스케줄: 278개 성공
업체: 5개 성공
메모: 12개 성공

[확인]
```

**일부 실패 시**:
```
복구 완료 (일부 오류 발생)
━━━━━━━━━━━━━━━━━━━━━
스케줄: 275개 성공, 3개 실패
업체: 5개 성공
메모: 12개 성공

오류 내역:
• 스케줄 "김철수" 복구 실패: UNIQUE constraint
• 스케줄 "이영희" 복구 실패: Invalid date format
• 스케줄 "박민수" 복구 실패: Missing required field
... 외 0개

[확인]
```

---

## 데이터 구조

### 1. 백업 파일 형식 (JSON)

#### 버전 1.1 (최신)
```json
{
  "version": "1.1",
  "exportDate": "2026-01-07T10:30:45.123Z",
  "schedules": [
    {
      "id": 1,
      "userId": "user-uuid",
      "customerName": "김철수",
      "visitDate": "2026-01-10T00:00:00.000",
      "visitTime": "14:30",
      "phoneNumber": "010-1234-5678",
      "address": "서울특별시 강남구 테헤란로 427",
      "jibunAddress": "서울특별시 강남구 삼성동 143-37",
      "companyName": "케어원",
      "workItems": "벽걸이에어컨 세척,스탠드에어컨 세척",
      "workPrices": "벽걸이에어컨 세척:66000|스탠드에어컨 세척:55000",
      "workCount": 2,
      "notes": "주차 가능",
      "status": "확정"
    }
  ],
  "companies": [
    {
      "id": 2,
      "userId": "user-uuid",
      "name": "케어원",
      "workItems": [
        {"name": "벽걸이에어컨 세척", "price": 66000},
        {"name": "스탠드에어컨 세척", "price": 55000}
      ],
      "color": 4289667571,
      "displayOrder": 12
    }
  ],
  "memos": [
    {
      "id": 1,
      "user_id": "user-uuid",
      "date": "2026-01-10",
      "content": "오늘은 강남 지역 집중 방문",
      "created_at": "2026-01-10T08:00:00.000Z",
      "updated_at": null
    }
  ],
  "signature": "7961265731411aee24d24db9d409ece786cebf82..."
}
```

#### 버전 1.0 (구 버전)
```json
{
  "version": "1.0",
  "exportDate": "2025-11-27T18:10:51.792Z",
  "schedules": [...],
  "companies": [...],
  // memos 필드 없음
  "signature": "..."
}
```

**버전별 차이점**:
| 버전 | 추가/변경 사항 | 하위 호환성 |
|------|---------------|------------|
| 1.0  | 초기 버전 (스케줄, 업체만) | - |
| 1.1  | 날짜별 메모 추가 | ✅ 1.0 파일 복구 가능 |

### 2. Schedule 데이터 구조

**필드 설명**:
| 필드 | 타입 | 필수 | 설명 | 백업 시 처리 |
|------|------|------|------|-------------|
| id | int | ❌ | 스케줄 고유 ID | 복구 시 제거 (자동 생성) |
| userId | String | ✅ | 사용자 ID | 복구 시 현재 사용자로 변경 |
| customerName | String | ✅ | 고객명 | 그대로 유지 |
| visitDate | DateTime | ❌ | 방문 날짜 | ISO 8601 형식 |
| visitTime | String | ❌ | 방문 시간 | null 허용 |
| phoneNumber | String | ✅ | 전화번호 | 그대로 유지 |
| address | String | ❌ | 주소 (도로명) | null 허용 |
| jibunAddress | String | ❌ | 지번 주소 | null 허용 |
| companyName | String | ❌ | 업체명 | null 허용 |
| workItems | String | ✅ | 작업 항목 (쉼표 구분) | List → String 변환 |
| workPrices | String | ✅ | 작업 가격 (파이프 구분) | Map → String 변환 |
| workCount | int | ✅ | 작업 건수 | 기본값 0 |
| notes | String | ❌ | 메모 | null 허용 |
| status | String | ✅ | 상태 | 기본값 "예정" |
| ~~requestDate~~ | DateTime | ❌ | **폐기됨** | 복구 시 제거 |

**변환 규칙**:
```dart
// workItems 변환
List → String: ["에어컨 세척", "냉장고 세척"] → "에어컨 세척,냉장고 세척"
String → List: "에어컨 세척,냉장고 세척" → ["에어컨 세척", "냉장고 세척"]

// workPrices 변환
Map → String: {"에어컨 세척": 66000, "냉장고 세척": 55000}
              → "에어컨 세척:66000|냉장고 세척:55000"
String → Map: "에어컨 세척:66000|냉장고 세척:55000"
              → {"에어컨 세척": 66000, "냉장고 세척": 55000}
```

### 3. Company 데이터 구조

**필드 설명**:
| 필드 | 타입 | 필수 | 설명 | 복구 시 처리 |
|------|------|------|------|-------------|
| id | int | ❌ | 업체 고유 ID | 복구 시 제거 |
| userId | String | ✅ | 사용자 ID | 현재 사용자로 변경 |
| name | String | ✅ | 업체명 | 중복 체크 키 |
| workItems | List | ✅ | 작업 항목 리스트 | JSON 배열 |
| color | int | ✅ | 업체 색상 (ARGB) | 그대로 유지 |
| displayOrder | int | ✅ | 표시 순서 | 그대로 유지 |

**중복 처리 로직**:
```dart
Merge 모드:
  - 같은 이름의 업체가 있으면 색상/작업항목 업데이트
  - 없으면 새로 생성

Replace 모드:
  - 모든 업체 삭제 ("개인" 제외)
  - 백업 데이터로 새로 생성
```

### 4. DateMemo 데이터 구조

**필드 설명**:
| 필드 | 타입 | 필수 | 설명 | 복구 시 처리 |
|------|------|------|------|-------------|
| id | int | ❌ | 메모 고유 ID | 복구 시 제거 |
| user_id | String | ✅ | 사용자 ID | 현재 사용자로 변경 |
| date | String | ✅ | 날짜 (YYYY-MM-DD) | 중복 체크 키 |
| content | String | ✅ | 메모 내용 | 그대로 유지 |
| created_at | String | ✅ | 생성 일시 | ISO 8601 형식 |
| updated_at | String | ❌ | 수정 일시 | null 허용 |

**중복 처리 로직**:
```dart
Merge 모드:
  - 같은 날짜의 메모가 있으면 건너뛰기
  - 없으면 새로 생성

Replace 모드:
  - 모든 메모 삭제
  - 백업 데이터로 새로 생성
```

---

## 보안

### 1. 디지털 서명

#### 목적
- 백업 파일 위변조 방지
- 앱에서 생성된 정식 파일만 복구 가능

#### 구현
```dart
// 서명 생성
String _generateSignature(Map<String, dynamic> data) {
  // 1. signature 필드 제외하고 데이터 복사
  final dataWithoutSignature = Map<String, dynamic>.from(data);
  dataWithoutSignature.remove('signature');

  // 2. 키 정렬 후 JSON 문자열 변환
  final sortedKeys = dataWithoutSignature.keys.toList()..sort();
  final sortedData = <String, dynamic>{};
  for (final key in sortedKeys) {
    sortedData[key] = dataWithoutSignature[key];
  }
  final jsonString = jsonEncode(sortedData);

  // 3. HMAC-SHA256 서명 생성
  final key = utf8.encode(_secretKey);
  final bytes = utf8.encode(jsonString);
  final hmac = Hmac(sha256, key);
  final digest = hmac.convert(bytes);

  return digest.toString();
}

// 서명 검증
bool _verifySignature(Map<String, dynamic> data) {
  final providedSignature = data['signature'];
  final calculatedSignature = _generateSignature(data);
  return providedSignature == calculatedSignature;
}
```

#### 서명 키
```dart
static const String _secretKey = 'bizplan_backup_secret_key_v1_2025';
```

**보안 강화 방안** (향후):
- 사용자별 고유 키 생성
- 키 암호화 저장
- 서버 검증 추가

### 2. 데이터 프라이버시

#### 백업 파일에 포함되는 개인정보
- 고객명
- 전화번호
- 주소
- 작업 내역
- 메모

#### 보호 조치
1. **로컬 저장**: 백업 파일은 사용자 기기에만 저장
2. **전송 암호화**: 공유 시 플랫폼별 암호화 사용
3. **접근 제어**: 파일 권한 설정 (Android/iOS)

**사용자 주의사항**:
```
⚠️ 백업 파일 보안 주의사항

백업 파일에는 고객 정보가 포함되어 있습니다.
- 안전한 장소에 보관하세요
- 공유 시 주의하세요
- 불필요한 백업은 삭제하세요
```

---

## 오류 처리

### 1. 백업 생성 오류

#### 1.1 데이터베이스 읽기 실패
**원인**:
- 데이터베이스 손상
- 권한 부족
- 메모리 부족

**처리**:
```dart
try {
  final schedules = await db.readAllSchedules(userId);
} catch (e) {
  throw Exception('스케줄 조회 실패: $e');
}
```

**사용자 메시지**:
```
백업 생성 실패
스케줄 데이터를 읽을 수 없습니다.
앱을 재시작한 후 다시 시도해주세요.
```

#### 1.2 파일 저장 실패
**원인**:
- 저장 공간 부족
- 권한 부족
- 파일 시스템 오류

**처리**:
```dart
try {
  await file.writeAsString(jsonString);
} catch (e) {
  throw Exception('백업 파일 생성 실패: $e');
}
```

**사용자 메시지**:
```
백업 저장 실패
저장 공간을 확인해주세요.
현재 사용 가능: 500MB
필요 공간: 2MB
```

### 2. 복구 오류

#### 2.1 파일 읽기 실패
**원인**:
- 파일이 존재하지 않음
- 권한 부족
- 파일 형식 오류

**처리**:
```dart
if (!await file.exists()) {
  throw Exception('백업 파일을 찾을 수 없습니다');
}

try {
  final jsonString = await file.readAsString();
  final backupData = jsonDecode(jsonString);
} catch (e) {
  throw Exception('백업 파일 읽기 실패: $e');
}
```

**사용자 메시지**:
```
복구 실패
백업 파일을 읽을 수 없습니다.
올바른 백업 파일인지 확인해주세요.
```

#### 2.2 데이터 유효성 검증 실패
**원인**:
- 버전 필드 없음
- 필수 필드 누락
- 데이터 형식 오류

**처리**:
```dart
// 버전 확인
if (!backupData.containsKey('version')) {
  throw Exception('유효하지 않은 백업 파일입니다');
}

// 스케줄 검증
for (final schedule in schedules) {
  if (schedule['customerName'] == null) {
    throw Exception('필수 필드 누락: customerName');
  }
}
```

**사용자 메시지**:
```
복구 실패
백업 파일이 손상되었거나
올바른 형식이 아닙니다.

오류: 필수 필드 누락 (customerName)
```

#### 2.3 개별 항목 복구 실패
**원인**:
- UNIQUE 제약 조건 위반
- 외래 키 제약 조건 위반
- 데이터 형식 오류

**처리**:
```dart
for (int i = 0; i < schedules.length; i++) {
  try {
    final schedule = Schedule.fromMap(scheduleMap);
    await db.createSchedule(schedule);
    schedulesImported++;
  } catch (e, stackTrace) {
    schedulesFailed++;
    errors.add('스케줄 "$customerName" 복구 실패: $e');
    debugPrint('❌ 스케줄 복구 실패: $e');
    debugPrint('스택트레이스: $stackTrace');
  }
}
```

**사용자 메시지**:
```
복구 완료 (일부 오류 발생)
━━━━━━━━━━━━━━━━━━━━━
스케줄: 275개 성공, 3개 실패

오류 내역:
• 스케줄 "김철수" 복구 실패:
  데이터베이스 제약 조건 위반
• 스케줄 "이영희" 복구 실패:
  잘못된 날짜 형식
• 스케줄 "박민수" 복구 실패:
  필수 필드 누락

계속하시겠습니까?
```

#### 2.4 위젯 생명주기 오류
**원인**:
- 백업 파일 선택 후 Activity/Widget 폐기
- Android 메모리 관리
- 장시간 작업

**처리**:
```dart
// 모든 async 작업은 다이얼로그 내부에서 실행
class _RestoreProgressDialog extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    _loadBackupInfo(); // 다이얼로그 생명주기 내에서 실행
  }

  Future<void> _loadBackupInfo() async {
    final backupData = await backupService.readBackupFile(filePath);
    if (mounted) { // mounted 체크
      setState(() {
        // UI 업데이트
      });
    }
  }
}
```

### 3. 오류 로그

**디버그 로그 형식**:
```
========================================
📂 백업 파일 읽기 시작
파일 경로: /storage/emulated/0/Download/schedule_backup_2026-01-07.json
✅ 파일 존재 확인 (42ms)
✅ JSON 문자열 읽기 완료 (146402 바이트, 293ms)
✅ JSON 파싱 완료 (8ms)
✅ 버전: 1.1
✅ 스케줄 개수: 278개
✅ 업체 개수: 5개
✅ 메모 개수: 12개
✅ 백업 파일 읽기 완료 (총 343ms)
========================================

========================================
🔄 restoreBackup 시작 (replaceAll: true)
✅ 백업 데이터 로드 완료 (0ms)
🗑️ 기존 데이터 삭제 시작...
📋 삭제할 스케줄: 278개
  스케줄 삭제 중... 50/278
  스케줄 삭제 중... 100/278
  스케줄 삭제 중... 150/278
  스케줄 삭제 중... 200/278
  스케줄 삭제 중... 250/278
  스케줄 삭제 중... 278/278
🏢 삭제할 업체: 4개
✅ 기존 데이터 삭제 완료 (8532ms)

========================================
📦 스케줄 복구 시작: 총 278개
========================================
✅ 스케줄 복구 성공 [1/278]: 김철수
✅ 스케줄 복구 성공 [2/278]: 이영희
❌ 스케줄 복구 실패 [3/278]: 박민수
  에러: Missing required field: phoneNumber
...
========================================
📊 스케줄 복구 완료:
   성공: 275개
   실패: 3개
========================================

========================================
📝 메모 복구 시작: 총 12개
========================================
✅ 메모 복구 성공 [1/12]: 2026-01-10
✅ 메모 복구 성공 [2/12]: 2026-01-11
...
========================================
📊 메모 복구 완료:
   성공: 12개
   실패: 0개
========================================
```

---

## 성능 최적화

### 1. 백업 파일 읽기 최적화

#### 문제
- 278개 스케줄 파일 파싱: 293ms (JSON 읽기) + 8ms (파싱) = 301ms
- 복구 시 두 번 읽기: 파일 선택 시 + 복구 시 = 600ms

#### 해결
**데이터 캐싱**:
```dart
class _RestoreProgressDialogState extends State<_RestoreProgressDialog> {
  Map<String, dynamic>? _cachedBackupData; // 캐싱

  Future<void> _loadBackupInfo() async {
    // 한 번만 읽기
    _cachedBackupData = await backupService.readBackupFile(widget.filePath);
  }

  Future<void> _performRestore(bool replaceAll) async {
    // 캐싱된 데이터 재사용
    final result = await backupService.restoreBackup(
      widget.filePath,
      replaceAll: replaceAll,
      cachedData: _cachedBackupData, // ✅ 재사용
    );
  }
}
```

**효과**:
- Before: 파일 읽기 2회 (600ms)
- After: 파일 읽기 1회 (300ms)
- **성능 개선: 50%**

### 2. 대용량 데이터 복구 최적화

#### 문제
- 전체 교체 모드에서 기존 데이터 삭제가 느림
- 3000개 스케줄 삭제: 약 20-30초

#### 현재 구현
```dart
// 개별 삭제 (느림)
for (final schedule in existingSchedules) {
  await db.deleteSchedule(userId, schedule.id!);
}
```

#### 최적화 방안 (향후)
```dart
// 배치 삭제 (빠름)
await db.transaction((txn) async {
  await txn.delete(
    'schedules',
    where: 'userId = ?',
    whereArgs: [userId],
  );
});
```

**예상 효과**:
- Before: 3000개 삭제 = 30초
- After: 3000개 삭제 = 1초
- **성능 개선: 97%**

### 3. UI 응답성 개선

#### 진행 상황 표시
```dart
// 50개마다 로그 출력
if ((i + 1) % 50 == 0 || i == length - 1) {
  debugPrint('  처리 중... ${i + 1}/$length');
}
```

#### 비동기 처리
```dart
// 긴 작업은 다이얼로그 내부에서 실행
Future<void> _performRestore(bool replaceAll) async {
  setState(() {
    _showOptions = false;
    _statusMessage = '데이터 복구 중...';
  });

  // UI 업데이트 시간 확보
  await Future.delayed(const Duration(milliseconds: 100));

  // 실제 복구 작업
  final result = await backupService.restoreBackup(...);
}
```

### 4. 메모리 최적화

#### 스트리밍 방식 고려 (향후)
현재: 전체 JSON을 메모리에 로드
```dart
final jsonString = await file.readAsString(); // 전체 읽기
final backupData = jsonDecode(jsonString);
```

향후: 스트리밍 파싱 (대용량 파일)
```dart
final stream = file.openRead();
await for (final chunk in stream) {
  // 청크 단위 처리
}
```

---

## 사용 시나리오

### 시나리오 1: 정기 백업
**목적**: 데이터 손실 방지

**절차**:
1. 매월 말일에 전체 백업 생성
2. 백업 파일을 Google Drive에 저장
3. 이전 백업 파일 삭제

**자동화** (향후):
- 자동 백업 스케줄 설정
- 클라우드 자동 업로드
- 백업 이력 관리

### 시나리오 2: 기기 변경
**목적**: 새 기기로 데이터 이동

**절차**:
1. 구 기기: 전체 백업 생성 및 공유
2. 신 기기: 앱 설치 및 로그인
3. 신 기기: 백업 복구 (전체 교체)
4. 데이터 확인

### 시나리오 3: 데이터 병합
**목적**: 여러 기기의 데이터 통합

**절차**:
1. 기기 A: 백업 생성 및 공유
2. 기기 B: 백업 복구 (기존 데이터에 추가)
3. 중복 데이터 확인 및 정리

### 시나리오 4: 실수로 삭제한 데이터 복구
**목적**: 삭제된 스케줄 복구

**절차**:
1. 최근 백업 파일 찾기
2. 백업 복구 (기존 데이터에 추가)
3. 필요한 데이터만 선택적으로 유지

---

## 향후 개선 사항

### 1. 기능 추가
- [ ] 자동 백업 스케줄링
- [ ] 클라우드 연동 (Google Drive, iCloud, Dropbox)
- [ ] 선택적 백업 (특정 업체, 기간 등)
- [ ] 백업 암호화
- [ ] 백업 이력 관리
- [ ] 백업 파일 비교
- [ ] 증분 백업 (변경사항만)

### 2. 성능 개선
- [ ] 배치 삭제/삽입
- [ ] 스트리밍 파싱 (대용량 파일)
- [ ] 백그라운드 작업
- [ ] 진행률 세분화

### 3. UX 개선
- [ ] 백업 미리보기
- [ ] 복구 전 데이터 비교
- [ ] 복구 후 변경사항 요약
- [ ] 실행 취소 기능
- [ ] 백업 파일 관리 화면

### 4. 보안 강화
- [ ] 사용자별 고유 서명 키
- [ ] 백업 파일 암호화
- [ ] 생체 인증 연동
- [ ] 서버 검증

---

## 기술 스택

### 라이브러리
- **file_picker**: 백업 파일 선택
- **share_plus**: 백업 파일 공유
- **path_provider**: 저장 경로 관리
- **crypto**: 디지털 서명 (HMAC-SHA256)

### 데이터베이스
- **SQLite**: 로컬 데이터 저장
- **sqflite**: Flutter SQLite 패키지

### 파일 형식
- **JSON**: 백업 데이터 형식
- **UTF-8**: 문자열 인코딩

---

## 버전 히스토리

### v1.1 (2026-01-07)
- ✅ 날짜별 메모 백업/복구 추가
- ✅ 지번 주소 필드 백업 지원
- ✅ requestDate 필드 제거 (구 버전 호환)
- ✅ 데이터 캐싱으로 성능 개선
- ✅ 위젯 생명주기 오류 수정

### v1.0 (2025-11-27)
- ✅ 스케줄 백업/복구
- ✅ 업체 백업/복구
- ✅ 디지털 서명
- ✅ 기간별 백업
- ✅ 파일 공유/다운로드
- ✅ 복구 모드 선택 (Merge/Replace)

---

## 참고 자료

### 코드 위치
- **BackupService**: `lib/services/backup_service.dart`
- **SettingsScreen**: `lib/screens/settings_screen.dart`
- **DatabaseHelper**: `lib/database/database_helper.dart`
- **Models**: `lib/models/`
  - `schedule.dart`
  - `company.dart`
  - `date_memo.dart`

### 관련 문서
- [SQLite 공식 문서](https://www.sqlite.org/docs.html)
- [Flutter file_picker](https://pub.dev/packages/file_picker)
- [Flutter share_plus](https://pub.dev/packages/share_plus)
- [HMAC-SHA256](https://en.wikipedia.org/wiki/HMAC)

---

**문서 버전**: 1.0
**최종 수정일**: 2026-01-07
**작성자**: Claude (AI Assistant)
