import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ImageTextExtractor {
  static final ImagePicker _picker = ImagePicker();

  // TextRecognizer 인스턴스를 동적으로 생성
  static TextRecognizer? _textRecognizer;

  static TextRecognizer _getTextRecognizer() {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.korean);
    return _textRecognizer!;
  }

  /// 갤러리에서 이미지 선택
  static Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// 카메라로 사진 촬영
  static Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// 이미지에서 텍스트 추출 (OCR)
  static Future<String> extractTextFromImage(String imagePath) async {
    try {
      final recognizer = _getTextRecognizer();
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);

      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }

      debugPrint('Extracted text: $extractedText');
      return extractedText.trim();
    } catch (e) {
      debugPrint('Error extracting text from image: $e');
      rethrow;
    }
  }

  /// 리소스 정리
  static Future<void> dispose() async {
    await _textRecognizer?.close();
  }
}
