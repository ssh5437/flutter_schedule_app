class Company {
  final int? id;
  final String name;
  final List<WorkItem> workItems;
  final int color; // ARGB color value
  final int displayOrder; // 표시 순서

  Company({
    this.id,
    required this.name,
    required this.workItems,
    this.color = 0xFF2196F3, // 기본값: 파란색
    this.displayOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'workItems': workItems.map((item) => item.toMap()).toList(),
      'color': color,
      'displayOrder': displayOrder,
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'],
      name: map['name'],
      workItems: (map['workItems'] as List<dynamic>)
          .map((item) => WorkItem.fromMap(item))
          .toList(),
      color: map['color'] ?? 0xFF2196F3,
      displayOrder: map['displayOrder'] ?? 0,
    );
  }

  Company copyWith({
    int? id,
    String? name,
    List<WorkItem>? workItems,
    int? color,
    int? displayOrder,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      workItems: workItems ?? this.workItems,
      color: color ?? this.color,
      displayOrder: displayOrder ?? this.displayOrder,
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
