import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule.dart';

class StorageHelper {
  static const String _schedulesKey = 'schedules';
  static int _nextId = 1;

  static Future<List<Schedule>> getAllSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final String? schedulesJson = prefs.getString(_schedulesKey);

    if (schedulesJson == null) {
      return [];
    }

    final List<dynamic> schedulesList = json.decode(schedulesJson);
    final schedules = schedulesList.map((json) => Schedule.fromMap(json)).toList();

    // nextId 업데이트
    if (schedules.isNotEmpty) {
      _nextId = schedules.map((s) => s.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    }

    return schedules;
  }

  static Future<void> saveSchedules(List<Schedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final String schedulesJson = json.encode(
      schedules.map((schedule) => schedule.toMap()).toList(),
    );
    await prefs.setString(_schedulesKey, schedulesJson);
  }

  static Future<int> createSchedule(Schedule schedule) async {
    final schedules = await getAllSchedules();

    // nextId 재계산 (안전성을 위해)
    if (schedules.isNotEmpty) {
      _nextId = schedules.map((s) => s.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
    }

    final newSchedule = schedule.copyWith(id: _nextId);
    schedules.add(newSchedule);
    await saveSchedules(schedules);

    print('Schedule saved with ID: ${newSchedule.id}'); // 디버깅용

    _nextId++;
    return newSchedule.id!;
  }

  static Future<Schedule?> readSchedule(int id) async {
    final schedules = await getAllSchedules();
    try {
      return schedules.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<List<Schedule>> getSchedulesByStatus(List<String> statuses) async {
    final schedules = await getAllSchedules();
    final filtered = schedules.where((s) => statuses.contains(s.status)).toList();

    filtered.sort((a, b) {
      if (a.visitDate == null && b.visitDate == null) return 0;
      if (a.visitDate == null) return 1;
      if (b.visitDate == null) return -1;
      return a.visitDate!.compareTo(b.visitDate!);
    });

    return filtered;
  }

  static Future<List<Schedule>> getCompletedSchedules() async {
    final schedules = await getAllSchedules();
    final now = DateTime.now();

    final completed = schedules.where((s) {
      if (s.visitDate == null) return false;
      if (s.status == '취소') return false;
      return s.visitDate!.isBefore(now);
    }).toList();

    completed.sort((a, b) => b.visitDate!.compareTo(a.visitDate!));

    return completed;
  }

  static Future<List<Schedule>> searchSchedules(String query) async {
    final schedules = await getAllSchedules();
    final lowerQuery = query.toLowerCase();

    return schedules.where((s) {
      return s.customerName.toLowerCase().contains(lowerQuery) ||
          s.phoneNumber.contains(query) ||
          (s.visitDate?.toString().contains(query) ?? false) ||
          (s.requestDate.toString().contains(query));
    }).toList();
  }

  static Future<void> updateSchedule(Schedule schedule) async {
    final schedules = await getAllSchedules();
    final index = schedules.indexWhere((s) => s.id == schedule.id);

    if (index != -1) {
      schedules[index] = schedule;
      await saveSchedules(schedules);
    }
  }

  static Future<void> deleteSchedule(int id) async {
    final schedules = await getAllSchedules();
    schedules.removeWhere((s) => s.id == id);
    await saveSchedules(schedules);
  }
}
