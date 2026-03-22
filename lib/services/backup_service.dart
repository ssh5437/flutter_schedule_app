import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import '../database/database_helper.dart';
import '../models/schedule.dart';
import '../models/company.dart';
import '../models/date_memo.dart';
import '../models/message_template.dart';

class BackupService {
  // 앱 전용 비밀 키 (실제 배포 시에는 더 안전한 방법으로 관리해야 함)
  static const String _secretKey = 'bizplan_backup_secret_key_v1_2025';


  // 백업 데이터에 서명 생성
  String _generateSignature(Map<String, dynamic> data) {
    // signature 필드를 제외한 데이터를 정렬된 JSON 문자열로 변환
    final dataWithoutSignature = Map<String, dynamic>.from(data);
    dataWithoutSignature.remove('signature');

    // 정렬된 JSON 문자열 생성 (일관성을 위해)
    final sortedKeys = dataWithoutSignature.keys.toList()..sort();
    final sortedData = <String, dynamic>{};
    for (final key in sortedKeys) {
      sortedData[key] = dataWithoutSignature[key];
    }

    final jsonString = jsonEncode(sortedData);

    // HMAC-SHA256으로 서명 생성
    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(jsonString);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    return digest.toString();
  }

  // 백업 파일 서명 검증
  bool _verifySignature(Map<String, dynamic> data) {
    if (!data.containsKey('signature')) {
      return false;
    }

    final providedSignature = data['signature'] as String;
    final calculatedSignature = _generateSignature(data);

    return providedSignature == calculatedSignature;
  }

  // 백업 가능 여부 확인 (제한 없음)
  Future<Map<String, dynamic>> checkBackupLimit() async {
    return {
      'canBackup': true,
      'isPremium': true,
    };
  }

  // 백업 데이터 생성 (기간 필터 추가)
  Future<Map<String, dynamic>> createBackupData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = DatabaseHelper.instance;
    final userId = Supabase.instance.client.auth.currentUser!.id;

    // 모든 스케줄 조회
    var schedules = await db.readAllSchedules(userId);

    // 기간 필터링 (startDate와 endDate가 제공된 경우, visitDate가 있는 것만)
    if (startDate != null || endDate != null) {
      schedules = schedules.where((schedule) {
        if (schedule.visitDate == null) return false;

        // startDate 체크
        if (startDate != null && schedule.visitDate!.isBefore(startDate)) {
          return false;
        }

        // endDate 체크 (endDate의 23:59:59까지 포함)
        if (endDate != null) {
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          if (schedule.visitDate!.isAfter(endOfDay)) {
            return false;
          }
        }

        return true;
      }).toList();
    }

    // 모든 업체 조회
    final companies = await db.readAllCompanies(userId);

    // 모든 날짜별 메모 조회
    final memos = await db.readAllMemos(userId);

    // 모든 메시지 템플릿 조회
    final messageTemplates = await db.readAllMessageTemplatesForUser(userId);

    // JSON 형식으로 변환
    final backupData = {
      'version': '1.2', // 메시지 템플릿 추가로 버전 업
      'exportDate': DateTime.now().toIso8601String(),
      'schedules': schedules.map((s) => s.toMap()).toList(),
      'companies': companies.map((c) => c.toMap()).toList(),
      'memos': memos.map((m) => m.toMap()).toList(),
      'messageTemplates': messageTemplates.map((t) => t.toMap()).toList(),
    };

    // 서명 추가
    backupData['signature'] = _generateSignature(backupData);

