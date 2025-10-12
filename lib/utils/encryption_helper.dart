import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionHelper {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'app_encryption_key';
  static Key? _cachedKey;

  /// 앱 최초 실행 시 키 생성 또는 기존 키 로드
  static Future<Key> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    // 저장된 키가 있는지 확인
    String? storedKey = await _storage.read(key: _keyName);

    if (storedKey == null) {
      // 없으면 새로운 랜덤 키 생성 (32바이트)
      final random = Random.secure();
      final keyBytes = Uint8List.fromList(
        List<int>.generate(32, (i) => random.nextInt(256))
      );
      storedKey = base64.encode(keyBytes);

      // 안전한 저장소에 저장
      await _storage.write(key: _keyName, value: storedKey);
    }

    _cachedKey = Key.fromBase64(storedKey);
    return _cachedKey!;
  }

  /// 문자열을 암호화
  static Future<String> encrypt(String plainText) async {
    if (plainText.isEmpty) return '';
    try {
      final key = await _getOrCreateKey();
      final iv = IV.fromLength(16);
      final encrypter = Encrypter(AES(key));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // IV와 암호화된 데이터를 함께 저장 (형식: "IV:암호화된데이터")
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      // 오류 발생 시 원본 반환
      return plainText;
    }
  }

  /// 암호화된 문자열을 복호화
  static Future<String> decrypt(String encryptedText) async {
    if (encryptedText.isEmpty) return '';
    try {
      // 구분자로 IV와 암호화된 데이터 분리
      final parts = encryptedText.split(':');
      if (parts.length != 2) {
        // 구분자가 없으면 암호화되지 않은 데이터 (기존 데이터)
        return encryptedText;
      }

      final key = await _getOrCreateKey();
      final iv = IV.fromBase64(parts[0]);
      final encrypter = Encrypter(AES(key));

      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (e) {
      // 오류 발생 시 원본 반환 (암호화되지 않은 데이터일 수 있음)
      return encryptedText;
    }
  }

  /// 복호화 가능 여부 확인 (IV:데이터 형식인지 체크)
  static bool isEncrypted(String text) {
    if (text.isEmpty) return false;
    try {
      // "IV:데이터" 형식인지 확인
      final parts = text.split(':');
      if (parts.length != 2) return false;

      // Base64로 디코딩 가능한지 확인
      base64.decode(parts[0]);
      base64.decode(parts[1]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 테스트용: 저장된 키 삭제 (개발 중에만 사용)
  static Future<void> deleteKey() async {
    await _storage.delete(key: _keyName);
    _cachedKey = null;
  }
}
