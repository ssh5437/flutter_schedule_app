class DateMemo {
  final int? id;
  final String userId;
  final DateTime date; // 날짜 (시간 제외)
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DateMemo({
    this.id,
    required this.userId,
    required this.date,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  // 데이터베이스에서 읽어올 때
  factory DateMemo.fromMap(Map<String, dynamic> map) {
    return DateMemo(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      date: DateTime.parse(map['date'] as String),
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // 데이터베이스에 저장할 때
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String().split('T')[0], // 날짜만 저장 (YYYY-MM-DD)
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // copyWith 메서드
  DateMemo copyWith({
    int? id,
    String? userId,
    DateTime? date,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DateMemo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
