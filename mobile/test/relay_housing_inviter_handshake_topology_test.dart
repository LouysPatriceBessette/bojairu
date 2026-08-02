import 'dart:io';
import 'dart:typed_data';

import 'package:compartarenta/contacts/contact_invitations_repository.dart';
import 'package:compartarenta/contacts/invitation_code.dart';
import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/contacts_repository.dart';
import 'package:compartarenta/housing/proposals/plan_agreement_proposal_service.dart';
import 'package:compartarenta/notifications/contact_notification_service.dart';
import 'package:compartarenta/relay/handshake_orchestrator.dart';
import 'package:compartarenta/relay/identity_keystore.dart';
import 'package:compartarenta/relay/testing/fake_relay_client.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/device_binding_test_support.dart';

/// QA topology: Monica (web inviter) uses `contact:handshake:*` rows; Louys and
/// Roberr (invitees) use `contact:redeemed:*`. This test uses inviter-side
/// handshake contact ids on the author's plan — matching production UI picks.
class _DbForTesting extends AppDatabase {
  _DbForTesting(super.e) : super.forTesting();
}

class _FakeContactNotificationSink implements ContactNotificationSink {
  @override
  Future<void> contactAddRequestReceived({required String displayName}) async {}

  @override
  Future<void> contactAddedViaInvitation({required String displayName}) async {}

  @override
  Future<void> contactAddRequestResolved({
    required String displayName,
    required bool accepted,
  }) async {}

  @override
  Future<void> contactAddRequestFailed({required String errorCode}) async {}

  @override
  Future<void> contactDuplicateModuleAnchorRejected() async {}

  @override
  Future<void> contactDisconnected({required String displayName}) async {}

  @override
  Future<void> planPeerEstablishmentRequestReceived({
    required String requesterDisplayName,
    required String proposerDisplayName,
    required String planId,
  }) async {}
}

class _Side {
  _Side({required this.db, required this.dbFile, required this.orchestrator});

  final AppDatabase db;
  final File dbFile;
  final HandshakeOrchestrator orchestrator;
}

int _relayDbFileSeq = 0;

Future<_Side> _spawnSide({
  required FakeRelayClient relay,
  required Uint8List identitySeed,
}) async {
  final id = _relayDbFileSeq++;
  final dbFile = File(
    '${Directory.systemTemp.path}/relay_housing_inviter_topo_$id.sqlite',
  );
  if (dbFile.existsSync()) dbFile.deleteSync();
  final db = _DbForTesting(NativeDatabase(dbFile));
  final identity = InMemoryIdentityKeystore(seed: identitySeed);
  final orchestrator = HandshakeOrchestrator(
    db: db,
    identity: identity,
    relay: relay,
    contacts: ContactsRepository(db),
    invitations: ContactInvitationsRepository(db),
    contactNotifications: _FakeContactNotificationSink(),
    pollInterval: const Duration(seconds: 60),
    deviceBinding: deviceBindingForTest(),
  );
  return _Side(db: db, dbFile: dbFile, orchestrator: orchestrator);
}

Future<({String inviterContactId, String inviteeContactId})> _completeHandshake({
  required _Side inviter,
  required _Side invitee,
  required String inviteeDisplayName,
}) async {
  inviter.orchestrator.ackProfileForAutoAccept = () async => (
        displayName: 'Monica',
        avatarId: 'mdi:monica',
      );
  final invite = await inviter.orchestrator.generateInvitation(
    validFor: const Duration(hours: 1),
    stubDisplayName: 'pending',
    stubAvatarId: 'mdi:account',
  );
  final code =
      (parseInvitationCode(invite.shortCode) as InvitationCodeOk).code;
  final redeem = await invitee.orchestrator.redeemInvitation(
    code: code,
    selfDisplayName: inviteeDisplayName,
    selfAvatarId: 'mdi:peer',
  );
  await inviter.orchestrator.processAllPendingHandshakes();
  await invitee.orchestrator.processAllPendingHandshakes();
  return (
    inviterContactId: invite.localContactId,
    inviteeContactId: redeem.localContactId,
  );
}

