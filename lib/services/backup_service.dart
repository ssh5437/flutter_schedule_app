import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/schedule.dart';
import '../models/company.dart';

class BackupService {
  // 백업 데이터 생성
  Future<Map<String, dynamic>> createBackupData() async {
    final db = DatabaseHelper.instance;

    // 모든 스케줄 조회
    final schedules = await db.readAllSchedules();

    // 모든 업체 조회
    final companies = await db.readAllCompanies();

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
  Future<Map<String, int>> restoreBackup(String filePath, {bool replaceAll = false}) async {
    try {
      final backupData = await readBackupFile(filePath);
      final db = DatabaseHelper.instance;

      int schedulesImported = 0;
      int companiesImported = 0;

      // 전체 교체 모드인 경우 기존 데이터 삭제
      if (replaceAll) {
        // 모든 스케줄 삭제
        final existingSchedules = await db.readAllSchedules();
        for (final schedule in existingSchedules) {
          if (schedule.id != null) {
            await db.deleteSchedule(schedule.id!);
          }
        }

        // 모든 업체 삭제 (기본 업체 제외)
        final existingCompanies = await db.readAllCompanies();
        for (final company in existingCompanies) {
          if (company.id != null && company.name != '개인') {
            await db.deleteCompany(company.id!);
          }
        }
      }

      // 업체 복구
      if (backupData.containsKey('companies')) {
        final companies = backupData['companies'] as List<dynamic>;
        for (final companyMap in companies) {
          try {
            final company = Company.fromMap(companyMap as Map<String, dynamic>);

            // 중복 확인
            final existing = await db.readCompanyByName(company.name);
            if (existing == null) {
              await db.createCompany(company);
              companiesImported++;
            } else if (replaceAll) {
              // 교체 모드에서는 업데이트
              await db.updateCompany(company.copyWith(id: existing.id));
              companiesImported++;
            }
          } catch (e) {
            // 개별 업체 복구 실패는 무시하고 계속 진행
            print('업체 복구 실패: $e');
          }
        }
      }

      // 스케줄 복구
      if (backupData.containsKey('schedules')) {
        final schedules = backupData['schedules'] as List<dynamic>;
        for (final scheduleMap in schedules) {
          try {
            final schedule = Schedule.fromMap(scheduleMap as Map<String, dynamic>);
            await db.createSchedule(schedule);
            schedulesImported++;
          } catch (e) {
            // 개별 스케줄 복구 실패는 무시하고 계속 진행
            print('스케줄 복구 실패: $e');
          }
        }
      }

      return {
        'schedules': schedulesImported,
        'companies': companiesImported,
      };
    } catch (e) {
      throw Exception('백업 복구 실패: $e');
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