    return backupData;
  }

  // 백업 파일 생성 및 공유
  Future<File> exportBackup({DateTime? startDate, DateTime? endDate}) async {
    try {
      // 백업 데이터 생성
      final backupData = await createBackupData(startDate: startDate, endDate: endDate);

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
  Future<void> shareBackup({DateTime? startDate, DateTime? endDate}) async {
    try {
      final file = await exportBackup(startDate: startDate, endDate: endDate);

      // 파일 공유
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '스케줄 백업 파일',
        text: 'B-EZ 앱 백업 데이터입니다.',
      );
    } catch (e) {
      throw Exception('백업 파일 공유 실패: $e');
    }
  }

  // 백업 파일 다운로드 (Downloads 폴더에 저장)
  Future<String> downloadBackup({DateTime? startDate, DateTime? endDate}) async {
    try {
      final file = await exportBackup(startDate: startDate, endDate: endDate);

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
  Future<Map<String, dynamic>> readBackupFile(String filePath, {bool bypassSignature = false}) async {
    try {
      final startTime = DateTime.now();
      debugPrint('========================================');
      debugPrint('📂 백업 파일 읽기 시작');
      debugPrint('파일 경로: $filePath');

      final file = File(filePath);

      if (!await file.exists()) {
        debugPrint('❌ 파일이 존재하지 않음');
        throw Exception('백업 파일을 찾을 수 없습니다');
      }

      final afterExistsCheck = DateTime.now();
      debugPrint('✅ 파일 존재 확인 (${afterExistsCheck.difference(startTime).inMilliseconds}ms)');

      final jsonString = await file.readAsString();
      final afterReadString = DateTime.now();
      debugPrint('✅ JSON 문자열 읽기 완료 (${jsonString.length} 바이트, ${afterReadString.difference(afterExistsCheck).inMilliseconds}ms)');

      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;
      final afterJsonDecode = DateTime.now();
      debugPrint('✅ JSON 파싱 완료 (${afterJsonDecode.difference(afterReadString).inMilliseconds}ms)');

      // 버전 확인
      if (!backupData.containsKey('version')) {
        debugPrint('❌ version 필드 없음');
        throw Exception('유효하지 않은 백업 파일입니다');
      }

      debugPrint('✅ 버전: ${backupData['version']}');
      debugPrint('✅ 스케줄 개수: ${(backupData['schedules'] as List?)?.length ?? 0}');
      debugPrint('✅ 업체 개수: ${(backupData['companies'] as List?)?.length ?? 0}');

      // 서명 검증 (bypassSignature가 true이면 건너뜀)
      if (!bypassSignature && !_verifySignature(backupData)) {
        throw Exception('서명 불일치: 파일이 수정되었거나 앱 외부에서 생성된 파일입니다.\n직접 편집 복구를 사용하세요.');
      }
      if (bypassSignature) {
        debugPrint('⚠️ 서명 검증 우회 모드 - 직접 편집 복구');
      }

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('✅ 백업 파일 읽기 완료 (총 ${totalTime}ms)');
      debugPrint('========================================');
      return backupData;
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('❌ 백업 파일 읽기 실패');
      debugPrint('에러: $e');
      debugPrint('스택트레이스: $stackTrace');
      debugPrint('========================================');
      rethrow;
    }
  }

  // 백업 복구 (기존 데이터 유지하고 추가)
  Future<Map<String, dynamic>> restoreBackup(String filePath, {bool replaceAll = false, bool bypassSignature = false, Map<String, dynamic>? cachedData}) async {
    try {
      final restoreStartTime = DateTime.now();
      debugPrint('========================================');
      debugPrint('🔄 restoreBackup 시작 (replaceAll: $replaceAll)');

      // 캐싱된 데이터가 있으면 사용, 없으면 파일 읽기
      final backupData = cachedData ?? await readBackupFile(filePath, bypassSignature: bypassSignature);
      final afterDataLoad = DateTime.now();
      debugPrint('✅ 백업 데이터 로드 완료 (${afterDataLoad.difference(restoreStartTime).inMilliseconds}ms)');

      final db = DatabaseHelper.instance;
      final userId = Supabase.instance.client.auth.currentUser!.id;

      int schedulesImported = 0;
      int companiesImported = 0;
      int schedulesFailed = 0;
      int companiesFailed = 0;
      final List<String> errors = [];
      // 백업 업체 ID → 복구 후 실제 업체 ID 매핑
      final Map<int, int> companyIdMap = {};

      // 전체 교체 모드인 경우 기존 데이터 삭제
      if (replaceAll) {
        final deleteStartTime = DateTime.now();
        debugPrint('🗑️ 기존 데이터 삭제 시작...');

        // 모든 스케줄 삭제
        final existingSchedules = await db.readAllSchedules(userId);
        debugPrint('📋 삭제할 스케줄: ${existingSchedules.length}개');

        for (int i = 0; i < existingSchedules.length; i++) {
          final schedule = existingSchedules[i];
          if (schedule.id != null) {
            await db.deleteSchedule(userId, schedule.id!);
            if ((i + 1) % 50 == 0 || i == existingSchedules.length - 1) {
              debugPrint('  스케줄 삭제 중... ${i + 1}/${existingSchedules.length}');
            }
          }
        }

        // 모든 업체 삭제 (기본 업체 제외)
        final existingCompanies = await db.readAllCompanies(userId);
        final companiesToDelete = existingCompanies.where((c) => c.name != '개인').toList();
        debugPrint('🏢 삭제할 업체: ${companiesToDelete.length}개');

        for (final company in companiesToDelete) {
          if (company.id != null) {
            await db.deleteCompany(userId, company.id!);
          }
        }

        final deleteEndTime = DateTime.now();
        debugPrint('✅ 기존 데이터 삭제 완료 (${deleteEndTime.difference(deleteStartTime).inMilliseconds}ms)');
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
              final newId = await db.createCompany(company);
              if (company.id != null) companyIdMap[company.id!] = newId;
              companiesImported++;
            } else if (replaceAll) {
              // 교체 모드에서는 업데이트 (색상 포함)
              await db.updateCompany(company.copyWith(
                id: existing.id,
                userId: userId,
                color: company.color,
                displayOrder: company.displayOrder,
              ));
              if (company.id != null) companyIdMap[company.id!] = existing.id!;
              companiesImported++;
            } else {
              // 병합 모드에서도 색상과 작업 항목 업데이트
              await db.updateCompany(company.copyWith(
                id: existing.id,
                userId: userId,
                color: company.color,
                displayOrder: company.displayOrder,
              ));
              if (company.id != null) companyIdMap[company.id!] = existing.id!;
              companiesImported++;
            }
          } catch (e) {
            // 개별 업체 복구 실패
            companiesFailed++;
            errors.add('업체 ${i + 1} 복구 실패: $e');
            debugPrint('업체 복구 실패: $e');
          }
        }
      }

      // 스케줄 복구
      if (backupData.containsKey('schedules')) {
        final schedules = backupData['schedules'] as List<dynamic>;
        debugPrint('========================================');
        debugPrint('📦 스케줄 복구 시작: 총 ${schedules.length}개');
        debugPrint('========================================');
        for (int i = 0; i < schedules.length; i++) {
          try {
            final scheduleMap = schedules[i] as Map<String, dynamic>;

            // DateTime 파싱 처리 개선
            // 구 버전 백업 호환: requestDate가 있으면 visitDate로 이전
            final requestDateStr = scheduleMap['requestDate'];
            final visitDateStr = scheduleMap['visitDate'];

            // visitDate 파싱 (선택, 없으면 구 버전의 requestDate 사용)
            if (visitDateStr != null && visitDateStr.toString().isNotEmpty && visitDateStr.toString() != 'null') {
              try {
                scheduleMap['visitDate'] = _parseDateTime(visitDateStr.toString()).toIso8601String();
              } catch (e) {
                // visitDate 파싱 실패 시 requestDate로 대체
                if (requestDateStr != null && requestDateStr.toString().isNotEmpty) {
                  scheduleMap['visitDate'] = _parseDateTime(requestDateStr.toString()).toIso8601String();
                } else {
                  scheduleMap['visitDate'] = null;
                }
              }
            } else if (requestDateStr != null && requestDateStr.toString().isNotEmpty) {
              // visitDate가 없고 requestDate가 있는 경우 (구 버전 백업)
              scheduleMap['visitDate'] = _parseDateTime(requestDateStr.toString()).toIso8601String();
            } else {
              scheduleMap['visitDate'] = null;
            }

            // requestDate는 더 이상 사용하지 않으므로 제거
            scheduleMap.remove('requestDate');

            // userId를 현재 사용자 ID로 덮어쓰기
            scheduleMap['userId'] = userId;

            // visitTime null 처리
            if (scheduleMap['visitTime'] == null || scheduleMap['visitTime'].toString() == 'null') {
              scheduleMap['visitTime'] = null;
            }

            // notes null 처리
            if (scheduleMap['notes'] == null || scheduleMap['notes'].toString() == 'null') {
              scheduleMap['notes'] = null;
            }

            // companyName null 처리
            if (scheduleMap['companyName'] == null || scheduleMap['companyName'].toString() == 'null') {
              scheduleMap['companyName'] = null;
            }

            // address null 처리
            if (scheduleMap['address'] == null || scheduleMap['address'].toString() == 'null' || scheduleMap['address'].toString().isEmpty) {
              scheduleMap['address'] = null;
            }

            // jibunAddress null 처리
            if (scheduleMap['jibunAddress'] == null || scheduleMap['jibunAddress'].toString() == 'null' || scheduleMap['jibunAddress'].toString().isEmpty) {
              scheduleMap['jibunAddress'] = null;
            }

            // workPrices 필드가 없으면 빈 문자열로 설정 (버전 9 이전 백업 대응)
            if (!scheduleMap.containsKey('workPrices') || scheduleMap['workPrices'] == null) {
              scheduleMap['workPrices'] = '';
            }

            // workItems 처리: 리스트를 쉼표로 구분된 문자열로 변환
            if (scheduleMap['workItems'] is List) {
              final workItemsList = scheduleMap['workItems'] as List;
              scheduleMap['workItems'] = workItemsList.join(',');
            } else if (scheduleMap['workItems'] == null || scheduleMap['workItems'].toString().isEmpty) {
              scheduleMap['workItems'] = '';
            }

            // workPrices 처리: Map을 문자열로 변환
            if (scheduleMap['workPrices'] is Map) {
              final workPricesMap = scheduleMap['workPrices'] as Map;
              scheduleMap['workPrices'] = workPricesMap.entries
                  .map((e) => '${e.key}:${e.value}')
                  .join('|');
            }

            // workCount null 처리
            if (scheduleMap['workCount'] == null) {
              scheduleMap['workCount'] = 0;
            }

            // status null 처리
            if (scheduleMap['status'] == null || scheduleMap['status'].toString().isEmpty) {
              scheduleMap['status'] = '예정';
            }

            // ID 제거 - 데이터베이스가 자동으로 새 ID 생성하도록
            scheduleMap.remove('id');

            final schedule = Schedule.fromMap(scheduleMap);
            await db.createSchedule(schedule);
            schedulesImported++;
            debugPrint('✅ 스케줄 복구 성공 [${i + 1}/${schedules.length}]: ${scheduleMap['customerName']}');
          } catch (e, stackTrace) {
            // 개별 스케줄 복구 실패
            schedulesFailed++;
            final scheduleMap = schedules[i] as Map<String, dynamic>;
            final customerName = scheduleMap['customerName'] ?? '알 수 없음';
            errors.add('스케줄 "$customerName" 복구 실패: $e');
            debugPrint('========================================');
            debugPrint('❌ 스케줄 복구 실패 [${i + 1}/${schedules.length}]: $customerName');
            debugPrint('  에러: $e');
            debugPrint('  스케줄 데이터:');
            debugPrint('    visitDate: ${scheduleMap['visitDate']}');
            debugPrint('    visitTime: ${scheduleMap['visitTime']}');
            debugPrint('    workItems: ${scheduleMap['workItems']}');
            debugPrint('    workPrices: ${scheduleMap['workPrices']}');
            debugPrint('    status: ${scheduleMap['status']}');
            debugPrint('  스택트레이스: $stackTrace');
            debugPrint('========================================');
          }
        }
        debugPrint('========================================');
        debugPrint('📊 스케줄 복구 완료:');
        debugPrint('   성공: $schedulesImported개');
        debugPrint('   실패: $schedulesFailed개');
        debugPrint('========================================');
      }

      // 날짜별 메모 복구 (버전 1.1 이상)
      int memosImported = 0;
      int memosFailed = 0;
      if (backupData.containsKey('memos')) {
        final memos = backupData['memos'] as List<dynamic>;
        debugPrint('========================================');
        debugPrint('📝 메모 복구 시작: 총 ${memos.length}개');
        debugPrint('========================================');

        // 전체 교체 모드인 경우 기존 메모 삭제
        if (replaceAll) {
          final existingMemos = await db.readAllMemos(userId);
          debugPrint('🗑️ 기존 메모 삭제: ${existingMemos.length}개');
          for (final memo in existingMemos) {
            if (memo.id != null) {
              await db.deleteMemo(userId, memo.id!);
            }
          }
        }

        for (int i = 0; i < memos.length; i++) {
          try {
            final memoMap = memos[i] as Map<String, dynamic>;

            // userId를 현재 사용자 ID로 덮어쓰기
            memoMap['user_id'] = userId;

            // ID 제거 - 데이터베이스가 자동으로 새 ID 생성하도록
            memoMap.remove('id');

            final memo = DateMemo.fromMap(memoMap);

            // 중복 확인: 같은 날짜에 이미 메모가 있는지 확인
            final existing = await db.readMemoByDate(userId, memo.date);
            if (existing == null) {
              await db.createMemo(memo);
              memosImported++;
              debugPrint('✅ 메모 복구 성공 [${i + 1}/${memos.length}]: ${memo.date.toString().split(' ')[0]}');
            } else if (replaceAll) {
              // 교체 모드에서는 업데이트
              await db.updateMemo(memo.copyWith(id: existing.id));
              memosImported++;
              debugPrint('✅ 메모 업데이트 [${i + 1}/${memos.length}]: ${memo.date.toString().split(' ')[0]}');
            } else {
              // 병합 모드에서는 건너뛰기
              debugPrint('⏭️ 메모 건너뛰기 (중복) [${i + 1}/${memos.length}]: ${memo.date.toString().split(' ')[0]}');
            }
          } catch (e) {
            memosFailed++;
            final memoMap = memos[i] as Map<String, dynamic>;
            final date = memoMap['date'] ?? '알 수 없음';
            errors.add('메모 "$date" 복구 실패: $e');
            debugPrint('❌ 메모 복구 실패 [${i + 1}/${memos.length}]: $date - $e');
          }
        }

        debugPrint('========================================');
        debugPrint('📊 메모 복구 완료:');
        debugPrint('   성공: $memosImported개');
        debugPrint('   실패: $memosFailed개');
        debugPrint('========================================');
      }

      // 메시지 템플릿 복구 (버전 1.2 이상)
      int templatesImported = 0;
      int templatesFailed = 0;
      if (backupData.containsKey('messageTemplates')) {
        final templates = backupData['messageTemplates'] as List<dynamic>;
        debugPrint('========================================');
        debugPrint('💬 메시지 템플릿 복구 시작: 총 ${templates.length}개');
        debugPrint('========================================');

        // 전체 교체 모드인 경우 기존 템플릿 삭제
        if (replaceAll) {
          for (final companyId in companyIdMap.values) {
            await db.deleteAllMessageTemplatesByCompany(userId, companyId);
          }
        }

        for (int i = 0; i < templates.length; i++) {
          try {
            final templateMap = Map<String, dynamic>.from(templates[i] as Map<String, dynamic>);

            // 백업된 company_id를 현재 DB의 company_id로 변환
            final backupCompanyId = templateMap['company_id'] as int?;
            if (backupCompanyId == null) {
              templatesFailed++;
              errors.add('템플릿 ${i + 1}: company_id 없음');
              continue;
            }
            final currentCompanyId = companyIdMap[backupCompanyId];
            if (currentCompanyId == null) {
              templatesFailed++;
              errors.add('템플릿 "${templateMap['name']}": 매핑된 업체 없음 (backup company_id: $backupCompanyId)');
              continue;
            }

            templateMap['user_id'] = userId;
            templateMap['company_id'] = currentCompanyId;
            templateMap.remove('id');

            final template = MessageTemplate.fromMap(templateMap);

            // 중복 확인: 같은 업체에 같은 이름의 템플릿이 있는지 확인
            final existing = await db.readAllMessageTemplates(userId, currentCompanyId);
            final duplicate = existing.where((t) => t.name == template.name).firstOrNull;

            if (duplicate == null) {
              await db.createMessageTemplate(template);
              templatesImported++;
              debugPrint('✅ 템플릿 복구 성공 [${i + 1}/${templates.length}]: ${template.name}');
            } else if (replaceAll) {
              await db.updateMessageTemplate(template.copyWith(id: duplicate.id));
              templatesImported++;
              debugPrint('✅ 템플릿 업데이트 [${i + 1}/${templates.length}]: ${template.name}');
            } else {
              debugPrint('⏭️ 템플릿 건너뛰기 (중복) [${i + 1}/${templates.length}]: ${template.name}');
            }
          } catch (e) {
            templatesFailed++;
            final templateMap = templates[i] as Map<String, dynamic>;
            errors.add('템플릿 "${templateMap['name'] ?? '알 수 없음'}" 복구 실패: $e');
            debugPrint('❌ 템플릿 복구 실패 [${i + 1}/${templates.length}]: $e');
          }
        }

        debugPrint('========================================');
        debugPrint('📊 메시지 템플릿 복구 완료:');
        debugPrint('   성공: $templatesImported개');
        debugPrint('   실패: $templatesFailed개');
        debugPrint('========================================');
      }

      return {
        'schedules': schedulesImported,
        'companies': companiesImported,
        'memos': memosImported,
        'messageTemplates': templatesImported,
        'schedulesFailed': schedulesFailed,
        'companiesFailed': companiesFailed,
        'memosFailed': memosFailed,
        'templatesFailed': templatesFailed,
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
      final memosCount = (backupData['memos'] as List?)?.length ?? 0;
      final messageTemplatesCount = (backupData['messageTemplates'] as List?)?.length ?? 0;
      final exportDate = backupData['exportDate'] as String?;

      return {
        'schedulesCount': schedulesCount,
        'companiesCount': companiesCount,
        'memosCount': memosCount,
        'messageTemplatesCount': messageTemplatesCount,
        'exportDate': exportDate != null ? DateTime.parse(exportDate) : null,
        'version': backupData['version'],
      };
    } catch (e) {
      throw Exception('백업 정보 조회 실패: $e');
    }
  }
}
