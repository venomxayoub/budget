class _DebtProfileSentinel {
  const _DebtProfileSentinel();
}

const _debtProfileSentinel = _DebtProfileSentinel();

class DebtProfile {
  final int? id;
  final String name;
  final int initialBalanceCents;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const DebtProfile({
    this.id,
    required this.name,
    required this.initialBalanceCents,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isArchived => deletedAt != null;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'initial_balance_cents': initialBalanceCents,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory DebtProfile.fromMap(Map<String, dynamic> map) => DebtProfile(
    id: map['id'] as int?,
    name: map['name'] as String,
    initialBalanceCents: (map['initial_balance_cents'] as num).toInt(),
    createdAt:
        map['created_at'] == null
            ? null
            : DateTime.parse(map['created_at'] as String),
    updatedAt:
        map['updated_at'] == null
            ? null
            : DateTime.parse(map['updated_at'] as String),
    deletedAt:
        map['deleted_at'] == null
            ? null
            : DateTime.parse(map['deleted_at'] as String),
  );

  DebtProfile copyWith({
    int? id,
    String? name,
    int? initialBalanceCents,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _debtProfileSentinel,
  }) => DebtProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    initialBalanceCents: initialBalanceCents ?? this.initialBalanceCents,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt:
        identical(deletedAt, _debtProfileSentinel)
            ? this.deletedAt
            : deletedAt as DateTime?,
  );
}
