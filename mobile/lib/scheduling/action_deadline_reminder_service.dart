import 'package:flutter/foundation.dart';

import '../relay/relay_client.dart';
import '../relay/relay_scheduling.dart';
import 'client_scheduled_fire_times.dart';

/// Registers recipe-A decision-deadline fires (soon → decision makers,
/// at T → waiters) on the relay.
final class ActionDeadlineReminderService {
  ActionDeadlineReminderService({required RelayClient relay}) : _relay = relay;

  final RelayClient _relay;

  Future<void> register({
    required Uint8List senderIdentity,
    required String domain,
    required Uint8List scopeKeyBytes,
    required DateTime expiresAtUtc,
    required Duration validFor,
    required List<Uint8List> decisionMakerRoutingIds,
    required List<Uint8List> waiterRoutingIds,
  }) async {
    if (kIsWeb) return;
    final now = DateTime.now().toUtc();
    final pairs = ClientScheduledFireTimes.actionDeadlineFires(
      validFor: validFor,
      expiresAtUtc: expiresAtUtc,
      nowUtc: now,
    );
    if (pairs.isEmpty) return;
    final due = expiresAtUtc.toUtc();
    final targets = <ClientScheduledFireTarget>[];
    for (final pair in pairs) {
      final recipients = pair.kind == ClientScheduledFireTimes.kindExpired
          ? waiterRoutingIds
          : decisionMakerRoutingIds;
      for (final recipient in recipients) {
        targets.add(
          ClientScheduledFireTarget(
            domain: domain,
            scopeKeyBytes: scopeKeyBytes,
            recipientRoutingId: recipient,
            reminderKind: pair.kind,
            fireAts: [pair.fireAt],
            dueAt: due,
          ),
        );
      }
    }
    if (targets.isEmpty) return;
    try {
      await _relay.upsertClientScheduledFires(
        senderIdentity: senderIdentity,
        targets: targets,
      );
    } on RelayClientError catch (e) {
      if (kDebugMode) {
        debugPrint('actionDeadlineReminder: upsert failed: $e');
      }
    }
  }

  Future<void> cancel({
    required Uint8List senderIdentity,
    required String domain,
    required Uint8List scopeKeyBytes,
  }) async {
    if (kIsWeb) return;
    try {
      await _relay.cancelClientScheduledFires(
        senderIdentity: senderIdentity,
        domain: domain,
        scopeKeyBytes: [scopeKeyBytes],
      );
    } on RelayClientError catch (e) {
      if (kDebugMode) {
        debugPrint('actionDeadlineReminder: cancel failed: $e');
      }
    }
  }
}
