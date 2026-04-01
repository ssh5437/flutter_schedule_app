import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule.dart';
import '../models/company.dart';
import '../models/message_template.dart';
import '../models/date_memo.dart';

/// 로컬 SQLite → Supabase 단방향 동기화 서비스
/// 로컬 DB가 기본(primary), Supabase는 클라우드 백업 + 웹 버전용
/// CRUD 성공 후 비동기로 호출 → 실패해도 앱 동작에 영향 없음
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ──────────────────────────────────────────────
  // Schedule 동기화
  // ──────────────────────────────────────────────

  Future<void> upsertSchedule(Schedule schedule) async {
    if (schedule.id == null) return;
    try {
      await _client.from('schedules').upsert({
        'id': schedule.id,
        'user_id': schedule.userId,
        'customer_name': schedule.customerName,
        'visit_date': schedule.visitDate?.toIso8601String().split('T')[0],
        'visit_time': schedule.visitTime,
        'phone_number': schedule.phoneNumber,
        'address': schedule.address,
        'jibun_address': schedule.jibunAddress,
        'company_name': schedule.companyName,
        'work_items': schedule.workItems.join(','),
        'work_prices': schedule.workPrices.entries.map((e) => '${e.key}:${e.value}').join('|'),
        'work_count': schedule.workCount,
        'notes': schedule.notes,
        'status': schedule.status,
        'synced_at': DateTime.now().toIso8601String(),
      });
      debugPrint('☁️ [Sync] Schedule upserted: ${schedule.id}');
    } catch (e) {
      debugPrint('⚠️ [Sync] Schedule upsert failed (non-critical): $e');
    }
  }

  Future<void> deleteSchedule(int id, String userId) async {
    try {
      await _client.from('schedules').delete().eq('id', id).eq('user_id', userId);
      debugPrint('☁️ [Sync] Schedule deleted: $id');
    } catch (e) {
      debugPrint('⚠️ [Sync] Schedule delete failed (non-critical): $e');
    }
  }

  // ──────────────────────────────────────────────
  // Company 동기화
  // ──────────────────────────────────────────────

  Future<void> upsertCompany(Company company) async {
    if (company.id == null) return;
    try {
      await _client.from('companies').upsert({
        'id': company.id,
        'user_id': company.userId,
        'name': company.name,
        'work_items': jsonEncode(company.workItems.map((i) => i.toMap()).toList()),
        'color': company.color,
        'display_order': company.displayOrder,
        'synced_at': DateTime.now().toIso8601String(),
      });
      debugPrint('☁️ [Sync] Company upserted: ${company.id}');
    } catch (e) {
      debugPrint('⚠️ [Sync] Company upsert failed (non-critical): $e');
    }
  }

  Future<void> deleteCompany(int id, String userId) async {
    try {
      await _client.from('companies').delete().eq('id', id).eq('user_id', userId);
      debugPrint('☁️ [Sync] Company deleted: $id');
    } catch (e) {
      debugPrint('⚠️ [Sync] Company delete failed (non-critical): $e');
    }
  }

  /// 업체 순서 일괄 동기화
  Future<void> upsertCompanies(List<Company> companies) async {
    if (companies.isEmpty) return;
    try {
      final rows = companies
          .where((c) => c.id != null)
          .map((c) => {
                'id': c.id,
                'user_id': c.userId,
                'name': c.name,
                'work_items': jsonEncode(c.workItems.map((i) => i.toMap()).toList()),
                'color': c.color,
                'display_order': c.displayOrder,
                'synced_at': DateTime.now().toIso8601String(),
              })
          .toList();
      if (rows.isEmpty) return;
      await _client.from('companies').upsert(rows);
      debugPrint('☁️ [Sync] Companies batch upserted: ${rows.length}개');
    } catch (e) {
      debugPrint('⚠️ [Sync] Companies batch upsert failed (non-critical): $e');
    }
  }

  /// 업체명 변경 시 Supabase schedules의 company_name 일괄 업데이트
  Future<void> updateScheduleCompanyName(String userId, String oldName, String newName) async {
    try {
      await _client
          .from('schedules')
          .update({'company_name': newName, 'synced_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .eq('company_name', oldName);
      debugPrint('☁️ [Sync] Company name updated in schedules: $oldName → $newName');
    } catch (e) {
      debugPrint('⚠️ [Sync] Company name update failed (non-critical): $e');
    }
  }

  // ──────────────────────────────────────────────
  // MessageTemplate 동기화
  // ──────────────────────────────────────────────

  Future<void> upsertMessageTemplate(MessageTemplate template) async {
    if (template.id == null) return;
    try {
      await _client.from('message_templates').upsert({
        'id': template.id,
        'user_id': template.userId,
        'company_id': template.companyId,
        'name': template.name,
        'content': template.content,
        'display_order': template.displayOrder,
        'created_at': template.createdAt.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });
      debugPrint('☁️ [Sync] MessageTemplate upserted: ${template.id}');
    } catch (e) {
      debugPrint('⚠️ [Sync] MessageTemplate upsert failed (non-critical): $e');
    }
  }

  Future<void> deleteMessageTemplate(int id, String userId) async {
    try {
      await _client.from('message_templates').delete().eq('id', id).eq('user_id', userId);
      debugPrint('☁️ [Sync] MessageTemplate deleted: $id');
    } catch (e) {
      debugPrint('⚠️ [Sync] MessageTemplate delete failed (non-critical): $e');
    }
  }

  Future<void> deleteMessageTemplatesByCompany(String userId, int companyId) async {
    try {
      await _client
          .from('message_templates')
          .delete()
          .eq('user_id', userId)
          .eq('company_id', companyId);
      debugPrint('☁️ [Sync] MessageTemplates deleted for company: $companyId');
    } catch (e) {
      debugPrint('⚠️ [Sync] MessageTemplates delete failed (non-critical): $e');
    }
  }

  /// 템플릿 순서 일괄 동기화
  Future<void> upsertMessageTemplates(List<MessageTemplate> templates) async {
    if (templates.isEmpty) return;
    try {
      final rows = templates
          .where((t) => t.id != null)
          .map((t) => {
                'id': t.id,
                'user_id': t.userId,
                'company_id': t.companyId,
                'name': t.name,
                'content': t.content,
                'display_order': t.displayOrder,
                'created_at': t.createdAt.toIso8601String(),
                'synced_at': DateTime.now().toIso8601String(),
              })
          .toList();
      if (rows.isEmpty) return;
      await _client.from('message_templates').upsert(rows);
      debugPrint('☁️ [Sync] MessageTemplates batch upserted: ${rows.length}개');
    } catch (e) {
      debugPrint('⚠️ [Sync] MessageTemplates batch upsert failed (non-critical): $e');
    }
  }

  // ──────────────────────────────────────────────
  // DateMemo 동기화
  // ──────────────────────────────────────────────

  Future<void> upsertMemo(DateMemo memo) async {
    if (memo.id == null) return;
    try {
      await _client.from('date_memos').upsert({
        'id': memo.id,
        'user_id': memo.userId,
        'date': memo.date.toIso8601String().split('T')[0],
        'content': memo.content,
        'created_at': memo.createdAt.toIso8601String(),
        'updated_at': memo.updatedAt?.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });
      debugPrint('☁️ [Sync] DateMemo upserted: ${memo.id}');
    } catch (e) {
      debugPrint('⚠️ [Sync] DateMemo upsert failed (non-critical): $e');
    }
  }

  Future<void> deleteMemo(int id, String userId) async {
    try {
      await _client.from('date_memos').delete().eq('id', id).eq('user_id', userId);
      debugPrint('☁️ [Sync] DateMemo deleted: $id');
    } catch (e) {
      debugPrint('⚠️ [Sync] DateMemo delete failed (non-critical): $e');
    }
  }
}
