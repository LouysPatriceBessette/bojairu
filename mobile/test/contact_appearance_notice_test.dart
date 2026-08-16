import 'dart:io';
import 'dart:typed_data';

import 'package:compartarenta/contacts/contact_display.dart';
import 'package:compartarenta/contacts/contact_invitations_repository.dart';
import 'package:compartarenta/contacts/invitation_code.dart';
import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/contacts_repository.dart';
import 'package:compartarenta/device/device_binding_service.dart';
import 'package:compartarenta/notifications/contact_notification_service.dart';
import 'package:compartarenta/relay/envelopes.dart';
import 'package:compartarenta/relay/handshake_orchestrator.dart';
import 'package:compartarenta/relay/identity_keystore.dart';
import 'package:compartarenta/relay/relay_client.dart';
import 'package:compartarenta/relay/testing/fake_relay_client.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DbForTesting extends AppDatabase {
  _DbForTesting(super.e) : super.forTesting();
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

int _dbSeq = 0;

Future<_Side> _spawnSide({
  required RelayClient relay,
  required Uint8List identitySeed,
  required String selfDisplayName,
}) async {
  final id = _dbSeq++;
  final dbFile = File(
    '${Directory.systemTemp.path}/appearance_notice_test_$id.sqlite',
  );
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
  }
  final db = _DbForTesting(NativeDatabase(dbFile));
  final identity = InMemoryIdentityKeystore(seed: identitySeed);
  final contacts = ContactsRepository(db);
  final orchestrator = HandshakeOrchestrator(
    db: db,
    identity: identity,
    relay: relay,
    contacts: contacts,
    invitations: ContactInvitationsRepository(db),
    contactNotifications: _SilentNotifications(),
    pollInterval: const Duration(seconds: 60),
    deviceBinding: DeviceBindingService(
      fixedIdForTesting: 'binding-appearance-$id',
    ),
  );
  orchestrator.ackProfileForAutoAccept = () async => (
        displayName: selfDisplayName,
        avatarId: 'a01',
      );
  return _Side(
    db: db,
    dbFile: dbFile,
    identity: identity,
    orchestrator: orchestrator,
    contacts: contacts,
  );
}

final class _SilentNotifications implements ContactNotificationSink {
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

Future<({String inviterPeerId, String inviteePeerId})> _handshake({
  required _Side inviter,
  required _Side invitee,
}) async {
  final invite = await inviter.orchestrator.generateInvitation(
    validFor: const Duration(hours: 1),
    stubDisplayName: 'pending peer',
    stubAvatarId: 'a01',
  );
  final parsed = parseInvitationCode(invite.shortCode);
  final code = (parsed as InvitationCodeOk).code;
  final redeem = await invitee.orchestrator.redeemInvitation(
    code: code,
    selfDisplayName: 'Fafoin',
    selfAvatarId: 'a01',
  );
  await inviter.orchestrator.processAllPendingHandshakes();
  await invitee.orchestrator.processAllPendingHandshakes();
  return (
    inviterPeerId: invite.localContactId,
    inviteePeerId: redeem.localContactId,
  );
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({
      'profile.displayName': 'Gilles',
      'profile.avatarId': 'a01',
    });
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  late FakeRelayClient relay;
  late _Side gilles;
  late _Side fafoin;

  setUp(() async {
    relay = FakeRelayClient();
    gilles = await _spawnSide(
      relay: relay,
      identitySeed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      selfDisplayName: 'Gilles',
    );
    fafoin = await _spawnSide(
      relay: relay,
      identitySeed: Uint8List.fromList(List<int>.generate(32, (i) => 100 + i)),
      selfDisplayName: 'Fafoin',
    );
  });

  tearDown(() async {
    gilles.orchestrator.stopPolling();
    fafoin.orchestrator.stopPolling();
    await gilles.db.close();
    await fafoin.db.close();
    try {
      if (gilles.dbFile.existsSync()) gilles.dbFile.deleteSync();
    } catch (_) {}
    try {
      if (fafoin.dbFile.existsSync()) fafoin.dbFile.deleteSync();
    } catch (_) {}
  });

  group('HandshakeOrchestrator appearance notices', () {
    test('Settings-path broadcastProfileUpdate fans out profile_update',
        () async {
      final ids = await _handshake(inviter: gilles, invitee: fafoin);
      await gilles.contacts.setLocalDisplayLabel(ids.inviterPeerId, 'Éric');

      final n = await gilles.orchestrator.broadcastProfileUpdate(
        displayName: 'Gilles',
        avatarId: 'a01',
      );
      expect(n, 1);
      expect(relay.envelopeCount, 1);
      expect(relay.storedEnvelopes.single.kind, EnvelopeKind.profileUpdate);

      final fafoinPriv = await fafoin.identity.loadOrCreatePrivateKey();
      final decoded = await EnvelopeCodec.decryptProfileUpdate(
        frame: relay.storedEnvelopes.single.ciphertext,
        receiverLongTermPrivateKey: fafoinPriv,
      );
      expect(decoded.displayName, 'Gilles');
      expect(decoded.hasHowILabelYou, isTrue);
      expect(decoded.howILabelYou, 'Éric');
    });

    test('inbound how_i_label_you fills theirLabelForMe without renaming self',
        () async {
      final ids = await _handshake(inviter: gilles, invitee: fafoin);
      await gilles.contacts.setLocalDisplayLabel(ids.inviterPeerId, 'Éric');
      await gilles.orchestrator.broadcastProfileUpdate(
        displayName: 'Gilles',
        avatarId: 'a01',
      );

      await fafoin.orchestrator.pollSteadyStateInboxes();
      final row = await fafoin.contacts.get(ids.inviteePeerId);
      expect(row!.theirLabelForMe, 'Éric');
      expect(row.displayName, 'Gilles');
    });

    test('scenario F: matching override clears label and skips conflict',
        () async {
      final ids = await _handshake(inviter: gilles, invitee: fafoin);
      await fafoin.contacts.setLocalDisplayLabel(ids.inviteePeerId, 'Éric');

      await gilles.orchestrator.broadcastProfileUpdate(
        displayName: 'Éric',
        avatarId: 'a01',
      );
      await fafoin.orchestrator.pollSteadyStateInboxes();

      expect(fafoin.orchestrator.profileLabelConflict.value, isNull);
      final row = await fafoin.contacts.get(ids.inviteePeerId);
      expect(row!.localDisplayLabel, isNull);
      expect(row.displayName, 'Éric');
      expect(row.effectiveDisplayName, 'Éric');
    });

    test('scenario F: unequal override raises Align/Keep conflict', () async {
      final ids = await _handshake(inviter: gilles, invitee: fafoin);
      await fafoin.contacts.setLocalDisplayLabel(ids.inviteePeerId, 'Erik');

      await gilles.orchestrator.broadcastProfileUpdate(
        displayName: 'Éric',
        avatarId: 'a01',
      );
      await fafoin.orchestrator.pollSteadyStateInboxes();

      final conflict = fafoin.orchestrator.profileLabelConflict.value;
      expect(conflict, isNotNull);
      expect(conflict!.localDisplayLabel, 'Erik');
      expect(conflict.newCanonicalDisplayName, 'Éric');
      final row = await fafoin.contacts.get(ids.inviteePeerId);
      expect(row!.localDisplayLabel, 'Erik');
      expect(row.displayName, 'Éric');
      expect(row.effectiveDisplayName, 'Erik');
    });
  });
}
