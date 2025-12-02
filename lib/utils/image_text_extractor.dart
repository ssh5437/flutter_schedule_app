
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

class ImageTextExtractor {
  static final ImagePicker _picker = ImagePicker();

  // TextRecognizer 인스턴스를 동적으로 생성
  static TextRecognizer? _textRecognizer;

  static TextRecognizer _getTextRecognizer() {
    try {
      _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
      return _textRecognizer!;
    } catch (e) {
      debugPrint('Error creating TextRecognizer: $e');
      rethrow;
    }
  }

  /// 갤러리에서 이미지 선택
  static Future<XFile?> pickImageFromGallery() async {
    try {
      debugPrint('📷 Starting gallery picker...');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      ).timeout(
        const Duration(seconds: 60),
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
      } else {
        debugPrint('ℹ️ No image selected from gallery');
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
        preferredCameraDevice: CameraDevice.rear,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('⏱️ Camera timed out');
          return null;
        },
      );

      if (image != null) {
        debugPrint('✅ Camera image captured: ${image.path}');
        // 파일 존재 여부 확인
        final file = File(image.path);
        if (!await file.exists()) {
          debugPrint('❌ Captured file does not exist');
          return null;
        }
        final fileSize = await file.length();
        debugPrint('📊 File size: ${fileSize / 1024} KB');
      } else {
        debugPrint('ℹ️ No image captured from camera');
      }

      return image;
    } catch (e, stackTrace) {
      debugPrint('❌ Error picking image from camera: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// 이미지에서 텍스트 추출 (OCR)
  static Future<String> extractTextFromImage(String imagePath) async {
    TextRecognizer? recognizer;

    try {
      debugPrint('🔍 Starting OCR process...');

      // 이미지 파일 존재 여부 확인
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('이미지 파일을 찾을 수 없습니다');
      }

      final fileSize = await imageFile.length();
      debugPrint('📊 Image file size: ${fileSize / 1024} KB');

      // 파일 크기 제한 (10MB)
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('이미지 파일이 너무 큽니다. 10MB 이하의 이미지를 사용해주세요.');
      }

      debugPrint('🔧 Initializing TextRecognizer...');
      recognizer = _getTextRecognizer();

      debugPrint('📸 Creating InputImage...');
      final inputImage = InputImage.fromFilePath(imagePath);

      debugPrint('🤖 Processing image for text recognition...');
      final RecognizedText recognizedText = await recognizer.processImage(inputImage)
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw Exception('텍스트 인식 시간이 초과되었습니다. 더 작은 이미지를 사용해주세요.');
            },
          );

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

      // 모델 다운로드 관련 에러인 경우 더 명확한 메시지 제공
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
      debugPrint('Stack trace: $stackTrace');
      throw Exception('예상치 못한 오류가 발생했습니다: ${e.toString()}');
    }
  }

  /// 리소스 정리
  static Future<void> dispose() async {
    await _textRecognizer?.close();
  }
}
