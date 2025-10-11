import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/schedule.dart';
import '../models/company.dart';

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
      version: 2,
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
        type TEXT NOT NULL,
        workItems TEXT NOT NULL
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
          type TEXT NOT NULL,
          workItems TEXT NOT NULL
        )
      ''');

      await _insertDefaultCompanies(db);
    }
  }

  Future _insertDefaultCompanies(Database db) async {
    final defaultCompanies = [
      Company(
        name: '삼성케어플러스',
        type: 'samsung',
        workItems: [
          WorkItem(name: '벽걸이 에어컨', price: 0),
          WorkItem(name: '스텐드 에어컨', price: 0),
          WorkItem(name: '1way 에어컨', price: 0),
          WorkItem(name: '2way 에어컨', price: 0),
          WorkItem(name: '드럼세탁기', price: 0),
          WorkItem(name: '통돌이세탁기', price: 0),
          WorkItem(name: '냉장고', price: 0),
        ],
      ),
      Company(
        name: '케어원',
        type: 'carewon',
        workItems: [
          WorkItem(name: '벽걸이 에어컨', price: 0),
          WorkItem(name: '스텐드 에어컨', price: 0),
          WorkItem(name: '드럼세탁기', price: 0),
          WorkItem(name: '통돌이세탁기', price: 0),
          WorkItem(name: '냉장고', price: 0),
        ],
      ),
      Company(
        name: '개인',
        type: 'personal',
        workItems: [
          WorkItem(name: '1way 에어컨', price: 35000),
          WorkItem(name: '2way 에어컨', price: 45000),
          WorkItem(name: '벽걸이 에어컨', price: 35000),
          WorkItem(name: '스텐드 에어컨', price: 45000),
          WorkItem(name: '드럼세탁기', price: 40000),
          WorkItem(name: '통돌이세탁기', price: 35000),
          WorkItem(name: '냉장고', price: 50000),
          WorkItem(name: '입주 청소', price: 150000),
          WorkItem(name: '이사 청소', price: 120000),
          WorkItem(name: '정기 청소', price: 80000),
        ],
      ),
    ];

    for (var company in defaultCompanies) {
      await db.insert('companies', {
        'name': company.name,
        'type': company.type,
        'workItems': jsonEncode(company.workItems.map((item) => item.toMap()).toList()),
      });
    }
  }

  Future<int> createSchedule(Schedule schedule) async {
    final db = await database;
    return await db.insert('schedules', schedule.toMap());
  }

  Future<Schedule?> readSchedule(int id) async {
    final db = await database;
    final maps = await db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Schedule.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Schedule>> readAllSchedules() async {
    final db = await database;
    final result = await db.query('schedules', orderBy: 'requestDate DESC');
    return result.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<List<Schedule>> getSchedulesByStatus(List<String> statuses) async {
    final db = await database;
    final result = await db.query(
      'schedules',
      where: 'status IN (${List.filled(statuses.length, '?').join(',')})',
      whereArgs: statuses,
      orderBy: 'visitDate ASC, requestDate ASC',
    );
    return result.map((map) => Schedule.fromMap(map)).toList();
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
    return result.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<List<Schedule>> searchSchedules(String query) async {
    final db = await database;
    final result = await db.query(
      'schedules',
      where: 'customerName LIKE ? OR phoneNumber LIKE ? OR requestDate LIKE ? OR visitDate LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'requestDate DESC',
    );
    return result.map((map) => Schedule.fromMap(map)).toList();
  }

  Future<int> updateSchedule(Schedule schedule) async {
    final db = await database;
    return await db.update(
      'schedules',
      schedule.toMap(),
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
        type: map['type'] as String,
        workItems: (jsonDecode(map['workItems'] as String) as List<dynamic>)
            .map((item) => WorkItem.fromMap(item))
            .toList(),
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
        type: map['type'] as String,
        workItems: (jsonDecode(map['workItems'] as String) as List<dynamic>)
            .map((item) => WorkItem.fromMap(item))
            .toList(),
      );
    }
    return null;
  }

  Future<int> createCompany(Company company) async {
    final db = await database;
    return await db.insert('companies', {
      'name': company.name,
      'type': company.type,
      'workItems': jsonEncode(company.workItems.map((item) => item.toMap()).toList()),
    });
  }

  Future<int> updateCompany(Company company) async {
    final db = await database;
    return await db.update(
      'companies',
      {
        'name': company.name,
        'type': company.type,
        'workItems': jsonEncode(company.workItems.map((item) => item.toMap()).toList()),
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
