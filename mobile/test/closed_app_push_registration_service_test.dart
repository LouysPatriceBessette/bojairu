import 'dart:typed_data';

import 'package:compartarenta/contacts/contact_invitations_repository.dart';
import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/contacts_repository.dart';
import 'package:compartarenta/notifications/closed_app_push_registration_service.dart';
import 'package:compartarenta/notifications/push_notification_service.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/relay/handshake_orchestrator.dart';
import 'package:compartarenta/relay/identity_keystore.dart';
import 'package:compartarenta/relay/testing/fake_relay_client.dart';
import 'package:drift/native.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/device_binding_test_support.dart';

class _DbForTesting extends AppDatabase {
  _DbForTesting(super.e) : super.forTesting();
}

void main() {
  group('AppPreferences routing push wire values', () {
    test('country off sends UNDISCLOSED', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();
      expect(prefs.countryCodeForRoutingPushRegistration, 'UNDISCLOSED');
    });

    test('country on with selection sends ISO code', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();
      await prefs.setNotificationCountryStatisticsEnabled(true);
      await prefs.setNotificationCountryStatisticsCode('fr');
      expect(prefs.countryCodeForRoutingPushRegistration, 'FR');
    });

    test('country on without selection sends UNDISCLOSED', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();
      await prefs.setNotificationCountryStatisticsEnabled(true);
      expect(prefs.countryCodeForRoutingPushRegistration, 'UNDISCLOSED');
    });

    test('wake-eligible requires contact add, payment, or housing plan categories',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();
      expect(prefs.hasWakeEligibleCategoryEnabled, isTrue);
      await prefs.setNotificationContactAddRequests(false);
      await prefs.setNotificationHousingPaymentReminders(false);
      await prefs.setNotificationHousingPlanSubmission(false);
      await prefs.setNotificationHousingDecisionChange(false);
      expect(prefs.hasWakeEligibleCategoryEnabled, isFalse);
      await prefs.setNotificationHousingPlanSubmission(true);
      expect(prefs.hasWakeEligibleCategoryEnabled, isTrue);
    });
  });

  group('ClosedAppPushRegistrationService', () {
    late FakeRelayClient relay;
    late AppPreferences prefs;
    late SharedPreferences sp;
    late HandshakeOrchestrator orch;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sp = await SharedPreferences.getInstance();
      prefs = await AppPreferences.load();
      await prefs.setNotificationsEnabled(true);
      relay = FakeRelayClient();
      final db = _DbForTesting(NativeDatabase.memory());
      orch = HandshakeOrchestrator(
        db: db,
        identity: InMemoryIdentityKeystore(seed: Uint8List.fromList(List.filled(32, 3))),
        relay: relay,
        contacts: ContactsRepository(db),
        invitations: ContactInvitationsRepository(db),
        pollInterval: const Duration(days: 1),
        deviceBinding: deviceBindingForTest(),
      );
      HandshakeOrchestrator.install(orch);
      ClosedAppPushRegistrationService.install(
        relay: relay,
        prefs: prefs,
        tokenProvider: () async => 'device-token-a',
        prefsStore: sp,
      );
    });

    test('master switch off does not register', () async {
      await prefs.setNotificationsEnabled(false);
      await ClosedAppPushRegistrationService.maybeInstance!.sync(force: true);
      expect(relay.routingPushRegistrations, isEmpty);
    });

    test('all wake-eligible categories off does not register', () async {
      await prefs.setNotificationContactAddRequests(false);
      await prefs.setNotificationHousingPaymentReminders(false);
      await ClosedAppPushRegistrationService.maybeInstance!.sync(force: true);
      expect(relay.routingPushRegistrations, isEmpty);
    });

    test('syncIfNeeded skips before half TTL elapsed', () async {
      final now = DateTime.now().toUtc();
      await sp.setInt('routing_push.last_refresh_ms', now.millisecondsSinceEpoch);
      await sp.setInt(
        'routing_push.min_expires_ms',
        now.add(const Duration(days: 14)).millisecondsSinceEpoch,
      );
      await ClosedAppPushRegistrationService.maybeInstance!.syncIfNeeded();
      expect(relay.routingPushRegistrations, isEmpty);
    });

    test('onTokenRefreshed replaces stored token after rotation', () async {
      await sp.setString('routing_push.last_token', 'device-token-a');
      ClosedAppPushRegistrationService.install(
        relay: relay,
        prefs: prefs,
        tokenProvider: () async => 'device-token-b',
        prefsStore: sp,
      );
      await ClosedAppPushRegistrationService.maybeInstance!.onTokenRefreshed(
        'device-token-b',
      );
      expect(sp.getString('routing_push.last_token'), 'device-token-b');
    });
  });

  group('Wake push recognition', () {
    test('wake_for_inbox kind is detected', () {
      final msg = RemoteMessage(
        data: const {'kind': 'wake_for_inbox', 'v': '1'},
      );
      expect(PushNotificationService.isWakeForInboxRemoteMessage(msg), isTrue);
    });

    test('operator_notice kind is detected and is not a wake', () {
      final msg = RemoteMessage(
        data: const {
          'kind': 'operator_notice',
          'v': '1',
          'consult_site': '1',
          'target_build': '39',
        },
      );
      expect(PushNotificationService.isOperatorNoticeRemoteMessage(msg), isTrue);
      expect(PushNotificationService.isWakeForInboxRemoteMessage(msg), isFalse);
    });
  });
}
