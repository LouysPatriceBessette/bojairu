import 'dart:io';
import 'dart:typed_data';

import 'package:compartarenta/contacts/contact_invitations_repository.dart';
import 'package:compartarenta/contacts/invitation_code.dart';
import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/contacts_repository.dart';
import 'package:compartarenta/notifications/contact_notification_service.dart';
import 'package:compartarenta/housing/proposals/plan_agreement_proposal_service.dart';
import 'package:compartarenta/relay/envelopes.dart';
import 'package:compartarenta/relay/handshake_orchestrator.dart';
import 'package:compartarenta/relay/identity_keystore.dart';
import 'package:compartarenta/relay/routing.dart';
import 'package:compartarenta/relay/testing/fake_relay_client.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/device_binding_test_support.dart';

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
  _Side({
    required this.db,
    required this.dbFile,
    required this.identity,
    required this.orchestrator,
    required this.contacts,
  });

  final AppDatabase db;
  final File dbFile;
  final IdentityKeystore identity;
  final HandshakeOrchestrator orchestrator;
  final ContactsRepository contacts;
}

int _relayDbFileSeq = 0;

Future<_Side> _spawnSide({
  required FakeRelayClient relay,
  required Uint8List identitySeed,
}) async {
  final id = _relayDbFileSeq++;
  final dbFile = File(
    '${Directory.systemTemp.path}/relay_housing_stale_test_$id.sqlite',
  );
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
  }
  final db = _DbForTesting(NativeDatabase(dbFile));
  final identity = InMemoryIdentityKeystore(seed: identitySeed);
  final contacts = ContactsRepository(db);
  final invitations = ContactInvitationsRepository(db);
  final orchestrator = HandshakeOrchestrator(
    db: db,
    identity: identity,
    relay: relay,
    contacts: contacts,
    invitations: invitations,
    contactNotifications: _FakeContactNotificationSink(),
    pollInterval: const Duration(seconds: 60),
    deviceBinding: deviceBindingForTest(),
  );
  return _Side(
    db: db,
    dbFile: dbFile,
    identity: identity,
    orchestrator: orchestrator,
    contacts: contacts,
  );
}

Future<({String inviterContactId, String inviteeContactId})> _completeHandshake({
  required _Side inviter,
  required _Side invitee,
  required String inviteeDisplayName,
}) async {
  inviter.orchestrator.ackProfileForAutoAccept = () async => (
        displayName: 'Android User',
        avatarId: 'mdi:android',
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
    selfAvatarId: 'mdi:web',
  );
  await inviter.orchestrator.processAllPendingHandshakes();
  await invitee.orchestrator.processAllPendingHandshakes();
  return (
    inviterContactId: invite.localContactId,
    inviteeContactId: redeem.localContactId,
  );
}

