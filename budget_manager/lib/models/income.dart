import 'dart:convert';

class Income {
  final int? id;
  final List<int> categoryIds;
  final double price;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Income({
    this.id,
    required this.categoryIds,
    required this.price,
    required this.note,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_ids': jsonEncode(categoryIds),
      'price': price,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'] as int?,
      categoryIds: (jsonDecode(map['category_ids'] as String) as List)
          .map((e) => e as int)
          .toList(),
      price: (map['price'] as num).toDouble(),
      note: map['note'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Income copyWith({
    int? id,
    List<int>? categoryIds,
    double? price,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Income(
      id: id ?? this.id,
      categoryIds: categoryIds ?? this.categoryIds,
      price: price ?? this.price,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