Future<String> _seedThreeParticipantPlanWithInviterContacts({
  required AppDatabase db,
  required String planId,
  required String louysInviterContactId,
  required String roberrInviterContactId,
}) async {
  final now = DateTime.utc(2026, 6, 18);
  await db.upsertPlan(
    PlansCompanion.insert(
      id: planId,
      type: 'housing',
      createdAt: now,
      title: const drift.Value('Monica three-way'),
      currency: const drift.Value('CAD'),
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: '$planId:self',
      displayName: 'Monica',
      avatarId: 'mdi:monica',
      createdAt: now,
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: '$planId:p0',
      displayName: 'Louys',
      avatarId: 'mdi:louys',
      createdAt: now,
      contactId: drift.Value(louysInviterContactId),
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: '$planId:p1',
      displayName: 'Roberr',
      avatarId: 'mdi:roberr',
      createdAt: now,
      contactId: drift.Value(roberrInviterContactId),
    ),
  );
  await db.upsertAgreement(
    AgreementsCompanion.insert(
      id: 'agreement:$planId',
      planId: planId,
      periodStart: now,
      periodEnd: now.add(const Duration(days: 30)),
      createdAt: now,
    ),
  );
  await db.upsertPlanLine(
    PlanLinesCompanion.insert(
      id: '$planId:line0',
      planId: planId,
      isRecurring: true,
      title: 'Rent',
      currency: 'CAD',
      amountMinor: const drift.Value(10000),
      recurrenceDayOfMonth: const drift.Value(1),
      createdAt: now,
    ),
  );
  return PlanAgreementProposalService(db).createRevisionFromCurrentDraft(
    planId: planId,
    proposerParticipantId: '$planId:self',
  );
}

Future<int> _proposalPackageCount(AppDatabase db) async {
  return (await db.select(db.proposalPackages).get()).length;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  test(
    'inviter handshake contact ids deliver proposal to redeemed invitees',
    () async {
      SharedPreferences.setMockInitialValues({
        'profile.displayName': 'Monica',
        'profile.avatarId': 'mdi:monica',
      });
      final relay = FakeRelayClient();
      final monica = await _spawnSide(
        relay: relay,
        identitySeed: Uint8List.fromList(List<int>.generate(32, (i) => 10 + i)),
      );
      final louys = await _spawnSide(
        relay: relay,
        identitySeed: Uint8List.fromList(List<int>.generate(32, (i) => 20 + i)),
      );
      final roberr = await _spawnSide(
        relay: relay,
        identitySeed: Uint8List.fromList(List<int>.generate(32, (i) => 30 + i)),
      );
      addTearDown(() async {
        for (final side in [monica, louys, roberr]) {
          side.orchestrator.stopPolling();
          await side.db.close();
          try {
            if (side.dbFile.existsSync()) side.dbFile.deleteSync();
          } catch (_) {}
        }
      });

      final monicaLouys = await _completeHandshake(
        inviter: monica,
        invitee: louys,
        inviteeDisplayName: 'Louys',
      );
      final monicaRoberr = await _completeHandshake(
        inviter: monica,
        invitee: roberr,
        inviteeDisplayName: 'Roberr',
      );

      expect(monicaLouys.inviterContactId, startsWith('contact:handshake:'));
      expect(monicaRoberr.inviterContactId, startsWith('contact:handshake:'));
      expect(monicaLouys.inviteeContactId, startsWith('contact:redeemed:'));
      expect(monicaRoberr.inviteeContactId, startsWith('contact:redeemed:'));

      const planId = 'housing:monica-topology';
      final revisionId = await _seedThreeParticipantPlanWithInviterContacts(
        db: monica.db,
        planId: planId,
        louysInviterContactId: monicaLouys.inviterContactId,
        roberrInviterContactId: monicaRoberr.inviterContactId,
      );

      final send = await monica.orchestrator.sendHousingProposalToPlanParticipants(
        planId: planId,
        revisionId: revisionId,
      );
      expect(send.sentCount, 2);
      expect(send.failedParticipantIds, isEmpty);
      expect(relay.envelopeCount, 2);

      expect(await _proposalPackageCount(louys.db), 0);
      expect(await _proposalPackageCount(roberr.db), 0);

      await louys.orchestrator.pollSteadyStateInboxes();
      await roberr.orchestrator.pollSteadyStateInboxes();

      expect(await _proposalPackageCount(louys.db), 1);
      expect(await _proposalPackageCount(roberr.db), 1);
      expect(relay.envelopeCount, 0);
    },
  );
}
