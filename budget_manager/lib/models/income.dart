import 'dart:convert';

class _IncomeSentinel {
  const _IncomeSentinel();
}

const _incomeSentinel = _IncomeSentinel();

class Income {
  final int? id;
  final List<int> categoryIds;
  final int amountCents;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Income({
    this.id,
    required this.categoryIds,
    required this.amountCents,
    required this.note,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_ids': jsonEncode(categoryIds),
      'price_cents': amountCents,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'] as int?,
      categoryIds:
          (jsonDecode(map['category_ids'] as String) as List)
              .map((e) => e as int)
              .toList(),
      amountCents: (map['price_cents'] as num).toInt(),
      note: map['note'] as String,
      createdAt:
          map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.parse(map['updated_at'] as String)
              : null,
      deletedAt:
          map['deleted_at'] != null
              ? DateTime.parse(map['deleted_at'] as String)
              : null,
    );
  }

  Income copyWith({
    int? id,
    List<int>? categoryIds,
    int? amountCents,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _incomeSentinel,
  }) {
    return Income(
      id: id ?? this.id,
      categoryIds: categoryIds ?? this.categoryIds,
      amountCents: amountCents ?? this.amountCents,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          identical(deletedAt, _incomeSentinel)
              ? this.deletedAt
              : deletedAt as DateTime?,
    );
  }
}