Future<String> _seedHousingPlanReadyToSend({
  required AppDatabase db,
  required String planId,
  required String coParticipantContactId,
}) async {
  final now = DateTime.utc(2026, 5, 20);
  await db.upsertPlan(
    PlansCompanion.insert(
      id: planId,
      type: 'housing',
      createdAt: now,
      title: const drift.Value('Housing test plan'),
      currency: const drift.Value('CAD'),
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: '$planId:self',
      displayName: 'Web Proposer',
      avatarId: 'mdi:web',
      createdAt: now,
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: '$planId:p0',
      displayName: 'Android User',
      avatarId: 'mdi:android',
      createdAt: now,
      contactId: drift.Value(coParticipantContactId),
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

Future<List<String>> _receivedHousingPlanIds(AppDatabase db) async {
  final rows = await db.select(db.plans).get();
  return rows
      .map((p) => p.id)
      .where((id) => id.startsWith('received:'))
      .toList();
}

/// Invalid housing proposal frame: correct kind byte, AEAD will fail.
Uint8List _corruptHousingProposalFrame() {
  final frame = Uint8List(62);
  frame[0] = 1;
  frame[1] = EnvelopeKind.housingProposal;
  return frame;
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

  late FakeRelayClient relay;
  late _Side android;
  late _Side webOld;
  late _Side webNew;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'profile.displayName': 'Android User',
      'profile.avatarId': 'mdi:android',
    });
    relay = FakeRelayClient();
    android = await _spawnSide(
      relay: relay,
      identitySeed: Uint8List.fromList(List<int>.generate(32, (i) => 50 + i)),
    );
    webOld = await _spawnSide(
      relay: relay,
      identitySeed: Uint8List.fromList(List<int>.generate(32, (i) => 100 + i)),
    );
    webNew = await _spawnSide(
      relay: relay,
      identitySeed: Uint8List.fromList(List<int>.generate(32, (i) => 200 + i)),
    );
  });

  tearDown(() async {
    android.orchestrator.stopPolling();
    webOld.orchestrator.stopPolling();
    webNew.orchestrator.stopPolling();
    await android.db.close();
    await webOld.db.close();
    await webNew.db.close();
    for (final f in [android.dbFile, webOld.dbFile, webNew.dbFile]) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  });

  test(
    'android with stale and current web connected imports proposal for current web only',
    () async {
      await _completeHandshake(
        inviter: android,
        invitee: webOld,
        inviteeDisplayName: 'Web Old',
      );
      final second = await _completeHandshake(
        inviter: android,
        invitee: webNew,
        inviteeDisplayName: 'Web New',
      );

      final androidContacts = (await android.contacts.list())
          .where((c) => c.kind == 'connected')
          .toList();
      expect(androidContacts, hasLength(2));

      const planId = 'housing:stale-test';
      final revisionId = await _seedHousingPlanReadyToSend(
        db: webNew.db,
        planId: planId,
        coParticipantContactId: second.inviteeContactId,
      );

      final send = await webNew.orchestrator.sendHousingProposalToPlanParticipants(
        planId: planId,
        revisionId: revisionId,
      );
      expect(send.sentCount, 1);
      expect(send.failedParticipantIds, isEmpty);
      expect(relay.envelopeCount, greaterThan(0));

      expect(await _receivedHousingPlanIds(android.db), isEmpty);

      await android.orchestrator.pollSteadyStateInboxes();

      expect(await _receivedHousingPlanIds(android.db), hasLength(1));
      expect(relay.envelopeCount, 0);

      final imported = await (android.db.select(android.db.plans).get())
          .then((rows) => rows.singleWhere((p) => p.id.startsWith('received:')));
      final proposerRow = await (android.db.select(android.db.participants).get())
          .then(
            (rows) => rows.singleWhere((p) => p.contactId == second.inviterContactId),
          );
      expect(proposerRow.id, startsWith('${imported.id}:'));
      expect(proposerRow.displayName, 'Web New');
    },
  );

  test(
    'housing proposal with corrupt ciphertext is acked without import',
    () async {
      final pair = await _completeHandshake(
        inviter: android,
        invitee: webNew,
        inviteeDisplayName: 'Web New',
      );

      final androidContact = await android.contacts.get(pair.inviterContactId);
      expect(androidContact?.peerPublicMaterial, isNotNull);

      final androidPub = await android.identity.publicKey();
      // Android contact row stores the peer (web) long-term public key.
      final webPub = RelayRouting.unb64(androidContact!.peerPublicMaterial!);
      final listenAddr = await RelayRouting.steadyStateAddress(
        firstPub: androidPub,
        secondPub: webPub,
      );
      final senderAddr = await RelayRouting.steadyStateAddress(
        firstPub: webPub,
        secondPub: androidPub,
      );
      await relay.establishRouting(
        selfIdentity: senderAddr,
        peerIdentity: listenAddr,
      );

      expect(await _receivedHousingPlanIds(android.db), isEmpty);

      await relay.postEnvelope(
        senderIdentity: senderAddr,
        recipientIdentity: listenAddr,
        idempotencyKey: Uint8List.fromList(List<int>.filled(16, 7)),
        ciphertext: _corruptHousingProposalFrame(),
        kind: EnvelopeKind.housingProposal,
        ttl: const Duration(hours: 1),
      );

      await android.orchestrator.pollSteadyStateInboxes();

      expect(await _receivedHousingPlanIds(android.db), isEmpty);
      expect(relay.envelopeCount, 0);
    },
  );

  test(
    'housing proposal sender pubkey mismatch is acked without import',
    () async {
      final pair = await _completeHandshake(
        inviter: android,
        invitee: webNew,
        inviteeDisplayName: 'Web New',
      );

      final androidContact = await android.contacts.get(pair.inviterContactId);
      final androidPub = await android.identity.publicKey();
      final webPub = RelayRouting.unb64(androidContact!.peerPublicMaterial!);
      final webOldPub = await webOld.identity.publicKey();

      final listenAddr = await RelayRouting.steadyStateAddress(
        firstPub: androidPub,
        secondPub: webPub,
      );
      final senderAddr = await RelayRouting.steadyStateAddress(
        firstPub: webPub,
        secondPub: androidPub,
      );
      await relay.establishRouting(
        selfIdentity: senderAddr,
        peerIdentity: listenAddr,
      );

      // Stale web keypair: decrypt succeeds on Android but peerPub is webNew.
      final frame = await EnvelopeCodec.encryptHousingProposal(
        envelope: HousingProposalEnvelope(
          senderLongTermPublicKey: webOldPub,
          proposalJson: '{"revisionId":"rev:test","packageId":"pkg:test"}',
          targetParticipantId: 'housing:stale-test:p0',
        ),
        senderLongTermPrivateKey: await webOld.identity.loadOrCreatePrivateKey(),
        peerLongTermPublicKey: androidPub,
      );

      expect(await _receivedHousingPlanIds(android.db), isEmpty);

      await relay.postEnvelope(
        senderIdentity: senderAddr,
        recipientIdentity: listenAddr,
        idempotencyKey: Uint8List.fromList(List<int>.filled(16, 9)),
        ciphertext: frame,
        kind: EnvelopeKind.housingProposal,
        ttl: const Duration(hours: 1),
      );

      await android.orchestrator.pollSteadyStateInboxes();

      expect(await _receivedHousingPlanIds(android.db), isEmpty);
      expect(relay.envelopeCount, 0);
    },
  );
}
