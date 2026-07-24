import 'dart:typed_data';

import 'routing.dart';

/// Pending scheduled reminder delivery from relay cron.
final class RelayPendingReminderDelivery {
  const RelayPendingReminderDelivery({
    required this.fireId,
    required this.domain,
    required this.scopeKeyBytes,
    required this.reminderKind,
    required this.periodKeyBytes,
    this.periodDueAt,
    this.recurrencePeriodDays,
    required this.firedAt,
  });

  final Uint8List fireId;
  final String domain;
  final Uint8List scopeKeyBytes;
  final String reminderKind;
  final Uint8List periodKeyBytes;
  final DateTime? periodDueAt;
  final int? recurrencePeriodDays;
  final DateTime firedAt;

  factory RelayPendingReminderDelivery.fromJson(Map<String, dynamic> json) {
    return RelayPendingReminderDelivery(
      fireId: RelaySchedulingCodec.decodeId(json['fire_id'] as String),
      domain: json['domain'] as String,
      scopeKeyBytes: RelaySchedulingCodec.decodeId(json['scope_key'] as String),
      reminderKind: json['reminder_kind'] as String,
      periodKeyBytes: RelaySchedulingCodec.decodeOptionalId(
        json['period_key'] as String?,
      ),
      periodDueAt: json['period_due_at'] == null
          ? null
          : DateTime.parse(json['period_due_at'] as String),
      recurrencePeriodDays: (json['recurrence_period_days'] as num?)?.toInt(),
      firedAt: DateTime.parse(json['fired_at'] as String),
    );
  }
}

/// One housing payment target row sent during reconciliation.
final class HousingReminderScheduleTarget {
  const HousingReminderScheduleTarget({
    required this.scopeKeyBytes,
    required this.recipientRoutingId,
    required this.reminderKind,
    required this.periodKeyBytes,
    required this.recurrencePeriodDays,
    required this.dueAt,
    this.boundAt,
  });

  final Uint8List scopeKeyBytes;
  final Uint8List recipientRoutingId;
  final String reminderKind;
  final Uint8List periodKeyBytes;
  final int recurrencePeriodDays;
  final DateTime dueAt;
  final DateTime? boundAt;

  Map<String, dynamic> toJson() => {
    'scope_key': RelaySchedulingCodec.encodeId(scopeKeyBytes),
    'recipient_identity': RelaySchedulingCodec.encodeId(recipientRoutingId),
    'reminder_kind': reminderKind,
    'period_key': RelaySchedulingCodec.encodeId(periodKeyBytes),
    'recurrence_period_days': recurrencePeriodDays,
    'due_at': dueAt.toUtc().toIso8601String(),
    if (boundAt != null) 'bound_at': boundAt!.toUtc().toIso8601String(),
  };
}

/// One client-supplied scheduled-fire target (invitation / proposal deadline).
final class ClientScheduledFireTarget {
  const ClientScheduledFireTarget({
    required this.domain,
    required this.scopeKeyBytes,
    required this.recipientRoutingId,
    required this.reminderKind,
    required this.fireAts,
    this.dueAt,
    this.generation = 1,
  });

  final String domain;
  final Uint8List scopeKeyBytes;
  final Uint8List recipientRoutingId;
  final String reminderKind;
  final List<DateTime> fireAts;
  final DateTime? dueAt;
  final int generation;

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'scope_key': RelaySchedulingCodec.encodeId(scopeKeyBytes),
    'recipient_identity': RelaySchedulingCodec.encodeId(recipientRoutingId),
    'reminder_kind': reminderKind,
    'generation': generation,
    if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
    'fires': [
      for (final at in fireAts) {'fire_at': at.toUtc().toIso8601String()},
    ],
  };
}

class RelaySchedulingCodec {
  RelaySchedulingCodec._();

  static String encodeId(Uint8List bytes) => RelayRouting.b64(bytes);

  static Uint8List decodeId(String b64) => RelayRouting.unb64(b64);

  static Uint8List decodeOptionalId(String? b64) =>
      b64 == null || b64.isEmpty ? Uint8List(0) : decodeId(b64);
}
