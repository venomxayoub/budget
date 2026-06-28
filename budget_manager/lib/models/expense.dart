import 'dart:convert';

class _ExpenseSentinel {
  const _ExpenseSentinel();
}

const _expenseSentinel = _ExpenseSentinel();

class Expense {
  final int? id;
  final List<int> categoryIds;
  final int amountCents;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Expense({
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

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
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

  Expense copyWith({
    int? id,
    List<int>? categoryIds,
    int? amountCents,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _expenseSentinel,
  }) {
    return Expense(
      id: id ?? this.id,
      categoryIds: categoryIds ?? this.categoryIds,
      amountCents: amountCents ?? this.amountCents,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          identical(deletedAt, _expenseSentinel)
              ? this.deletedAt
              : deletedAt as DateTime?,
    );
  }
}
