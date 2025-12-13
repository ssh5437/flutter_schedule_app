import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/date_memo.dart';
import '../database/database_helper.dart';

class MemoDialog extends StatefulWidget {
  final DateTime date;
  final DateMemo? existingMemo;

  const MemoDialog({
    super.key,
    required this.date,
    this.existingMemo,
  });

  @override
  State<MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<MemoDialog> {
  late TextEditingController _contentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.existingMemo?.content ?? '',
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveMemo() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final content = _contentController.text.trim();

    // 내용이 비어있으면 메모 삭제
    if (content.isEmpty && widget.existingMemo != null) {
      await _deleteMemo();
      return;
    }

    // 내용이 비어있고 새 메모면 그냥 닫기
    if (content.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.existingMemo != null) {
        // 수정
        final updatedMemo = DateMemo(
          id: widget.existingMemo!.id,
          userId: userId,
          date: widget.date,
          content: content,
          createdAt: widget.existingMemo!.createdAt,
          updatedAt: DateTime.now(),
        );
        await DatabaseHelper.instance.updateMemo(updatedMemo);
      } else {
        // 생성
        final newMemo = DateMemo(
          userId: userId,
          date: widget.date,
          content: content,
          createdAt: DateTime.now(),
        );
        await DatabaseHelper.instance.createMemo(newMemo);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // 성공 시 true 반환
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메모 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteMemo() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || widget.existingMemo == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await DatabaseHelper.instance.deleteMemo(userId, widget.existingMemo!.id!);
      if (mounted) {
        Navigator.of(context).pop(true); // 성공 시 true 반환
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메모 삭제 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFAFAFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.date.month}월 ${widget.date.day}일 메모',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 텍스트 입력 필드
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '메모를 입력하세요',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 20),

            // 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 삭제 버튼 (기존 메모가 있을 때만 표시)
                if (widget.existingMemo != null) ...[
                  TextButton(
                    onPressed: _isSaving ? null : () async {
                      // 삭제 확인 다이얼로그
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFFFAFAFA),
                          title: const Text('메모 삭제'),
                          content: const Text('이 메모를 삭제하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        _deleteMemo();
                      }
                    },
                    child: const Text(
                      '삭제',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // 취소 버튼
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),

                // 저장 버튼
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveMemo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF579bf2),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
