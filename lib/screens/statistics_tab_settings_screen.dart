import 'package:flutter/material.dart';
import '../models/statistics_tab_config.dart';
import '../database/storage_helper.dart';

class StatisticsTabSettingsScreen extends StatefulWidget {
  const StatisticsTabSettingsScreen({super.key});

  @override
  State<StatisticsTabSettingsScreen> createState() => _StatisticsTabSettingsScreenState();
}

class _StatisticsTabSettingsScreenState extends State<StatisticsTabSettingsScreen> {
  List<StatisticsTabConfig> _tabs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTabConfig();
  }

  Future<void> _loadTabConfig() async {
    setState(() => _isLoading = true);
    try {
      final tabs = await StorageHelper.getStatisticsTabConfig();
      // order로 정렬
      tabs.sort((a, b) => a.order.compareTo(b.order));
      setState(() {
        _tabs = tabs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 불러오기 실패: $e')),
        );
      }
    }
  }

  Future<void> _saveTabConfig() async {
    // 저장 전 최소 1개 활성화 확인
    final enabledCount = _tabs.where((tab) => tab.isEnabled).length;
    if (enabledCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최소 1개 이상의 탭이 활성화되어야 합니다'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await StorageHelper.saveStatisticsTabConfig(_tabs);
      if (mounted) {
        Navigator.pop(context, true); // 저장 성공 시 true 반환
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 저장 실패: $e')),
        );
      }
    }
  }

  void _toggleTab(int index) {
    // 현재 활성화된 탭 개수 확인
    final enabledCount = _tabs.where((tab) => tab.isEnabled).length;

    // 마지막 활성화된 탭을 비활성화하려는 경우 경고
    if (_tabs[index].isEnabled && enabledCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최소 1개 이상의 탭이 활성화되어야 합니다'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _tabs[index] = _tabs[index].copyWith(
        isEnabled: !_tabs[index].isEnabled,
      );
    });
  }

  void _moveTabUp(int index) {
    if (index == 0) return;

    setState(() {
      final temp = _tabs[index];
      _tabs[index] = _tabs[index - 1].copyWith(order: index);
      _tabs[index - 1] = temp.copyWith(order: index - 1);

      // 리스트 재정렬
      _tabs.sort((a, b) => a.order.compareTo(b.order));
    });
  }

  void _moveTabDown(int index) {
    if (index == _tabs.length - 1) return;

    setState(() {
      final temp = _tabs[index];
      _tabs[index] = _tabs[index + 1].copyWith(order: index);
      _tabs[index + 1] = temp.copyWith(order: index + 1);

      // 리스트 재정렬
      _tabs.sort((a, b) => a.order.compareTo(b.order));
    });
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기본값으로 초기화'),
        content: const Text('탭 설정을 기본값으로 되돌리시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _tabs = StatisticsTabConfig.getDefaultTabs();
              });
              Navigator.pop(context);
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통계 탭 설정'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF579bf2),
                Color(0xFF7eb3f5),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefault,
            tooltip: '기본값으로 초기화',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '탭을 활성화/비활성화하고 순서를 변경할 수 있습니다',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tabs.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex--;
                        }
                        final item = _tabs.removeAt(oldIndex);
                        _tabs.insert(newIndex, item);

                        // order 재설정
                        for (int i = 0; i < _tabs.length; i++) {
                          _tabs[i] = _tabs[i].copyWith(order: i);
                        }
                      });
                    },
                    itemBuilder: (context, index) {
                      final tab = _tabs[index];
                      return Card(
                        key: ValueKey(tab.id),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(
                              Icons.drag_handle,
                              color: Color(0xFF579bf2),
                            ),
                          ),
                          title: Text(
                            tab.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: tab.isEnabled ? Colors.black : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            tab.isEnabled ? '활성화됨' : '비활성화됨',
                            style: TextStyle(
                              fontSize: 12,
                              color: tab.isEnabled ? Colors.green : Colors.grey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: tab.isEnabled,
                                onChanged: (value) => _toggleTab(index),
                                activeTrackColor: const Color(0xFF579bf2),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: index > 0 ? () => _moveTabUp(index) : null,
                                      child: Icon(
                                        Icons.arrow_upward,
                                        size: 18,
                                        color: index > 0 ? const Color(0xFF579bf2) : Colors.grey[300],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: index < _tabs.length - 1 ? () => _moveTabDown(index) : null,
                                      child: Icon(
                                        Icons.arrow_downward,
                                        size: 18,
                                        color: index < _tabs.length - 1 ? const Color(0xFF579bf2) : Colors.grey[300],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF579bf2)),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              color: Color(0xFF579bf2),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveTabConfig,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF579bf2),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            '저장',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
