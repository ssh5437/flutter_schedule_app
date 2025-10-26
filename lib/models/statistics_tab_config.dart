class StatisticsTabConfig {
  final String id;
  final String name;
  final bool isEnabled;
  final int order;

  StatisticsTabConfig({
    required this.id,
    required this.name,
    required this.isEnabled,
    required this.order,
  });

  factory StatisticsTabConfig.fromJson(Map<String, dynamic> json) {
    return StatisticsTabConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      isEnabled: json['isEnabled'] as bool,
      order: json['order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isEnabled': isEnabled,
      'order': order,
    };
  }

  StatisticsTabConfig copyWith({
    String? id,
    String? name,
    bool? isEnabled,
    int? order,
  }) {
    return StatisticsTabConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      order: order ?? this.order,
    );
  }

  // 기본 탭 설정
  static List<StatisticsTabConfig> getDefaultTabs() {
    return [
      StatisticsTabConfig(id: 'overview', name: '개요', isEnabled: true, order: 0),
      StatisticsTabConfig(id: 'period', name: '기간별', isEnabled: true, order: 1),
      StatisticsTabConfig(id: 'region', name: '지역별', isEnabled: true, order: 2),
      StatisticsTabConfig(id: 'workType', name: '작업유형별', isEnabled: true, order: 3),
      StatisticsTabConfig(id: 'company', name: '업체별', isEnabled: true, order: 4),
    ];
  }
}
