import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../notifications/push_notification_service.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/relay_client.dart';
import '../../relay/relay_scheduling.dart';
import '../../scheduling/client_scheduled_fire_times.dart';

/// Registers / cancels housing proposal deadline fires on the relay.
class ProposalDeadlineReminderService {
  ProposalDeadlineReminderService({
    required RelayClient relay,
    AppPreferences? prefs,
  }) : _relay = relay,
       _prefs = prefs;

  final RelayClient _relay;
  final AppPreferences? _prefs;

  Future<void> registerFires({
    required Uint8List senderIdentity,
    required String revisionId,
    required DateTime expiresAtUtc,
    required List<Uint8List> recipientRoutingIds,
  }) async {
    if (kIsWeb || recipientRoutingIds.isEmpty) return;
    final now = DateTime.now().toUtc();
    final fireAts = ClientScheduledFireTimes.proposalDeadlineFireAts(
      expiresAtUtc: expiresAtUtc,
      nowUtc: now,
    );
    if (fireAts.isEmpty) return;
    final scope = ClientScheduledFireTimes.scopeKeyFromUtf8(revisionId);
    final targets = [
      for (final recipient in recipientRoutingIds)
        ClientScheduledFireTarget(
          domain: ClientScheduledFireTimes.domainHousingProposalDeadline,
          scopeKeyBytes: scope,
          recipientRoutingId: recipient,
          reminderKind: ClientScheduledFireTimes.kindBeforeDeadline,
          fireAts: fireAts,
          dueAt: expiresAtUtc.toUtc(),
        ),
    ];
    try {
      await _relay.upsertClientScheduledFires(
        senderIdentity: senderIdentity,
        targets: targets,
      );
    } on RelayClientError catch (e) {
      if (kDebugMode) {
        debugPrint('proposalDeadlineReminder: upsert failed: $e');
      }
    }
  }

  Future<void> cancelForRevision({
    required Uint8List senderIdentity,
    required String revisionId,
  }) async {
    if (kIsWeb) return;
    try {
      await _relay.cancelClientScheduledFires(
        senderIdentity: senderIdentity,
        domain: ClientScheduledFireTimes.domainHousingProposalDeadline,
        scopeKeyBytes: [ClientScheduledFireTimes.scopeKeyFromUtf8(revisionId)],
      );
    } on RelayClientError catch (e) {
      if (kDebugMode) {
        debugPrint('proposalDeadlineReminder: cancel failed: $e');
      }
    }
  }

  Future<bool> deliverIfApplicable(RelayPendingReminderDelivery d) async {
    if (d.domain != ClientScheduledFireTimes.domainHousingProposalDeadline) {
      return false;
    }
    final prefs = _prefs;
    if (prefs == null) return false;
    if (!prefs.notificationsEnabled ||
        !prefs.notificationHousingOfferExpiration) {
      return true;
    }
    final revisionId = utf8.decode(d.scopeKeyBytes);
    await PushNotificationService.showLocalHousingProposalDeadlineNotification(
      revisionId: revisionId,
    );
    return true;
  }
}
