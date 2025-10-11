class Schedule {
  final int? id;
  final String customerName;
  final DateTime requestDate;
  final DateTime? visitDate;
  final String? visitTime;
  final String phoneNumber;
  final String address;
  final String? companyName;
  final List<String> workItems;
  final int workCount;
  final String? notes;
  final String status; // '예정', '확정', '완료', '취소'

  Schedule({
    this.id,
    required this.customerName,
    required this.requestDate,
    this.visitDate,
    this.visitTime,
    required this.phoneNumber,
    required this.address,
    this.companyName,
    required this.workItems,
    required this.workCount,
    this.notes,
    this.status = '예정',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'requestDate': requestDate.toIso8601String(),
      'visitDate': visitDate?.toIso8601String(),
      'visitTime': visitTime,
      'phoneNumber': phoneNumber,
      'address': address,
      'companyName': companyName,
      'workItems': workItems.join(','),
      'workCount': workCount,
      'notes': notes,
      'status': status,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'],
      customerName: map['customerName'],
      requestDate: DateTime.parse(map['requestDate']),
      visitDate: map['visitDate'] != null ? DateTime.parse(map['visitDate']) : null,
      visitTime: map['visitTime'],
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      companyName: map['companyName'],
      workItems: map['workItems'].toString().split(',').where((s) => s.isNotEmpty).toList(),
      workCount: map['workCount'],
      notes: map['notes'],
      status: map['status'] ?? '예정',
    );
  }

  Schedule copyWith({
    int? id,
    String? customerName,
    DateTime? requestDate,
    DateTime? visitDate,
    String? visitTime,
    String? phoneNumber,
    String? address,
    String? companyName,
    List<String>? workItems,
    int? workCount,
    String? notes,
    String? status,
  }) {
    return Schedule(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      requestDate: requestDate ?? this.requestDate,
      visitDate: visitDate ?? this.visitDate,
      visitTime: visitTime ?? this.visitTime,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      companyName: companyName ?? this.companyName,
      workItems: workItems ?? this.workItems,
      workCount: workCount ?? this.workCount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}
