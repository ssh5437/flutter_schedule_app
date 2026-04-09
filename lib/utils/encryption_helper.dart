import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class EncryptionHelper {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'app_encryption_key';
  static const _saltName = 'app_encryption_salt';
  static const _hasPasswordName = 'has_user_password';
  static const _verificationName = 'password_verification';
  static Key? _cachedKey;

  /// 사용자 비밀번호로부터 암호화 키 생성 (PBKDF2)
  static Future<Key> _deriveKeyFromPassword(String password, Uint8List salt) async {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));

    pbkdf2.init(Pbkdf2Parameters(
      salt,
      100000, // 반복 횟수 (보안 강도)
      32, // 키 길이 (256비트)
    ));

    final key = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
    return Key(key);
  }

  /// Salt 생성 또는 로드
  static Future<Uint8List> _getOrCreateSalt() async {
    String? storedSalt = await _storage.read(key: _saltName);

    if (storedSalt == null) {
      // 새로운 Salt 생성
      final random = Random.secure();
      final salt = Uint8List.fromList(
        List<int>.generate(16, (i) => random.nextInt(256))
      );
      storedSalt = base64.encode(salt);
      await _storage.write(key: _saltName, value: storedSalt);
      return salt;
    }

    return Uint8List.fromList(base64.decode(storedSalt));
  }

  /// 사용자가 비밀번호를 설정했는지 확인
  static Future<bool> hasUserPassword() async {
    final value = await _storage.read(key: _hasPasswordName);
    return value == 'true';
  }

  /// 사용자 비밀번호 설정
  static Future<void> setUserPassword(String password) async {
    final salt = await _getOrCreateSalt();
    final key = await _deriveKeyFromPassword(password, salt);

    // 검증용 데이터 생성 (비밀번호 확인용)
    final verificationData = 'password_verification_${DateTime.now().millisecondsSinceEpoch}';
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(verificationData, iv: iv);

    // 검증 데이터 저장
    await _storage.write(
      key: _verificationName,
      value: '${iv.base64}:${encrypted.base64}:$verificationData'
    );

    // 생성된 키를 저장
    await _storage.write(key: _keyName, value: base64.encode(key.bytes));
    await _storage.write(key: _hasPasswordName, value: 'true');

    _cachedKey = key;
  }

  /// 사용자 비밀번호로 키 복원 및 검증
  static Future<bool> unlockWithPassword(String password) async {
    try {
      final salt = await _getOrCreateSalt();
      final key = await _deriveKeyFromPassword(password, salt);

      // 저장된 검증 데이터로 비밀번호 확인
      final verificationData = await _storage.read(key: _verificationName);
      if (verificationData == null) {
        return false;
      }

      final parts = verificationData.split(':');
      if (parts.length != 3) return false;

      final iv = IV.fromBase64(parts[0]);
      final encrypter = Encrypter(AES(key));
      final decrypted = encrypter.decrypt64(parts[1], iv: iv);

      // 복호화된 데이터가 원본과 일치하는지 확인
      if (decrypted == parts[2]) {
        _cachedKey = key;
        await _storage.write(key: _keyName, value: base64.encode(key.bytes));
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  /// 비밀번호 변경
  static Future<bool> changePassword(String oldPassword, String newPassword) async {
    // 기존 비밀번호 확인
    final isValid = await unlockWithPassword(oldPassword);
    if (!isValid) return false;

    // 새 비밀번호로 키 재생성
    await setUserPassword(newPassword);
    return true;
  }

  /// 기존 방식과 호환되는 키 로드
  static Future<Key> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    // 사용자 비밀번호가 설정되어 있는지 확인
    final hasPassword = await hasUserPassword();

    if (hasPassword) {
      // 비밀번호 기반 키 사용
      String? storedKey = await _storage.read(key: _keyName);
      if (storedKey != null) {
        _cachedKey = Key.fromBase64(storedKey);
        return _cachedKey!;
      }

      // 키가 없으면 에러 (앱 잠금 상태)
      throw Exception('App is locked. Please unlock with password.');
    }

    // 기존 방식: 랜덤 키 생성 (마이그레이션용)
    String? storedKey = await _storage.read(key: _keyName);
    if (storedKey == null) {
      final random = Random.secure();
      final keyBytes = Uint8List.fromList(
        List<int>.generate(32, (i) => random.nextInt(256))
      );
      storedKey = base64.encode(keyBytes);
      await _storage.write(key: _keyName, value: storedKey);
    }

    _cachedKey = Key.fromBase64(storedKey);
    return _cachedKey!;
  }

  /// 키를 미리 로드하여 첫 번째 암복호화 지연을 제거
  static Future<void> warmUp() async {
    await _getOrCreateKey();
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

  /// 앱 잠금 (캐시된 키 삭제)
  static void lock() {
    _cachedKey = null;
  }

  /// 테스트용: 모든 데이터 삭제 (개발 중에만 사용)
  static Future<void> resetAll() async {
    await _storage.deleteAll();
    _cachedKey = null;
  }
}
