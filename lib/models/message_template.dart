class MessageTemplate {
  int? id;
  String userId;
  int companyId;
  String name;        // 템플릿 이름 (예: "확정 안내", "일정 변경", "부재 알림")
  String content;     // 메세지 내용 (변수 포함 가능: #{일자}, #{시간}, #{고객명}, #{업체명})
  int displayOrder;   // 표시 순서
  DateTime createdAt;

  MessageTemplate({
    this.id,
    required this.userId,
    required this.companyId,
    required this.name,
    required this.content,
    required this.displayOrder,
    required this.createdAt,
  });

  // Map을 MessageTemplate 객체로 변환
  factory MessageTemplate.fromMap(Map<String, dynamic> map) {
    return MessageTemplate(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      companyId: map['company_id'] as int,
      name: map['name'] as String,
      content: map['content'] as String,
      displayOrder: map['display_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // MessageTemplate 객체를 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'company_id': companyId,
      'name': name,
      'content': content,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // 메세지 내용에서 변수를 실제 값으로 치환
  String replaceVariables({
    String? visitDate,
    String? visitTime,
    String? customerName,
    String? companyName,
  }) {
    String result = content;

    if (visitDate != null) {
      result = result.replaceAll('#{일자}', visitDate);
    }
    if (visitTime != null) {
      result = result.replaceAll('#{시간}', visitTime);
    }
    if (customerName != null) {
      result = result.replaceAll('#{고객명}', customerName);
    }
    if (companyName != null) {
      result = result.replaceAll('#{업체명}', companyName);
    }

    return result;
  }

  // 복사용
  MessageTemplate copyWith({
    int? id,
    String? userId,
    int? companyId,
    String? name,
    String? content,
    int? displayOrder,
    DateTime? createdAt,
  }) {
    return MessageTemplate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      content: content ?? this.content,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
