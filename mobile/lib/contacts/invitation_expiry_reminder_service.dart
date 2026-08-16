import 'package:flutter/foundation.dart';

import '../notifications/push_notification_service.dart';
import '../prefs/app_preferences.dart';
import '../relay/handshake_orchestrator.dart';
import '../relay/relay_client.dart';
import '../relay/relay_scheduling.dart';
import '../scheduling/action_deadline_reminder_service.dart';
import '../scheduling/client_scheduled_fire_times.dart';

/// Contacts invitation expiry fires (recipe A; both pings to the inviter).
class InvitationExpiryReminderService {
  InvitationExpiryReminderService({
    required RelayClient relay,
    required HandshakeOrchestrator orchestrator,
    AppPreferences? prefs,
  }) : _orchestrator = orchestrator,
       _prefs = prefs,
       _actions = ActionDeadlineReminderService(relay: relay);

  final HandshakeOrchestrator _orchestrator;
  final AppPreferences? _prefs;
  final ActionDeadlineReminderService _actions;

  Future<void> registerForInvitation({
    required String invitationId,
    required Duration validFor,
    required DateTime expiresAtUtc,
  }) async {
    if (kIsWeb) return;
    final recipients = await _orchestrator.routingWakeRecipientIdentities();
    if (recipients.isEmpty) return;
    await _actions.register(
      senderIdentity: recipients.first,
      domain: ClientScheduledFireTimes.domainContactsInvitationExpiry,
      scopeKeyBytes: ClientScheduledFireTimes.scopeKeyFromUtf8(invitationId),
      expiresAtUtc: expiresAtUtc,
      validFor: validFor,
      decisionMakerRoutingIds: recipients,
      waiterRoutingIds: recipients,
    );
  }

  Future<void> cancelForInvitation(String invitationId) async {
    if (kIsWeb) return;
    final recipients = await _orchestrator.routingWakeRecipientIdentities();
    if (recipients.isEmpty) return;
    await _actions.cancel(
      senderIdentity: recipients.first,
      domain: ClientScheduledFireTimes.domainContactsInvitationExpiry,
      scopeKeyBytes: ClientScheduledFireTimes.scopeKeyFromUtf8(invitationId),
    );
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
