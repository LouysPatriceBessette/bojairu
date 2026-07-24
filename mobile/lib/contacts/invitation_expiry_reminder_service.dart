import 'package:flutter/foundation.dart';

import '../notifications/push_notification_service.dart';
import '../prefs/app_preferences.dart';
import '../relay/handshake_orchestrator.dart';
import '../relay/relay_client.dart';
import '../relay/relay_scheduling.dart';
import '../scheduling/client_scheduled_fire_times.dart';

/// Registers / cancels contacts invitation expiry fires on the relay.
class InvitationExpiryReminderService {
  InvitationExpiryReminderService({
    required RelayClient relay,
    required HandshakeOrchestrator orchestrator,
    AppPreferences? prefs,
  }) : _relay = relay,
       _orchestrator = orchestrator,
       _prefs = prefs;

  final RelayClient _relay;
  final HandshakeOrchestrator _orchestrator;
  final AppPreferences? _prefs;

  Future<void> registerForInvitation({
    required String invitationId,
    required Duration validFor,
    required DateTime expiresAtUtc,
  }) async {
    if (kIsWeb) return;
    final recipients = await _orchestrator.routingWakeRecipientIdentities();
    if (recipients.isEmpty) return;
    final now = DateTime.now().toUtc();
    final pairs = ClientScheduledFireTimes.invitationExpiryFires(
      validFor: validFor,
      expiresAtUtc: expiresAtUtc,
      nowUtc: now,
    );
    if (pairs.isEmpty) return;
    final scope = ClientScheduledFireTimes.scopeKeyFromUtf8(invitationId);
    final sender = recipients.first;
    final targets = <ClientScheduledFireTarget>[];
    for (final recipient in recipients) {
      for (final pair in pairs) {
        targets.add(
          ClientScheduledFireTarget(
            domain: ClientScheduledFireTimes.domainContactsInvitationExpiry,
            scopeKeyBytes: scope,
            recipientRoutingId: recipient,
            reminderKind: pair.kind,
            fireAts: [pair.fireAt],
            dueAt: expiresAtUtc.toUtc(),
          ),
        );
      }
    }
    try {
      await _relay.upsertClientScheduledFires(
        senderIdentity: sender,
        targets: targets,
      );
    } on RelayClientError catch (e) {
      if (kDebugMode) {
        debugPrint('invitationExpiryReminder: upsert failed: $e');
      }
    }
  }

  Future<void> cancelForInvitation(String invitationId) async {
    if (kIsWeb) return;
    final recipients = await _orchestrator.routingWakeRecipientIdentities();
    if (recipients.isEmpty) return;
    try {
      await _relay.cancelClientScheduledFires(
        senderIdentity: recipients.first,
        domain: ClientScheduledFireTimes.domainContactsInvitationExpiry,
        scopeKeyBytes: [ClientScheduledFireTimes.scopeKeyFromUtf8(invitationId)],
      );
    } on RelayClientError catch (e) {
      if (kDebugMode) {
        debugPrint('invitationExpiryReminder: cancel failed: $e');
      }
    }
  }

  Future<bool> deliverIfApplicable(RelayPendingReminderDelivery d) async {
    if (d.domain != ClientScheduledFireTimes.domainContactsInvitationExpiry) {
      return false;
    }
    final prefs = _prefs;
    if (prefs == null) return false;
    if (!prefs.notificationsEnabled ||
        !prefs.notificationContactInvitationExpiration) {
      return true;
    }
    await PushNotificationService.showLocalContactInvitationExpiryNotification(
      reminderKind: d.reminderKind,
    );
    return true;
  }
}
