import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule.dart';
import '../models/statistics_tab_config.dart';

class StorageHelper {
  static const String _schedulesKey = 'schedules';
  static const String _statisticsTabsKey = 'statistics_tabs';
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

    debugPrint('Schedule saved with ID: ${newSchedule.id}'); // 디버깅용

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
    final filtered = schedules.where((s) => statuses.contains(s.computedStatus)).toList();

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
      if (s.computedStatus == '취소') return false;
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
          (s.visitDate?.toString().contains(query) ?? false);
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

  // 통계 탭 설정 관련 메서드
  static Future<List<StatisticsTabConfig>> getStatisticsTabConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tabsJson = prefs.getString(_statisticsTabsKey);

    if (tabsJson == null) {
      // 저장된 설정이 없으면 기본값 반환
      return StatisticsTabConfig.getDefaultTabs();
    }

    try {
      final List<dynamic> tabsList = json.decode(tabsJson);
      final existingTabs = tabsList.map((json) => StatisticsTabConfig.fromJson(json)).toList();

      // 마이그레이션: 새로운 탭(고객별) 추가
      final existingIds = existingTabs.map((tab) => tab.id).toSet();
      final defaultTabs = StatisticsTabConfig.getDefaultTabs();

      // 기본 탭 중 없는 탭이 있으면 추가
      final newTabs = <StatisticsTabConfig>[];
      for (final defaultTab in defaultTabs) {
        if (!existingIds.contains(defaultTab.id)) {
          newTabs.add(defaultTab);
          debugPrint('새 탭 추가: ${defaultTab.name} (${defaultTab.id})');
        }
      }

      if (newTabs.isNotEmpty) {
        // 새 탭이 추가되었으면 병합하고 저장
        final mergedTabs = [...existingTabs, ...newTabs];
        await saveStatisticsTabConfig(mergedTabs);
        return mergedTabs;
      }

      return existingTabs;
    } catch (e) {
      debugPrint('탭 설정 로드 실패: $e');
      // 파싱 실패 시 기본값 반환
      return StatisticsTabConfig.getDefaultTabs();
    }
  }

  static Future<void> saveStatisticsTabConfig(List<StatisticsTabConfig> tabs) async {
    final prefs = await SharedPreferences.getInstance();
    final String tabsJson = json.encode(
      tabs.map((tab) => tab.toJson()).toList(),
    );
    await prefs.setString(_statisticsTabsKey, tabsJson);
  }
}
