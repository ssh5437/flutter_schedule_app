import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/schedule.dart';
import '../models/company.dart';

class BackupService {
  // 백업 데이터 생성
  Future<Map<String, dynamic>> createBackupData() async {
    final db = DatabaseHelper.instance;
    final userId = Supabase.instance.client.auth.currentUser!.id;

    // 모든 스케줄 조회
    final schedules = await db.readAllSchedules(userId);

    // 모든 업체 조회
    final companies = await db.readAllCompanies(userId);

    // JSON 형식으로 변환
    final backupData = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'schedules': schedules.map((s) => s.toMap()).toList(),
      'companies': companies.map((c) => c.toMap()).toList(),
    };

    return backupData;
  }

  // 백업 파일 생성 및 공유
  Future<File> exportBackup() async {
    try {
      // 백업 데이터 생성
      final backupData = await createBackupData();

      // JSON 문자열로 변환
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);

      // 임시 디렉토리 가져오기
      final tempDir = await getTemporaryDirectory();

      // 파일명 생성 (날짜 포함)
      final fileName = 'schedule_backup_${DateTime.now().toString().replaceAll(':', '-').replaceAll(' ', '_').substring(0, 19)}.json';
      final file = File('${tempDir.path}/$fileName');

      // 파일 저장
      await file.writeAsString(jsonString);

      return file;
    } catch (e) {
      throw Exception('백업 파일 생성 실패: $e');
    }
  }

  // 백업 파일 공유하기
  Future<void> shareBackup() async {
    try {
      final file = await exportBackup();

      // 파일 공유
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '스케줄 백업 파일',
        text: '스케줄 관리 앱 백업 데이터입니다.',
      );
    } catch (e) {
      throw Exception('백업 파일 공유 실패: $e');
    }
  }

  // 백업 파일 다운로드 (Downloads 폴더에 저장)
  Future<String> downloadBackup() async {
    try {
      final file = await exportBackup();

      // 다운로드 디렉토리 가져오기
      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      // 파일명
      final fileName = 'schedule_backup_${DateTime.now().toString().replaceAll(':', '-').replaceAll(' ', '_').substring(0, 19)}.json';
      final downloadPath = '${downloadDir.path}/$fileName';

      // 파일 복사
      await file.copy(downloadPath);

      return downloadPath;
    } catch (e) {
      throw Exception('백업 파일 다운로드 실패: $e');
    }
  }

  // 백업 파일에서 데이터 읽기
  Future<Map<String, dynamic>> readBackupFile(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw Exception('백업 파일을 찾을 수 없습니다');
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // 버전 확인
      if (!backupData.containsKey('version')) {
        throw Exception('유효하지 않은 백업 파일입니다');
      }

      return backupData;
    } catch (e) {
      throw Exception('백업 파일 읽기 실패: $e');
    }
  }

  // 백업 복구 (기존 데이터 유지하고 추가)
  Future<Map<String, dynamic>> restoreBackup(String filePath, {bool replaceAll = false}) async {
    try {
      final backupData = await readBackupFile(filePath);
      final db = DatabaseHelper.instance;
      final userId = Supabase.instance.client.auth.currentUser!.id;

      int schedulesImported = 0;
      int companiesImported = 0;
      int schedulesFailed = 0;
      int companiesFailed = 0;
      final List<String> errors = [];

      // 전체 교체 모드인 경우 기존 데이터 삭제
      if (replaceAll) {
        // 모든 스케줄 삭제
        final existingSchedules = await db.readAllSchedules(userId);
        for (final schedule in existingSchedules) {
          if (schedule.id != null) {
            await db.deleteSchedule(userId, schedule.id!);
          }
        }

        // 모든 업체 삭제 (기본 업체 제외)
        final existingCompanies = await db.readAllCompanies(userId);
        for (final company in existingCompanies) {
          if (company.id != null && company.name != '개인') {
            await db.deleteCompany(userId, company.id!);
          }
        }
      }

      // 업체 복구
      if (backupData.containsKey('companies')) {
        final companies = backupData['companies'] as List<dynamic>;
        for (int i = 0; i < companies.length; i++) {
          try {
            final companyMap = companies[i] as Map<String, dynamic>;
            // userId를 현재 사용자 ID로 덮어쓰기
            companyMap['userId'] = userId;
            final company = Company.fromMap(companyMap);

            // 중복 확인
            final existing = await db.readCompanyByName(userId, company.name);
            if (existing == null) {
              await db.createCompany(company);
              companiesImported++;
            } else if (replaceAll) {
              // 교체 모드에서는 업데이트
              await db.updateCompany(company.copyWith(id: existing.id, userId: userId));
              companiesImported++;
            }
          } catch (e) {
            // 개별 업체 복구 실패
            companiesFailed++;
            errors.add('업체 ${i + 1} 복구 실패: $e');
            print('업체 복구 실패: $e');
          }
        }
      }

      // 스케줄 복구
      if (backupData.containsKey('schedules')) {
        final schedules = backupData['schedules'] as List<dynamic>;
        for (int i = 0; i < schedules.length; i++) {
          try {
            final scheduleMap = schedules[i] as Map<String, dynamic>;

            // DateTime 파싱 처리 개선
            final requestDateStr = scheduleMap['requestDate'] as String;
            final visitDateStr = scheduleMap['visitDate'] as String?;

            // 안전한 DateTime 파싱
            scheduleMap['requestDate'] = _parseDateTime(requestDateStr).toIso8601String();
            if (visitDateStr != null) {
              scheduleMap['visitDate'] = _parseDateTime(visitDateStr).toIso8601String();
            }

            // userId를 현재 사용자 ID로 덮어쓰기
            scheduleMap['userId'] = userId;

            final schedule = Schedule.fromMap(scheduleMap);
            await db.createSchedule(schedule);
            schedulesImported++;
          } catch (e) {
            // 개별 스케줄 복구 실패
            schedulesFailed++;
            final customerName = (schedules[i] as Map<String, dynamic>)['customerName'] ?? '알 수 없음';
            errors.add('스케줄 "$customerName" 복구 실패: $e');
            print('스케줄 복구 실패: $e');
          }
        }
      }

      return {
        'schedules': schedulesImported,
        'companies': companiesImported,
        'schedulesFailed': schedulesFailed,
        'companiesFailed': companiesFailed,
        'errors': errors,
      };
    } catch (e) {
      throw Exception('백업 복구 실패: $e');
    }
  }

  // DateTime 파싱 헬퍼 (밀리초 처리)
  DateTime _parseDateTime(String dateStr) {
    try {
      // ISO 8601 형식 파싱 (.000 밀리초 포함)
      return DateTime.parse(dateStr);
    } catch (e) {
      // 파싱 실패 시 밀리초 제거 후 재시도
      final cleanStr = dateStr.replaceAll(RegExp(r'\.\d{3}'), '');
      return DateTime.parse(cleanStr);
    }
  }

  // 파일 선택기로 백업 파일 선택
  Future<String?> pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path!;
      }

      return null;
    } catch (e) {
      throw Exception('파일 선택 실패: $e');
    }
  }

  // 백업 파일 정보 조회
  Future<Map<String, dynamic>> getBackupInfo(String filePath) async {
    try {
      final backupData = await readBackupFile(filePath);

      final schedulesCount = (backupData['schedules'] as List?)?.length ?? 0;
      final companiesCount = (backupData['companies'] as List?)?.length ?? 0;
      final exportDate = backupData['exportDate'] as String?;

      return {
        'schedulesCount': schedulesCount,
        'companiesCount': companiesCount,
        'exportDate': exportDate != null ? DateTime.parse(exportDate) : null,
        'version': backupData['version'],
      };
    } catch (e) {
      throw Exception('백업 정보 조회 실패: $e');
    }
  }
}
