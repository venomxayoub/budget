enum DebtTransactionType {
  gave,
  received,
  update;

  String get databaseValue => name;

  String get label => switch (this) {
    DebtTransactionType.gave => 'I Gave',
    DebtTransactionType.received => 'I Received',
    DebtTransactionType.update => 'Update',
  };

  static DebtTransactionType fromDatabase(String value) =>
      DebtTransactionType.values.firstWhere(
        (type) => type.databaseValue == value,
        orElse:
            () =>
                throw FormatException('Unknown debt transaction type: $value'),
      );
}

class DebtTransaction {
  final int? id;
  final int profileId;
  final DebtTransactionType type;
  final int amountCents;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const DebtTransaction({
    this.id,
    required this.profileId,
    required this.type,
    required this.amountCents,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'profile_id': profileId,
    'type': type.databaseValue,
    'amount_cents': amountCents,
    'note': note,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
  };

  factory DebtTransaction.fromMap(Map<String, dynamic> map) => DebtTransaction(
    id: map['id'] as int?,
    profileId: map['profile_id'] as int,
    type: DebtTransactionType.fromDatabase(map['type'] as String),
    amountCents: (map['amount_cents'] as num).toInt(),
    note: map['note'] as String?,
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

  DebtTransaction copyWith({
    int? id,
    int? profileId,
    DebtTransactionType? type,
    int? amountCents,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) => DebtTransaction(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    type: type ?? this.type,
    amountCents: amountCents ?? this.amountCents,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}
