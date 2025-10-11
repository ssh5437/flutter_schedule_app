class Company {
  final int? id;
  final String name;
  final String type; // 'samsung', 'carewon', 'personal'
  final List<WorkItem> workItems;

  Company({
    this.id,
    required this.name,
    required this.type,
    required this.workItems,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'workItems': workItems.map((item) => item.toMap()).toList(),
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      workItems: (map['workItems'] as List<dynamic>)
          .map((item) => WorkItem.fromMap(item))
          .toList(),
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
