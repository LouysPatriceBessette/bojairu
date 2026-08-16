import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';

import 'routing.dart';

/// Envelope kinds, encoded as the `kind` byte on the wire of the relay.
///
/// The relay only sees the integer value; the framing and AEAD live in
/// the `ciphertext` payload below.
class EnvelopeKind {
  static const int hello = 1;
  static const int ack = 2;
  static const int profileUpdate = 3;
  static const int disconnect = 4;
  static const int housingProposal = 5;
  static const int housingProposalResponse = 6;
  static const int housingRealizedExpensePropose = 7;
  static const int housingRealizedExpenseAccept = 8;
  static const int housingRealizedExpenseReject = 9;
  static const int housingParticipationChangePropose = 10;
  static const int housingParticipationChangeDecision = 11;
  static const int housingParticipationChangeNotify = 12;
  static const int contactEstablishmentRequest = 13;
  static const int contactEstablishmentResponse = 14;
  static const int participantInstallationMigration = 15;
  static const int vehicleSharingOffer = 16;
  static const int vehicleSharingOfferAccept = 17;
  static const int vehicleUseSessionStart = 18;
  static const int vehicleUseSessionEnd = 19;
  static const int vehicleFuelPurchase = 20;
  static const int vehicleMaintenance = 21;
  static const int vehicleTrafficViolation = 22;
  static const int vehicleFuelPurchaseCatchUp = 23;
  static const int vehicleUsageBalanceFreezePropose = 24;
  static const int vehicleUsageBalanceFreezeDecision = 25;
  static const int vehicleUsageTransferPropose = 26;
  static const int vehicleUsageTransferDecision = 27;
  static const int vehicleUsageBalanceFreezeCatchUp = 28;
  static const int vehicleSharingRevoke = 29;
  static const int vehicleSharingReactivatePropose = 30;
  static const int vehicleSharingReactivateAccept = 31;
  static const int vehicleUseSessionEndByOwner = 32;
}

/// One byte at the start of every envelope frame so we can evolve the
/// layout without breaking older clients. Bumped only when the header or
/// AEAD framing changes in a way old clients cannot ignore.
const int _framingVersion = 1;

/// Hello envelope: invitee -> inviter, encrypted to the inviter's
/// derived handshake public key.
///
/// On the wire (inside the relay `ciphertext` field):
/// `[ framing_version | kind=1 | inv_id(8) | invitee_long_term_pub(32) |
///    aead_nonce(12) | aead_ciphertext_with_tag ]`
///
/// The AEAD plaintext is a JSON object:
/// `{ "display_name": "...", "avatar_id": "...", "echo_nonce_b64": "...",
///    "device_binding_id": "..." }`
class HelloEnvelope {
  HelloEnvelope({
    required this.invitationId,
    required this.inviteeLongTermPublicKey,
    required this.displayName,
    required this.avatarId,
    required this.echoedNonce,
    required this.deviceBindingId,
  });

  final Uint8List invitationId;
  final Uint8List inviteeLongTermPublicKey;
  final String displayName;
  final String avatarId;
  final Uint8List echoedNonce;

  /// Opaque hash of Tier A + Tier B device signals from the invitee device.
  final String deviceBindingId;
}

/// Ack envelope: inviter -> invitee, encrypted under the same shared
/// secret as the hello (different HKDF `info` string => different key).
///
/// On the wire:
/// `[ framing_version | kind=2 | inv_id(8) | inviter_long_term_pub(32) |
///    aead_nonce(12) | aead_ciphertext_with_tag ]`
///
/// The AEAD plaintext is a JSON object:
/// `{ "decision": "accepted"|"rejected",
///    "device_binding_id": "...",
///    "display_name": "...",     # omitted when decision=rejected
///    "avatar_id": "...",        # omitted when decision=rejected
///    "rejection_reason": "...", # optional when decision=rejected
///    "anchor_kind": "..." }`    # optional; duplicate_module_anchor only
class AckEnvelope {
  AckEnvelope({
    required this.invitationId,
    required this.inviterLongTermPublicKey,
    required this.accepted,
    required this.deviceBindingId,
    this.displayName = '',
    this.avatarId = '',
    this.rejectionReason,
    this.duplicateAnchorKind,
  });

  final Uint8List invitationId;
  final Uint8List inviterLongTermPublicKey;
  final bool accepted;
  final String deviceBindingId;
  final String displayName;
  final String avatarId;

  /// Present on some rejected acks (e.g. duplicate module anchor).
  final String? rejectionReason;

  /// [DuplicateModuleAnchorKind] when [rejectionReason] is duplicate anchor.
  final String? duplicateAnchorKind;
}

/// Steady-state profile update sent between two connected contacts.
///
/// Wire layout:
/// `[ framing_version | kind=3 | sender_long_term_pub(32) |
///    aead_nonce(12) | aead_ciphertext_with_tag ]`
///
/// AEAD plaintext: `{ "display_name": "...", "avatar_id": "..." }` and
/// optionally `how_i_label_you` when the sender includes how they list
/// the recipient on their device (encrypted appearance notice).
class ProfileUpdateEnvelope {
  ProfileUpdateEnvelope({
    required this.senderLongTermPublicKey,
    required this.displayName,
    required this.avatarId,
    this.hasHowILabelYou = false,
    this.howILabelYou = '',
  });

  final Uint8List senderLongTermPublicKey;
  final String displayName;
  final String avatarId;

  /// When true, [howILabelYou] was present on the wire (possibly empty,
  /// meaning the sender cleared their local label for the recipient).
  final bool hasHowILabelYou;
  final String howILabelYou;
}

/// Steady-state disconnect notice. No payload beyond identifying the
/// sender; receipt drops the connected contact locally on the peer's
/// device.
///
/// Wire layout identical to [ProfileUpdateEnvelope] with empty plaintext
/// (just framing + AEAD).
class DisconnectEnvelope {
  DisconnectEnvelope({required this.senderLongTermPublicKey});

  final Uint8List senderLongTermPublicKey;
}

/// Steady-state Housing proposal sent to a connected contact.
class HousingProposalEnvelope {
  HousingProposalEnvelope({
    required this.senderLongTermPublicKey,
    required this.proposalJson,
    required this.targetParticipantId,
  });

  final Uint8List senderLongTermPublicKey;
  final String proposalJson;
  final String targetParticipantId;
}

/// Steady-state response to a Housing proposal revision.
class HousingProposalResponseEnvelope {
  HousingProposalResponseEnvelope({
    required this.senderLongTermPublicKey,
    required this.sourcePackageId,
    required this.sourceRevisionId,
    required this.sourceParticipantId,
    required this.status,
    this.message = '',
    this.participantInstallationId,
  });

  final Uint8List senderLongTermPublicKey;
  final String sourcePackageId;
  final String sourceRevisionId;
  final String sourceParticipantId;
  final String status;
  final String message;

  /// Responder entitlement installation id (exchanged for roster reporting).
  final String? participantInstallationId;
}

