class Company {
  final int? id;
  final String name;
  final List<WorkItem> workItems;
  final int color; // ARGB color value

  Company({
    this.id,
    required this.name,
    required this.workItems,
    this.color = 0xFF2196F3, // 기본값: 파란색
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'workItems': workItems.map((item) => item.toMap()).toList(),
      'color': color,
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
