class Company {
  final int? id;
  final String userId;
  final String name;
  final List<WorkItem> workItems;
  final int color; // ARGB color value
  final int displayOrder; // 표시 순서
  final String confirmMessage; // 확정 메시지 템플릿
  final String absenceMessage; // 부재 메시지 템플릿

  Company({
    this.id,
    required this.userId,
    required this.name,
    required this.workItems,
    this.color = 0xFF2196F3, // 기본값: 파란색
    this.displayOrder = 0,
    this.confirmMessage = '',
    this.absenceMessage = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'workItems': workItems.map((item) => item.toMap()).toList(),
      'color': color,
      'displayOrder': displayOrder,
      'confirmMessage': confirmMessage,
      'absenceMessage': absenceMessage,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'],
      userId: map['userId'] ?? 'legacy_user',
      name: map['name'],
      workItems: (map['workItems'] as List<dynamic>)
          .map((item) => WorkItem.fromMap(item))
          .toList(),
      color: map['color'] ?? 0xFF2196F3,
      displayOrder: map['displayOrder'] ?? 0,
      confirmMessage: map['confirmMessage'] ?? '',
      absenceMessage: map['absenceMessage'] ?? '',
    );
  }

  Company copyWith({
    int? id,
    String? userId,
    String? name,
    List<WorkItem>? workItems,
    int? color,
    int? displayOrder,
    String? confirmMessage,
    String? absenceMessage,
  }) {
    return Company(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      workItems: workItems ?? this.workItems,
      color: color ?? this.color,
      displayOrder: displayOrder ?? this.displayOrder,
      confirmMessage: confirmMessage ?? this.confirmMessage,
      absenceMessage: absenceMessage ?? this.absenceMessage,
    );
  }
}

class WorkItem {
  final String name;
  final int price;

  WorkItem({
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }

  factory WorkItem.fromMap(Map<String, dynamic> map) {
    return WorkItem(
      name: map['name'],
      price: map['price'],
    );
  }
}
