import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/schedule.dart';
import '../models/company.dart';
import '../utils/encryption_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('schedules.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        customerName TEXT NOT NULL,
        requestDate TEXT NOT NULL,
        visitDate TEXT,
        visitTime TEXT,
        phoneNumber TEXT NOT NULL,
        address TEXT NOT NULL,
        jibunAddress TEXT,
        companyName TEXT,
        workItems TEXT NOT NULL,
        workPrices TEXT NOT NULL,
        workCount INTEGER NOT NULL,
        notes TEXT,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        name TEXT NOT NULL,
        workItems TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 4283215411,
        displayOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT NOT NULL,
        purchase_id TEXT,
        purchase_date TEXT,
        expiry_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        is_test_mode INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 새로운 DB 생성 시에는 기본 업체를 삽입하지 않음
    // 첫 로그인 시 사용자별로 기본 업체가 생성됨
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE companies (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          workItems TEXT NOT NULL,
          color INTEGER NOT NULL DEFAULT 4283215411
        )
      ''');
    }
    if (oldVersion < 3) {
      // color 컬럼 추가 (기존 데이터가 있는 경우)
      try {
        await db.execute('ALTER TABLE companies ADD COLUMN color INTEGER');
      } catch (e) {
        // 컬럼이 이미 존재하는 경우 무시
      }

      // 기존 데이터에 기본 색상 설정
      await db.execute('UPDATE companies SET color = 4283215411 WHERE color IS NULL');

      // 업체별 기본 색상 적용
      await db.execute("UPDATE companies SET color = 4280423122 WHERE name = '삼성케어플러스'"); // 0xFF1976D2
      await db.execute("UPDATE companies SET color = 4293918208 WHERE name = '케어원'"); // 0xFFF57C00
      await db.execute("UPDATE companies SET color = 4282549820 WHERE name = '개인'"); // 0xFF388E3C
    }
    if (oldVersion < 4) {
      // type 컬럼 제거 (SQLite는 컬럼 삭제를 직접 지원하지 않으므로 테이블 재생성)
      await db.execute('ALTER TABLE companies RENAME TO companies_old');
      await db.execute('''
        CREATE TABLE companies (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          workItems TEXT NOT NULL,
          color INTEGER NOT NULL DEFAULT 4283215411
        )
      ''');
      await db.execute('INSERT INTO companies (id, name, workItems, color) SELECT id, name, workItems, color FROM companies_old');
      await db.execute('DROP TABLE companies_old');

      // "개인" 업체가 없으면 생성 (기존 업체는 유지)
      final result = await db.query('companies', where: "name = '개인'");
      if (result.isEmpty) {
        await db.insert('companies', {
          'name': '개인',
          'workItems': jsonEncode([]),
          'color': 4282549820, // 0xFF388E3C
        });
      }
    }
    if (oldVersion < 5) {
      // 삭제된 기본 업체들을 복원 (없는 경우만)
      final samsungResult = await db.query('companies', where: "name = '삼성케어플러스'");
      if (samsungResult.isEmpty) {
        await db.insert('companies', {
          'name': '삼성케어플러스',
          'workItems': jsonEncode([
            {'name': '냉장고 세척', 'price': 88000},
            {'name': '드럼세탁기 세척', 'price': 77000},
            {'name': '스탠드에어컨 세척', 'price': 99000},
          ]),
          'color': 4280423122, // 0xFF1976D2
        });
      }

      final carewonResult = await db.query('companies', where: "name = '케어원'");
      if (carewonResult.isEmpty) {
        await db.insert('companies', {
          'name': '케어원',
          'workItems': jsonEncode([
            {'name': '벽걸이에어컨 세척', 'price': 55000},
            {'name': '냉장고 세척', 'price': 66000},
            {'name': '통돌이세탁기 세척', 'price': 55000},
          ]),
          'color': 4293918208, // 0xFFF57C00
        });
      }

      // "개인" 업체가 없으면 생성
      final personalResult = await db.query('companies', where: "name = '개인'");
      if (personalResult.isEmpty) {
        await db.insert('companies', {
          'name': '개인',
          'workItems': jsonEncode([]),
          'color': 4282549820, // 0xFF388E3C
        });
      }
    }
    if (oldVersion < 6) {
      // 기존 암호화되지 않은 데이터를 암호화
      await _migrateToEncryptedData(db);
    }
    if (oldVersion < 7) {
      // displayOrder 컬럼 추가
      try {
        await db.execute('ALTER TABLE companies ADD COLUMN displayOrder INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        // 컬럼이 이미 존재하는 경우 무시
      }

      // 기존 업체들의 displayOrder를 ID 순서로 설정
      final companies = await db.query('companies', orderBy: 'id ASC');
      for (int i = 0; i < companies.length; i++) {
        await db.update(
          'companies',
          {'displayOrder': i},
          where: 'id = ?',
          whereArgs: [companies[i]['id']],
        );
      }
    }
    if (oldVersion < 8) {
      // userId 컬럼 추가
      try {
        await db.execute('ALTER TABLE schedules ADD COLUMN userId TEXT');
        await db.execute('ALTER TABLE companies ADD COLUMN userId TEXT');
      } catch (e) {
        // 컬럼이 이미 존재하는 경우 무시
      }

      // 기존 데이터는 'legacy_user'로 할당 (첫 로그인 시 현재 사용자 ID로 변경됨)
      await db.execute("UPDATE schedules SET userId = 'legacy_user' WHERE userId IS NULL");
      await db.execute("UPDATE companies SET userId = 'legacy_user' WHERE userId IS NULL");
    }
    if (oldVersion < 9) {
      // workPrices 컬럼 추가
      try {
        await db.execute('ALTER TABLE schedules ADD COLUMN workPrices TEXT');
      } catch (e) {
        // 컬럼이 이미 존재하는 경우 무시
      }

      // 기존 데이터는 빈 문자열로 초기화 (금액 정보 없음)
      await db.execute("UPDATE schedules SET workPrices = '' WHERE workPrices IS NULL");
    }
    if (oldVersion < 10) {
      // subscriptions 테이블 생성
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subscriptions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id TEXT NOT NULL,
          purchase_id TEXT,
          purchase_date TEXT,
          expiry_date TEXT,
          is_active INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 11) {
      // is_test_mode 컬럼 추가
      try {
        await db.execute('ALTER TABLE subscriptions ADD COLUMN is_test_mode INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        // 컬럼이 이미 존재하는 경우 무시
      }
    }
    if (oldVersion < 12) {
      // jibunAddress 컬럼 추가 (지번 주소 - 통계용)
      try {
        await db.execute('ALTER TABLE schedules ADD COLUMN jibunAddress TEXT');
      } catch (e) {
        // 컬럼이 이미 존재하는 경우 무시
      }
    }
  }

  Future<void> _migrateToEncryptedData(Database db) async {
    // 모든 스케줄 데이터를 가져옴
    final schedules = await db.query('schedules');

    for (var schedule in schedules) {
      final id = schedule['id'];
      final customerName = schedule['customerName'] as String;
      final phoneNumber = schedule['phoneNumber'] as String;
      final address = schedule['address'] as String;

      // 이미 암호화된 데이터인지 확인
      if (!EncryptionHelper.isEncrypted(customerName)) {
        // 암호화되지 않은 데이터만 암호화하여 업데이트
        await db.update(
          'schedules',
          {
            'customerName': await EncryptionHelper.encrypt(customerName),
            'phoneNumber': await EncryptionHelper.encrypt(phoneNumber),
            'address': await EncryptionHelper.encrypt(address),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  // legacy_user 데이터를 현재 사용자에게 마이그레이션
  Future<void> migrateLegacyDataToUser(String userId) async {
    final db = await database;

    // 현재 사용자의 데이터가 이미 있는지 확인
    final userSchedules = await db.query(
      'schedules',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );

    final userCompanies = await db.query(
      'companies',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );

    // 현재 사용자의 데이터가 없고, legacy_user 데이터가 있으면 마이그레이션
    if (userSchedules.isEmpty && userCompanies.isEmpty) {
      // legacy_user의 스케줄을 현재 사용자에게 할당
      await db.update(
        'schedules',
        {'userId': userId},
        where: "userId = 'legacy_user'",
      );

      // legacy_user의 업체를 현재 사용자에게 할당
      await db.update(
        'companies',
        {'userId': userId},
        where: "userId = 'legacy_user'",
      );

      debugPrint('Migrated legacy data to user: $userId');
    }
  }

  // 사용자별 기본 업체 생성
  Future<void> initializeDefaultCompaniesForUser(String userId) async {
    final db = await database;

    // 이미 업체가 있는지 확인
    final existingCompanies = await db.query(
      'companies',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    if (existingCompanies.isNotEmpty) {
      return; // 이미 업체가 있으면 생성하지 않음
    }

    final defaultCompanies = [
      Company(
        userId: userId,
        name: '개인',
        color: 0xFF388E3C, // 초록색
        workItems: [], // 작업 항목 없음
      ),
    ];

    for (int i = 0; i < defaultCompanies.length; i++) {
      final company = defaultCompanies[i];
      await db.insert('companies', {
        'userId': company.userId,
        'name': company.name,
        'workItems': jsonEncode(company.workItems.map((item) => item.toMap()).toList()),
        'color': company.color,
        'displayOrder': i,
      });
    }
  }

  Future<int> createSchedule(Schedule schedule) async {
    final db = await database;
    final map = schedule.toMap();

    // 개인정보 암호화
    map['customerName'] = await EncryptionHelper.encrypt(map['customerName']);
    map['phoneNumber'] = await EncryptionHelper.encrypt(map['phoneNumber']);
    map['address'] = await EncryptionHelper.encrypt(map['address']);

    return await db.insert('schedules', map);
  }

  Future<Schedule?> readSchedule(String userId, int id) async {
    final db = await database;
    final maps = await db.query(
      'schedules',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );

    if (maps.isNotEmpty) {
      final map = Map<String, dynamic>.from(maps.first);

      // 개인정보 복호화
      map['customerName'] = await EncryptionHelper.decrypt(map['customerName']);
      map['phoneNumber'] = await EncryptionHelper.decrypt(map['phoneNumber']);
      map['address'] = await EncryptionHelper.decrypt(map['address']);

      return Schedule.fromMap(map);
    } else {
      return null;
    }
  }

  Future<List<Schedule>> readAllSchedules(String userId) async {
    final db = await database;
    final result = await db.query(
      'schedules',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'requestDate DESC',
    );

    // 모든 스케줄의 개인정보 복호화
    final schedules = <Schedule>[];
    for (var item in result) {
      final map = Map<String, dynamic>.from(item);
      map['customerName'] = await EncryptionHelper.decrypt(map['customerName']);
      map['phoneNumber'] = await EncryptionHelper.decrypt(map['phoneNumber']);
      map['address'] = await EncryptionHelper.decrypt(map['address']);
      schedules.add(Schedule.fromMap(map));
    }
    return schedules;
  }

  Future<List<Schedule>> getSchedulesByStatus(String userId, List<String> statuses) async {
    // 모든 스케줄을 가져온 후 상태로 필터링
    final allSchedules = await readAllSchedules(userId);

    // computedStatus로 필터링
    return allSchedules.where((schedule) {
      return statuses.contains(schedule.computedStatus);
    }).toList()
      ..sort((a, b) {
        // visitDate가 있으면 visitDate 순, 없으면 requestDate 순
        if (a.visitDate != null && b.visitDate != null) {
          return a.visitDate!.compareTo(b.visitDate!);
        } else if (a.visitDate != null) {
          return -1;
        } else if (b.visitDate != null) {
          return 1;
        } else {
          return a.requestDate.compareTo(b.requestDate);
        }
      });
  }

  Future<List<Schedule>> getCompletedSchedules(String userId) async {
    final db = await database;
    final now = DateTime.now();
    final result = await db.query(
      'schedules',
      where: 'userId = ? AND visitDate < ? AND status != ?',
      whereArgs: [userId, now.toIso8601String(), '취소'],
      orderBy: 'visitDate DESC',
    );

    // 모든 스케줄의 개인정보 복호화
    final schedules = <Schedule>[];
    for (var item in result) {
      final map = Map<String, dynamic>.from(item);
      map['customerName'] = await EncryptionHelper.decrypt(map['customerName']);
      map['phoneNumber'] = await EncryptionHelper.decrypt(map['phoneNumber']);
      map['address'] = await EncryptionHelper.decrypt(map['address']);
      schedules.add(Schedule.fromMap(map));
    }
    return schedules;
  }

  // 날짜 범위로 완료 스케줄 조회 (페이지네이션용)
  Future<List<Schedule>> getCompletedSchedulesByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final result = await db.query(
      'schedules',
      where: 'userId = ? AND visitDate < ? AND visitDate >= ? AND visitDate <= ? AND status != ?',
      whereArgs: [userId, now.toIso8601String(), startDate.toIso8601String(), endDate.toIso8601String(), '취소'],
      orderBy: 'visitDate DESC',
    );

    // 모든 스케줄의 개인정보 복호화
    final schedules = <Schedule>[];
    for (var item in result) {
      final map = Map<String, dynamic>.from(item);
      map['customerName'] = await EncryptionHelper.decrypt(map['customerName']);
      map['phoneNumber'] = await EncryptionHelper.decrypt(map['phoneNumber']);
      map['address'] = await EncryptionHelper.decrypt(map['address']);
      schedules.add(Schedule.fromMap(map));
    }
    return schedules;
  }

  // 완료 스케줄 검색 (전체 범위에서)
  Future<List<Schedule>> searchCompletedSchedules(String userId, String query) async {
    final db = await database;
    final now = DateTime.now();
    // 암호화된 데이터는 LIKE 검색이 불가능하므로 모든 완료 스케줄을 가져와서 필터링
    final result = await db.query(
      'schedules',
      where: 'userId = ? AND visitDate < ? AND status != ?',
      whereArgs: [userId, now.toIso8601String(), '취소'],
      orderBy: 'visitDate DESC',
    );

    // 모든 스케줄의 개인정보 복호화
    final schedules = <Schedule>[];
    for (var item in result) {
      final map = Map<String, dynamic>.from(item);
      map['customerName'] = await EncryptionHelper.decrypt(map['customerName']);
      map['phoneNumber'] = await EncryptionHelper.decrypt(map['phoneNumber']);
      map['address'] = await EncryptionHelper.decrypt(map['address']);
      schedules.add(Schedule.fromMap(map));
    }

    // 복호화된 데이터로 검색
    final lowerQuery = query.toLowerCase();
    return schedules.where((schedule) {
      return schedule.customerName.toLowerCase().contains(lowerQuery) ||
             schedule.phoneNumber.toLowerCase().contains(lowerQuery) ||
             (schedule.companyName?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  Future<List<Schedule>> searchSchedules(String userId, String query) async {
    final db = await database;
    // 암호화된 데이터는 LIKE 검색이 불가능하므로 모든 데이터를 가져와서 필터링
    final result = await db.query(
      'schedules',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'requestDate DESC',
    );

    // 모든 스케줄의 개인정보 복호화
    final schedules = <Schedule>[];
    for (var item in result) {
      final map = Map<String, dynamic>.from(item);
      map['customerName'] = await EncryptionHelper.decrypt(map['customerName']);
      map['phoneNumber'] = await EncryptionHelper.decrypt(map['phoneNumber']);
      map['address'] = await EncryptionHelper.decrypt(map['address']);
      schedules.add(Schedule.fromMap(map));
    }

    // 복호화된 데이터로 검색
    return schedules.where((schedule) {
      final lowerQuery = query.toLowerCase();
      return schedule.customerName.toLowerCase().contains(lowerQuery) ||
             schedule.phoneNumber.toLowerCase().contains(lowerQuery) ||
             schedule.address.toLowerCase().contains(lowerQuery) ||
             schedule.requestDate.toString().contains(lowerQuery) ||
             (schedule.visitDate?.toString().contains(lowerQuery) ?? false);
    }).toList();
  }

  Future<int> updateSchedule(Schedule schedule) async {
    final db = await database;
    final map = schedule.toMap();

    // 개인정보 암호화
    map['customerName'] = await EncryptionHelper.encrypt(map['customerName']);
    map['phoneNumber'] = await EncryptionHelper.encrypt(map['phoneNumber']);
    map['address'] = await EncryptionHelper.encrypt(map['address']);

    return await db.update(
      'schedules',
      map,
      where: 'id = ? AND userId = ?',
      whereArgs: [schedule.id, schedule.userId],
    );
  }

  Future<int> deleteSchedule(String userId, int id) async {
    final db = await database;
    return await db.delete(
      'schedules',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  // Company CRUD operations
  Future<List<Company>> readAllCompanies(String userId) async {
    final db = await database;
    final result = await db.query(
      'companies',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'displayOrder ASC, id ASC',
    );
    return result.map((map) {
      return Company(
        id: map['id'] as int,
        userId: map['userId'] as String,
        name: map['name'] as String,
        workItems: (jsonDecode(map['workItems'] as String) as List<dynamic>)
            .map((item) => WorkItem.fromMap(item))
            .toList(),
        color: (map['color'] as int?) ?? 0xFF2196F3,
        displayOrder: (map['displayOrder'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<Company?> readCompanyByName(String userId, String name) async {
    final db = await database;
    final result = await db.query(
      'companies',
      where: 'userId = ? AND name = ?',
      whereArgs: [userId, name],
    );

    if (result.isNotEmpty) {
      final map = result.first;
      return Company(
        id: map['id'] as int,
        userId: map['userId'] as String,
        name: map['name'] as String,
        workItems: (jsonDecode(map['workItems'] as String) as List<dynamic>)
            .map((item) => WorkItem.fromMap(item))
            .toList(),
        color: (map['color'] as int?) ?? 0xFF2196F3,
        displayOrder: (map['displayOrder'] as int?) ?? 0,
      );
    }
    return null;
  }

  Future<int> createCompany(Company company) async {
    final db = await database;

    // 새 업체는 해당 사용자의 맨 마지막 순서로 추가
    final result = await db.rawQuery(
      'SELECT MAX(displayOrder) as maxOrder FROM companies WHERE userId = ?',
      [company.userId],
    );
    final maxOrder = (result.first['maxOrder'] as int?) ?? -1;

    return await db.insert('companies', {
      'userId': company.userId,
      'name': company.name,
      'workItems': jsonEncode(company.workItems.map((item) => item.toMap()).toList()),
      'color': company.color,
      'displayOrder': maxOrder + 1,
    });
  }

  Future<int> updateCompany(Company company) async {
    final db = await database;
    return await db.update(
      'companies',
      {
        'userId': company.userId,
        'name': company.name,
        'workItems': jsonEncode(company.workItems.map((item) => item.toMap()).toList()),
        'color': company.color,
        'displayOrder': company.displayOrder,
      },
      where: 'id = ? AND userId = ?',
      whereArgs: [company.id, company.userId],
    );
  }

  // 업체 순서 일괄 업데이트
  Future<void> updateCompaniesOrder(String userId, List<Company> companies) async {
    final db = await database;
    final batch = db.batch();

    for (int i = 0; i < companies.length; i++) {
      batch.update(
        'companies',
        {'displayOrder': i},
        where: 'id = ? AND userId = ?',
        whereArgs: [companies[i].id, userId],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<int> deleteCompany(String userId, int id) async {
    final db = await database;
    return await db.delete(
      'companies',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
