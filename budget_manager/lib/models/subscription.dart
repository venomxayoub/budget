enum SubscriptionPeriod {
  weekly,
  monthly,
  annual;

  String get label => switch (this) {
    weekly => 'Weekly',
    monthly => 'Monthly',
    annual => 'Annual',
  };
}

enum SubscriptionStatus {
  active,
  paused,
  cancelled;

  String get label => switch (this) {
    active => 'Active',
    paused => 'Paused',
    cancelled => 'Cancelled',
  };
}

class Subscription {
  final int? id;
  final String name;
  final int priceCents;
  final SubscriptionPeriod period;
  final SubscriptionStatus status;
  final DateTime renewalAnchorDate;
  final DateTime nextRenewalDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Subscription({
    this.id,
    required this.name,
    required this.priceCents,
    required this.period,
    required this.status,
    required this.renewalAnchorDate,
    required this.nextRenewalDate,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'price_cents': priceCents,
    'period': period.name,
    'status': status.name,
    'renewal_anchor_date': _dateToStorage(renewalAnchorDate),
    'next_renewal_date': _dateToStorage(nextRenewalDate),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
    id: map['id'] as int?,
    name: map['name'] as String,
    priceCents: (map['price_cents'] as num).toInt(),
    period: SubscriptionPeriod.values.byName(map['period'] as String),
    status: SubscriptionStatus.values.byName(map['status'] as String),
    renewalAnchorDate: DateTime.parse(map['renewal_anchor_date'] as String),
    nextRenewalDate: DateTime.parse(map['next_renewal_date'] as String),
    createdAt:
        map['created_at'] == null
            ? null
            : DateTime.parse(map['created_at'] as String),
    updatedAt:
        map['updated_at'] == null
            ? null
            : DateTime.parse(map['updated_at'] as String),
  );

  Subscription copyWith({
    int? id,
    String? name,
    int? priceCents,
    SubscriptionPeriod? period,
    SubscriptionStatus? status,
    DateTime? renewalAnchorDate,
    DateTime? nextRenewalDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Subscription(
    id: id ?? this.id,
    name: name ?? this.name,
    priceCents: priceCents ?? this.priceCents,
    period: period ?? this.period,
    status: status ?? this.status,
    renewalAnchorDate: renewalAnchorDate ?? this.renewalAnchorDate,
    nextRenewalDate: nextRenewalDate ?? this.nextRenewalDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

String _dateToStorage(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
