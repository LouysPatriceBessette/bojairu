import 'dart:typed_data';

import 'package:compartarenta/relay/envelopes.dart';
import 'package:compartarenta/relay/identity_keystore.dart';
import 'package:compartarenta/relay/routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvelopeCodec hello', () {
    final invitationId = Uint8List.fromList(List<int>.generate(8, (i) => i));
    final invitationNonce = Uint8List.fromList(
      List<int>.generate(12, (i) => 0x10 + i),
    );

    setUp(() {
      // Use a fixed nonce in tests so failures point at logic, not RNG.
      setNonceSourceForTesting(
        () => Uint8List.fromList(List<int>.generate(12, (i) => 0xC0 + i)),
      );
    });
    tearDown(resetNonceSourceForTesting);

    test('round-trips display name and avatar id through inviter', () async {
      final inviteeKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final inviteePriv = await inviteeKeystore.loadOrCreatePrivateKey();
      final inviteePub = await inviteeKeystore.publicKey();

      final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
        invitationId: invitationId,
        nonce: invitationNonce,
      );
      final inviterHandshakePub = await RelayRouting.handshakePublicKey(
        inviterHandshakePriv,
      );

      final frame = await EnvelopeCodec.encryptHello(
        envelope: HelloEnvelope(
          invitationId: invitationId,
          inviteeLongTermPublicKey: inviteePub,
          displayName: 'Alice',
          avatarId: 'cat',
          echoedNonce: invitationNonce,
          deviceBindingId: 'binding-invitee-test',
        ),
        invitationNonce: invitationNonce,
        inviteeLongTermPrivateKey: inviteePriv,
        inviterHandshakePublicKey: inviterHandshakePub,
      );

      // Header is observable.
      final header = EnvelopeCodec.peekHelloHeader(frame);
      expect(header.invitationId, equals(invitationId));
      expect(header.inviteeLongTermPublicKey, equals(inviteePub));

      // Inviter decrypts using the locally stored nonce.
      final decoded = await EnvelopeCodec.decryptHello(
        frame: frame,
        invitationNonce: invitationNonce,
        inviterHandshakePrivateKey: inviterHandshakePriv,
      );
      expect(decoded.displayName, 'Alice');
      expect(decoded.avatarId, 'cat');
      expect(decoded.echoedNonce, equals(invitationNonce));
      expect(decoded.inviteeLongTermPublicKey, equals(inviteePub));
    });

    test(
      'decrypt rejects wrong nonce (per nonce-mixed-into-salt rule)',
      () async {
        final inviteeKeystore = InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
        );
        final inviteePriv = await inviteeKeystore.loadOrCreatePrivateKey();
        final inviteePub = await inviteeKeystore.publicKey();

        final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
          invitationId: invitationId,
          nonce: invitationNonce,
        );
        final inviterHandshakePub = await RelayRouting.handshakePublicKey(
          inviterHandshakePriv,
        );

        final frame = await EnvelopeCodec.encryptHello(
          envelope: HelloEnvelope(
            invitationId: invitationId,
            inviteeLongTermPublicKey: inviteePub,
            displayName: 'Alice',
            avatarId: 'cat',
            echoedNonce: invitationNonce,
            deviceBindingId: 'binding-invitee-test',
          ),
          invitationNonce: invitationNonce,
          inviteeLongTermPrivateKey: inviteePriv,
          inviterHandshakePublicKey: inviterHandshakePub,
        );

        final wrongNonce = Uint8List.fromList(
          List<int>.generate(12, (i) => i + 1),
        );

        expect(
          () => EnvelopeCodec.decryptHello(
            frame: frame,
            invitationNonce: wrongNonce,
            inviterHandshakePrivateKey: inviterHandshakePriv,
          ),
          throwsA(isA<EnvelopeDecryptionError>()),
        );
      },
    );

    test('rejects wrong framing version / kind', () async {
      final frame = Uint8List.fromList([
        0x02,
        0x01,
        ...List<int>.filled(80, 0),
      ]);
      expect(
        () => EnvelopeCodec.peekHelloHeader(frame),
        throwsA(isA<EnvelopeDecryptionError>()),
      );
    });
  });

  group('EnvelopeCodec ack', () {
    final invitationId = Uint8List.fromList(List<int>.generate(8, (i) => i));
    final invitationNonce = Uint8List.fromList(
      List<int>.generate(12, (i) => 0x10 + i),
    );

    setUp(
      () => setNonceSourceForTesting(
        () => Uint8List.fromList(List<int>.generate(12, (i) => 0x33 + i)),
      ),
    );
    tearDown(resetNonceSourceForTesting);

    test('round-trips accepted ack with inviter profile', () async {
      final inviterKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x80 + i)),
      );
      final inviteeKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );

      final inviterPub = await inviterKeystore.publicKey();
      final inviteePriv = await inviteeKeystore.loadOrCreatePrivateKey();
      final inviteePub = await inviteeKeystore.publicKey();

      final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
        invitationId: invitationId,
        nonce: invitationNonce,
      );

      final frame = await EnvelopeCodec.encryptAck(
        envelope: AckEnvelope(
          invitationId: invitationId,
          inviterLongTermPublicKey: inviterPub,
          accepted: true,
          deviceBindingId: 'binding-inviter-test',
          displayName: 'Bob',
          avatarId: 'dog',
        ),
        invitationNonce: invitationNonce,
        inviterHandshakePrivateKey: inviterHandshakePriv,
        inviteeLongTermPublicKey: inviteePub,
      );

      final decoded = await EnvelopeCodec.decryptAck(
        frame: frame,
        invitationId: invitationId,
        invitationNonce: invitationNonce,
        inviteeLongTermPrivateKey: inviteePriv,
      );
      expect(decoded.accepted, isTrue);
      expect(decoded.displayName, 'Bob');
      expect(decoded.avatarId, 'dog');
      expect(decoded.inviterLongTermPublicKey, equals(inviterPub));
    });

    test('round-trips rejected ack without leaking profile fields', () async {
      final inviterKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x80 + i)),
      );
      final inviteeKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );

      final inviterPub = await inviterKeystore.publicKey();
      final inviteePriv = await inviteeKeystore.loadOrCreatePrivateKey();
      final inviteePub = await inviteeKeystore.publicKey();

      final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
        invitationId: invitationId,
        nonce: invitationNonce,
      );

      final frame = await EnvelopeCodec.encryptAck(
        envelope: AckEnvelope(
          invitationId: invitationId,
          inviterLongTermPublicKey: inviterPub,
          accepted: false,
          deviceBindingId: 'binding-inviter-test',
        ),
        invitationNonce: invitationNonce,
        inviterHandshakePrivateKey: inviterHandshakePriv,
        inviteeLongTermPublicKey: inviteePub,
      );

      final decoded = await EnvelopeCodec.decryptAck(
        frame: frame,
        invitationId: invitationId,
        invitationNonce: invitationNonce,
        inviteeLongTermPrivateKey: inviteePriv,
      );
      expect(decoded.accepted, isFalse);
      expect(decoded.displayName, isEmpty);
      expect(decoded.avatarId, isEmpty);
      expect(decoded.rejectionReason, isNull);
      expect(decoded.duplicateAnchorKind, isNull);
    });

    test('round-trips rejected ack with duplicate module anchor reason', () async {
      final inviterKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x80 + i)),
      );
      final inviteeKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );

      final inviterPub = await inviterKeystore.publicKey();
      final inviteePriv = await inviteeKeystore.loadOrCreatePrivateKey();
      final inviteePub = await inviteeKeystore.publicKey();

      final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
        invitationId: invitationId,
        nonce: invitationNonce,
      );

      final frame = await EnvelopeCodec.encryptAck(
        envelope: AckEnvelope(
          invitationId: invitationId,
          inviterLongTermPublicKey: inviterPub,
          accepted: false,
          deviceBindingId: 'binding-inviter-test',
          rejectionReason: 'duplicate_module_anchor',
          duplicateAnchorKind: 'housing',
        ),
        invitationNonce: invitationNonce,
        inviterHandshakePrivateKey: inviterHandshakePriv,
        inviteeLongTermPublicKey: inviteePub,
      );

      final decoded = await EnvelopeCodec.decryptAck(
        frame: frame,
        invitationId: invitationId,
        invitationNonce: invitationNonce,
        inviteeLongTermPrivateKey: inviteePriv,
      );
      expect(decoded.accepted, isFalse);
      expect(decoded.rejectionReason, 'duplicate_module_anchor');
      expect(decoded.duplicateAnchorKind, 'housing');
    });
  });

  group('EnvelopeCodec steady-state', () {
    setUp(
      () => setNonceSourceForTesting(
        () => Uint8List.fromList(List<int>.generate(12, (i) => 0x55 + i)),
      ),
    );
    tearDown(resetNonceSourceForTesting);

    test('profile_update round-trips between two connected contacts', () async {
      final aliceKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final bobKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x40 + i)),
      );
      final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
      final alicePub = await aliceKeystore.publicKey();
      final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
      final bobPub = await bobKeystore.publicKey();

      final frame = await EnvelopeCodec.encryptProfileUpdate(
        envelope: ProfileUpdateEnvelope(
          senderLongTermPublicKey: alicePub,
          displayName: 'Alice (renamed)',
          avatarId: 'bird',
        ),
        senderLongTermPrivateKey: alicePriv,
        peerLongTermPublicKey: bobPub,
      );
      final decoded = await EnvelopeCodec.decryptProfileUpdate(
        frame: frame,
        receiverLongTermPrivateKey: bobPriv,
      );
      expect(decoded.displayName, 'Alice (renamed)');
      expect(decoded.avatarId, 'bird');
      expect(decoded.senderLongTermPublicKey, equals(alicePub));
      expect(decoded.hasHowILabelYou, isFalse);
    });

    test('profile_update round-trips how_i_label_you when present', () async {
      final aliceKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final bobKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x40 + i)),
      );
      final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
      final alicePub = await aliceKeystore.publicKey();
      final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
      final bobPub = await bobKeystore.publicKey();

      final frame = await EnvelopeCodec.encryptProfileUpdate(
        envelope: ProfileUpdateEnvelope(
          senderLongTermPublicKey: alicePub,
          displayName: 'Alice',
          avatarId: 'cat',
          hasHowILabelYou: true,
          howILabelYou: 'Boss',
        ),
        senderLongTermPrivateKey: alicePriv,
        peerLongTermPublicKey: bobPub,
      );
      final decoded = await EnvelopeCodec.decryptProfileUpdate(
        frame: frame,
        receiverLongTermPrivateKey: bobPriv,
      );
      expect(decoded.hasHowILabelYou, isTrue);
      expect(decoded.howILabelYou, 'Boss');
    });

    test('disconnect round-trips an empty payload', () async {
      final aliceKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final bobKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x40 + i)),
      );
      final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
      final alicePub = await aliceKeystore.publicKey();
      final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
      final bobPub = await bobKeystore.publicKey();

      final frame = await EnvelopeCodec.encryptDisconnect(
        envelope: DisconnectEnvelope(senderLongTermPublicKey: alicePub),
        senderLongTermPrivateKey: alicePriv,
        peerLongTermPublicKey: bobPub,
      );
      final decoded = await EnvelopeCodec.decryptDisconnect(
        frame: frame,
        receiverLongTermPrivateKey: bobPriv,
      );
      expect(decoded.senderLongTermPublicKey, equals(alicePub));
    });

    test(
      'housing_proposal round-trips proposal json and target participant',
      () async {
        final aliceKeystore = InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
        );
        final bobKeystore = InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x40 + i)),
        );
        final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
        final alicePub = await aliceKeystore.publicKey();
        final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
        final bobPub = await bobKeystore.publicKey();

        const proposalJson =
            '{"kind":"expensePlanAgreementProposal","revisionId":"rev:1"}';
        final frame = await EnvelopeCodec.encryptHousingProposal(
          envelope: HousingProposalEnvelope(
            senderLongTermPublicKey: alicePub,
            proposalJson: proposalJson,
            targetParticipantId: 'plan:p0',
          ),
          senderLongTermPrivateKey: alicePriv,
          peerLongTermPublicKey: bobPub,
        );
        final decoded = await EnvelopeCodec.decryptHousingProposal(
          frame: frame,
          receiverLongTermPrivateKey: bobPriv,
        );

        expect(decoded.senderLongTermPublicKey, equals(alicePub));
        expect(decoded.proposalJson, proposalJson);
        expect(decoded.targetParticipantId, 'plan:p0');
      },
    );

    test('housing_proposal_response round-trips status and message', () async {
      final aliceKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final bobKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x40 + i)),
      );
      final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
      final alicePub = await aliceKeystore.publicKey();
      final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
      final bobPub = await bobKeystore.publicKey();

      final frame = await EnvelopeCodec.encryptHousingProposalResponse(
        envelope: HousingProposalResponseEnvelope(
          senderLongTermPublicKey: alicePub,
          sourcePackageId: 'pkg:plan',
          sourceRevisionId: 'rev:1',
          sourceParticipantId: 'plan:p0',
          status: 'negotiate',
          message: 'Please lower the rent.',
        ),
        senderLongTermPrivateKey: alicePriv,
        peerLongTermPublicKey: bobPub,
      );
      final decoded = await EnvelopeCodec.decryptHousingProposalResponse(
        frame: frame,
        receiverLongTermPrivateKey: bobPriv,
      );

      expect(decoded.senderLongTermPublicKey, equals(alicePub));
      expect(decoded.sourcePackageId, 'pkg:plan');
      expect(decoded.sourceRevisionId, 'rev:1');
      expect(decoded.sourceParticipantId, 'plan:p0');
      expect(decoded.status, 'negotiate');
      expect(decoded.message, 'Please lower the rent.');
      expect(decoded.participantInstallationId, isNull);
    });

    test('housing_proposal_response round-trips participant_installation_id',
        () async {
      final aliceKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final bobKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x40 + i)),
      );
      final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
      final alicePub = await aliceKeystore.publicKey();
      final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
      final bobPub = await bobKeystore.publicKey();

      final frame = await EnvelopeCodec.encryptHousingProposalResponse(
        envelope: HousingProposalResponseEnvelope(
          senderLongTermPublicKey: alicePub,
          sourcePackageId: 'pkg:plan',
          sourceRevisionId: 'rev:1',
          sourceParticipantId: 'plan:p0',
          status: 'accepted',
          participantInstallationId: 'inst-responder-web',
        ),
        senderLongTermPrivateKey: alicePriv,
        peerLongTermPublicKey: bobPub,
      );
      final decoded = await EnvelopeCodec.decryptHousingProposalResponse(
        frame: frame,
        receiverLongTermPrivateKey: bobPriv,
      );

      expect(decoded.participantInstallationId, 'inst-responder-web');
    });

    test('vehicle_sharing_offer round-trips offer_json', () async {
      final aliceKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final bobKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x40 + i)),
      );
      final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
      final alicePub = await aliceKeystore.publicKey();
      final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
      final bobPub = await bobKeystore.publicKey();

      const payload = '{"kind":"vehicleSharingOffer","linkId":"vshare:1"}';
      final frame = await EnvelopeCodec.encryptVehicleSharingOffer(
        envelope: VehicleSharingOfferEnvelope(
          senderLongTermPublicKey: alicePub,
          offerJson: payload,
        ),
        senderLongTermPrivateKey: alicePriv,
        peerLongTermPublicKey: bobPub,
      );
      expect(frame[1], EnvelopeKind.vehicleSharingOffer);
      final decoded = await EnvelopeCodec.decryptVehicleSharingOffer(
        frame: frame,
        receiverLongTermPrivateKey: bobPriv,
      );
      expect(decoded.offerJson, payload);
      expect(decoded.senderLongTermPublicKey, equals(alicePub));
    });

    test('vehicle_sharing_offer_accept round-trips accept_json', () async {
      final aliceKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
      );
      final bobKeystore = InMemoryIdentityKeystore(
        seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x40 + i)),
      );
      final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
      final alicePub = await aliceKeystore.publicKey();
      final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
      final bobPub = await bobKeystore.publicKey();

      const payload =
          '{"kind":"vehicleSharingOfferAccept","linkId":"vshare:1"}';
      final frame = await EnvelopeCodec.encryptVehicleSharingOfferAccept(
        envelope: VehicleSharingOfferAcceptEnvelope(
          senderLongTermPublicKey: alicePub,
          acceptJson: payload,
        ),
        senderLongTermPrivateKey: alicePriv,
        peerLongTermPublicKey: bobPub,
      );
      expect(frame[1], EnvelopeKind.vehicleSharingOfferAccept);
      final decoded = await EnvelopeCodec.decryptVehicleSharingOfferAccept(
        frame: frame,
        receiverLongTermPrivateKey: bobPriv,
      );
      expect(decoded.acceptJson, payload);
    });
  });
}