/// Steady-state realized expense proposal (active agreement ledger).
class HousingRealizedExpenseEnvelope {
  HousingRealizedExpenseEnvelope({
    required this.senderLongTermPublicKey,
    required this.expenseJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String expenseJson;
}

/// Accept or reject decision for a realized expense proposal.
class HousingRealizedExpenseDecisionEnvelope {
  HousingRealizedExpenseDecisionEnvelope({
    required this.senderLongTermPublicKey,
    required this.decisionJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String decisionJson;
}

/// Steady-state participation change proposal or notify payload.
class HousingParticipationChangeEnvelope {
  HousingParticipationChangeEnvelope({
    required this.senderLongTermPublicKey,
    required this.changeJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String changeJson;
}

/// Accept or reject decision for a participation change.
class HousingParticipationChangeDecisionEnvelope {
  HousingParticipationChangeDecisionEnvelope({
    required this.senderLongTermPublicKey,
    required this.decisionJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String decisionJson;
}

/// Plan-mediated contact establishment request (requester → target).
class ContactEstablishmentRequestEnvelope {
  ContactEstablishmentRequestEnvelope({
    required this.senderLongTermPublicKey,
    required this.requesterDisplayName,
    required this.requesterAvatarId,
    required this.proposerDisplayName,
    this.receivedPlanId = '',
    this.revisionId = '',
  });

  final Uint8List senderLongTermPublicKey;
  final String requesterDisplayName;
  final String requesterAvatarId;
  final String proposerDisplayName;
  final String receivedPlanId;
  final String revisionId;
}

/// Plan-mediated contact establishment response (target → requester).
class ContactEstablishmentResponseEnvelope {
  ContactEstablishmentResponseEnvelope({
    required this.senderLongTermPublicKey,
    required this.accepted,
    this.responderDisplayName = '',
    this.responderAvatarId = '',
  });

  final Uint8List senderLongTermPublicKey;
  final bool accepted;
  final String responderDisplayName;
  final String responderAvatarId;
}

/// Steady-state vehicle sharing offer (Propriétaire → Emprunteur).
class VehicleSharingOfferEnvelope {
  VehicleSharingOfferEnvelope({
    required this.senderLongTermPublicKey,
    required this.offerJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String offerJson;
}

/// Steady-state accept of a vehicle sharing offer (Emprunteur → Propriétaire).
class VehicleSharingOfferAcceptEnvelope {
  VehicleSharingOfferAcceptEnvelope({
    required this.senderLongTermPublicKey,
    required this.acceptJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String acceptJson;
}

/// Steady-state revoke / reactivate propose / accept (JSON payload).
class VehicleSharingLifecycleEnvelope {
  VehicleSharingLifecycleEnvelope({
    required this.senderLongTermPublicKey,
    required this.payloadJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String payloadJson;
}

/// Steady-state borrower use-session start (Emprunteur → Propriétaire).
class VehicleUseSessionStartEnvelope {
  VehicleUseSessionStartEnvelope({
    required this.senderLongTermPublicKey,
    required this.sessionJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String sessionJson;
}

/// Steady-state borrower use-session end (Emprunteur → Propriétaire).
class VehicleUseSessionEndEnvelope {
  VehicleUseSessionEndEnvelope({
    required this.senderLongTermPublicKey,
    required this.sessionJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String sessionJson;
}

/// Steady-state borrower fuel purchase (Emprunteur → Propriétaire).
class VehicleFuelPurchaseEnvelope {
  VehicleFuelPurchaseEnvelope({
    required this.senderLongTermPublicKey,
    required this.purchaseJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String purchaseJson;
}

/// Steady-state borrower maintenance (Emprunteur → Propriétaire).
class VehicleMaintenanceEnvelope {
  VehicleMaintenanceEnvelope({
    required this.senderLongTermPublicKey,
    required this.eventJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String eventJson;
}

/// Steady-state borrower traffic violation (Emprunteur → Propriétaire).
class VehicleTrafficViolationEnvelope {
  VehicleTrafficViolationEnvelope({
    required this.senderLongTermPublicKey,
    required this.violationJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String violationJson;
}

/// Steady-state fuel purchase catch-up (Propriétaire → Emprunteur).
class VehicleFuelPurchaseCatchUpEnvelope {
  VehicleFuelPurchaseCatchUpEnvelope({
    required this.senderLongTermPublicKey,
    required this.catchUpJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String catchUpJson;
}

/// Usage-balance freeze propose / decision / freeze-catch-up JSON envelopes.
class VehicleUsageBalanceFreezeEnvelope {
  VehicleUsageBalanceFreezeEnvelope({
    required this.senderLongTermPublicKey,
    required this.payloadJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String payloadJson;
}

/// Usage-balance transfer propose / decision JSON envelopes.
class VehicleUsageTransferEnvelope {
  VehicleUsageTransferEnvelope({
    required this.senderLongTermPublicKey,
    required this.payloadJson,
  });

  final Uint8List senderLongTermPublicKey;
  final String payloadJson;
}

// ---------- HKDF info strings ----------

const String _helloAeadInfo = 'compartarenta/handshake-v1/hello-aead';
const String _ackAeadInfo = 'compartarenta/handshake-v1/ack-aead';
const String _profileUpdateAeadInfo =
    'compartarenta/steady-v1/profile-update-aead';
const String _disconnectAeadInfo = 'compartarenta/steady-v1/disconnect-aead';
const String _housingProposalAeadInfo =
    'compartarenta/steady-v1/housing-proposal-aead';
const String _housingProposalResponseAeadInfo =
    'compartarenta/steady-v1/housing-proposal-response-aead';
const String _housingRealizedExpenseProposeAeadInfo =
    'compartarenta/steady-v1/housing-realized-expense-propose-aead';
const String _housingRealizedExpenseAcceptAeadInfo =
    'compartarenta/steady-v1/housing-realized-expense-accept-aead';
const String _housingRealizedExpenseRejectAeadInfo =
    'compartarenta/steady-v1/housing-realized-expense-reject-aead';
const String _housingParticipationChangeProposeAeadInfo =
    'compartarenta/steady-v1/housing-participation-change-propose-aead';
const String _housingParticipationChangeDecisionAeadInfo =
    'compartarenta/steady-v1/housing-participation-change-decision-aead';
const String _housingParticipationChangeNotifyAeadInfo =
    'compartarenta/steady-v1/housing-participation-change-notify-aead';
const String _contactEstablishmentRequestAeadInfo =
    'compartarenta/steady-v1/contact-establishment-request-aead';
const String _contactEstablishmentResponseAeadInfo =
    'compartarenta/steady-v1/contact-establishment-response-aead';
const String _vehicleSharingOfferAeadInfo =
    'compartarenta/steady-v1/vehicle-sharing-offer-aead';
const String _vehicleSharingOfferAcceptAeadInfo =
    'compartarenta/steady-v1/vehicle-sharing-offer-accept-aead';
const String _vehicleUseSessionStartAeadInfo =
    'compartarenta/steady-v1/vehicle-use-session-start-aead';
const String _vehicleUseSessionEndAeadInfo =
    'compartarenta/steady-v1/vehicle-use-session-end-aead';
const String _vehicleFuelPurchaseAeadInfo =
    'compartarenta/steady-v1/vehicle-fuel-purchase-aead';
const String _vehicleMaintenanceAeadInfo =
    'compartarenta/steady-v1/vehicle-maintenance-aead';
const String _vehicleTrafficViolationAeadInfo =
    'compartarenta/steady-v1/vehicle-traffic-violation-aead';
const String _vehicleFuelPurchaseCatchUpAeadInfo =
    'compartarenta/steady-v1/vehicle-fuel-purchase-catch-up-aead';
const String _vehicleUsageBalanceFreezeProposeAeadInfo =
    'compartarenta/steady-v1/vehicle-usage-balance-freeze-propose-aead';
const String _vehicleUsageBalanceFreezeDecisionAeadInfo =
    'compartarenta/steady-v1/vehicle-usage-balance-freeze-decision-aead';
const String _vehicleUsageTransferProposeAeadInfo =
    'compartarenta/steady-v1/vehicle-usage-transfer-propose-aead';
const String _vehicleUsageTransferDecisionAeadInfo =
    'compartarenta/steady-v1/vehicle-usage-transfer-decision-aead';
const String _vehicleUsageBalanceFreezeCatchUpAeadInfo =
    'compartarenta/steady-v1/vehicle-usage-balance-freeze-catch-up-aead';
const String _vehicleSharingRevokeAeadInfo =
    'compartarenta/steady-v1/vehicle-sharing-revoke-aead';
const String _vehicleSharingReactivateProposeAeadInfo =
    'compartarenta/steady-v1/vehicle-sharing-reactivate-propose-aead';
const String _vehicleSharingReactivateAcceptAeadInfo =
    'compartarenta/steady-v1/vehicle-sharing-reactivate-accept-aead';
const String _vehicleUseSessionEndByOwnerAeadInfo =
    'compartarenta/steady-v1/vehicle-use-session-end-by-owner-aead';

// ---------- Public encode / decode API ----------

/// Source of 12-byte AEAD nonces. Swapped out in tests for deterministic
/// nonces; production uses `Random.secure`.
typedef NonceSource = Uint8List Function();

NonceSource _defaultNonceSource = _randomNonce;

Uint8List _randomNonce() {
  final r = Random.secure();
  final out = Uint8List(12);
  for (var i = 0; i < 12; i++) {
    out[i] = r.nextInt(256);
  }
  return out;
}

/// FOR TESTS ONLY. Override the AEAD nonce source.
void setNonceSourceForTesting(NonceSource source) {
  _defaultNonceSource = source;
}

/// FOR TESTS ONLY. Reset to the secure default.
void resetNonceSourceForTesting() {
  _defaultNonceSource = _randomNonce;
}

class EnvelopeCodec {
  EnvelopeCodec._();

  /// Encrypts a [HelloEnvelope] for the inviter's handshake public key.
  ///
  /// The result is the bytes to put in the relay's `ciphertext` field on
  /// `POST /v1/envelopes`. Pass [inviterHandshakePublicKey] derived from
  /// the invitation code via [RelayRouting.handshakePublicKey].
  static Future<Uint8List> encryptHello({
    required HelloEnvelope envelope,
    required Uint8List invitationNonce,
    required Uint8List inviteeLongTermPrivateKey,
    required Uint8List inviterHandshakePublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: inviteeLongTermPrivateKey,
      peerPublicKey: inviterHandshakePublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: invitationNonce,
      info: _helloAeadInfo,
      length: 32,
    );
    final header = _helloHeader(
      invitationId: envelope.invitationId,
      inviteePub: envelope.inviteeLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final plaintext = utf8.encode(
      jsonEncode({
        'display_name': envelope.displayName,
        'avatar_id': envelope.avatarId,
        'echo_nonce_b64': RelayRouting.b64(envelope.echoedNonce),
        'device_binding_id': envelope.deviceBindingId,
      }),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final body = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: plaintext,
      aad: header,
    );
    return _concat(header, body);
  }

  /// Reads the unauthenticated header of a hello envelope. The inviter
  /// calls this to learn `invitationId` (to look the nonce up in the
  /// local invitations table) and `inviteeLongTermPub` (to compute the
  /// shared secret) before invoking [decryptHello].
  static HelloHeader peekHelloHeader(Uint8List frame) {
    _expectKind(frame, EnvelopeKind.hello);
    final invitationId = Uint8List.fromList(frame.sublist(2, 10));
    final inviteePub = Uint8List.fromList(frame.sublist(10, 42));
    final aeadNonce = Uint8List.fromList(frame.sublist(42, 54));
    return HelloHeader(
      invitationId: invitationId,
      inviteeLongTermPublicKey: inviteePub,
      aeadNonce: aeadNonce,
    );
  }

  /// Validates and decrypts a hello envelope on the inviter's side.
  ///
  /// Requires the locally stored `invitationNonce` (which the inviter
  /// trusts because the row exists in their database) and the locally
  /// derived `inviterHandshakePrivateKey`.
  ///
  /// Throws [EnvelopeDecryptionError] when AEAD validation fails or the
  /// echoed nonce inside the plaintext does not match the stored one.
  static Future<HelloEnvelope> decryptHello({
    required Uint8List frame,
    required Uint8List invitationNonce,
    required Uint8List inviterHandshakePrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.hello);
    final header = peekHelloHeader(frame);
    final body = frame.sublist(54);
    final shared = await _x25519(
      privateKey: inviterHandshakePrivateKey,
      peerPublicKey: header.inviteeLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: invitationNonce,
      info: _helloAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: header.aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 54)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    final echoed = RelayRouting.unb64(json['echo_nonce_b64'] as String);
    if (!_constantTimeEquals(echoed, invitationNonce)) {
      throw const EnvelopeDecryptionError('echoed_nonce_mismatch');
    }
    final bindingId = json['device_binding_id'] as String?;
    if (bindingId == null || bindingId.isEmpty) {
      throw const EnvelopeDecryptionError('missing_device_binding_id');
    }
    return HelloEnvelope(
      invitationId: header.invitationId,
      inviteeLongTermPublicKey: header.inviteeLongTermPublicKey,
      displayName: (json['display_name'] as String?) ?? '',
      avatarId: (json['avatar_id'] as String?) ?? '',
      echoedNonce: echoed,
      deviceBindingId: bindingId,
    );
  }

  /// Encrypts an [AckEnvelope] for the invitee's long-term public key,
  /// reusing the same shared secret as the hello (different HKDF info).
  static Future<Uint8List> encryptAck({
    required AckEnvelope envelope,
    required Uint8List invitationNonce,
    required Uint8List inviterHandshakePrivateKey,
    required Uint8List inviteeLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: inviterHandshakePrivateKey,
      peerPublicKey: inviteeLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: invitationNonce,
      info: _ackAeadInfo,
      length: 32,
    );
    final header = _ackHeader(
      invitationId: envelope.invitationId,
      inviterPub: envelope.inviterLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({
        'decision': envelope.accepted ? 'accepted' : 'rejected',
        'device_binding_id': envelope.deviceBindingId,
        if (envelope.accepted) ...{
          'display_name': envelope.displayName,
          'avatar_id': envelope.avatarId,
        },
        if (!envelope.accepted && envelope.rejectionReason != null)
          'rejection_reason': envelope.rejectionReason,
        if (!envelope.accepted && envelope.duplicateAnchorKind != null)
          'anchor_kind': envelope.duplicateAnchorKind,
      }),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Reads the unauthenticated header of an ack envelope.
  static AckHeader peekAckHeader(Uint8List frame) {
    _expectKind(frame, EnvelopeKind.ack);
    final invitationId = Uint8List.fromList(frame.sublist(2, 10));
    final inviterPub = Uint8List.fromList(frame.sublist(10, 42));
    final aeadNonce = Uint8List.fromList(frame.sublist(42, 54));
    return AckHeader(
      invitationId: invitationId,
      inviterLongTermPublicKey: inviterPub,
      aeadNonce: aeadNonce,
    );
  }

  /// Validates and decrypts an ack envelope on the invitee's side.
  ///
  /// The ack uses the SAME shared secret as the hello (different HKDF
  /// `info` string => different AEAD key). The invitee re-derives the
  /// inviter's one-time handshake public key from the invitation code
  /// bytes it has stored locally; the inviter's long-term public key is
  /// **only** carried in the ack header (and is transferred to the local
  /// Contact stub once the AEAD passes).
  static Future<AckEnvelope> decryptAck({
    required Uint8List frame,
    required Uint8List invitationId,
    required Uint8List invitationNonce,
    required Uint8List inviteeLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.ack);
    final header = peekAckHeader(frame);
    final body = frame.sublist(54);
    final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
      invitationId: invitationId,
      nonce: invitationNonce,
    );
    final inviterHandshakePub = await RelayRouting.handshakePublicKey(
      inviterHandshakePriv,
    );
    final shared = await _x25519(
      privateKey: inviteeLongTermPrivateKey,
      peerPublicKey: inviterHandshakePub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: invitationNonce,
      info: _ackAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: header.aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 54)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    final accepted = (json['decision'] as String? ?? '') == 'accepted';
    final bindingId = json['device_binding_id'] as String?;
    if (bindingId == null || bindingId.isEmpty) {
      throw const EnvelopeDecryptionError('missing_device_binding_id');
    }
    return AckEnvelope(
      invitationId: header.invitationId,
      inviterLongTermPublicKey: header.inviterLongTermPublicKey,
      accepted: accepted,
      deviceBindingId: bindingId,
      displayName: (json['display_name'] as String?) ?? '',
      avatarId: (json['avatar_id'] as String?) ?? '',
      rejectionReason: json['rejection_reason'] as String?,
      duplicateAnchorKind: json['anchor_kind'] as String?,
    );
  }

  /// Encrypts a steady-state profile-update envelope addressed to a
  /// connected contact.
  static Future<Uint8List> encryptProfileUpdate({
    required ProfileUpdateEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _profileUpdateAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.profileUpdate,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final payload = <String, dynamic>{
      'display_name': envelope.displayName,
      'avatar_id': envelope.avatarId,
    };
    if (envelope.hasHowILabelYou) {
      payload['how_i_label_you'] = envelope.howILabelYou;
    }
    final body = utf8.encode(jsonEncode(payload));
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state profile-update envelope.
  static Future<ProfileUpdateEnvelope> decryptProfileUpdate({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.profileUpdate);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _profileUpdateAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    final how = parseProfileUpdateHowILabelYou(json);
    return ProfileUpdateEnvelope(
      senderLongTermPublicKey: senderPub,
      displayName: (json['display_name'] as String?) ?? '',
      avatarId: (json['avatar_id'] as String?) ?? '',
      hasHowILabelYou: how.present,
      howILabelYou: how.value,
    );
  }

  /// Encrypts a steady-state disconnect envelope addressed to the
  /// previously-connected peer.
  static Future<Uint8List> encryptDisconnect({
    required DisconnectEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _disconnectAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.disconnect,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: const <int>[],
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state disconnect envelope.
  static Future<DisconnectEnvelope> decryptDisconnect({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.disconnect);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _disconnectAeadInfo,
      length: 32,
    );
    await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    return DisconnectEnvelope(senderLongTermPublicKey: senderPub);
  }

  /// Encrypts a steady-state Housing proposal envelope.
  static Future<Uint8List> encryptHousingProposal({
    required HousingProposalEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _housingProposalAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.housingProposal,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({
        'proposal_json': envelope.proposalJson,
        'target_participant_id': envelope.targetParticipantId,
      }),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state Housing proposal envelope.
  static Future<HousingProposalEnvelope> decryptHousingProposal({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.housingProposal);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _housingProposalAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return HousingProposalEnvelope(
      senderLongTermPublicKey: senderPub,
      proposalJson: (json['proposal_json'] as String?) ?? '{}',
      targetParticipantId: (json['target_participant_id'] as String?) ?? '',
    );
  }

  /// Encrypts a steady-state Housing proposal response envelope.
  static Future<Uint8List> encryptHousingProposalResponse({
    required HousingProposalResponseEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _housingProposalResponseAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.housingProposalResponse,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({
        'source_package_id': envelope.sourcePackageId,
        'source_revision_id': envelope.sourceRevisionId,
        'source_participant_id': envelope.sourceParticipantId,
        'status': envelope.status,
        'message': envelope.message,
        if (envelope.participantInstallationId != null &&
            envelope.participantInstallationId!.isNotEmpty)
          'participant_installation_id': envelope.participantInstallationId,
      }),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state Housing proposal response envelope.
  static Future<HousingProposalResponseEnvelope>
  decryptHousingProposalResponse({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.housingProposalResponse);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _housingProposalResponseAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return HousingProposalResponseEnvelope(
      senderLongTermPublicKey: senderPub,
      sourcePackageId: (json['source_package_id'] as String?) ?? '',
      sourceRevisionId: (json['source_revision_id'] as String?) ?? '',
      sourceParticipantId: (json['source_participant_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      participantInstallationId:
          json['participant_installation_id'] as String?,
    );
  }

  /// Encrypts a steady-state realized expense proposal envelope.
  static Future<Uint8List> encryptHousingRealizedExpensePropose({
    required HousingRealizedExpenseEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _housingRealizedExpenseProposeAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.housingRealizedExpensePropose,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(jsonEncode({'expense_json': envelope.expenseJson}));
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state realized expense proposal envelope.
  static Future<HousingRealizedExpenseEnvelope> decryptHousingRealizedExpensePropose({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.housingRealizedExpensePropose);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _housingRealizedExpenseProposeAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return HousingRealizedExpenseEnvelope(
      senderLongTermPublicKey: senderPub,
      expenseJson: (json['expense_json'] as String?) ?? '{}',
    );
  }

  static Future<Uint8List> encryptHousingRealizedExpenseDecision({
    required int kind,
    required HousingRealizedExpenseDecisionEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final info = kind == EnvelopeKind.housingRealizedExpenseAccept
        ? _housingRealizedExpenseAcceptAeadInfo
        : _housingRealizedExpenseRejectAeadInfo;
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: info,
      length: 32,
    );
    final header = _steadyHeader(
      kind: kind,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'decision_json': envelope.decisionJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  static Future<HousingRealizedExpenseDecisionEnvelope>
  decryptHousingRealizedExpenseDecision({
    required int kind,
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, kind);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final info = kind == EnvelopeKind.housingRealizedExpenseAccept
        ? _housingRealizedExpenseAcceptAeadInfo
        : _housingRealizedExpenseRejectAeadInfo;
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: info,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return HousingRealizedExpenseDecisionEnvelope(
      senderLongTermPublicKey: senderPub,
      decisionJson: (json['decision_json'] as String?) ?? '{}',
    );
  }

  static Future<Uint8List> encryptHousingParticipationChangePropose({
    required HousingParticipationChangeEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    return _encryptParticipationChangePayload(
      kind: EnvelopeKind.housingParticipationChangePropose,
      aeadInfo: _housingParticipationChangeProposeAeadInfo,
      envelope: envelope,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      jsonKey: 'change_json',
    );
  }

  static Future<HousingParticipationChangeEnvelope>
  decryptHousingParticipationChangePropose({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    return _decryptParticipationChangePayload(
      expectedKind: EnvelopeKind.housingParticipationChangePropose,
      aeadInfo: _housingParticipationChangeProposeAeadInfo,
      frame: frame,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'change_json',
    );
  }

  static Future<Uint8List> encryptHousingParticipationChangeDecision({
    required HousingParticipationChangeDecisionEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    return _encryptParticipationChangeDecisionPayload(
      envelope: envelope,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
    );
  }

  static Future<HousingParticipationChangeDecisionEnvelope>
  decryptHousingParticipationChangeDecision({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.housingParticipationChangeDecision);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _housingParticipationChangeDecisionAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return HousingParticipationChangeDecisionEnvelope(
      senderLongTermPublicKey: senderPub,
      decisionJson: (json['decision_json'] as String?) ?? '{}',
    );
  }

  static Future<Uint8List> encryptHousingParticipationChangeNotify({
    required HousingParticipationChangeEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    return _encryptParticipationChangePayload(
      kind: EnvelopeKind.housingParticipationChangeNotify,
      aeadInfo: _housingParticipationChangeNotifyAeadInfo,
      envelope: envelope,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      jsonKey: 'change_json',
    );
  }

  static Future<HousingParticipationChangeEnvelope>
  decryptHousingParticipationChangeNotify({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    return _decryptParticipationChangePayload(
      expectedKind: EnvelopeKind.housingParticipationChangeNotify,
      aeadInfo: _housingParticipationChangeNotifyAeadInfo,
      frame: frame,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'change_json',
    );
  }

  static Future<Uint8List> _encryptParticipationChangePayload({
    required int kind,
    required String aeadInfo,
    required HousingParticipationChangeEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
    required String jsonKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: aeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: kind,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(jsonEncode({jsonKey: envelope.changeJson}));
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  static Future<Uint8List> _encryptParticipationChangeDecisionPayload({
    required HousingParticipationChangeDecisionEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _housingParticipationChangeDecisionAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.housingParticipationChangeDecision,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'decision_json': envelope.decisionJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  static Future<HousingParticipationChangeEnvelope>
  _decryptParticipationChangePayload({
    required int expectedKind,
    required String aeadInfo,
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
    required String jsonKey,
  }) async {
    _expectKind(frame, expectedKind);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: aeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return HousingParticipationChangeEnvelope(
      senderLongTermPublicKey: senderPub,
      changeJson: (json[jsonKey] as String?) ?? '{}',
    );
  }

  static Future<Uint8List> encryptContactEstablishmentRequest({
    required ContactEstablishmentRequestEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _contactEstablishmentRequestAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.contactEstablishmentRequest,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({
        'requester_display_name': envelope.requesterDisplayName,
        'requester_avatar_id': envelope.requesterAvatarId,
        'proposer_display_name': envelope.proposerDisplayName,
        if (envelope.receivedPlanId.isNotEmpty)
          'received_plan_id': envelope.receivedPlanId,
        if (envelope.revisionId.isNotEmpty) 'revision_id': envelope.revisionId,
      }),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  static Future<ContactEstablishmentRequestEnvelope>
  decryptContactEstablishmentRequest({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.contactEstablishmentRequest);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _contactEstablishmentRequestAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return ContactEstablishmentRequestEnvelope(
      senderLongTermPublicKey: senderPub,
      requesterDisplayName:
          (json['requester_display_name'] as String?) ?? '',
      requesterAvatarId: (json['requester_avatar_id'] as String?) ?? '',
      proposerDisplayName: (json['proposer_display_name'] as String?) ?? '',
      receivedPlanId: (json['received_plan_id'] as String?) ?? '',
      revisionId: (json['revision_id'] as String?) ?? '',
    );
  }

  static Future<Uint8List> encryptContactEstablishmentResponse({
    required ContactEstablishmentResponseEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _contactEstablishmentResponseAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.contactEstablishmentResponse,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final payload = <String, dynamic>{'accepted': envelope.accepted};
    if (envelope.accepted) {
      payload['responder_display_name'] = envelope.responderDisplayName;
      payload['responder_avatar_id'] = envelope.responderAvatarId;
    }
    final body = utf8.encode(jsonEncode(payload));
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  static Future<ContactEstablishmentResponseEnvelope>
  decryptContactEstablishmentResponse({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.contactEstablishmentResponse);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _contactEstablishmentResponseAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    final accepted = json['accepted'] == true;
    return ContactEstablishmentResponseEnvelope(
      senderLongTermPublicKey: senderPub,
      accepted: accepted,
      responderDisplayName: (json['responder_display_name'] as String?) ?? '',
      responderAvatarId: (json['responder_avatar_id'] as String?) ?? '',
    );
  }

  /// Encrypts a steady-state vehicle sharing offer envelope.
  static Future<Uint8List> encryptVehicleSharingOffer({
    required VehicleSharingOfferEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleSharingOfferAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.vehicleSharingOffer,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'offer_json': envelope.offerJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state vehicle sharing offer envelope.
  static Future<VehicleSharingOfferEnvelope> decryptVehicleSharingOffer({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.vehicleSharingOffer);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleSharingOfferAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return VehicleSharingOfferEnvelope(
      senderLongTermPublicKey: senderPub,
      offerJson: (json['offer_json'] as String?) ?? '{}',
    );
  }

  /// Encrypts a steady-state vehicle sharing offer accept envelope.
  static Future<Uint8List> encryptVehicleSharingOfferAccept({
    required VehicleSharingOfferAcceptEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleSharingOfferAcceptAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.vehicleSharingOfferAccept,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'accept_json': envelope.acceptJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state vehicle sharing offer accept envelope.
  static Future<VehicleSharingOfferAcceptEnvelope>
  decryptVehicleSharingOfferAccept({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.vehicleSharingOfferAccept);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleSharingOfferAcceptAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return VehicleSharingOfferAcceptEnvelope(
      senderLongTermPublicKey: senderPub,
      acceptJson: (json['accept_json'] as String?) ?? '{}',
    );
  }

  /// Encrypts a steady-state vehicle use session start envelope.
  static Future<Uint8List> encryptVehicleUseSessionStart({
    required VehicleUseSessionStartEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleUseSessionStartAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.vehicleUseSessionStart,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'session_json': envelope.sessionJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state vehicle use session start envelope.
  static Future<VehicleUseSessionStartEnvelope> decryptVehicleUseSessionStart({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.vehicleUseSessionStart);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleUseSessionStartAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return VehicleUseSessionStartEnvelope(
      senderLongTermPublicKey: senderPub,
      sessionJson: (json['session_json'] as String?) ?? '{}',
    );
  }

  /// Encrypts a steady-state vehicle use session end envelope.
  static Future<Uint8List> encryptVehicleUseSessionEnd({
    required VehicleUseSessionEndEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleUseSessionEndAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.vehicleUseSessionEnd,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'session_json': envelope.sessionJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state vehicle use session end envelope.
  static Future<VehicleUseSessionEndEnvelope> decryptVehicleUseSessionEnd({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.vehicleUseSessionEnd);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleUseSessionEndAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return VehicleUseSessionEndEnvelope(
      senderLongTermPublicKey: senderPub,
      sessionJson: (json['session_json'] as String?) ?? '{}',
    );
  }

  /// Encrypts a steady-state vehicle fuel purchase envelope.
  static Future<Uint8List> encryptVehicleFuelPurchase({
    required VehicleFuelPurchaseEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleFuelPurchaseAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.vehicleFuelPurchase,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'purchase_json': envelope.purchaseJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state vehicle fuel purchase envelope.
  static Future<VehicleFuelPurchaseEnvelope> decryptVehicleFuelPurchase({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.vehicleFuelPurchase);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleFuelPurchaseAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return VehicleFuelPurchaseEnvelope(
      senderLongTermPublicKey: senderPub,
      purchaseJson: (json['purchase_json'] as String?) ?? '{}',
    );
  }

  /// Encrypts a steady-state vehicle maintenance envelope.
  static Future<Uint8List> encryptVehicleMaintenance({
    required VehicleMaintenanceEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleMaintenanceAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.vehicleMaintenance,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'event_json': envelope.eventJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state vehicle maintenance envelope.
  static Future<VehicleMaintenanceEnvelope> decryptVehicleMaintenance({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.vehicleMaintenance);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleMaintenanceAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return VehicleMaintenanceEnvelope(
      senderLongTermPublicKey: senderPub,
      eventJson: (json['event_json'] as String?) ?? '{}',
    );
  }

  /// Encrypts a steady-state vehicle traffic violation envelope.
  static Future<Uint8List> encryptVehicleTrafficViolation({
    required VehicleTrafficViolationEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleTrafficViolationAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.vehicleTrafficViolation,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'violation_json': envelope.violationJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state vehicle traffic violation envelope.
  static Future<VehicleTrafficViolationEnvelope>
      decryptVehicleTrafficViolation({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.vehicleTrafficViolation);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleTrafficViolationAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return VehicleTrafficViolationEnvelope(
      senderLongTermPublicKey: senderPub,
      violationJson: (json['violation_json'] as String?) ?? '{}',
    );
  }

  /// Encrypts a steady-state fuel purchase catch-up envelope.
  static Future<Uint8List> encryptVehicleFuelPurchaseCatchUp({
    required VehicleFuelPurchaseCatchUpEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleFuelPurchaseCatchUpAeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: EnvelopeKind.vehicleFuelPurchaseCatchUp,
      senderPub: envelope.senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(
      jsonEncode({'catch_up_json': envelope.catchUpJson}),
    );
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  /// Decrypts a steady-state fuel purchase catch-up envelope.
  static Future<VehicleFuelPurchaseCatchUpEnvelope>
      decryptVehicleFuelPurchaseCatchUp({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    _expectKind(frame, EnvelopeKind.vehicleFuelPurchaseCatchUp);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: _vehicleFuelPurchaseCatchUpAeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return VehicleFuelPurchaseCatchUpEnvelope(
      senderLongTermPublicKey: senderPub,
      catchUpJson: (json['catch_up_json'] as String?) ?? '{}',
    );
  }

  static Future<Uint8List> _encryptSteadyPayloadJson({
    required int kind,
    required String aeadInfo,
    required Uint8List senderLongTermPublicKey,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
    required String payloadJson,
    required String jsonKey,
  }) async {
    final shared = await _x25519(
      privateKey: senderLongTermPrivateKey,
      peerPublicKey: peerLongTermPublicKey,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: aeadInfo,
      length: 32,
    );
    final header = _steadyHeader(
      kind: kind,
      senderPub: senderLongTermPublicKey,
      aeadNonce: _defaultNonceSource(),
    );
    final body = utf8.encode(jsonEncode({jsonKey: payloadJson}));
    final aeadNonce = header.sublist(header.length - 12);
    final encrypted = await _aeadEncrypt(
      key: key,
      nonce: aeadNonce,
      plaintext: body,
      aad: header,
    );
    return _concat(header, encrypted);
  }

  static Future<({Uint8List senderPub, String payloadJson})>
      _decryptSteadyPayloadJson({
    required Uint8List frame,
    required int kind,
    required String aeadInfo,
    required Uint8List receiverLongTermPrivateKey,
    required String jsonKey,
  }) async {
    _expectKind(frame, kind);
    final senderPub = Uint8List.fromList(frame.sublist(2, 34));
    final aeadNonce = Uint8List.fromList(frame.sublist(34, 46));
    final body = frame.sublist(46);
    final shared = await _x25519(
      privateKey: receiverLongTermPrivateKey,
      peerPublicKey: senderPub,
    );
    final key = await _hkdf(
      ikm: shared,
      salt: const <int>[],
      info: aeadInfo,
      length: 32,
    );
    final plain = await _aeadDecrypt(
      key: key,
      nonce: aeadNonce,
      cipherWithTag: body,
      aad: Uint8List.fromList(frame.sublist(0, 46)),
    );
    final json = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return (
      senderPub: senderPub,
      payloadJson: (json[jsonKey] as String?) ?? '{}',
    );
  }

  static Future<Uint8List> encryptVehicleUsageBalanceFreezePropose({
    required VehicleUsageBalanceFreezeEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) {
    return _encryptSteadyPayloadJson(
      kind: EnvelopeKind.vehicleUsageBalanceFreezePropose,
      aeadInfo: _vehicleUsageBalanceFreezeProposeAeadInfo,
      senderLongTermPublicKey: envelope.senderLongTermPublicKey,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      payloadJson: envelope.payloadJson,
      jsonKey: 'payload_json',
    );
  }

  static Future<VehicleUsageBalanceFreezeEnvelope>
      decryptVehicleUsageBalanceFreezePropose({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    final d = await _decryptSteadyPayloadJson(
      frame: frame,
      kind: EnvelopeKind.vehicleUsageBalanceFreezePropose,
      aeadInfo: _vehicleUsageBalanceFreezeProposeAeadInfo,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'payload_json',
    );
    return VehicleUsageBalanceFreezeEnvelope(
      senderLongTermPublicKey: d.senderPub,
      payloadJson: d.payloadJson,
    );
  }

  static Future<Uint8List> encryptVehicleUsageBalanceFreezeDecision({
    required VehicleUsageBalanceFreezeEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) {
    return _encryptSteadyPayloadJson(
      kind: EnvelopeKind.vehicleUsageBalanceFreezeDecision,
      aeadInfo: _vehicleUsageBalanceFreezeDecisionAeadInfo,
      senderLongTermPublicKey: envelope.senderLongTermPublicKey,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      payloadJson: envelope.payloadJson,
      jsonKey: 'payload_json',
    );
  }

  static Future<VehicleUsageBalanceFreezeEnvelope>
      decryptVehicleUsageBalanceFreezeDecision({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    final d = await _decryptSteadyPayloadJson(
      frame: frame,
      kind: EnvelopeKind.vehicleUsageBalanceFreezeDecision,
      aeadInfo: _vehicleUsageBalanceFreezeDecisionAeadInfo,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'payload_json',
    );
    return VehicleUsageBalanceFreezeEnvelope(
      senderLongTermPublicKey: d.senderPub,
      payloadJson: d.payloadJson,
    );
  }

  static Future<Uint8List> encryptVehicleUsageTransferPropose({
    required VehicleUsageTransferEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) {
    return _encryptSteadyPayloadJson(
      kind: EnvelopeKind.vehicleUsageTransferPropose,
      aeadInfo: _vehicleUsageTransferProposeAeadInfo,
      senderLongTermPublicKey: envelope.senderLongTermPublicKey,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      payloadJson: envelope.payloadJson,
      jsonKey: 'payload_json',
    );
  }

  static Future<VehicleUsageTransferEnvelope> decryptVehicleUsageTransferPropose({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    final d = await _decryptSteadyPayloadJson(
      frame: frame,
      kind: EnvelopeKind.vehicleUsageTransferPropose,
      aeadInfo: _vehicleUsageTransferProposeAeadInfo,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'payload_json',
    );
    return VehicleUsageTransferEnvelope(
      senderLongTermPublicKey: d.senderPub,
      payloadJson: d.payloadJson,
    );
  }

  static Future<Uint8List> encryptVehicleUsageTransferDecision({
    required VehicleUsageTransferEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) {
    return _encryptSteadyPayloadJson(
      kind: EnvelopeKind.vehicleUsageTransferDecision,
      aeadInfo: _vehicleUsageTransferDecisionAeadInfo,
      senderLongTermPublicKey: envelope.senderLongTermPublicKey,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      payloadJson: envelope.payloadJson,
      jsonKey: 'payload_json',
    );
  }

  static Future<VehicleUsageTransferEnvelope>
      decryptVehicleUsageTransferDecision({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    final d = await _decryptSteadyPayloadJson(
      frame: frame,
      kind: EnvelopeKind.vehicleUsageTransferDecision,
      aeadInfo: _vehicleUsageTransferDecisionAeadInfo,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'payload_json',
    );
    return VehicleUsageTransferEnvelope(
      senderLongTermPublicKey: d.senderPub,
      payloadJson: d.payloadJson,
    );
  }

  static Future<Uint8List> encryptVehicleUsageBalanceFreezeCatchUp({
    required VehicleUsageBalanceFreezeEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) {
    return _encryptSteadyPayloadJson(
      kind: EnvelopeKind.vehicleUsageBalanceFreezeCatchUp,
      aeadInfo: _vehicleUsageBalanceFreezeCatchUpAeadInfo,
      senderLongTermPublicKey: envelope.senderLongTermPublicKey,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      payloadJson: envelope.payloadJson,
      jsonKey: 'payload_json',
    );
  }

  static Future<VehicleUsageBalanceFreezeEnvelope>
      decryptVehicleUsageBalanceFreezeCatchUp({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    final d = await _decryptSteadyPayloadJson(
      frame: frame,
      kind: EnvelopeKind.vehicleUsageBalanceFreezeCatchUp,
      aeadInfo: _vehicleUsageBalanceFreezeCatchUpAeadInfo,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'payload_json',
    );
    return VehicleUsageBalanceFreezeEnvelope(
      senderLongTermPublicKey: d.senderPub,
      payloadJson: d.payloadJson,
    );
  }

  static Future<Uint8List> encryptVehicleSharingRevoke({
    required VehicleSharingLifecycleEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) {
    return _encryptSteadyPayloadJson(
      kind: EnvelopeKind.vehicleSharingRevoke,
      aeadInfo: _vehicleSharingRevokeAeadInfo,
      senderLongTermPublicKey: envelope.senderLongTermPublicKey,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      payloadJson: envelope.payloadJson,
      jsonKey: 'payload_json',
    );
  }

  static Future<VehicleSharingLifecycleEnvelope> decryptVehicleSharingRevoke({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    final d = await _decryptSteadyPayloadJson(
      frame: frame,
      kind: EnvelopeKind.vehicleSharingRevoke,
      aeadInfo: _vehicleSharingRevokeAeadInfo,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'payload_json',
    );
    return VehicleSharingLifecycleEnvelope(
      senderLongTermPublicKey: d.senderPub,
      payloadJson: d.payloadJson,
    );
  }

  static Future<Uint8List> encryptVehicleSharingReactivatePropose({
    required VehicleSharingLifecycleEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) {
    return _encryptSteadyPayloadJson(
      kind: EnvelopeKind.vehicleSharingReactivatePropose,
      aeadInfo: _vehicleSharingReactivateProposeAeadInfo,
      senderLongTermPublicKey: envelope.senderLongTermPublicKey,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      payloadJson: envelope.payloadJson,
      jsonKey: 'payload_json',
    );
  }

  static Future<VehicleSharingLifecycleEnvelope>
      decryptVehicleSharingReactivatePropose({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    final d = await _decryptSteadyPayloadJson(
      frame: frame,
      kind: EnvelopeKind.vehicleSharingReactivatePropose,
      aeadInfo: _vehicleSharingReactivateProposeAeadInfo,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'payload_json',
    );
    return VehicleSharingLifecycleEnvelope(
      senderLongTermPublicKey: d.senderPub,
      payloadJson: d.payloadJson,
    );
  }

  static Future<Uint8List> encryptVehicleSharingReactivateAccept({
    required VehicleSharingLifecycleEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) {
    return _encryptSteadyPayloadJson(
      kind: EnvelopeKind.vehicleSharingReactivateAccept,
      aeadInfo: _vehicleSharingReactivateAcceptAeadInfo,
      senderLongTermPublicKey: envelope.senderLongTermPublicKey,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      payloadJson: envelope.payloadJson,
      jsonKey: 'payload_json',
    );
  }

  static Future<VehicleSharingLifecycleEnvelope>
      decryptVehicleSharingReactivateAccept({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    final d = await _decryptSteadyPayloadJson(
      frame: frame,
      kind: EnvelopeKind.vehicleSharingReactivateAccept,
      aeadInfo: _vehicleSharingReactivateAcceptAeadInfo,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'payload_json',
    );
    return VehicleSharingLifecycleEnvelope(
      senderLongTermPublicKey: d.senderPub,
      payloadJson: d.payloadJson,
    );
  }

  static Future<Uint8List> encryptVehicleUseSessionEndByOwner({
    required VehicleUseSessionEndEnvelope envelope,
    required Uint8List senderLongTermPrivateKey,
    required Uint8List peerLongTermPublicKey,
  }) {
    return _encryptSteadyPayloadJson(
      kind: EnvelopeKind.vehicleUseSessionEndByOwner,
      aeadInfo: _vehicleUseSessionEndByOwnerAeadInfo,
      senderLongTermPublicKey: envelope.senderLongTermPublicKey,
      senderLongTermPrivateKey: senderLongTermPrivateKey,
      peerLongTermPublicKey: peerLongTermPublicKey,
      payloadJson: envelope.sessionJson,
      jsonKey: 'session_json',
    );
  }

  static Future<VehicleUseSessionEndEnvelope>
      decryptVehicleUseSessionEndByOwner({
    required Uint8List frame,
    required Uint8List receiverLongTermPrivateKey,
  }) async {
    final d = await _decryptSteadyPayloadJson(
      frame: frame,
      kind: EnvelopeKind.vehicleUseSessionEndByOwner,
      aeadInfo: _vehicleUseSessionEndByOwnerAeadInfo,
      receiverLongTermPrivateKey: receiverLongTermPrivateKey,
      jsonKey: 'session_json',
    );
    return VehicleUseSessionEndEnvelope(
      senderLongTermPublicKey: d.senderPub,
      sessionJson: d.payloadJson,
    );
  }
}

/// Header view of a hello envelope returned by [EnvelopeCodec.peekHelloHeader].
class HelloHeader {
  HelloHeader({
    required this.invitationId,
    required this.inviteeLongTermPublicKey,
    required this.aeadNonce,
  });

  final Uint8List invitationId;
  final Uint8List inviteeLongTermPublicKey;
  final Uint8List aeadNonce;
}

/// Header view of an ack envelope returned by [EnvelopeCodec.peekAckHeader].
class AckHeader {
  AckHeader({
    required this.invitationId,
    required this.inviterLongTermPublicKey,
    required this.aeadNonce,
  });

  final Uint8List invitationId;
  final Uint8List inviterLongTermPublicKey;
  final Uint8List aeadNonce;
}

class EnvelopeDecryptionError implements Exception {
  const EnvelopeDecryptionError(this.reason);
  final String reason;

  @override
  String toString() => 'EnvelopeDecryptionError($reason)';
}

/// Reads optional `how_i_label_you` from decrypted profile_update JSON.
///
/// Omitted key → not an appearance notice. Empty string → sender cleared
/// their local label. Non-string value → [EnvelopeDecryptionError].
({bool present, String value}) parseProfileUpdateHowILabelYou(
  Map<String, dynamic> json,
) {
  if (!json.containsKey('how_i_label_you')) {
    return (present: false, value: '');
  }
  final raw = json['how_i_label_you'];
  if (raw != null && raw is! String) {
    throw const EnvelopeDecryptionError('malformed_how_i_label_you');
  }
  return (present: true, value: (raw as String?) ?? '');
}

// ---------- internal helpers ----------

Uint8List _helloHeader({
  required Uint8List invitationId,
  required Uint8List inviteePub,
  required Uint8List aeadNonce,
}) {
  assert(invitationId.length == 8);
  assert(inviteePub.length == 32);
  assert(aeadNonce.length == 12);
  final out = Uint8List(2 + 8 + 32 + 12);
  out[0] = _framingVersion;
  out[1] = EnvelopeKind.hello;
  out.setRange(2, 10, invitationId);
  out.setRange(10, 42, inviteePub);
  out.setRange(42, 54, aeadNonce);
  return out;
}

Uint8List _ackHeader({
  required Uint8List invitationId,
  required Uint8List inviterPub,
  required Uint8List aeadNonce,
}) {
  assert(invitationId.length == 8);
  assert(inviterPub.length == 32);
  assert(aeadNonce.length == 12);
  final out = Uint8List(2 + 8 + 32 + 12);
  out[0] = _framingVersion;
  out[1] = EnvelopeKind.ack;
  out.setRange(2, 10, invitationId);
  out.setRange(10, 42, inviterPub);
  out.setRange(42, 54, aeadNonce);
  return out;
}

Uint8List _steadyHeader({
  required int kind,
  required Uint8List senderPub,
  required Uint8List aeadNonce,
}) {
  assert(senderPub.length == 32);
  assert(aeadNonce.length == 12);
  final out = Uint8List(2 + 32 + 12);
  out[0] = _framingVersion;
  out[1] = kind;
  out.setRange(2, 34, senderPub);
  out.setRange(34, 46, aeadNonce);
  return out;
}

Uint8List _concat(Uint8List a, Uint8List b) {
  final out = Uint8List(a.length + b.length);
  out.setRange(0, a.length, a);
  out.setRange(a.length, out.length, b);
  return out;
}

void _expectKind(Uint8List frame, int kind) {
  if (frame.length < 2) {
    throw const EnvelopeDecryptionError('frame_too_short');
  }
  if (frame[0] != _framingVersion) {
    throw const EnvelopeDecryptionError('unsupported_framing_version');
  }
  if (frame[1] != kind) {
    throw const EnvelopeDecryptionError('wrong_envelope_kind');
  }
}

Future<Uint8List> _x25519({
  required Uint8List privateKey,
  required Uint8List peerPublicKey,
}) async {
  final algo = Cryptography.instance.x25519();
  final ourKeyPair = await algo.newKeyPairFromSeed(privateKey);
  final peer = SimplePublicKey(peerPublicKey, type: KeyPairType.x25519);
  final shared = await algo.sharedSecretKey(
    keyPair: ourKeyPair,
    remotePublicKey: peer,
  );
  final bytes = await shared.extractBytes();
  return Uint8List.fromList(bytes);
}

Future<Uint8List> _hkdf({
  required List<int> ikm,
  required List<int> salt,
  required String info,
  required int length,
}) async {
  // Per RFC 5869 §2.2, an empty salt is treated as `HashLen` zero bytes.
  // `cryptography_plus` rejects an empty HMAC key, so we substitute here.
  final effectiveSalt = salt.isEmpty ? Uint8List(32) : salt;
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: length);
  final out = await hkdf.deriveKey(
    secretKey: SecretKey(ikm),
    nonce: effectiveSalt,
    info: utf8.encode(info),
  );
  final bytes = await out.extractBytes();
  return Uint8List.fromList(bytes);
}

Future<Uint8List> _aeadEncrypt({
  required Uint8List key,
  required Uint8List nonce,
  required List<int> plaintext,
  required List<int> aad,
}) async {
  final algo = Chacha20.poly1305Aead();
  final secretBox = await algo.encrypt(
    plaintext,
    secretKey: SecretKey(key),
    nonce: nonce,
    aad: aad,
  );
  final out = Uint8List(
    secretBox.cipherText.length + secretBox.mac.bytes.length,
  );
  out.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
  out.setRange(secretBox.cipherText.length, out.length, secretBox.mac.bytes);
  return out;
}

Future<Uint8List> _aeadDecrypt({
  required Uint8List key,
  required Uint8List nonce,
  required List<int> cipherWithTag,
  required List<int> aad,
}) async {
  if (cipherWithTag.length < 16) {
    throw const EnvelopeDecryptionError('body_too_short');
  }
  final cipher = cipherWithTag.sublist(0, cipherWithTag.length - 16);
  final tag = cipherWithTag.sublist(cipherWithTag.length - 16);
  final algo = Chacha20.poly1305Aead();
  try {
    final plain = await algo.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(tag)),
      secretKey: SecretKey(key),
      aad: aad,
    );
    return Uint8List.fromList(plain);
  } on SecretBoxAuthenticationError {
    throw const EnvelopeDecryptionError('aead_authentication_failed');
  }
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
