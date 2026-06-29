import 'subscription.dart';

class SubscriptionStatusEvent {
  final int? id;
  final int subscriptionId;
  final SubscriptionStatus? fromStatus;
  final SubscriptionStatus toStatus;
  final DateTime occurredAt;

  const SubscriptionStatusEvent({
    this.id,
    required this.subscriptionId,
    required this.fromStatus,
    required this.toStatus,
    required this.occurredAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'subscription_id': subscriptionId,
    'from_status': fromStatus?.name,
    'to_status': toStatus.name,
    'occurred_at': occurredAt.toIso8601String(),
  };

  factory SubscriptionStatusEvent.fromMap(Map<String, dynamic> map) =>
      SubscriptionStatusEvent(
        id: map['id'] as int?,
        subscriptionId: map['subscription_id'] as int,
        fromStatus:
            map['from_status'] == null
                ? null
                : SubscriptionStatus.values.byName(
                  map['from_status'] as String,
                ),
        toStatus: SubscriptionStatus.values.byName(map['to_status'] as String),
        occurredAt: DateTime.parse(map['occurred_at'] as String),
      );
}
