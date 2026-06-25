class IncomeCategory {
  final int? id;
  final String name;
  final String emoji;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  IncomeCategory({
    this.id,
    required this.name,
    required this.emoji,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'emoji': emoji,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory IncomeCategory.fromMap(Map<String, dynamic> map) {
    return IncomeCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  IncomeCategory copyWith({
    int? id,
    String? name,
    String? emoji,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IncomeCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
