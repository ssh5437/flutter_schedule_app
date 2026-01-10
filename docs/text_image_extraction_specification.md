# 텍스트 및 이미지 추출 기능 정의서

## 목차
1. [개요](#1-개요)
2. [기능 흐름도](#2-기능-흐름도)
3. [텍스트 추출 기능](#3-텍스트-추출-기능)
4. [이미지 추출 기능](#4-이미지-추출-기능)
5. [Gemini API 연동](#5-gemini-api-연동)
6. [Supabase Edge Functions](#6-supabase-edge-functions)
7. [사용량 제한 시스템](#7-사용량-제한-시스템)
8. [에러 처리](#8-에러-처리)
9. [데이터 구조](#9-데이터-구조)
10. [보안 고려사항](#10-보안-고려사항)
11. [성능 최적화](#11-성능-최적화)

---

## 1. 개요

### 1.1 기능 목적
스케줄 등록 시 텍스트나 이미지에서 고객 정보(이름, 전화번호, 주소, 날짜, 시간, 작업 내용)를 자동으로 추출하여 입력 폼에 자동 입력하는 기능입니다.

### 1.2 주요 기능
- **텍스트 추출**: 복사한 텍스트에서 스케줄 정보 추출
- **이미지 추출**: 문서 사진/캡처 이미지에서 OCR로 텍스트 인식 후 정보 추출
- **AI 기반 파싱**: Gemini API를 활용한 지능형 정보 추출
- **사용량 제한**: 월 30회 무료 사용 제한 (향후 멤버십 연동)

### 1.3 기술 스택
- **Flutter**: 클라이언트 앱 개발
- **Google ML Kit**: 온디바이스 OCR (한글 지원)
- **Gemini API**: AI 기반 텍스트 파싱 (gemini-2.5-flash-lite)
- **Supabase Edge Functions**: 서버리스 백엔드 (Deno 런타임)
- **SharedPreferences**: 로컬 사용량 추적

---

## 2. 기능 흐름도

### 2.1 전체 흐름

```
[사용자]
   ↓
[스케줄 추가 화면]
   ↓
   ├─→ [텍스트 추출 버튼] → [텍스트 입력 다이얼로그]
   │                             ↓
   │                        [사용량 체크]
   │                             ↓
   │                        [Gemini API 호출]
   │                             ↓
   │                        [폼에 자동 입력]
   │
   └─→ [이미지 추출 버튼] → [이미지 선택 다이얼로그]
                                ↓
                           [갤러리/카메라 선택]
                                ↓
                           [이미지 선택]
                                ↓
                           [사용량 체크]
                                ↓
                           [ML Kit OCR 실행]
                                ↓
                           [Gemini API 호출]
                                ↓
                           [폼에 자동 입력]
```

### 2.2 세부 단계별 흐름

#### 텍스트 추출 흐름
```
1. 사용자가 "텍스트에서 추출" 버튼 클릭
   ↓
2. TextExtractionLimitHelper.getRemainingCount() 호출
   ↓
3. 다이얼로그에 남은 횟수 표시 (예: 25/30)
   ↓
4. 사용자가 텍스트 입력 및 "추출하기" 버튼 클릭
   ↓
5. 사용량 재확인 (remaining > 0?)
   ↓
6. TextExtractionLimitHelper.incrementUsage() 호출
   ↓
7. 로딩 다이얼로그 표시 ("AI로 정보 추출 중...")
   ↓
8. GeminiHelper.extractScheduleInfo() 호출
   ↓
9. Supabase Edge Function 'extract-schedule' 호출
   ↓
10. Gemini API로 텍스트 파싱
   ↓
11. 추출된 정보 반환
   ↓
12. 성공 시: 폼에 데이터 자동 입력
    실패 시: TextExtractionLimitHelper.decrementUsage() 호출 (사용량 복구)
```

#### 이미지 추출 흐름
```
1. 사용자가 "이미지에서 추출" 버튼 클릭
   ↓
2. TextExtractionLimitHelper.getRemainingCount() 호출
   ↓
3. 다이얼로그에 남은 횟수 표시
   ↓
4. 사용자가 "갤러리" 또는 "카메라" 선택
   ↓
5. ImagePicker로 이미지 선택/촬영
   ↓
6. 사용량 재확인 (remaining > 0?)
   ↓
7. TextExtractionLimitHelper.incrementUsage() 호출
   ↓
8. 로딩 다이얼로그 표시 ("이미지에서 텍스트 추출 중...")
   ↓
9. ImageTextExtractor.extractTextFromImage() 호출
   ↓
10. ML Kit TextRecognizer로 OCR 실행
   ↓
11. 추출된 텍스트 획득
   ↓
12. 로딩 메시지 변경 ("AI로 정보 추출 중...")
   ↓
13. GeminiHelper.extractScheduleInfo() 호출
   ↓
14. Supabase Edge Function 'extract-schedule' 호출
   ↓
15. Gemini API로 텍스트 파싱
   ↓
16. 추출된 정보 반환
   ↓
17. 성공 시: 폼에 데이터 자동 입력
    실패 시: TextExtractionLimitHelper.decrementUsage() 호출 (사용량 복구)
```

---

## 3. 텍스트 추출 기능

### 3.1 구현 위치
- 파일: `lib/screens/schedule_form_screen.dart`
- 메서드: `_showPasteDialog()`, `_extractScheduleInfoDirect()`

### 3.2 UI 구성

#### 텍스트 입력 다이얼로그
```dart
AlertDialog(
  title: Row(
    children: [
      Text('텍스트에서 스케줄 추출'),
      Container(
        // 사용량 표시 배지
        child: Text('25/30'),  // 남은 횟수/전체 횟수
      ),
    ],
  ),
  content: TextField(
    maxLines: null,
    minLines: 12,
    decoration: InputDecoration(
      hintText: '예시:\n홍길동\n010-1234-5678\n서울시 강남구 테헤란로 123\n2025년 10월 15일 14시',
    ),
  ),
  actions: [
    TextButton('취소'),
    FilledButton('추출하기'),  // AI 아이콘 포함
  ],
)
```

### 3.3 처리 로직

#### 사용량 체크
```dart
Future<void> _showPasteDialog() async {
  // 1. 남은 횟수 조회
  final remaining = await TextExtractionLimitHelper.getRemainingCount();

  // 2. 다이얼로그에 표시
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Text('텍스트에서 스케줄 추출'),
          Container(
            decoration: BoxDecoration(
              color: remaining > 0 ? Colors.green.shade50 : Colors.red.shade50,
              // ...
            ),
            child: Text('$remaining/${TextExtractionLimitHelper.monthlyLimit}'),
          ),
        ],
      ),
      // ...
    ),
  );
}
```

#### 추출 실행
```dart
FilledButton.icon(
  onPressed: () async {
    final text = textController.text.trim();

    // 1. 빈 텍스트 체크
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('텍스트를 입력해주세요')),
      );
      return;
    }

    Navigator.pop(context);  // 입력 다이얼로그 닫기

    // 2. 사용 가능 횟수 재확인
    final remaining = await TextExtractionLimitHelper.getRemainingCount();

    if (remaining <= 0) {
      // 제한 초과 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('사용 횟수 초과'),
          content: Text(
            '텍스트 추출 기능은 한 달에 ${TextExtractionLimitHelper.monthlyLimit}회까지 무료로 사용할 수 있습니다.\n\n'
            '이번 달 남은 횟수: $remaining회\n\n'
            '무제한으로 사용하려면 멤버십에 가입해주세요.',
          ),
        ),
      );
      return;
    }

    // 3. 사용 횟수 증가
    await TextExtractionLimitHelper.incrementUsage();

    // 4. 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI로 정보 추출 중...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 5. 정보 추출
    await _extractScheduleInfoDirect(text, true, shouldDecrementOnError: true);
  },
  icon: Icon(Icons.auto_fix_high),
  label: Text('추출하기'),
)
```

### 3.4 정보 추출 및 폼 입력

```dart
Future<void> _extractScheduleInfoDirect(
  String text,
  bool isDialogOpen,
  {bool shouldDecrementOnError = false}
) async {
  if (!mounted) return;

  try {
    // 1. 현재 업체의 작업 목록 준비
    List<String>? availableWorkItems;
    if (_selectedCompany != null && _selectedCompany!.workItems.isNotEmpty) {
      availableWorkItems = _selectedCompany!.workItems.map((item) => item.name).toList();
    }

    // 2. Gemini API 호출 (Edge Function 경유)
    final result = await GeminiHelper.extractScheduleInfo(
      text,
      availableWorkItems: availableWorkItems
    );

    if (!mounted) return;

    // 3. 로딩 다이얼로그 닫기
    if (isDialogOpen) {
      Navigator.pop(context);
    }

    if (result == null) {
      // 추출 실패 시 사용량 복구
      if (shouldDecrementOnError) {
        await TextExtractionLimitHelper.decrementUsage();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('정보 추출에 실패했습니다. Gemini API 키를 확인해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 4. 추출된 정보를 폼에 입력
    setState(() {
      // 이름
      if (result['name'] != null && result['name'].toString().isNotEmpty) {
        _customerNameController.text = result['name'].toString();
      }

      // 전화번호 (숫자만 추출 후 포맷팅)
      if (result['phone'] != null && result['phone'].toString().isNotEmpty) {
        final phone = result['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
        _phoneNumberController.text = _formatPhoneNumber(phone);
      }

      // 주소
      if (result['address'] != null && result['address'].toString().isNotEmpty) {
        _addressController.text = result['address'].toString();
      }

      // 날짜 (과거 날짜는 오늘로 변경)
      if (result['date'] != null && result['date'].toString().isNotEmpty) {
        try {
          final extractedDate = DateTime.parse(result['date'].toString());
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final extractedDateOnly = DateTime(
            extractedDate.year,
            extractedDate.month,
            extractedDate.day
          );

          if (extractedDateOnly.isBefore(todayDate)) {
            _visitDate = today;  // 과거 날짜는 오늘로
          } else {
            _visitDate = extractedDate;
          }
        } catch (e) {
          // 날짜 파싱 실패 시 무시
        }
      }

      // 시간
      if (result['time'] != null && result['time'].toString().isNotEmpty) {
        _visitTime = result['time'].toString();
      } else {
        _visitTime = null;  // 미정
      }

      // 작업 내용 매칭
      if (result['workItems'] != null && result['workItems'] is List) {
        final extractedWorkItems = result['workItems'] as List;

        if (extractedWorkItems.isNotEmpty && _selectedCompany != null) {
          _workItemsWithCount.clear();
          _workPrices.clear();

          for (var extractedItem in extractedWorkItems) {
            final itemName = extractedItem.toString();

            // 현재 업체의 작업 항목과 매칭
            final matchedWorkItem = _selectedCompany!.workItems.firstWhere(
              (workItem) => workItem.name == itemName,  // 정확히 일치
              orElse: () {
                // 유사한 항목 찾기 (대소문자 무시, 부분 일치)
                try {
                  return _selectedCompany!.workItems.firstWhere(
                    (workItem) =>
                      workItem.name.toLowerCase().contains(itemName.toLowerCase()) ||
                      itemName.toLowerCase().contains(workItem.name.toLowerCase()),
                  );
                } catch (e) {
                  // 매칭 실패 시 기본값
                  return _selectedCompany!.workItems.isNotEmpty
                    ? _selectedCompany!.workItems.first
                    : WorkItem(name: itemName, price: 0);
                }
              },
            );

            // 작업 항목 카운트 증가
            _workItemsWithCount[matchedWorkItem.name] =
              (_workItemsWithCount[matchedWorkItem.name] ?? 0) + 1;
            _workPrices[matchedWorkItem.name] = matchedWorkItem.price;
          }

          // 총 건수 업데이트
          int total = _workItemsWithCount.values.fold(0, (sum, count) => sum + count);
          _workCountController.text = total.toString();
        }
      }
    });

    // 5. 성공 메시지
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('정보가 추출되었습니다. 내용을 확인하고 수정해주세요.'),
        backgroundColor: Colors.green,
      ),
    );

    // 6. Analytics 로깅
    await AnalyticsService().logFeatureUsed(
      featureName: 'ocr_text_extraction',
      parameters: {'success': true},
    );

  } catch (e) {
    if (!mounted) return;

    // 추출 실패 시 사용량 복구
    if (shouldDecrementOnError) {
      await TextExtractionLimitHelper.decrementUsage();
    }

    // 로딩 다이얼로그 닫기
    if (isDialogOpen) {
      Navigator.pop(context);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('오류가 발생했습니다: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

---

## 4. 이미지 추출 기능

### 4.1 구현 위치
- 파일: `lib/screens/schedule_form_screen.dart`, `lib/utils/image_text_extractor.dart`
- 메서드: `_showImageExtractionDialog()`, `_pickAndExtractImage()`, `_processImageOCR()`

### 4.2 UI 구성

#### 이미지 선택 다이얼로그
```dart
AlertDialog(
  title: Row(
    children: [
      Text('이미지에서 스케줄 추출'),
      Container(
        // 사용량 표시 배지
        child: Text('25/30'),
      ),
    ],
  ),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('문서 사진이나 캡처 이미지에서\n스케줄 정보를 추출합니다.'),
      Row(
        children: [
          // 갤러리 버튼
          OutlinedButton.icon(
            icon: Icon(Icons.photo_library),
            label: Text('갤러리'),
            onPressed: () => _requestPermissionAndPick(fromCamera: false),
          ),
          // 카메라 버튼
          OutlinedButton.icon(
            icon: Icon(Icons.camera_alt),
            label: Text('카메라'),
            onPressed: () => _requestPermissionAndPick(fromCamera: true),
          ),
        ],
      ),
    ],
  ),
)
```

### 4.3 이미지 선택 로직

#### ImagePicker 사용
```dart
// lib/utils/image_text_extractor.dart

class ImageTextExtractor {
  static final ImagePicker _picker = ImagePicker();

  /// 갤러리에서 이미지 선택
  static Future<XFile?> pickImageFromGallery() async {
    try {
      debugPrint('📷 Starting gallery picker...');

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,      // 품질 85%로 압축
        maxWidth: 2048,        // 최대 너비 제한
        maxHeight: 2048,       // 최대 높이 제한
      ).timeout(
        Duration(seconds: 60),
        onTimeout: () {
          debugPrint('⏱️ Gallery picker timed out');
          return null;
        },
      );

      if (image != null) {
        debugPrint('✅ Gallery image selected: ${image.path}');

        // 파일 존재 여부 확인
        final file = File(image.path);
        if (!await file.exists()) {
          debugPrint('❌ Selected file does not exist');
          return null;
        }

        final fileSize = await file.length();
        debugPrint('📊 File size: ${fileSize / 1024} KB');
      }

      return image;
    } catch (e, stackTrace) {
      debugPrint('❌ Error picking image from gallery: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// 카메라로 사진 촬영
  static Future<XFile?> pickImageFromCamera() async {
    try {
      debugPrint('📸 Starting camera...');

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
        preferredCameraDevice: CameraDevice.rear,  // 후면 카메라 우선
      ).timeout(
        Duration(seconds: 60),
        onTimeout: () {
          debugPrint('⏱️ Camera timed out');
          return null;
        },
      );

      if (image != null) {
        debugPrint('✅ Camera image captured: ${image.path}');

        final file = File(image.path);
        if (!await file.exists()) {
          debugPrint('❌ Captured file does not exist');
          return null;
        }

        final fileSize = await file.length();
        debugPrint('📊 File size: ${fileSize / 1024} KB');
      }

      return image;
    } catch (e, stackTrace) {
      debugPrint('❌ Error picking image from camera: $e');
      return null;
    }
  }
}
```

### 4.4 OCR 처리 (Google ML Kit)

#### TextRecognizer 초기화 및 OCR 실행
```dart
// lib/utils/image_text_extractor.dart

class ImageTextExtractor {
  static TextRecognizer? _textRecognizer;

  /// TextRecognizer 인스턴스 생성 (한글 모델)
  static TextRecognizer _getTextRecognizer() {
    try {
      _textRecognizer ??= TextRecognizer(
        script: TextRecognitionScript.korean  // 한글 스크립트 지정
      );
      return _textRecognizer!;
    } catch (e) {
      debugPrint('Error creating TextRecognizer: $e');
      rethrow;
    }
  }

  /// 이미지에서 텍스트 추출 (OCR)
  static Future<String> extractTextFromImage(String imagePath) async {
    TextRecognizer? recognizer;

    try {
      debugPrint('🔍 Starting OCR process...');

      // 1. 이미지 파일 존재 여부 확인
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('이미지 파일을 찾을 수 없습니다');
      }

      final fileSize = await imageFile.length();
      debugPrint('📊 Image file size: ${fileSize / 1024} KB');

      // 2. 파일 크기 제한 (10MB)
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('이미지 파일이 너무 큽니다. 10MB 이하의 이미지를 사용해주세요.');
      }

      // 3. TextRecognizer 초기화
      debugPrint('🔧 Initializing TextRecognizer...');
      recognizer = _getTextRecognizer();

      // 4. InputImage 생성
      debugPrint('📸 Creating InputImage...');
      final inputImage = InputImage.fromFilePath(imagePath);

      // 5. OCR 실행
      debugPrint('🤖 Processing image for text recognition...');
      final RecognizedText recognizedText = await recognizer
        .processImage(inputImage)
        .timeout(
          Duration(seconds: 45),
          onTimeout: () {
            throw Exception('텍스트 인식 시간이 초과되었습니다. 더 작은 이미지를 사용해주세요.');
          },
        );

      // 6. 텍스트 추출
      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }

      debugPrint('✅ OCR completed. Extracted ${extractedText.length} characters');
      return extractedText.trim();

    } on Exception catch (e, stackTrace) {
      debugPrint('❌ Exception in extractTextFromImage: $e');
      debugPrint('Stack trace: $stackTrace');

      // 모델 다운로드 관련 에러인 경우 명확한 메시지 제공
      final errorMessage = e.toString();
      if (errorMessage.contains('model') || errorMessage.contains('download')) {
        throw Exception('한글 인식 모델을 다운로드하는 중 오류가 발생했습니다. 인터넷 연결을 확인하고 다시 시도해주세요.');
      }

      if (errorMessage.contains('MlKitException')) {
        throw Exception('ML Kit 초기화 오류가 발생했습니다. 앱을 재시작해주세요.');
      }

      throw Exception('텍스트 추출 중 오류가 발생했습니다: ${errorMessage.replaceAll('Exception: ', '')}');

    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error in extractTextFromImage: $e');
      throw Exception('예상치 못한 오류가 발생했습니다: ${e.toString()}');
    }
  }

  /// 리소스 정리
  static Future<void> dispose() async {
    await _textRecognizer?.close();
  }
}
```

#### ML Kit 특징
1. **온디바이스 처리**: 인터넷 없이도 OCR 실행 가능
2. **한글 모델**: `TextRecognitionScript.korean` 지정으로 한글 인식 정확도 향상
3. **첫 실행 시 모델 다운로드**: 약 10-20MB 한글 모델 자동 다운로드
4. **오프라인 캐싱**: 한 번 다운로드 후 로컬에 저장되어 재사용

### 4.5 이미지 추출 전체 프로세스

```dart
// lib/screens/schedule_form_screen.dart

Future<void> _pickAndExtractImage({required bool fromCamera}) async {
  debugPrint('📸 [ScheduleForm] _pickAndExtractImage START');

  if (!mounted) return;

  XFile? selectedImage;

  // Step 1: 이미지 선택
  try {
    selectedImage = fromCamera
        ? await ImageTextExtractor.pickImageFromCamera()
        : await ImageTextExtractor.pickImageFromGallery();

    if (selectedImage == null) {
      debugPrint('ℹ️ [ScheduleForm] No image selected');
      return;  // 사용자 취소
    }

    debugPrint('✅ [ScheduleForm] Image selected: ${selectedImage.path}');
  } catch (e) {
    debugPrint('❌ [ScheduleForm] Error in image picker: $e');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다')),
      );
    }
    return;
  }

  if (!mounted) return;

  // Step 2: OCR 처리
  await _processImageOCR(selectedImage.path);
}

Future<void> _processImageOCR(String imagePath) async {
  debugPrint('🔍 [ScheduleForm] _processImageOCR START');

  if (!mounted) return;

  // 1. 사용 가능 횟수 확인
  final remaining = await TextExtractionLimitHelper.getRemainingCount();

  if (remaining <= 0) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('사용 횟수 초과'),
        content: Text(
          '이미지 추출 기능은 한 달에 ${TextExtractionLimitHelper.monthlyLimit}회까지 무료로 사용할 수 있습니다.\n\n'
          '이번 달 남은 횟수: $remaining회\n\n'
          '무제한으로 사용하려면 멤버십에 가입해주세요.',
        ),
      ),
    );
    return;
  }

  // 2. 사용 횟수 증가
  await TextExtractionLimitHelper.incrementUsage();

  bool isDialogOpen = false;

  try {
    // 3. 로딩 다이얼로그 표시 (OCR 단계)
    isDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('이미지에서 텍스트 추출 중...'),
                  SizedBox(height: 8),
                  Text(
                    '처음 사용시 한글 모델을 다운로드합니다\n잠시만 기다려주세요',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 다이얼로그 표시 대기
    await Future.delayed(Duration(milliseconds: 500));

    if (!mounted) return;

    // 4. OCR 실행
    debugPrint('🤖 [ScheduleForm] Executing OCR');
    final String extractedText = await ImageTextExtractor.extractTextFromImage(imagePath);

    debugPrint('✅ [ScheduleForm] OCR SUCCESS: ${extractedText.length} chars');
    debugPrint('📄 [ScheduleForm] Extracted text:\n$extractedText');

    if (!mounted) return;

    // 5. 텍스트가 비어있는 경우
    if (extractedText.trim().isEmpty) {
      debugPrint('⚠️ [ScheduleForm] No text found in image');

      // 추출 실패 시 사용량 복구
      await TextExtractionLimitHelper.decrementUsage();

      // 로딩 다이얼로그 닫기
      if (isDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogOpen = false;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('텍스트 추출 실패'),
            content: Text('이미지에서 텍스트를 찾을 수 없습니다.'),
          ),
        );
      }
      return;
    }

    // 6. 로딩 메시지 변경 (Gemini API 처리 중)
    if (mounted && isDialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      isDialogOpen = false;

      isDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('AI로 정보 추출 중...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!mounted) return;

    // 7. Gemini API로 정보 추출
    debugPrint('🤖 [ScheduleForm] Calling Gemini API');
    await _extractScheduleInfoDirect(
      extractedText,
      isDialogOpen,
      shouldDecrementOnError: true
    );

  } catch (e, stack) {
    debugPrint('❌ [ScheduleForm] ERROR in _processImageOCR: $e');

    if (!mounted) return;

    // 추출 실패 시 사용량 복구
    await TextExtractionLimitHelper.decrementUsage();

    // 다이얼로그 닫기
    if (isDialogOpen) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (e) {
        debugPrint('⚠️ Failed to close dialog: $e');
      }
    }

    // 에러 표시
    String errorMsg = e.toString().replaceAll('Exception: ', '');

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('오류 발생'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('이미지 처리 중 오류가 발생했습니다:'),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(errorMsg),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
```

---

## 5. Gemini API 연동

### 5.1 구현 위치
- 파일: `lib/utils/gemini_helper.dart`
- 메서드: `extractScheduleInfo()`

### 5.2 GeminiHelper 클래스

```dart
// lib/utils/gemini_helper.dart

class GeminiHelper {
  static Future<Map<String, dynamic>?> extractScheduleInfo(
    String text,
    {List<String>? availableWorkItems}
  ) async {
    try {
      debugPrint('🚀 [GeminiHelper] Calling Edge Function...');

      // Supabase Edge Function 호출
      final response = await Supabase.instance.client.functions.invoke(
        'extract-schedule',  // Edge Function 이름
        body: {
          'text': text,
          'availableWorkItems': availableWorkItems,  // 업체별 작업 목록
        },
      );

      debugPrint('✅ [GeminiHelper] Edge Function response received');

      // 응답 확인
      if (response.data == null) {
        debugPrint('Edge Function 응답 없음');
        return null;
      }

      // 응답 파싱
      final data = response.data as Map<String, dynamic>;

      if (data.containsKey('error')) {
        debugPrint('Edge Function 오류: ${data['error']}');
        return null;
      }

      if (data.containsKey('data')) {
        return data['data'] as Map<String, dynamic>;
      }

      return null;

    } catch (e) {
      debugPrint('텍스트 추출 오류: $e');
      return null;
    }
  }
}
```

### 5.3 호출 흐름

```
Flutter App (GeminiHelper)
   ↓ HTTP POST
Supabase Edge Function (extract-schedule)
   ↓ HTTP POST
Gemini API (gemini-2.5-flash-lite)
   ↓ JSON Response
Supabase Edge Function
   ↓ JSON Response
Flutter App
```

### 5.4 Gemini API 요청 형식

#### Request Body (Flutter → Edge Function)
```json
{
  "text": "홍길동\n010-1234-5678\n서울시 강남구 테헤란로 123\n2025년 10월 15일 14시\n1way 에어컨 세척 3개",
  "availableWorkItems": [
    "1way 에어컨 세척",
    "2way 에어컨 세척",
    "실외기 세척"
  ]
}
```

#### Response (Edge Function → Flutter)
```json
{
  "data": {
    "name": "홍길동",
    "phone": "01012345678",
    "address": "서울시 강남구 테헤란로 123",
    "date": "2025-10-15",
    "time": "14:00",
    "workItems": ["1way 에어컨 세척", "1way 에어컨 세척", "1way 에어컨 세척"]
  }
}
```

---

## 6. Supabase Edge Functions

### 6.1 개요
Supabase Edge Functions는 Deno 런타임 기반의 서버리스 함수로, Gemini API 키를 안전하게 관리하고 API 호출을 중개합니다.

### 6.2 Edge Function 코드

#### 파일 위치
- `supabase/functions/extract-schedule/index.ts`

#### 전체 코드
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// 환경 변수에서 Gemini API 키 로드
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')

serve(async (req) => {
  // ========================================
  // 1. CORS 헤더 설정
  // ========================================
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  // OPTIONS 요청 처리 (preflight)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // ========================================
    // 2. 요청 파라미터 추출
    // ========================================
    const requestId = crypto.randomUUID()  // 고유 요청 ID 생성

    const { text, availableWorkItems } = await req.json()

    console.log(`📥 [${requestId}] Request received:`, {
      text: text?.substring(0, 100),
      availableWorkItemsCount: availableWorkItems?.length
    })

    // ========================================
    // 3. 입력 검증
    // ========================================
    if (!text || typeof text !== 'string') {
      console.error(`❌ [${requestId}] Invalid text parameter`)
      return new Response(
        JSON.stringify({ error: 'text 파라미터가 필요합니다' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (!GEMINI_API_KEY) {
      console.error(`❌ [${requestId}] GEMINI_API_KEY not found`)
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY가 설정되지 않았습니다' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`✅ [${requestId}] GEMINI_API_KEY exists`)

    // ========================================
    // 4. Gemini API 프롬프트 생성
    // ========================================

    // 작업 목록이 있는 경우 해당 목록에서만 선택하도록 제한
    const workItemsPrompt = availableWorkItems && availableWorkItems.length > 0
      ? `\n- 작업 내용 (workItems) - 문자열 배열 형식. 아래 작업 목록에서만 선택하여 추출하세요. 텍스트에 "3개", "2건" 등의 수량이 있으면 해당 작업명을 그 수량만큼 배열에 반복해서 넣으세요.
  사용 가능한 작업 목록: ${JSON.stringify(availableWorkItems)}
  예시: 텍스트에 "실외기 세척 3개"가 있으면 workItems: ["실외기 세척", "실외기 세척", "실외기 세척"]로 반환`
      : '\n- 작업 내용 (workItems) - 문자열 배열 형식. 에어컨 청소, 세탁기 청소, 이사, 레슨 등 서비스/작업 항목을 추출. 수량이 있으면 해당 수량만큼 배열에 반복'

    const workItemsExample = availableWorkItems && availableWorkItems.length > 0
      ? availableWorkItems.slice(0, 2)  // 처음 2개만 예시로 사용
      : ["1way 에어컨 세척", "실외기 세척"]

    const prompt = `다음 텍스트에서 스케줄 정보를 추출해주세요. 추출할 정보는 다음과 같습니다:
- 고객명 (name)
- 전화번호 (phone) - 숫자만 추출
- 주소 (address)
- 날짜 (date) - YYYY-MM-DD 형식
- 시간 (time) - HH:MM 형식 (24시간제)${workItemsPrompt}

JSON 형식으로만 응답해주세요. 값을 찾을 수 없는 경우 null을 사용하세요.
형식 예시:
{
  "name": "홍길동",
  "phone": "01012345678",
  "address": "서울시 강남구 테헤란로 123",
  "date": "2025-10-15",
  "time": "14:00",
  "workItems": ${JSON.stringify(workItemsExample)}
}

텍스트:
${text}

JSON 응답:`

    // ========================================
    // 5. Gemini API 호출
    // ========================================
    const modelVersion = 'gemini-2.5-flash-lite'
    const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelVersion}:generateContent?key=${GEMINI_API_KEY}`

    console.log(`🚀 [${requestId}] Calling Gemini API...`, { model: modelVersion })

    const geminiResponse = await fetch(
      apiUrl,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text: prompt
                }
              ]
            }
          ]
        })
      }
    )

    console.log(`📡 [${requestId}] Gemini response status:`, geminiResponse.status)

    // ========================================
    // 6. Gemini API 응답 처리
    // ========================================
    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text()
      console.error(`❌ [${requestId}] Gemini API 오류:`, errorText)
      return new Response(
        JSON.stringify({ error: 'Gemini API 호출 실패', details: errorText }),
        {
          status: geminiResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const geminiData = await geminiResponse.json()

    // Gemini 응답에서 텍스트 추출
    const responseText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text

    if (!responseText) {
      return new Response(
        JSON.stringify({ error: 'Gemini 응답을 파싱할 수 없습니다' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // ========================================
    // 7. JSON 파싱 (마크다운 코드 블록 제거)
    // ========================================
    let jsonText = responseText.trim()

    // ```json ... ``` 형식 제거
    if (jsonText.startsWith('```json')) {
      jsonText = jsonText.substring(7)
    } else if (jsonText.startsWith('```')) {
      jsonText = jsonText.substring(3)
    }
    if (jsonText.endsWith('```')) {
      jsonText = jsonText.substring(0, jsonText.length - 3)
    }
    jsonText = jsonText.trim()

    // JSON 파싱
    const extractedData = JSON.parse(jsonText)

    console.log(`✅ [${requestId}] Successfully extracted data:`, extractedData)
    console.log(`🎯 [${requestId}] Total Gemini API calls: 1`)

    // ========================================
    // 8. 응답 반환
    // ========================================
    return new Response(
      JSON.stringify({ data: extractedData }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('오류:', error)
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : '알 수 없는 오류가 발생했습니다'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
```

### 6.3 Edge Function 특징

#### Deno 런타임
- **보안**: Node.js보다 강력한 보안 샌드박스
- **TypeScript 네이티브 지원**: 별도 컴파일 없이 TypeScript 실행
- **표준 라이브러리**: Deno.land에서 제공하는 표준 모듈 사용
- **환경 변수**: `Deno.env.get()` 으로 안전하게 접근

#### 환경 변수 설정
```bash
# Supabase 프로젝트 환경 변수 설정
supabase secrets set GEMINI_API_KEY=your_gemini_api_key_here
```

#### 배포
```bash
# Edge Function 배포
supabase functions deploy extract-schedule

# 배포 확인
supabase functions list
```

#### 로컬 테스트
```bash
# 로컬에서 Edge Function 실행
supabase functions serve extract-schedule

# cURL로 테스트
curl -i --location --request POST 'http://localhost:54321/functions/v1/extract-schedule' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"text":"홍길동\n010-1234-5678"}'
```

### 6.4 Gemini API 상세

#### API 엔드포인트
```
https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
```

#### 모델 선택
- **gemini-2.5-flash-lite**: 빠른 응답, 저비용 (현재 사용 중)
- **gemini-2.5-flash**: 균형잡힌 성능
- **gemini-2.5-pro**: 고성능, 복잡한 작업용

#### Request 구조
```json
{
  "contents": [
    {
      "parts": [
        {
          "text": "프롬프트 텍스트"
        }
      ]
    }
  ]
}
```

#### Response 구조
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {
            "text": "{\n  \"name\": \"홍길동\",\n  \"phone\": \"01012345678\"\n}"
          }
        ]
      },
      "finishReason": "STOP",
      "index": 0,
      "safetyRatings": [...]
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 123,
    "candidatesTokenCount": 45,
    "totalTokenCount": 168
  }
}
```

#### 프롬프트 엔지니어링

**핵심 전략**:
1. **명확한 형식 지정**: JSON 형식 요청, 예시 제공
2. **작업 목록 제한**: availableWorkItems로 선택지 제한하여 정확도 향상
3. **수량 처리**: "3개", "2건" 등의 수량을 배열 반복으로 변환
4. **Null 처리**: 값이 없으면 null 반환하도록 명시

**예시 프롬프트**:
```
다음 텍스트에서 스케줄 정보를 추출해주세요. 추출할 정보는 다음과 같습니다:
- 고객명 (name)
- 전화번호 (phone) - 숫자만 추출
- 주소 (address)
- 날짜 (date) - YYYY-MM-DD 형식
- 시간 (time) - HH:MM 형식 (24시간제)
- 작업 내용 (workItems) - 문자열 배열 형식. 아래 작업 목록에서만 선택하여 추출하세요.
  사용 가능한 작업 목록: ["1way 에어컨 세척", "2way 에어컨 세척", "실외기 세척"]
  예시: 텍스트에 "1way 에어컨 세척 3개"가 있으면 workItems: ["1way 에어컨 세척", "1way 에어컨 세척", "1way 에어컨 세척"]로 반환

JSON 형식으로만 응답해주세요. 값을 찾을 수 없는 경우 null을 사용하세요.
```

### 6.5 API 키 보안

#### 문제점
- Flutter 앱에 API 키를 하드코딩하면 디컴파일로 노출 위험
- 클라이언트에서 직접 API 호출 시 사용량 제어 불가

#### 해결책: Edge Functions
1. **API 키 숨김**: 서버 환경 변수에 저장
2. **요청 검증**: Supabase Auth로 인증된 사용자만 호출 가능 (선택적)
3. **사용량 제어**: Edge Function에서 rate limiting 적용 가능
4. **로깅**: 모든 API 호출 추적 가능

#### Supabase 환경 변수 설정
```bash
# 로컬 개발 (.env.local)
GEMINI_API_KEY=your_key_here

# 프로덕션 (Supabase Secrets)
supabase secrets set GEMINI_API_KEY=your_key_here
```

---

## 7. 사용량 제한 시스템

### 7.1 구현 위치
- 파일: `lib/utils/text_extraction_limit_helper.dart`

### 7.2 TextExtractionLimitHelper 클래스

```dart
import 'package:shared_preferences/shared_preferences.dart';

class TextExtractionLimitHelper {
  static const String _usageCountKey = 'text_extraction_usage_count';
  static const String _lastResetDateKey = 'text_extraction_last_reset_date';
  static const int monthlyLimit = 30;  // 월 30회 제한

  /// 이번 달 남은 사용 가능 횟수 반환
  static Future<int> getRemainingCount() async {
    await _resetIfNewMonth();
    final prefs = await SharedPreferences.getInstance();
    final usageCount = prefs.getInt(_usageCountKey) ?? 0;
    return monthlyLimit - usageCount;
  }

  /// 사용 횟수 증가 (성공 시 true, 제한 초과 시 false 반환)
  static Future<bool> incrementUsage() async {
    await _resetIfNewMonth();
    final prefs = await SharedPreferences.getInstance();
    final usageCount = prefs.getInt(_usageCountKey) ?? 0;

    if (usageCount >= monthlyLimit) {
      return false;  // 제한 초과
    }

    await prefs.setInt(_usageCountKey, usageCount + 1);
    return true;
  }

  /// 이번 달의 총 사용 횟수 반환
  static Future<int> getUsageCount() async {
    await _resetIfNewMonth();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_usageCountKey) ?? 0;
  }

  /// 새로운 달이 되었으면 사용 횟수 초기화
  static Future<void> _resetIfNewMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month}';
    final lastResetDate = prefs.getString(_lastResetDateKey);

    if (lastResetDate != currentMonthKey) {
      // 새로운 달이므로 초기화
      await prefs.setInt(_usageCountKey, 0);
      await prefs.setString(_lastResetDateKey, currentMonthKey);
    }
  }

  /// 사용 횟수 감소 (추출 실패 시 복구용)
  static Future<void> decrementUsage() async {
    await _resetIfNewMonth();
    final prefs = await SharedPreferences.getInstance();
    final usageCount = prefs.getInt(_usageCountKey) ?? 0;

    if (usageCount > 0) {
      await prefs.setInt(_usageCountKey, usageCount - 1);
    }
  }

  /// 테스트용: 사용 횟수 초기화
  static Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_usageCountKey, 0);
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month}';
    await prefs.setString(_lastResetDateKey, currentMonthKey);
  }
}
```

### 7.3 사용량 체크 흐름

```
앱 실행
   ↓
사용자가 추출 기능 클릭
   ↓
getRemainingCount() 호출
   ↓
_resetIfNewMonth() 내부 호출
   ↓
현재 달 = 마지막 리셋 달?
   ├─ YES → 현재 사용량 반환
   └─ NO → 사용량 0으로 초기화, 0 반환
   ↓
남은 횟수 UI에 표시
   ↓
사용자가 "추출하기" 클릭
   ↓
remaining > 0?
   ├─ YES → incrementUsage() 호출 → API 호출
   └─ NO → "사용 횟수 초과" 다이얼로그 표시
   ↓
API 호출 결과
   ├─ 성공 → 사용량 유지
   └─ 실패 → decrementUsage() 호출 (복구)
```

### 7.4 SharedPreferences 데이터 구조

```dart
// 저장되는 데이터
{
  'text_extraction_usage_count': 15,        // 이번 달 사용 횟수
  'text_extraction_last_reset_date': '2025-10'  // 마지막 리셋 날짜 (년-월)
}
```

### 7.5 월별 자동 초기화 로직

```dart
static Future<void> _resetIfNewMonth() async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final currentMonthKey = '${now.year}-${now.month}';  // 예: "2025-10"
  final lastResetDate = prefs.getString(_lastResetDateKey);

  if (lastResetDate != currentMonthKey) {
    // 새로운 달이므로 초기화
    await prefs.setInt(_usageCountKey, 0);
    await prefs.setString(_lastResetDateKey, currentMonthKey);
  }
}
```

**동작 예시**:
- 9월 30일: `lastResetDate = "2025-9"`, `usageCount = 28`
- 10월 1일: `currentMonthKey = "2025-10"` ≠ `"2025-9"` → 초기화
- 결과: `lastResetDate = "2025-10"`, `usageCount = 0`

### 7.6 에러 복구 메커니즘

```dart
// 추출 실패 시 사용량 복구
try {
  await TextExtractionLimitHelper.incrementUsage();

  // API 호출
  final result = await GeminiHelper.extractScheduleInfo(text);

  if (result == null) {
    // 실패 시 복구
    await TextExtractionLimitHelper.decrementUsage();
  }
} catch (e) {
  // 에러 발생 시 복구
  await TextExtractionLimitHelper.decrementUsage();
  rethrow;
}
```

---

## 8. 에러 처리

### 8.1 에러 유형 및 처리

#### 1. 이미지 선택 에러
```dart
try {
  selectedImage = await ImageTextExtractor.pickImageFromGallery();
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다')),
  );
  return;
}
```

**발생 원인**:
- 권한 거부
- 파일 시스템 오류
- 메모리 부족

#### 2. OCR 에러
```dart
try {
  final text = await ImageTextExtractor.extractTextFromImage(imagePath);
} on Exception catch (e) {
  final errorMessage = e.toString();

  if (errorMessage.contains('model') || errorMessage.contains('download')) {
    throw Exception('한글 인식 모델을 다운로드하는 중 오류가 발생했습니다.');
  }

  if (errorMessage.contains('MlKitException')) {
    throw Exception('ML Kit 초기화 오류가 발생했습니다. 앱을 재시작해주세요.');
  }

  throw Exception('텍스트 추출 중 오류가 발생했습니다');
}
```

**발생 원인**:
- 한글 모델 다운로드 실패 (인터넷 연결 문제)
- ML Kit 초기화 실패
- 이미지 파일 손상
- 파일 크기 초과 (10MB 제한)

#### 3. API 호출 에러
```dart
try {
  final response = await Supabase.instance.client.functions.invoke(
    'extract-schedule',
    body: {'text': text},
  );

  if (response.data == null) {
    return null;
  }

  final data = response.data as Map<String, dynamic>;

  if (data.containsKey('error')) {
    debugPrint('Edge Function 오류: ${data['error']}');
    return null;
  }

} catch (e) {
  debugPrint('API 호출 오류: $e');
  return null;
}
```

**발생 원인**:
- 네트워크 연결 문제
- Edge Function 오류
- Gemini API 키 오류
- Gemini API 할당량 초과
- JSON 파싱 실패

### 8.2 사용자 친화적 에러 메시지

```dart
// 사용 횟수 초과
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('사용 횟수 초과'),
    content: Text(
      '텍스트 추출 기능은 한 달에 30회까지 무료로 사용할 수 있습니다.\n\n'
      '이번 달 남은 횟수: 0회\n\n'
      '무제한으로 사용하려면 멤버십에 가입해주세요.',
    ),
  ),
);

// 이미지에서 텍스트를 찾을 수 없음
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('텍스트 추출 실패'),
    content: Text('이미지에서 텍스트를 찾을 수 없습니다.'),
  ),
);

// API 호출 실패
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('정보 추출에 실패했습니다. Gemini API 키를 확인해주세요.'),
    backgroundColor: Colors.red,
  ),
);
```

### 8.3 로깅 전략

```dart
// 단계별 디버그 로깅
debugPrint('📸 [ScheduleForm] Starting image selection');
debugPrint('✅ [ScheduleForm] Image selected: $imagePath');
debugPrint('🔍 [ScheduleForm] Starting OCR process');
debugPrint('✅ [ScheduleForm] OCR SUCCESS: ${text.length} chars');
debugPrint('🤖 [ScheduleForm] Calling Gemini API');
debugPrint('✅ [ScheduleForm] Successfully extracted data');

// Edge Function 로깅
console.log(`📥 [${requestId}] Request received`);
console.log(`🚀 [${requestId}] Calling Gemini API...`);
console.log(`📡 [${requestId}] Gemini response status: ${status}`);
console.log(`✅ [${requestId}] Successfully extracted data`);
console.error(`❌ [${requestId}] Gemini API 오류: ${error}`);
```

---

## 9. 데이터 구조

### 9.1 추출 데이터 형식

#### JSON 구조
```typescript
interface ExtractedScheduleData {
  name: string | null;          // 고객명
  phone: string | null;         // 전화번호 (숫자만)
  address: string | null;       // 주소
  date: string | null;          // 날짜 (YYYY-MM-DD)
  time: string | null;          // 시간 (HH:MM, 24시간제)
  workItems: string[] | null;   // 작업 내용 배열
}
```

#### 예시
```json
{
  "name": "홍길동",
  "phone": "01012345678",
  "address": "서울시 강남구 테헤란로 123",
  "date": "2025-10-15",
  "time": "14:00",
  "workItems": ["1way 에어컨 세척", "1way 에어컨 세척", "1way 에어컨 세척"]
}
```

### 9.2 작업 목록 데이터

#### availableWorkItems 구조
```dart
List<String> availableWorkItems = [
  "1way 에어컨 세척",
  "2way 에어컨 세척",
  "실외기 세척",
  "스탠드 에어컨 세척",
];
```

#### 작업 항목 매칭 로직
```dart
for (var extractedItem in extractedWorkItems) {
  final itemName = extractedItem.toString();

  // 1. 정확히 일치하는 항목 찾기
  final matchedWorkItem = _selectedCompany!.workItems.firstWhere(
    (workItem) => workItem.name == itemName,
    orElse: () {
      // 2. 유사한 항목 찾기 (대소문자 무시, 부분 일치)
      try {
        return _selectedCompany!.workItems.firstWhere(
          (workItem) =>
            workItem.name.toLowerCase().contains(itemName.toLowerCase()) ||
            itemName.toLowerCase().contains(workItem.name.toLowerCase()),
        );
      } catch (e) {
        // 3. 매칭 실패 시 첫 번째 항목 또는 새 항목
        return _selectedCompany!.workItems.isNotEmpty
          ? _selectedCompany!.workItems.first
          : WorkItem(name: itemName, price: 0);
      }
    },
  );

  // 작업 항목 카운트 증가
  _workItemsWithCount[matchedWorkItem.name] =
    (_workItemsWithCount[matchedWorkItem.name] ?? 0) + 1;
  _workPrices[matchedWorkItem.name] = matchedWorkItem.price;
}
```

### 9.3 폼 데이터 매핑

| 추출 데이터 | 폼 필드 | 변환 로직 |
|------------|--------|----------|
| name | _customerNameController | 그대로 입력 |
| phone | _phoneNumberController | 숫자만 추출 → `_formatPhoneNumber()` |
| address | _addressController | 그대로 입력 |
| date | _visitDate | `DateTime.parse()` → 과거 날짜는 오늘로 변경 |
| time | _visitTime | 그대로 입력 (HH:MM 형식) |
| workItems | _workItemsWithCount | 작업 목록 매칭 → 카운트 증가 |

---

## 10. 보안 고려사항

### 10.1 API 키 보안

#### ❌ 잘못된 방법
```dart
// Flutter 앱에 API 키 하드코딩 (절대 금지!)
const GEMINI_API_KEY = 'AIzaSyC...';  // 디컴파일로 노출됨
```

#### ✅ 올바른 방법
```typescript
// Edge Function에서 환경 변수로 관리
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
```

```bash
# Supabase Secrets로 안전하게 저장
supabase secrets set GEMINI_API_KEY=your_key_here
```

### 10.2 사용자 인증 (선택적)

#### Edge Function에서 인증 확인
```typescript
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // Authorization 헤더에서 JWT 토큰 추출
  const authHeader = req.headers.get('Authorization')

  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: '인증이 필요합니다' }),
      { status: 401, headers: corsHeaders }
    )
  }

  // Supabase 클라이언트로 사용자 확인
  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error } = await supabaseClient.auth.getUser()

  if (error || !user) {
    return new Response(
      JSON.stringify({ error: '유효하지 않은 토큰입니다' }),
      { status: 401, headers: corsHeaders }
    )
  }

  // 인증된 사용자만 API 호출 가능
  // ...
})
```

### 10.3 Rate Limiting (요청 제한)

#### Edge Function에서 제한
```typescript
// 간단한 in-memory rate limiting (예시)
const rateLimitMap = new Map<string, { count: number; resetTime: number }>()

function checkRateLimit(userId: string): boolean {
  const now = Date.now()
  const limit = rateLimitMap.get(userId)

  if (!limit || now > limit.resetTime) {
    // 1분마다 리셋, 최대 10회
    rateLimitMap.set(userId, { count: 1, resetTime: now + 60000 })
    return true
  }

  if (limit.count >= 10) {
    return false  // 제한 초과
  }

  limit.count++
  return true
}
```

### 10.4 데이터 검증

#### 클라이언트 측 검증
```dart
// 텍스트 길이 제한
if (text.length > 5000) {
  throw Exception('텍스트가 너무 깁니다. 5000자 이하로 입력해주세요.');
}

// 이미지 파일 크기 제한
if (fileSize > 10 * 1024 * 1024) {
  throw Exception('이미지 파일이 너무 큽니다. 10MB 이하의 이미지를 사용해주세요.');
}
```

#### 서버 측 검증
```typescript
// Edge Function에서 입력 검증
if (!text || typeof text !== 'string') {
  return new Response(
    JSON.stringify({ error: 'text 파라미터가 필요합니다' }),
    { status: 400, headers: corsHeaders }
  )
}

if (text.length > 10000) {
  return new Response(
    JSON.stringify({ error: '텍스트가 너무 깁니다' }),
    { status: 400, headers: corsHeaders }
  )
}
```

---

## 11. 성능 최적화

### 11.1 이미지 최적화

#### 이미지 압축
```dart
final XFile? image = await _picker.pickImage(
  source: ImageSource.gallery,
  imageQuality: 85,      // 85% 품질로 압축
  maxWidth: 2048,        // 최대 너비 2048px
  maxHeight: 2048,       // 최대 높이 2048px
);
```

**효과**:
- 원본: 5MB (4000x3000px) → 압축: 1.2MB (2048x1536px)
- OCR 처리 시간: 10초 → 4초
- 네트워크 전송 시간 단축 (필요 시)

### 11.2 OCR 최적화

#### ML Kit 모델 캐싱
```dart
static TextRecognizer? _textRecognizer;

static TextRecognizer _getTextRecognizer() {
  // 재사용 가능한 싱글톤 인스턴스
  _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
  return _textRecognizer!;
}
```

**효과**:
- 첫 실행: 한글 모델 다운로드 (10-20초)
- 이후 실행: 즉시 사용 가능 (캐싱됨)

#### 타임아웃 설정
```dart
final RecognizedText recognizedText = await recognizer
  .processImage(inputImage)
  .timeout(
    Duration(seconds: 45),
    onTimeout: () {
      throw Exception('텍스트 인식 시간이 초과되었습니다.');
    },
  );
```

### 11.3 API 호출 최적화

#### 경량 모델 사용
```typescript
const modelVersion = 'gemini-2.5-flash-lite'  // 빠른 응답, 저비용
```

**비교**:
| 모델 | 응답 시간 | 비용 | 정확도 |
|-----|---------|------|-------|
| gemini-2.5-flash-lite | 1-2초 | 최저 | 높음 |
| gemini-2.5-flash | 2-3초 | 중간 | 매우 높음 |
| gemini-2.5-pro | 3-5초 | 최고 | 최고 |

#### 프롬프트 최적화
```typescript
// 간결한 프롬프트 = 빠른 응답
const prompt = `다음 텍스트에서 스케줄 정보를 추출해주세요.
JSON 형식으로만 응답해주세요.
...`
```

### 11.4 UI 응답성

#### 로딩 다이얼로그
```dart
// 사용자에게 진행 상황 표시
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => Center(
    child: Card(
      child: Column(
        children: [
          CircularProgressIndicator(),
          Text('이미지에서 텍스트 추출 중...'),
          Text('처음 사용시 한글 모델을 다운로드합니다'),
        ],
      ),
    ),
  ),
);
```

#### 비동기 처리
```dart
// async/await로 UI 블로킹 방지
await Future.delayed(Duration(milliseconds: 500));  // 다이얼로그 표시 대기

final text = await ImageTextExtractor.extractTextFromImage(imagePath);

// 다음 단계 진행
```

### 11.5 메모리 관리

#### 리소스 정리
```dart
@override
void dispose() {
  // TextRecognizer 정리
  ImageTextExtractor.dispose();

  // Controller 정리
  _customerNameController.dispose();
  _phoneNumberController.dispose();
  // ...

  super.dispose();
}
```

#### 큰 이미지 처리 후 메모리 해제
```dart
try {
  final text = await ImageTextExtractor.extractTextFromImage(imagePath);

  // 처리 완료 후 이미지 파일 삭제 (필요 시)
  final file = File(imagePath);
  if (await file.exists()) {
    await file.delete();
  }
} catch (e) {
  // ...
}
```

---

## 12. 향후 개선 사항

### 12.1 멤버십 연동
- 무제한 사용 멤버십 옵션 제공
- 사용량 통계 대시보드
- 멤버십 구독 관리

### 12.2 정확도 향상
- 사용자 피드백 수집 ("추출 결과가 정확한가요?")
- Fine-tuning용 데이터셋 구축
- 업체별 작업 목록 자동 학습

### 12.3 다국어 지원
- 영어, 일본어, 중국어 지원
- 다국어 OCR 모델 선택

### 12.4 배치 처리
- 여러 이미지 동시 처리
- 엑셀/CSV 파일 업로드로 대량 등록

### 12.5 오프라인 지원
- OCR은 이미 오프라인 (ML Kit)
- Gemini API 대신 온디바이스 LLM 사용 (TFLite, ONNX)

---

## 부록: 개발 환경 설정

### A. Flutter 의존성
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  image_picker: ^1.0.0
  google_mlkit_text_recognition: ^0.11.0
  shared_preferences: ^2.2.0
```

### B. Supabase CLI 설치
```bash
# Windows (PowerShell)
iwr -useb https://supabase.com/install.ps1 | iex

# macOS/Linux
brew install supabase/tap/supabase
```

### C. Edge Function 로컬 테스트
```bash
# Supabase 프로젝트 링크
supabase link --project-ref your-project-ref

# Edge Function 실행
supabase functions serve extract-schedule --env-file .env.local

# 다른 터미널에서 테스트
curl -i --location --request POST 'http://localhost:54321/functions/v1/extract-schedule' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{"text":"홍길동\n010-1234-5678\n서울시 강남구"}'
```

### D. 환경 변수 설정
```bash
# 로컬 개발 (.env.local)
GEMINI_API_KEY=AIzaSyC...

# 프로덕션
supabase secrets set GEMINI_API_KEY=AIzaSyC...
```

---

## 문서 버전
- **버전**: 1.0
- **작성일**: 2026-01-09
- **작성자**: Claude AI Assistant
- **마지막 업데이트**: 2026-01-09
