class Schedule {
  final int? id;
  final String userId;
  final String customerName;
  final DateTime requestDate;
  final DateTime? visitDate;
  final String? visitTime;
  final String phoneNumber;
  final String address;
  final String? companyName;
  final List<String> workItems;
  final Map<String, int> workPrices; // 작업명: 금액 매핑
  final int workCount;
  final String? notes;
  final String status; // '예정', '확정', '완료', '취소'

  Schedule({
    this.id,
    required this.userId,
    required this.customerName,
    required this.requestDate,
    this.visitDate,
    this.visitTime,
    required this.phoneNumber,
    required this.address,
    this.companyName,
    required this.workItems,
    required this.workPrices,
    required this.workCount,
    this.notes,
    this.status = '예정',
  });

  // 총 금액 계산 (작업 항목별 건수를 반영)
  int get totalPrice {
    // 작업 항목별 건수 카운팅
    final Map<String, int> itemCount = {};
    for (var item in workItems) {
      String cleanedItem = item.replaceAll(RegExp(r'\s+\d+건$'), '');
      itemCount[cleanedItem] = (itemCount[cleanedItem] ?? 0) + 1;
    }

    // 각 작업의 (단가 × 건수)를 모두 합산
    int total = 0;
    for (var entry in itemCount.entries) {
      final price = workPrices[entry.key] ?? 0;
      final count = entry.value;
      total += price * count;
    }
    return total;
  }

  // 스케줄 상태 자동 판단 (visitDate와 visitTime 기반)
  String get computedStatus {
    // visitDate와 visitTime이 모두 있으면 '확정'
    if (visitDate != null && visitTime != null && visitTime != '미정') {
      return '확정';
    }
    // 하나라도 없으면 '예정'
    return '예정';
  }

  // 확정 스케줄인지 확인
  bool get isConfirmed {
    return visitDate != null && visitTime != null && visitTime != '미정';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'customerName': customerName,
      'requestDate': requestDate.toIso8601String(),
      'visitDate': visitDate?.toIso8601String(),
      'visitTime': visitTime,
      'phoneNumber': phoneNumber,
      'address': address,
      'companyName': companyName,
      'workItems': workItems.join(','),
      'workPrices': workPrices.entries.map((e) => '${e.key}:${e.value}').join('|'),
      'workCount': workCount,
      'notes': notes,
      'status': status,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    // workPrices 파싱
    Map<String, int> parsedWorkPrices = {};
    if (map['workPrices'] != null && map['workPrices'].toString().isNotEmpty) {
      final priceEntries = map['workPrices'].toString().split('|');
      for (var entry in priceEntries) {
        if (entry.contains(':')) {
          final parts = entry.split(':');
          if (parts.length == 2) {
            parsedWorkPrices[parts[0]] = int.tryParse(parts[1]) ?? 0;
          }
        }
      }
    }

    return Schedule(
      id: map['id'],
      userId: map['userId'] ?? 'legacy_user',
      customerName: map['customerName'],
      requestDate: DateTime.parse(map['requestDate']),
      visitDate: map['visitDate'] != null ? DateTime.parse(map['visitDate']) : null,
      visitTime: map['visitTime'],
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      companyName: map['companyName'],
      workItems: map['workItems'].toString().split(',').where((s) => s.isNotEmpty).toList(),
      workPrices: parsedWorkPrices,
      workCount: map['workCount'],
      notes: map['notes'],
      status: map['status'] ?? '예정',
    );
  }

  Schedule copyWith({
    int? id,
    String? userId,
    String? customerName,
    DateTime? requestDate,
    DateTime? visitDate,
    String? visitTime,
    String? phoneNumber,
    String? address,
    String? companyName,
    List<String>? workItems,
    Map<String, int>? workPrices,
    int? workCount,
    String? notes,
    String? status,
  }) {
    return Schedule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      requestDate: requestDate ?? this.requestDate,
      visitDate: visitDate ?? this.visitDate,
      visitTime: visitTime ?? this.visitTime,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      companyName: companyName ?? this.companyName,
      workItems: workItems ?? this.workItems,
      workPrices: workPrices ?? this.workPrices,
      workCount: workCount ?? this.workCount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}
