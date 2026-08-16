import 'dart:typed_data';

import 'package:compartarenta/relay/testing/fake_relay_client.dart';
import 'package:compartarenta/scheduling/action_deadline_reminder_service.dart';
import 'package:compartarenta/scheduling/client_scheduled_fire_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recipe A soon goes to decision makers and expiry to waiters', () async {
    final relay = FakeRelayClient();
    final sender = Uint8List.fromList(List<int>.filled(32, 1));
    final decisionMaker = Uint8List.fromList(List<int>.filled(32, 2));
    final waiter = Uint8List.fromList(List<int>.filled(32, 3));
    final expires = DateTime.now().toUtc().add(const Duration(hours: 24));

    await ActionDeadlineReminderService(relay: relay).register(
      senderIdentity: sender,
      domain: ClientScheduledFireTimes.domainVehicleSharingDeadline,
      scopeKeyBytes: ClientScheduledFireTimes.scopeKeyFromUtf8('link-1'),
      expiresAtUtc: expires,
      validFor: const Duration(hours: 24),
      decisionMakerRoutingIds: [decisionMaker],
      waiterRoutingIds: [waiter],
    );

    final targets = relay.lastScheduledFireTargets;
    expect(targets, hasLength(2));
    final soon = targets.singleWhere(
      (t) => t.reminderKind == ClientScheduledFireTimes.kindBeforeExpiry,
    );
    final expired = targets.singleWhere(
      (t) => t.reminderKind == ClientScheduledFireTimes.kindExpired,
    );
    expect(soon.recipientRoutingId, same(decisionMaker));
    expect(expired.recipientRoutingId, same(waiter));
    expect(soon.domain, ClientScheduledFireTimes.domainVehicleSharingDeadline);
  });
}
