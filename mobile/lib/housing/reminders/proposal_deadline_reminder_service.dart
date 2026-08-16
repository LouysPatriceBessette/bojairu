import 'dart:convert';
import 'dart:typed_data';

import '../../notifications/push_notification_service.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/relay_client.dart';
import '../../relay/relay_scheduling.dart';
import '../../scheduling/action_deadline_reminder_service.dart';
import '../../scheduling/client_scheduled_fire_times.dart';

/// Housing proposal decision-deadline fires (recipe A).
class ProposalDeadlineReminderService {
  ProposalDeadlineReminderService({
    required RelayClient relay,
    AppPreferences? prefs,
  }) : _prefs = prefs,
       _actions = ActionDeadlineReminderService(relay: relay);

  final AppPreferences? _prefs;
  final ActionDeadlineReminderService _actions;

  Future<void> registerFires({
    required Uint8List senderIdentity,
    required String revisionId,
    required DateTime expiresAtUtc,
    required Duration validFor,
    required List<Uint8List> decisionMakerRoutingIds,
    required List<Uint8List> waiterRoutingIds,
  }) {
    return _actions.register(
      senderIdentity: senderIdentity,
      domain: ClientScheduledFireTimes.domainHousingProposalDeadline,
      scopeKeyBytes: ClientScheduledFireTimes.scopeKeyFromUtf8(revisionId),
      expiresAtUtc: expiresAtUtc,
      validFor: validFor,
      decisionMakerRoutingIds: decisionMakerRoutingIds,
      waiterRoutingIds: waiterRoutingIds,
    );
  }

  Future<void> cancelForRevision({
    required Uint8List senderIdentity,
    required String revisionId,
  }) {
    return _actions.cancel(
      senderIdentity: senderIdentity,
      domain: ClientScheduledFireTimes.domainHousingProposalDeadline,
      scopeKeyBytes: ClientScheduledFireTimes.scopeKeyFromUtf8(revisionId),
    );
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
      reminderKind: d.reminderKind,
    );
    return true;
  }
}
