import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerName TEXT NOT NULL,
        requestDate TEXT NOT NULL,
        visitDate TEXT,
        visitTime TEXT,
        phoneNumber TEXT NOT NULL,
        address TEXT NOT NULL,
        companyName TEXT,
        workItems TEXT NOT NULL,
        workCount INTEGER NOT NULL,
        notes TEXT,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        workItems TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 4283215411
      )
    ''');

    // 기본 업체 데이터 삽입
    await _insertDefaultCompanies(db);
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

      await _insertDefaultCompanies(db);
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
            {'name': 'TV AS', 'price': 66000},
            {'name': '냉장고 AS', 'price': 88000},
            {'name': '세탁기 AS', 'price': 77000},
            {'name': '에어컨 AS', 'price': 99000},
          ]),
          'color': 4280423122, // 0xFF1976D2
        });
      }

      final carewonResult = await db.query('companies', where: "name = '케어원'");
      if (carewonResult.isEmpty) {
        await db.insert('companies', {
          'name': '케어원',
          'workItems': jsonEncode([
            {'name': 'TV 설치', 'price': 55000},
            {'name': '냉장고 설치', 'price': 66000},
            {'name': '세탁기 설치', 'price': 55000},
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

  Future _insertDefaultCompanies(Database db) async {
    final defaultCompanies = [
      Company(
        name: '삼성케어플러스',
        color: 0xFF1976D2, // 파란색
        workItems: [
          WorkItem(name: 'TV AS', price: 66000),
          WorkItem(name: '냉장고 AS', price: 88000),
          WorkItem(name: '세탁기 AS', price: 77000),
          WorkItem(name: '에어컨 AS', price: 99000),
        ],
      ),
      Company(
        name: '케어원',
        color: 0xFFF57C00, // 오렌지색
        workItems: [
          WorkItem(name: 'TV 설치', price: 55000),
          WorkItem(name: '냉장고 설치', price: 66000),
          WorkItem(name: '세탁기 설치', price: 55000),
        ],
      ),
      Company(
        name: '개인',
        color: 0xFF388E3C, // 초록색
        workItems: [], // 작업 항목 없음
      ),
    ];

    for (var company in defaultCompanies) {
      await db.insert('companies', {
        'name': company.name,
        'workItems': jsonEncode(company.workItems.map((item) => item.toMap()).toList()),
        'color': company.color,
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

  Future<Schedule?> readSchedule(int id) async {
    final db = await database;
    final maps = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
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

  Future<List<Schedule>> readAllSchedules() async {
    final db = await database;
    final result = await db.query('schedules', orderBy: 'requestDate DESC');

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

  Future<List<Schedule>> getSchedulesByStatus(List<String> statuses) async {
    final db = await database;
    final result = await db.query(
      'schedules',
      where: 'status IN (${List.filled(statuses.length, '?').join(',')})',
      whereArgs: statuses,
      orderBy: 'visitDate ASC, requestDate ASC',
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

  Future<List<Schedule>> getCompletedSchedules() async {
    final db = await database;
    final now = DateTime.now();
    final result = await db.query(
      'schedules',
      where: 'visitDate < ? AND status != ?',
      whereArgs: [now.toIso8601String(), '취소'],
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

  Future<List<Schedule>> searchSchedules(String query) async {
    final db = await database;
    // 암호화된 데이터는 LIKE 검색이 불가능하므로 모든 데이터를 가져와서 필터링
    final result = await db.query('schedules', orderBy: 'requestDate DESC');

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
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return await db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Company CRUD operations
  Future<List<Company>> readAllCompanies() async {
    final db = await database;
    final result = await db.query('companies', orderBy: 'name ASC');
    return result.map((map) {
      return Company(
        id: map['id'] as int,
        name: map['name'] as String,
        workItems: (jsonDecode(map['workItems'] as String) as List<dynamic>)
            .map((item) => WorkItem.fromMap(item))
            .toList(),
        color: (map['color'] as int?) ?? 0xFF2196F3,
      );
    }).toList();
  }

  Future<Company?> readCompanyByName(String name) async {
    final db = await database;
    final result = await db.query(
      'companies',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (result.isNotEmpty) {
      final map = result.first;
      return Company(
        id: map['id'] as int,
        name: map['name'] as String,
        workItems: (jsonDecode(map['workItems'] as String) as List<dynamic>)
            .map((item) => WorkItem.fromMap(item))
            .toList(),
        color: (map['color'] as int?) ?? 0xFF2196F3,
      );
    }
    return null;
  }

  Future<int> createCompany(Company company) async {
    final db = await database;
    return await db.insert('companies', {
      'name': company.name,
      'workItems': jsonEncode(company.workItems.map((item) => item.toMap()).toList()),
      'color': company.color,
    });
  }

  Future<int> updateCompany(Company company) async {
    final db = await database;
    return await db.update(
      'companies',
      {
        'name': company.name,
        'workItems': jsonEncode(company.workItems.map((item) => item.toMap()).toList()),
        'color': company.color,
      },
      where: 'id = ?',
      whereArgs: [company.id],
    );
  }

  Future<int> deleteCompany(int id) async {
    final db = await database;
    return await db.delete(
      'companies',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
