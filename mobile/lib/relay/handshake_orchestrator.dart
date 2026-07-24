import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;

import '../activity/relay_activity_log_service.dart';
import '../contacts/contact_duplicate_handshake_dialog_state.dart';
import '../contacts/contact_duplicate_module_anchor.dart';
import '../contacts/contact_invitations_repository.dart';
import '../contacts/invitation_code.dart';
import '../contacts/invitation_expiry_reminder_service.dart';
import '../db/app_database.dart';
import '../db/repositories/contacts_repository.dart';
import '../device/device_binding_service.dart';
import '../entitlement/entitlement_coordinator.dart';
import '../relay/relay_http_policy.dart';
import '../housing/housing_navigation_intent.dart';
import '../housing/housing_participant_profile_sync.dart';
import '../housing/housing_plan_peer_contacts.dart';
import '../housing/housing_plan_peer_identity_reconcile.dart';
import '../housing/amendment/housing_amendment_type.dart';
import '../housing/plan_peer_establishment_service.dart';
import '../housing/proposals/housing_proposal_transport_service.dart';
import '../housing/proposals/plan_agreement_proposal_service.dart';
import '../housing/participation/housing_participation_change_kind.dart';
import '../housing/participation/housing_participation_change_service.dart';
import '../housing/participation/housing_participation_change_sync_service.dart';
import '../housing/reminders/housing_payment_reminder_service.dart';
import '../housing/reminders/proposal_deadline_reminder_service.dart';
import '../housing/proposals/housing_proposal_revision_state.dart';
import '../housing/realized_expense/realized_expense_ledger_service.dart';
import '../housing/realized_expense/realized_expense_participants.dart';
import '../housing/realized_expense/realized_expense_repository.dart';
import '../housing/realized_expense/realized_expense_status.dart';
import '../housing/realized_expense/realized_expense_sync_service.dart';
import '../notifications/contact_notification_service.dart';
import '../notifications/push_notification_service.dart';
import '../prefs/app_preferences.dart';
import '../sandbox/peer_simulator.dart';
import 'envelopes.dart';
import 'identity_keystore.dart';
import 'relay_client.dart';
import 'relay_diagnostics.dart';
import 'routing.dart';

/// Handshake state machine values mirrored from `PendingHandshakes.state`.
///
/// Inviter timeline:
///   awaitingHello -> helloReceived -> completed | rejected
///   (helloReceived is transient when [autoAcceptIncomingHandshakes] is true)
/// Invitee timeline:
///   dispatchingHello -> awaitingAck -> completed | rejected
/// Either side can transition to `failed` on unrecoverable error.
class HandshakeState {
  static const String awaitingHello = 'awaiting_hello';

  /// Invitee: hello not yet confirmed posted to the relay (poll retries POST).
  static const String dispatchingHello = 'dispatching_hello';
  static const String awaitingAck = 'awaiting_ack';

  /// Inviter has validated the hello; the peer's profile is stashed on
  /// the row, waiting for the local user to accept or reject.
  static const String helloReceived = 'hello_received';

  static const String rejected = 'rejected';
  static const String completed = 'completed';
  static const String failed = 'failed';
}

/// Role values mirrored from `PendingHandshakes.role`.
class HandshakeRole {
  static const String inviter = 'inviter';
  static const String invitee = 'invitee';
}

/// Lightweight view used by the UI to surface incoming handshakes from
/// the inviter side without forcing it to know the DB schema.
class IncomingHandshakeView {
  IncomingHandshakeView({
    required this.handshakeId,
    required this.invitationIdHex,
    required this.peerDisplayName,
    required this.peerAvatarId,
    required this.peerPublicMaterialB64,
    required this.contactStubId,
    required this.receivedAt,
  });

  final String handshakeId;
  final String invitationIdHex;
  final String peerDisplayName;
  final String peerAvatarId;
  final String peerPublicMaterialB64;
  final String contactStubId;
  final DateTime receivedAt;
}

/// Fired when a peer's canonical name no longer matches the local user's
/// display label override for that contact (see `contact-peer-display-ownership`).
class ProfileLabelConflict {
  ProfileLabelConflict({
    required this.contactId,
    required this.newCanonicalDisplayName,
    required this.localDisplayLabel,
  });

  final String contactId;
  final String newCanonicalDisplayName;
  final String localDisplayLabel;
}

enum InviterHandshakeFinalizeResult {
  accepted,
  acceptedMergedDuplicate,
  rejectedDuplicateModuleAnchor,
  alreadyHandled,
}

/// Result of a redeem attempt on the invitee side.
class RedeemHandshakeResult {
  RedeemHandshakeResult({
    required this.handshakeId,
    required this.localContactId,
  });

  final String handshakeId;
  final String localContactId;
}

class HousingProposalSendResult {
  const HousingProposalSendResult({
    required this.sentCount,
    required this.failedParticipantIds,
    this.relayStatusByParticipantId = const {},
  });

  final int sentCount;
  final List<String> failedParticipantIds;

  /// Per roster participant id: `queued` (relay POST ok) or `failed`.
  final Map<String, String> relayStatusByParticipantId;
}

/// Errors surfaced by the orchestrator.
class HandshakeOrchestratorError implements Exception {
  HandshakeOrchestratorError(this.code, [this.cause]);

  /// One of: `relay_unavailable`, `relay_error`, `invalid_code`,
  /// `already_completed`, `nonce_already_consumed`, `expired_code`,
  /// `unknown`.
  final String code;
  final Object? cause;

  @override
  String toString() =>
      'HandshakeOrchestratorError($code${cause == null ? '' : ': $cause'})';
}

/// Coordinates the entire Contacts handshake lifecycle on this device.
///
/// One instance per process; held by [bootstrap] and surfaced through the
/// [HandshakeOrchestrator.instance] static getter so any screen can drive
/// the flow without dependency injection.
///
/// Behaviour summary:
///
/// * **Generate an invitation** ([generateInvitation]): creates a stub
///   Contact, persists the local invitation row, pre-registers both
///   handshake-routing directions on the relay so the invitee can post
///   `hello` and so this device can post `ack` back to the invitee's
///   long-term address once the handshake completes.
/// * **Redeem an invitation** ([redeemInvitation]): derives handshake
///   addresses + handshake keys from the code, creates a stub Contact,
///   encrypts and posts the `hello`, persists a row in
///   `PendingHandshakes` so polling will pick up the ack.
/// * **Polling** ([processAllPendingHandshakes]): for each non-terminal
///   row, fetches the relevant relay inbox, decrypts incoming envelopes,
///   and finishes the flow (inviter auto-accepts valid hellos; invitee
///   receives the ack). The periodic poll also runs [pollSteadyStateInboxes]
///   so inbound steady-state envelopes reach connected contacts.
/// * **Accept / Reject** ([acceptIncoming] / [rejectIncoming]): legacy
///   manual inviter decision when [autoAcceptIncomingHandshakes] is false;
///   otherwise valid hellos are accepted automatically after validation.
/// * **Steady state** ([sendProfileUpdate], [sendDisconnect]): small
///   encrypted envelopes between connected contacts. Profile updates do
///   not transition any Contact kind; disconnect demotes both ends back
///   to local-only.
class HandshakeOrchestrator {
  HandshakeOrchestrator({
    required AppDatabase db,
    required IdentityKeystore identity,
    required RelayClient relay,
    required ContactsRepository contacts,
    required ContactInvitationsRepository invitations,
    EntitlementCoordinator? entitlement,
    DeviceBindingService? deviceBinding,
    ContactNotificationSink contactNotifications =
        const DefaultContactNotificationSink(),
    Duration pollInterval = RelayHttpPolicy.pollInterval,
    Duration helloTtl = const Duration(hours: 24),
    Duration ackTtl = const Duration(hours: 24),
    Duration steadyTtl = const Duration(hours: 24),
    DateTime Function() now = DateTime.now,
  }) : _db = db,
       _identity = identity,
       _relay = relay,
       _contacts = contacts,
       _invitations = invitations,
       _entitlement = entitlement ?? EntitlementCoordinator.maybeInstance,
       _deviceBinding = deviceBinding ?? DeviceBindingService(),
       _contactNotifications = contactNotifications,
       _pollInterval = pollInterval,
       _helloTtl = helloTtl,
       _ackTtl = ackTtl,
       _steadyTtl = steadyTtl,
       _now = now;

  /// When true (default), a validated inviter-side `hello` is accepted
  /// immediately without surfacing a manual confirmation step.
  @visibleForTesting
  bool autoAcceptIncomingHandshakes = true;

  /// Test hook supplying the inviter profile shipped inside the auto-accept
  /// ack. When null, [AppPreferences] is read (same as the manual accept UI).
  @visibleForTesting
  Future<({String displayName, String avatarId})> Function()?
  ackProfileForAutoAccept;

  /// Only the bootstrap [maybeInstance] posts housing notifications to the OS.
  /// Sandbox bot orchestrators poll the same FakeRelay but share one device.
  bool get _ownsDeviceHousingNotifications =>
      identical(this, HandshakeOrchestrator.maybeInstance);

  /// PeerSimulator / sandbox bots: keep inviter auto-accept and pin ack profile.
  void enableSandboxPeerAutoAccept({
    required Future<({String displayName, String avatarId})> Function() profile,
  }) {
    autoAcceptIncomingHandshakes = true;
    ackProfileForAutoAccept = profile;
  }

  final AppDatabase _db;
  final IdentityKeystore _identity;
  final RelayClient _relay;
  final ContactsRepository _contacts;
  final ContactInvitationsRepository _invitations;
  final EntitlementCoordinator? _entitlement;
  final DeviceBindingService _deviceBinding;
  final ContactNotificationSink _contactNotifications;
  final Duration _pollInterval;
  final Duration _helloTtl;
  final Duration _ackTtl;
  final Duration _steadyTtl;
  final DateTime Function() _now;

  AppPreferences? _cachedPrefs;
  HousingPaymentReminderService? _cachedReminderService;

  /// Same [RelayClient] passed at construction (used for routing push).
  RelayClient get relayClient => _relay;

  static HandshakeOrchestrator? _instance;

  /// Globally accessible orchestrator. Set during [bootstrap]. Tests can
  /// install a custom one via [installForTesting].
  static HandshakeOrchestrator get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'HandshakeOrchestrator has not been initialised. Call '
        'HandshakeOrchestrator.install(...) during bootstrap.',
      );
    }
    return i;
  }

  /// Returns the installed orchestrator, or `null` if none has been
  /// installed yet. Useful in environments (tests, dev builds with no
  /// relay configured) where the relay layer is intentionally absent.
  static HandshakeOrchestrator? get maybeInstance => _instance;

  /// Optional hook invoked after routing topology changes so the app can
  /// refresh closed-app push token registrations on the relay.
  static Future<void> Function()? refreshClosedAppPushRegistration;

  static void requestClosedAppPushRegistrationSync() {
    final fn = refreshClosedAppPushRegistration;
    if (fn == null) return;
    unawaited(
      fn().catchError((Object e, StackTrace st) {
        debugPrint('Closed-app push registration sync failed: $e\n$st');
      }),
    );
  }

  /// Installs the process-wide orchestrator. Must be called once during
  /// bootstrap. Subsequent calls replace the instance (useful for
  /// rebinding after preference changes).
  static void install(HandshakeOrchestrator orchestrator) {
    _instance = orchestrator;
  }

  @visibleForTesting
  static void installForTesting(HandshakeOrchestrator orchestrator) {
    _instance = orchestrator;
  }

  bool _pollLoopActive = false;
  bool _processing = false;
  bool _steadyInboxPolling = false;
  bool _steadyInboxPollNeededAgain = false;
  Completer<void>? _steadyInboxPollCompleter;

  /// In-process claim so concurrent inbox applies cannot double-post #7.
  final Set<String> _housingDecisionNotifiedResponseIds = <String>{};

  /// Exposes the list of incoming handshakes awaiting accept / reject on
  /// the inviter side. UI binds to this to show the confirmation card.
  final ValueNotifier<List<IncomingHandshakeView>> incomingHandshakes =
      ValueNotifier<List<IncomingHandshakeView>>(const []);

  /// Incremented whenever a steady-state inbox envelope is applied
  /// ([EnvelopeKind.profileUpdate] or [EnvelopeKind.disconnect]) so contact
  /// UIs can refresh.
  final ValueNotifier<int> steadyStateInboxTick = ValueNotifier<int>(0);

  /// When a profile-update changes a peer's canonical name but the local user
  /// had a different [Contacts.localDisplayLabel], UIs MAY listen and prompt.
  final ValueNotifier<ProfileLabelConflict?> profileLabelConflict =
      ValueNotifier<ProfileLabelConflict?>(null);

  /// One-shot duplicate-handshake dialog for inviter or invitee; consumed on
  /// [ContactsListScreen].
  final ValueNotifier<PendingContactDuplicateDialog?>
  pendingContactDuplicateDialog = ValueNotifier<PendingContactDuplicateDialog?>(
    null,
  );

  /// Disposes timers + notifiers. Mostly useful in tests.
  void dispose() {
    stopPolling();
    incomingHandshakes.dispose();
    steadyStateInboxTick.dispose();
    profileLabelConflict.dispose();
    pendingContactDuplicateDialog.dispose();
  }

  /// Starts the periodic polling loop. Safe to call multiple times.
  ///
  /// Each cycle waits [pollInterval] (30 s request budget + 1 s cooldown),
  /// then runs [processAllPendingHandshakes] and steady inbox polling.
  /// Callers that need an immediate poll should `await processAllPendingHandshakes()`
  /// explicitly (bootstrap and UI do this before [startPolling]).
  void startPolling() {
    if (_pollLoopActive) return;
    _pollLoopActive = true;
    unawaited(_runPollLoop());
  }

  /// Stops the periodic polling loop.
  void stopPolling() {
    _pollLoopActive = false;
  }

  Future<void> _runPollLoop() async {
    while (_pollLoopActive) {
      await Future<void>.delayed(_pollInterval);
      if (!_pollLoopActive) break;
      await _safePoll();
    }
  }

  /// Stops relay polling and closes the bootstrap-owned [AppDatabase] so the
  /// on-disk SQLite files can be removed (development-only local DB reset).
  Future<void> releaseLocalDatabaseConnectionForDevReset() async {
    stopPolling();
    _housingDecisionNotifiedResponseIds.clear();
    await _db.close();
    AppDatabase.clearProcessScopeIfReferencing(_db);
  }

  /// Clears the process-wide orchestrator after its database was closed for a
  /// dev reset. A full app restart is required to reinstall the relay stack.
  static void clearInstalledInstanceAfterDevDatabaseReset() {
    _instance = null;
  }

  Future<void> _safePoll() async {
    if (_processing) return;
    _processing = true;
    try {
      await processAllPendingHandshakes();
      await pollSteadyStateInboxes();
    } catch (e, st) {
      debugPrint('HandshakeOrchestrator poll failed: $e\n$st');
    } finally {
      _processing = false;
    }
  }

  // ---------------------------------------------------------------------
  // Inviter side
  // ---------------------------------------------------------------------

  /// Generates a new invitation, creates a local stub Contact, registers
  /// the handshake routing on the relay, and starts polling.
  ///
  /// [stubDisplayName] / [stubAvatarId] feed the local stub so the user
  /// has a non-empty Contact to look at while the invitee thinks about
  /// the request. The display name will be **replaced** by the invitee's
  /// chosen self-name on accept.
  /// Local invitation expiry for [code] when this device created the invite.
  Future<DateTime?> lookupInvitationExpiresAtUtc(InvitationCode code) async {
    final row = await (_db.select(
      _db.contactInvitations,
    )..where((t) => t.id.equals(code.invitationIdHex()))).getSingleOrNull();
    if (row == null || row.status != InvitationStatus.pending) return null;
    return row.expiresAt;
  }

  Future<
    ({
      ContactInvitation invitation,
      String localContactId,
      String shortCode,
      String deepLink,
      String webLink,
    })
  >
  generateInvitation({
    required Duration validFor,
    required String stubDisplayName,
    required String stubAvatarId,
    String? reconnectContactId,
  }) async {
    final created = _now().toUtc();
    final code = InvitationCode.generate();
    final invitationIdHex = code.invitationIdHex();
    final stubContactId =
        reconnectContactId ?? 'contact:handshake:$invitationIdHex';

    // 1) Stub Contact (local-only, will be promoted on accept). Reconnection
    // invitations point at the existing disconnected Contact instead.
    if (reconnectContactId == null) {
      await _contacts.upsertLocalOnly(
        id: stubContactId,
        displayName: stubDisplayName,
        avatarId: stubAvatarId,
        createdAt: created,
        updatedAt: created,
      );
    }

    // 2) Local invitation row owns the lifecycle (pending / used / ...).
    await _db.upsertContactInvitation(
      ContactInvitationsCompanion.insert(
        id: invitationIdHex,
        nonce: code.nonceHex(),
        status: InvitationStatus.pending,
        createdAt: created,
        expiresAt: created.add(validFor),
        contactStubId: drift.Value(stubContactId),
      ),
    );

    // 3) Register the handshake routing both directions so the invitee's
    //    hello AND the eventual ack are admitted by the relay.
    final addrInviter = await RelayRouting.inviterHandshakeAddress(
      invitationId: code.invitationId,
      nonce: code.nonce,
    );
    final addrInvitee = await RelayRouting.inviteeHandshakeAddress(
      invitationId: code.invitationId,
      nonce: code.nonce,
    );
    try {
      await _relay.establishRouting(
        selfIdentity: addrInvitee,
        peerIdentity: addrInviter,
      );
      await _relay.establishRouting(
        selfIdentity: addrInviter,
        peerIdentity: addrInvitee,
      );
    } on RelayClientError catch (e) {
      throw HandshakeOrchestratorError('relay_error', e);
    } on RelayUnreachableException catch (e) {
      throw HandshakeOrchestratorError('relay_unavailable', e);
    } on TimeoutException catch (e) {
      throw HandshakeOrchestratorError('relay_unavailable', e);
    }

    // 4) Pending handshake row keeps the orchestrator polling.
    final pendingId = _pendingHandshakeId(
      invitationIdHex,
      HandshakeRole.inviter,
    );
    await _db.upsertPendingHandshake(
      PendingHandshakesCompanion.insert(
        id: pendingId,
        invitationIdHex: invitationIdHex,
        nonceHex: code.nonceHex(),
        role: HandshakeRole.inviter,
        state: HandshakeState.awaitingHello,
        contactStubId: stubContactId,
        createdAt: created,
        updatedAt: created,
        expiresAt: created.add(validFor),
      ),
    );

    startPolling();
    requestClosedAppPushRegistrationSync();

    final expiresAt = created.add(validFor);
    final row = await (_db.select(
      _db.contactInvitations,
    )..where((t) => t.id.equals(invitationIdHex))).getSingle();

    unawaited(
      InvitationExpiryReminderService(
        relay: _relay,
        orchestrator: this,
      ).registerForInvitation(
        invitationId: invitationIdHex,
        validFor: validFor,
        expiresAtUtc: expiresAt,
      ),
    );

    return (
      invitation: row,
      localContactId: stubContactId,
      shortCode: code.renderShort(),
      deepLink: code.renderDeepLink(expiresAtUtc: expiresAt),
      webLink: code.renderWebLink(expiresAtUtc: expiresAt),
    );
  }

  /// Cancels relay invitation-expiry fires (revoke / used / extend).
  Future<void> cancelInvitationExpiryReminders(String invitationId) =>
      _cancelInvitationExpiryReminders(invitationId);

  Future<void> _cancelInvitationExpiryReminders(String invitationId) async {
    try {
      await InvitationExpiryReminderService(
        relay: _relay,
        orchestrator: this,
      ).cancelForInvitation(invitationId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('cancelInvitationExpiryReminders: $e');
      }
    }
  }

  /// Inviter accepts an incoming handshake.
  ///
  /// [selfDisplayName] and [selfAvatarId] are the LOCAL user's identity
  /// values (typically read from `AppPreferences`) shipped inside the
  /// ack envelope so the invitee can render the new connected contact.
  /// Sends the `ack`, promotes the stub Contact to connected with the
  /// invitee's display name / avatar, and registers the steady-state
  /// routing on the relay.
  Future<void> acceptIncoming(
    String handshakeId, {
    required String selfDisplayName,
    required String selfAvatarId,
  }) async {
    final row = await _db.getPendingHandshake(handshakeId);
    if (row == null) {
      throw HandshakeOrchestratorError('unknown');
    }
    if (row.role != HandshakeRole.inviter ||
        row.state != HandshakeState.helloReceived) {
      throw HandshakeOrchestratorError('already_completed');
    }
    final peerPubB64 = row.peerLongTermPublicMaterialB64;
    if (peerPubB64 == null) {
      throw HandshakeOrchestratorError('unknown');
    }
    await _finalizeInviterAccept(
      handshakeRow: row,
      peerPubBytes: RelayRouting.unb64(peerPubB64),
      peerDisplayName: row.peerDisplayName,
      peerAvatarId: row.peerAvatarId,
      peerDeviceBindingId: row.peerDeviceBindingId,
      selfDisplayName: selfDisplayName,
      selfAvatarId: selfAvatarId,
    );
  }

  /// Inviter rejects an incoming handshake. Sends a `rejected` ack so
  /// the invitee gets a documented signal back, then drops the local
  /// stub Contact (no promotion happens).
  Future<void> rejectIncoming(
    String handshakeId, {
    String? selfDisplayName,
    String? selfAvatarId,
  }) async {
    final row = await _db.getPendingHandshake(handshakeId);
    if (row == null) {
      throw HandshakeOrchestratorError('unknown');
    }
    if (row.role != HandshakeRole.inviter) {
      throw HandshakeOrchestratorError('unknown');
    }
    final peerPubB64 = row.peerLongTermPublicMaterialB64;
    if (peerPubB64 == null) {
      throw HandshakeOrchestratorError('unknown');
    }
    final invitationIdBytes = _hexDecode(row.invitationIdHex);
    final nonceBytes = _hexDecode(row.nonceHex);
    final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final String displayName;
    final String avatarId;
    if (selfDisplayName != null && selfAvatarId != null) {
      displayName = selfDisplayName;
      avatarId = selfAvatarId;
    } else {
      final prefs = await AppPreferences.load();
      displayName = selfDisplayName ?? prefs.displayName;
      avatarId = selfAvatarId ?? prefs.avatarId;
    }
    final inviterLongTermPub = await _identity.publicKey();
    final inviteePub = RelayRouting.unb64(peerPubB64);
    final selfBindingId = await _deviceBinding.loadOrComputeId();

    final ackFrame = await EnvelopeCodec.encryptAck(
      envelope: AckEnvelope(
        invitationId: invitationIdBytes,
        inviterLongTermPublicKey: inviterLongTermPub,
        accepted: false,
        deviceBindingId: selfBindingId,
        displayName: displayName,
        avatarId: avatarId,
      ),
      invitationNonce: nonceBytes,
      inviterHandshakePrivateKey: inviterHandshakePriv,
      inviteeLongTermPublicKey: inviteePub,
    );
    final addrInviter = await RelayRouting.inviterHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final addrInvitee = await RelayRouting.inviteeHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    try {
      await _relay.postEnvelope(
        senderIdentity: addrInviter,
        recipientIdentity: addrInvitee,
        idempotencyKey: _randomBytes(16),
        ciphertext: ackFrame,
        kind: EnvelopeKind.ack,
        ttl: _ackTtl,
      );
    } on RelayClientError catch (e) {
      throw HandshakeOrchestratorError('relay_error', e);
    }

    // Drop the local stub: rejection means no relationship was formed.
    await _contacts.deleteLocally(row.contactStubId);

    await _markHandshake(row.id, state: HandshakeState.rejected);
    await _decommissionHandshakeAddresses(
      addrInviter: addrInviter,
      addrInvitee: addrInvitee,
    );
    await refreshIncomingHandshakes();
    requestClosedAppPushRegistrationSync();
  }

  // ---------------------------------------------------------------------
  // Invitee side
  // ---------------------------------------------------------------------

  /// Invitee submits a parsed invitation code: this method creates the
  /// stub Contact, encrypts the `hello` envelope, posts it to the
  /// inviter's handshake address, persists a polling row, and starts
  /// polling so the ack will be picked up.
  Future<RedeemHandshakeResult> redeemInvitation({
    required InvitationCode code,
    required String selfDisplayName,
    required String selfAvatarId,
  }) async {
    final created = _now().toUtc();
    final invitationIdHex = code.invitationIdHex();
    final stubContactId = 'contact:redeemed:$invitationIdHex';

    final pendingId = _pendingHandshakeId(
      invitationIdHex,
      HandshakeRole.invitee,
    );
    final existing = await _db.getPendingHandshake(pendingId);
    if (existing != null) {
      if (existing.state == HandshakeState.dispatchingHello ||
          existing.state == HandshakeState.awaitingAck) {
        if (existing.state == HandshakeState.dispatchingHello) {
          await _ensureInviteeHelloPosted(existing);
        } else {
          await _retryUnconfirmedInviteeHello(existing);
        }
        startPolling();
        requestClosedAppPushRegistrationSync();
        return RedeemHandshakeResult(
          handshakeId: pendingId,
          localContactId: existing.contactStubId,
        );
      }
      if (existing.state != HandshakeState.failed) {
        throw HandshakeOrchestratorError('already_completed');
      }
    }

    // Local stub — replaced by the inviter's profile once we get the ack.
    await _contacts.upsertLocalOnly(
      id: stubContactId,
      displayName: selfDisplayName,
      avatarId: selfAvatarId,
      createdAt: created,
      updatedAt: created,
    );

    await _db.upsertPendingHandshake(
      PendingHandshakesCompanion.insert(
        id: pendingId,
        invitationIdHex: invitationIdHex,
        nonceHex: code.nonceHex(),
        role: HandshakeRole.invitee,
        state: HandshakeState.dispatchingHello,
        contactStubId: stubContactId,
        createdAt: created,
        updatedAt: created,
        expiresAt: created.add(_helloTtl),
      ),
    );

    final row = await _db.getPendingHandshake(pendingId);
    if (row == null) {
      throw HandshakeOrchestratorError('unknown');
    }
    try {
      await _ensureInviteeHelloPosted(row);
    } on HandshakeOrchestratorError {
      await _contacts.deleteLocally(stubContactId);
      await _db.deletePendingHandshake(pendingId);
      rethrow;
    }

    startPolling();
    requestClosedAppPushRegistrationSync();

    return RedeemHandshakeResult(
      handshakeId: pendingId,
      localContactId: stubContactId,
    );
  }

  /// Posts the invitee `hello` once the row is in [HandshakeState.dispatchingHello].
  /// Returns `true` when the relay HTTP call succeeded (or dispatch can be
  /// treated as confirmed — see [allowDecommissionedRouting]).
  Future<bool> _postInviteeHelloEnvelope(
    PendingHandshake row, {
    bool allowDecommissionedRouting = false,
  }) async {
    if (row.role != HandshakeRole.invitee) return false;

    final invitationIdBytes = _hexDecode(row.invitationIdHex);
    final nonceBytes = _hexDecode(row.nonceHex);
    final contact = await _contacts.get(row.contactStubId);
    if (contact == null) {
      throw HandshakeOrchestratorError('unknown');
    }

    final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final inviterHandshakePub = await RelayRouting.handshakePublicKey(
      inviterHandshakePriv,
    );
    final inviteePriv = await _identity.loadOrCreatePrivateKey();
    final inviteePub = await _identity.publicKey();
    final addrInviter = await RelayRouting.inviterHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final addrInvitee = await RelayRouting.inviteeHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final idempotencyKey = await RelayRouting.helloIdempotencyKey(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final deviceBindingId = await _deviceBinding.loadOrComputeId();

    final helloFrame = await EnvelopeCodec.encryptHello(
      envelope: HelloEnvelope(
        invitationId: invitationIdBytes,
        inviteeLongTermPublicKey: inviteePub,
        displayName: contact.displayName,
        avatarId: contact.avatarId,
        echoedNonce: nonceBytes,
        deviceBindingId: deviceBindingId,
      ),
      invitationNonce: nonceBytes,
      inviteeLongTermPrivateKey: inviteePriv,
      inviterHandshakePublicKey: inviterHandshakePub,
    );

    try {
      await _relay.postEnvelope(
        senderIdentity: addrInvitee,
        recipientIdentity: addrInviter,
        idempotencyKey: idempotencyKey,
        ciphertext: helloFrame,
        kind: EnvelopeKind.hello,
        ttl: _helloTtl,
      );
      debugPrint(
        'redeem hello posted invitation=${row.invitationIdHex} '
        'to=${RelayRouting.b64(addrInviter)}',
      );
      return true;
    } on RelayClientError catch (e) {
      if (e.isNoRouting && allowDecommissionedRouting) {
        debugPrint(
          'redeem hello post rejected (routing decommissioned) for ${row.id}; '
          'assuming hello was delivered',
        );
        return true;
      }
      throw HandshakeOrchestratorError(
        e.isNoRouting ? 'expired_code' : 'relay_error',
        e,
      );
    } on RelayUnreachableException catch (e) {
      debugPrint(
        'redeem hello relay unreachable for ${row.id} after '
        '${RelayHttpPolicy.maxAttempts} attempts: $e',
      );
      throw HandshakeOrchestratorError('relay_unavailable', e);
    } on TimeoutException catch (e) {
      debugPrint(
        'redeem hello post timed out for ${row.id}; '
        'will retry on next poll: $e',
      );
      return false;
    } on ClientException catch (e) {
      debugPrint(
        'redeem hello post failed for ${row.id}; '
        'will retry on next poll: $e',
      );
      return false;
    }
  }

  Future<void> _ensureInviteeHelloPosted(PendingHandshake row) async {
    if (row.state != HandshakeState.dispatchingHello) return;
    final posted = await _postInviteeHelloEnvelope(row);
    if (posted) {
      await _markHandshake(row.id, state: HandshakeState.awaitingAck);
    }
  }

  /// Poll-time hello retry after a prior HTTP timeout left the row in
  /// [HandshakeState.dispatchingHello].
  Future<void> _retryInviteeHelloDispatch(PendingHandshake row) async {
    if (row.state != HandshakeState.dispatchingHello) return;
    final posted = await _postInviteeHelloEnvelope(
      row,
      allowDecommissionedRouting: true,
    );
    if (posted) {
      await _markHandshake(row.id, state: HandshakeState.awaitingAck);
    }
  }

  /// Idempotent hello re-post for legacy rows already in [HandshakeState.awaitingAck]
  /// after a prior HTTP timeout before dispatch was confirmed.
  Future<void> _retryUnconfirmedInviteeHello(PendingHandshake row) async {
    if (row.state != HandshakeState.awaitingAck) return;
    await _postInviteeHelloEnvelope(row);
  }

  // ---------------------------------------------------------------------
  // Polling loop
  // ---------------------------------------------------------------------

  /// Returns the current state of the pending handshake row with the given
  /// id, or `null` if the row has been removed (e.g. cleaned up after
  /// completion in a future revision). The returned value is one of the
  /// [HandshakeState] constants. Used by the invitee side to observe the
  /// outcome of an in-flight redeem so the UI can react when the ack
  /// lands (completed) or the inviter rejects (rejected).
  Future<String?> pendingHandshakeState(String handshakeId) async {
    final row = await _db.getPendingHandshake(handshakeId);
    return row?.state;
  }

  /// Returns the `lastErrorCode` recorded on the pending handshake row, or
  /// `null` if no error was stored. Used together with [pendingHandshakeState]
  /// to surface specific failure reasons to the UI.
  Future<String?> pendingHandshakeErrorCode(String handshakeId) async {
    final row = await _db.getPendingHandshake(handshakeId);
    return row?.lastErrorCode;
  }

  /// Fetches each non-terminal handshake's inbox and processes any
  /// envelope it finds. Safe to call from a Timer or manually from a
  /// pull-to-refresh action.
  Future<void> processAllPendingHandshakes() async {
    final rows = await activePendingHandshakeRows();
    if (rows.isEmpty) {
      await refreshIncomingHandshakes();
      if (!await _hasSteadyInboxPollTargets()) {
        stopPolling();
      }
      return;
    }
    for (final row in rows) {
      try {
        await _processOne(row);
      } catch (e, st) {
        debugPrint('handshake row ${row.id} poll error: $e\n$st');
        final code = e is HandshakeOrchestratorError ? e.code : 'unknown';
        await _markHandshake(
          row.id,
          state: code == 'relay_unavailable' ? HandshakeState.failed : null,
          lastErrorCode: code,
        );
      }
    }
    await refreshIncomingHandshakes();
  }

  Future<List<PendingHandshake>> activePendingHandshakeRows() async {
    final rows = await _db.listPendingHandshakes();
    return rows.where(_shouldPollHandshakeRow).toList(growable: false);
  }

  Future<List<PendingHandshake>> allPendingHandshakeRowsForDiagnostics() {
    return _db.listPendingHandshakes();
  }

  bool _shouldPollHandshakeRow(PendingHandshake row) {
    if (row.state == HandshakeState.awaitingHello ||
        row.state == HandshakeState.dispatchingHello ||
        row.state == HandshakeState.awaitingAck) {
      return true;
    }
    if (row.state == HandshakeState.helloReceived &&
        row.role == HandshakeRole.inviter &&
        autoAcceptIncomingHandshakes) {
      return true;
    }
    if (row.state != HandshakeState.failed) return false;
    final code = row.lastErrorCode;
    return code.isEmpty ||
        code == 'unknown' ||
        code == 'relay_error' ||
        code == 'relay_unavailable';
  }

  /// Contacts with a stored peer long-term public key, deduped by that key.
  /// Includes `connected` rows and demoted / handshake rows so a reinstall on
  /// the peer device does not hide the inbox when an older row is still stored.
  ///
  /// Also includes plan-mediated establishment watch-list peers who are not yet
  /// connected contacts locally.
  Future<
    List<
      ({
        Contact? contact,
        Uint8List peerPub,
        PlanPeerEstablishment? establishment,
      })
    >
  >
  _steadyInboxPollPeers() async {
    final all = await _contacts.list();
    final seenPeer = <String>{};
    final out =
        <
          ({
            Contact? contact,
            Uint8List peerPub,
            PlanPeerEstablishment? establishment,
          })
        >[];
    for (final c in all) {
      if (c.id.startsWith('contact:local:')) continue;
      final peerB64 = c.peerPublicMaterial;
      if (peerB64 == null || peerB64.isEmpty) continue;
      if (!seenPeer.add(peerB64)) continue;
      try {
        out.add((
          contact: c,
          peerPub: RelayRouting.unb64(peerB64),
          establishment: null,
        ));
      } catch (_) {
        // ignore invalid peer material
      }
    }

    for (final row in await _db.listAllPlanPeerEstablishments()) {
      if (seenPeer.contains(row.peerPublicMaterialB64)) continue;
      final connected = await _contactForPeerPublicKey(
        RelayRouting.unb64(row.peerPublicMaterialB64),
      );
      if (connected != null && connected.kind == 'connected') continue;
      try {
        final peerPub = RelayRouting.unb64(row.peerPublicMaterialB64);
        if (!seenPeer.add(row.peerPublicMaterialB64)) continue;
        out.add((contact: connected, peerPub: peerPub, establishment: row));
      } catch (_) {
        // ignore invalid peer material
      }
    }
    return out;
  }

  Future<bool> _hasSteadyInboxPollTargets() async {
    return (await _steadyInboxPollPeers()).isNotEmpty;
  }

  Future<Contact?> _contactForPeerPublicKey(Uint8List peerPub) async {
    for (final c in await _contacts.list()) {
      final b64 = c.peerPublicMaterial;
      if (b64 == null || b64.isEmpty) continue;
      try {
        if (_bytesEqual(RelayRouting.unb64(b64), peerPub)) return c;
      } catch (_) {
        // ignore
      }
    }
    return null;
  }

  /// Polls the relay steady-state inbox once per known peer public key for
  /// inbound steady envelopes (profile, disconnect, housing proposal, …).
  ///
  /// Concurrent callers (hub, PeerSimulator, periodic poll) are serialized so
  /// the same envelope cannot be applied twice before ack.
  ///
  /// UIs should listen to [steadyStateInboxTick] and refresh contact rows.
  /// Scheduled housing payment reminders are polled via
  /// [pollHousingPaymentReminders] (wake / foreground resume), not here.
  Future<void> pollSteadyStateInboxes() async {
    if (_steadyInboxPolling) {
      _steadyInboxPollNeededAgain = true;
      final wait = _steadyInboxPollCompleter?.future;
      if (wait != null) {
        await wait;
      }
      return;
    }
    _steadyInboxPollCompleter = Completer<void>();
    _steadyInboxPolling = true;
    try {
      do {
        _steadyInboxPollNeededAgain = false;
        try {
          await _pollSteadyStateInboxesBody();
        } catch (e, st) {
          debugPrint('pollSteadyStateInboxes failed: $e\n$st');
        }
      } while (_steadyInboxPollNeededAgain);
    } finally {
      _steadyInboxPolling = false;
      final completer = _steadyInboxPollCompleter;
      _steadyInboxPollCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Fetches relay-fired housing payment reminders and shows local notifications.
  Future<void> pollHousingPaymentReminders() async {
    await _pollHousingPaymentReminders();
  }

  Future<void> _pollSteadyStateInboxesBody() async {
    final targets = await _steadyInboxPollPeers();
    if (targets.isEmpty) {
      final total = (await _contacts.list()).length;
      RelayDiagnostics.logSteadyInbox(
        'steady inbox poll skipped: no peer keys ($total contact row(s))',
      );
      return;
    }
    RelayDiagnostics.logSteadyInbox(
      'steady inbox poll: ${targets.length} peer key(s)',
    );

    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();

    for (final target in targets) {
      final contact = target.contact;
      final peerPub = target.peerPub;
      final pollLabel = contact?.id ?? target.establishment?.id ?? 'peer';

      final Uint8List myListen = await RelayRouting.steadyStateAddress(
        firstPub: selfPub,
        secondPub: peerPub,
      );
      final List<RelayEnvelopeView> envs;
      try {
        envs = await _relay.fetchInbox(recipient: myListen);
      } on RelayClientError catch (e) {
        RelayDiagnostics.logSteadyInbox(
          'steady inbox fetch failed for $pollLabel: $e',
        );
        continue;
      } on RelayUnreachableException catch (e) {
        RelayDiagnostics.logSteadyInbox(
          'steady inbox fetch timed out for $pollLabel: $e',
        );
        continue;
      } on TimeoutException catch (e) {
        RelayDiagnostics.logSteadyInbox(
          'steady inbox fetch timed out for $pollLabel: $e',
        );
        continue;
      }
      if (envs.isNotEmpty) {
        RelayDiagnostics.logSteadyInbox(
          'steady inbox fetched ${envs.length} envelope(s) for $pollLabel',
        );
        if (kDebugMode) {
          final kinds = <int, int>{};
          for (final e in envs) {
            kinds[e.kind] = (kinds[e.kind] ?? 0) + 1;
          }
          debugPrint(
            'steady inbox kinds for $pollLabel: $kinds',
          );
        }
      }
      for (final env in envs) {
        try {
          if (env.kind == EnvelopeKind.contactEstablishmentRequest) {
            await _handleInboundContactEstablishmentRequest(
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
              establishment: target.establishment,
            );
          } else if (env.kind == EnvelopeKind.contactEstablishmentResponse) {
            await _handleInboundContactEstablishmentResponse(
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
              establishment: target.establishment,
            );
          } else if (contact == null) {
            await _relay.ackEnvelope(
              envelopeId: env.envelopeId,
              recipient: myListen,
            );
          } else if (env.kind == EnvelopeKind.disconnect) {
            await _handleInboundDisconnect(
              contact: contact,
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
            );
          } else if (env.kind == EnvelopeKind.profileUpdate) {
            await _handleInboundProfileUpdate(
              contact: contact,
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
            );
          } else if (env.kind == EnvelopeKind.housingProposal) {
            await _handleInboundHousingProposal(
              contact: contact,
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
            );
          } else if (env.kind == EnvelopeKind.housingProposalResponse) {
            await _handleInboundHousingProposalResponse(
              contact: contact,
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
            );
          } else if (env.kind == EnvelopeKind.housingRealizedExpensePropose) {
            await _handleInboundHousingRealizedExpensePropose(
              contact: contact,
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
            );
          } else if (env.kind == EnvelopeKind.housingRealizedExpenseAccept ||
              env.kind == EnvelopeKind.housingRealizedExpenseReject) {
            await _handleInboundHousingRealizedExpenseDecision(
              contact: contact,
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
              kind: env.kind,
            );
          } else if (env.kind == EnvelopeKind.housingParticipationChangePropose) {
            await _handleInboundHousingParticipationChangePropose(
              contact: contact,
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
            );
          } else if (env.kind == EnvelopeKind.housingParticipationChangeDecision) {
            await _handleInboundHousingParticipationChangeDecision(
              contact: contact,
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
            );
          } else if (env.kind == EnvelopeKind.housingParticipationChangeNotify) {
            await _handleInboundHousingParticipationChangeNotify(
              contact: contact,
              envelope: env,
              myListenAddr: myListen,
              selfPriv: selfPriv,
              peerPub: peerPub,
            );
          } else {
            await _relay.ackEnvelope(
              envelopeId: env.envelopeId,
              recipient: myListen,
            );
          }
        } catch (e, st) {
          debugPrint('steady inbox env ${env.envelopeId} failed: $e\n$st');
          if (!_isTransientRelayFailure(e)) {
            try {
              await _relay.ackEnvelope(
                envelopeId: env.envelopeId,
                recipient: myListen,
              );
            } catch (_) {
              // ignore
            }
          }
        }
      }
    }
  }

  bool _isTransientRelayFailure(Object e) => isRelayTransportFailure(e);

  /// Ensures the relay has an active steady-state row for [selfListenAddr] and
  /// [peerListenAddr]. Idempotent (re-register after relay wipe or reinstall).
  Future<void> _ensureSteadyRoutingRegistered({
    required Uint8List selfListenAddr,
    required Uint8List peerListenAddr,
  }) async {
    await _relay.establishRouting(
      selfIdentity: selfListenAddr,
      peerIdentity: peerListenAddr,
    );
  }

  /// This device's long-term X25519 public key bytes.
  Future<Uint8List> selfLongTermPublicKey() => _identity.publicKey();

  /// Recipient routing ids whose inboxes this device polls: steady-state
  /// addresses for each connected contact plus handshake listen addresses
  /// for pending handshakes that still need relay polling.
  Future<List<Uint8List>> routingWakeRecipientIdentities() async {
    final out = <Uint8List>[];
    void addUnique(Uint8List id) {
      for (final e in out) {
        if (_bytesEqual(e, id)) return;
      }
      out.add(id);
    }

    final rows = await _db.listPendingHandshakes();
    for (final row in rows) {
      if (!_shouldPollHandshakeRow(row)) continue;
      final invitationIdBytes = _hexDecode(row.invitationIdHex);
      final nonceBytes = _hexDecode(row.nonceHex);
      final addrInviter = await RelayRouting.inviterHandshakeAddress(
        invitationId: invitationIdBytes,
        nonce: nonceBytes,
      );
      final addrInvitee = await RelayRouting.inviteeHandshakeAddress(
        invitationId: invitationIdBytes,
        nonce: nonceBytes,
      );
      final listenAddr = row.role == HandshakeRole.inviter
          ? addrInviter
          : addrInvitee;
      addUnique(listenAddr);
    }

    final selfPub = await _identity.publicKey();
    final contacts = await _contacts.list();
    for (final contact in contacts) {
      if (contact.kind != 'connected') continue;
      final peerB64 = contact.peerPublicMaterial;
      if (peerB64 == null || peerB64.isEmpty) continue;
      final Uint8List peerPub;
      try {
        peerPub = RelayRouting.unb64(peerB64);
      } catch (_) {
        continue;
      }
      final myListen = await RelayRouting.steadyStateAddress(
        firstPub: selfPub,
        secondPub: peerPub,
      );
      addUnique(myListen);
    }

    for (final row in await _db.listAllPlanPeerEstablishments()) {
      Contact? connectedContact;
      try {
        connectedContact = await _contactForPeerPublicKey(
          RelayRouting.unb64(row.peerPublicMaterialB64),
        );
      } catch (_) {
        continue;
      }
      if (connectedContact != null && connectedContact.kind == 'connected') {
        continue;
      }
      try {
        final peerPub = RelayRouting.unb64(row.peerPublicMaterialB64);
        final myListen = await RelayRouting.steadyStateAddress(
          firstPub: selfPub,
          secondPub: peerPub,
        );
        addUnique(myListen);
      } catch (_) {
        // ignore invalid peer material
      }
    }

    return out;
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _maybeRelayDisconnectSteady(
    Uint8List selfSteady,
    Uint8List peerSteady,
  ) async {
    try {
      await _relay.disconnectRouting(
        selfIdentity: selfSteady,
        peerIdentity: peerSteady,
      );
    } on RelayClientError catch (e) {
      debugPrint('steady disconnectRouting failed: $e');
    } on RelayUnreachableException catch (e) {
      debugPrint('steady disconnectRouting timed out: $e');
    } on TimeoutException catch (e) {
      debugPrint('steady disconnectRouting timed out: $e');
    }
  }

  Future<void> _handleInboundDisconnect({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
  }) async {
    final DisconnectEnvelope decrypted;
    try {
      decrypted = await EnvelopeCodec.decryptDisconnect(
        frame: envelope.ciphertext,
        receiverLongTermPrivateKey: selfPriv,
      );
    } on EnvelopeDecryptionError {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }

    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );

    final routingB64 = contact.relayRoutingId;
    await _contacts.demoteToLocalOnly(contact.id);
    if (routingB64 != null && routingB64.isNotEmpty) {
      await _maybeRelayDisconnectSteady(
        myListenAddr,
        RelayRouting.unb64(routingB64),
      );
    }
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    await RelayActivityLogService(_db).append(
      kind: RelayActivityLogKinds.contactDisconnected,
      initiatorKind: RelayActivityLogService.initiatorContact,
      initiatorContactId: contact.id,
      initiatorDisplayName: contact.displayName,
    );
    await _contactNotifications.contactDisconnected(
      displayName: contact.displayName,
    );
    requestClosedAppPushRegistrationSync();
  }

  Future<void> _handleInboundProfileUpdate({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
  }) async {
    final ProfileUpdateEnvelope decrypted;
    try {
      decrypted = await EnvelopeCodec.decryptProfileUpdate(
        frame: envelope.ciphertext,
        receiverLongTermPrivateKey: selfPriv,
      );
    } on EnvelopeDecryptionError {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }

    if (decrypted.hasHowILabelYou) {
      final raw = decrypted.howILabelYou.trim();
      await _contacts.setTheirLabelForMe(contact.id, raw.isEmpty ? null : raw);
    }

    final dn = decrypted.displayName.trim();
    final av = decrypted.avatarId.trim();
    if (dn.isNotEmpty || av.isNotEmpty) {
      final newDn = dn.isNotEmpty ? dn : contact.displayName;
      final newAv = av.isNotEmpty ? av : contact.avatarId;
      final label = contact.localDisplayLabel?.trim();
      if (label != null && label.isNotEmpty) {
        if (label == newDn.trim()) {
          await _contacts.clearLocalDisplayLabel(contact.id);
        }
      }
      await _contacts.rename(
        id: contact.id,
        displayName: newDn,
        avatarId: newAv,
      );
      await syncParticipantRowsForContactProfile(
        db: _db,
        contactId: contact.id,
        displayName: newDn,
        avatarId: newAv,
      );
      if (label != null && label.isNotEmpty && label != newDn.trim()) {
        profileLabelConflict.value = ProfileLabelConflict(
          contactId: contact.id,
          newCanonicalDisplayName: newDn,
          localDisplayLabel: label,
        );
      }
    }

    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
  }

  Future<void> _handleInboundHousingProposal({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
  }) async {
    final HousingProposalEnvelope decrypted;
    try {
      decrypted = await EnvelopeCodec.decryptHousingProposal(
        frame: envelope.ciphertext,
        receiverLongTermPrivateKey: selfPriv,
      );
    } on EnvelopeDecryptionError catch (e, st) {
      debugPrint(
        'housing_proposal decrypt failed for ${contact.id} '
        '(envelope ${envelope.envelopeId}): $e\n$st',
      );
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    var senderContact = contact;
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      final matched = await _contactForPeerPublicKey(
        decrypted.senderLongTermPublicKey,
      );
      if (matched == null) {
        debugPrint(
          'housing_proposal sender pubkey mismatch for ${contact.id} '
          '(envelope ${envelope.envelopeId})',
        );
        await _relay.ackEnvelope(
          envelopeId: envelope.envelopeId,
          recipient: myListenAddr,
        );
        return;
      }
      debugPrint(
        'housing_proposal sender matched contact ${matched.id} '
        '(polled via ${contact.id})',
      );
      senderContact = matched;
    }

    final imported = await HousingProposalTransportService(_db)
        .importReceivedProposal(
          proposalJson: decrypted.proposalJson,
          targetParticipantId: decrypted.targetParticipantId,
          senderContactId: senderContact.id,
          senderDisplayName: senderContact.displayName,
          senderAvatarId: senderContact.avatarId,
        );
    debugPrint(
      'housing_proposal imported from ${senderContact.id} '
      'plan=${imported.planId} amendment=${imported.isInForceAmendment}',
    );
    await RelayActivityLogService(_db).append(
      kind: RelayActivityLogKinds.housingProposalReceived,
      initiatorKind: RelayActivityLogService.initiatorContact,
      initiatorContactId: senderContact.id,
      initiatorDisplayName: senderContact.displayName,
      planId: imported.planId,
      revisionId: imported.revisionId,
    );
    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    if (_ownsDeviceHousingNotifications) {
      await PushNotificationService.showLocalHousingProposalNotification(
        senderDisplayName: senderContact.displayName,
        planId: imported.planId,
        isInForceAmendment: imported.isInForceAmendment,
      );
    }
    startPolling();
    requestClosedAppPushRegistrationSync();
  }

  Future<void> _handleInboundHousingProposalResponse({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
  }) async {
    final HousingProposalResponseEnvelope decrypted;
    try {
      decrypted = await EnvelopeCodec.decryptHousingProposalResponse(
        frame: envelope.ciphertext,
        receiverLongTermPrivateKey: selfPriv,
      );
    } on EnvelopeDecryptionError {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }

    await _applyHousingProposalResponse(
      decrypted,
      senderDisplayName: contact.displayName,
    );
    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
  }

  Future<void> _handleInboundHousingRealizedExpensePropose({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
  }) async {
    final HousingRealizedExpenseEnvelope decrypted;
    try {
      decrypted = await EnvelopeCodec.decryptHousingRealizedExpensePropose(
        frame: envelope.ciphertext,
        receiverLongTermPrivateKey: selfPriv,
      );
    } on EnvelopeDecryptionError catch (e, st) {
      debugPrint(
        'housing_realized_expense decrypt failed for ${contact.id}: $e\n$st',
      );
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    var senderContact = contact;
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      final matched = await _contactForPeerPublicKey(
        decrypted.senderLongTermPublicKey,
      );
      if (matched == null) {
        await _relay.ackEnvelope(
          envelopeId: envelope.envelopeId,
          recipient: myListenAddr,
        );
        return;
      }
      senderContact = matched;
    }

    final imported = await RealizedExpenseSyncService(_db)
        .importProposedFromPeer(
          expenseJson: decrypted.expenseJson,
          senderContactId: senderContact.id,
        );
    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );
    if (!imported) return;

    final expenseId = _expenseIdFromProposeJson(decrypted.expenseJson);
    if (expenseId != null) {
      final expense = await RealizedExpenseRepository(_db).getById(expenseId);
      if (expense != null) {
        final ledger = RealizedExpenseLedgerService(_db);
        await ledger.markPlanActiveUseIfNeeded(expense.planId);
        final selfId = ledger.selfIdForPlan(expense.planId);
        final visibility = await ledger.visibilityFor(
          expense: expense,
          selfParticipantId: selfId,
        );
        final summary = await ledger.pendingSummary(
          packageId: expense.packageId,
          planId: expense.planId,
        );
        final acceptances = await RealizedExpenseRepository(_db).acceptancesFor(
          expenseId,
        );
        final shouldNotify = await ledger.shouldNotifyImportedProposal(
          expense: expense,
          selfParticipantId: selfId,
        );
        debugPrint(
          'housing_realized_expense qa: import post expense=$expenseId '
          'self=$selfId localPayer=${expense.payerParticipantId} '
          'localBeneficiary=${expense.beneficiaryParticipantId} '
          'acceptances=${acceptances.length} '
          'rows=${acceptances.isEmpty ? "(none)" : acceptances.map((a) => "${a.participantId}:${a.decision}").join(",")} '
          'visibility=$visibility shouldNotify=$shouldNotify '
          'pendingYou=${summary.waitingForYouCount} '
          'pendingOthers=${summary.waitingForOthersCount}',
        );
        if (shouldNotify && _ownsDeviceHousingNotifications) {
          await PushNotificationService.showLocalHousingRealizedExpenseNotification(
            senderDisplayName: senderContact.displayName,
            expenseId: expenseId,
          );
        }
      }
    }

    RelayDiagnostics.logHousingRealizedExpense(
      'imported from ${senderContact.id}',
    );
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
  }

  String? _expenseIdFromProposeJson(String expenseJson) {
    try {
      final map = jsonDecode(expenseJson) as Map<String, dynamic>;
      final id = map['expense_id'] as String?;
      if (id == null || id.isEmpty) return null;
      return id;
    } on Object {
      return null;
    }
  }

  Future<void> _handleInboundHousingRealizedExpenseDecision({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
    required int kind,
  }) async {
    final HousingRealizedExpenseDecisionEnvelope decrypted;
    try {
      decrypted = await EnvelopeCodec.decryptHousingRealizedExpenseDecision(
        kind: kind,
        frame: envelope.ciphertext,
        receiverLongTermPrivateKey: selfPriv,
      );
    } on EnvelopeDecryptionError catch (e, st) {
      debugPrint(
        'housing_realized_expense decision decrypt failed for ${contact.id}: '
        '$e\n$st',
      );
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    var senderContact = contact;
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      final matched = await _contactForPeerPublicKey(
        decrypted.senderLongTermPublicKey,
      );
      if (matched == null) {
        await _relay.ackEnvelope(
          envelopeId: envelope.envelopeId,
          recipient: myListenAddr,
        );
        return;
      }
      senderContact = matched;
    }

    final applied = await RealizedExpenseSyncService(_db)
        .importDecisionFromPeer(
          decisionJson: decrypted.decisionJson,
          senderContactId: senderContact.id,
        );
    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );
    if (!applied) return;

    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    final expenseId = _expenseIdFromDecisionJson(decrypted.decisionJson);
    if (expenseId == null) return;
    final expense = await RealizedExpenseRepository(_db).getById(expenseId);
    if (expense == null) return;
    final ledger = RealizedExpenseLedgerService(_db);
    final selfParticipantId = ledger.selfIdForPlan(expense.planId);
    if (kind == EnvelopeKind.housingRealizedExpenseReject) {
      final shouldNotify = await ledger.shouldNotifyRejectedDecision(
        expense: expense,
        selfParticipantId: selfParticipantId,
      );
      if (shouldNotify && _ownsDeviceHousingNotifications) {
        await PushNotificationService.showLocalHousingRealizedExpenseRejectedNotification(
          senderDisplayName: senderContact.displayName,
          expenseId: expenseId,
        );
      }
      return;
    }
    if (kind == EnvelopeKind.housingRealizedExpenseAccept) {
      final shouldNotify = await ledger.shouldNotifyAcceptedDecision(
        expense: expense,
        selfParticipantId: selfParticipantId,
      );
      if (shouldNotify && _ownsDeviceHousingNotifications) {
        final localUserIsPayer =
            expense.payerParticipantId == selfParticipantId;
        String? payerDisplayName;
        if (!localUserIsPayer) {
          final roster = await participantsForPlan(_db, expense.planId);
          payerDisplayName = displayNameForParticipant(
            expense.payerParticipantId,
            roster,
          );
        }
        await PushNotificationService.showLocalHousingRealizedExpenseAcceptedNotification(
          senderDisplayName: senderContact.displayName,
          expenseId: expenseId,
          expenseKind: expense.kind,
          localUserIsPayer: localUserIsPayer,
          payerDisplayName: payerDisplayName,
        );
      }
    }
  }

  Future<void> _handleInboundHousingParticipationChangePropose({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
  }) async {
    await _handleInboundParticipationChangePayload(
      contact: contact,
      envelope: envelope,
      myListenAddr: myListenAddr,
      selfPriv: selfPriv,
      peerPub: peerPub,
      decrypt:
          (frame) => EnvelopeCodec.decryptHousingParticipationChangePropose(
            frame: frame,
            receiverLongTermPrivateKey: selfPriv,
          ),
      import:
          (json) => HousingParticipationChangeSyncService(
            _db,
          ).importProposeFromPeer(
            changeJson: json,
            senderContactId: contact.id,
          ),
    );
  }

  Future<void> _handleInboundHousingParticipationChangeNotify({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
  }) async {
    await _handleInboundParticipationChangePayload(
      contact: contact,
      envelope: envelope,
      myListenAddr: myListenAddr,
      selfPriv: selfPriv,
      peerPub: peerPub,
      decrypt:
          (frame) => EnvelopeCodec.decryptHousingParticipationChangeNotify(
            frame: frame,
            receiverLongTermPrivateKey: selfPriv,
          ),
      import:
          (json) => HousingParticipationChangeSyncService(
            _db,
          ).importNotifyFromPeer(
            notifyJson: json,
            senderContactId: contact.id,
          ),
    );
  }

  Future<void> _handleInboundParticipationChangePayload({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
    required Future<HousingParticipationChangeEnvelope> Function(Uint8List frame)
    decrypt,
    required Future<bool> Function(String json) import,
  }) async {
    final HousingParticipationChangeEnvelope decrypted;
    try {
      decrypted = await decrypt(envelope.ciphertext);
    } on EnvelopeDecryptionError catch (e, st) {
      debugPrint(
        'housing_participation_change decrypt failed for ${contact.id}: '
        '$e\n$st',
      );
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    var senderContact = contact;
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      final matched = await _contactForPeerPublicKey(
        decrypted.senderLongTermPublicKey,
      );
      if (matched == null) {
        await _relay.ackEnvelope(
          envelopeId: envelope.envelopeId,
          recipient: myListenAddr,
        );
        return;
      }
      senderContact = matched;
    }

    final imported = await import(decrypted.changeJson);
    if (!imported) {
      debugPrint(
        'housing_participation_change import skipped for ${senderContact.id}; '
        'envelope left unacked for retry',
      );
      return;
    }
    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );

    final changeId = _changeIdFromJson(decrypted.changeJson);
    if (changeId != null) {
      final planId = _planIdFromChangeJson(decrypted.changeJson);
      final changeKind = _participationChangeKindFromJson(decrypted.changeJson);
      final shouldNotify = await _shouldNotifySelfForParticipationChange(
        planId: planId,
        kind: changeKind,
      );
      if (shouldNotify && _ownsDeviceHousingNotifications) {
        await PushNotificationService
            .showLocalHousingParticipationChangeNotification(
          senderDisplayName: senderContact.displayName,
          changeId: changeId,
          planId: planId,
        );
      }
    }
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
  }

  Future<void> _handleInboundHousingParticipationChangeDecision({
    required Contact contact,
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
  }) async {
    final HousingParticipationChangeDecisionEnvelope decrypted;
    try {
      decrypted = await EnvelopeCodec.decryptHousingParticipationChangeDecision(
        frame: envelope.ciphertext,
        receiverLongTermPrivateKey: selfPriv,
      );
    } on EnvelopeDecryptionError catch (e, st) {
      debugPrint(
        'housing_participation_change decision decrypt failed for '
        '${contact.id}: $e\n$st',
      );
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    var senderContact = contact;
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      final matched = await _contactForPeerPublicKey(
        decrypted.senderLongTermPublicKey,
      );
      if (matched == null) {
        await _relay.ackEnvelope(
          envelopeId: envelope.envelopeId,
          recipient: myListenAddr,
        );
        return;
      }
      senderContact = matched;
    }

    final applied = await HousingParticipationChangeSyncService(_db)
        .importDecisionFromPeer(
          decisionJson: decrypted.decisionJson,
          senderContactId: senderContact.id,
        );
    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );
    if (!applied) return;
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
  }

  String? _changeIdFromJson(String changeJson) {
    try {
      final map = jsonDecode(changeJson) as Map<String, dynamic>;
      final id = map['change_id'] as String?;
      if (id == null || id.isEmpty) return null;
      return id;
    } on Object {
      return null;
    }
  }

  String? _planIdFromChangeJson(String changeJson) {
    try {
      final map = jsonDecode(changeJson) as Map<String, dynamic>;
      final id = map['plan_id'] as String?;
      if (id == null || id.isEmpty) return null;
      return id;
    } on Object {
      return null;
    }
  }

  HousingParticipationChangeKind? _participationChangeKindFromJson(
    String changeJson,
  ) {
    try {
      final map = jsonDecode(changeJson) as Map<String, dynamic>;
      return HousingParticipationChangeKind.fromWire(map['kind'] as String?);
    } on Object {
      return null;
    }
  }

  Future<bool> _shouldNotifySelfForParticipationChange({
    required String? planId,
    required HousingParticipationChangeKind? kind,
  }) async {
    return true;
  }

  String? _expenseIdFromDecisionJson(String decisionJson) {
    try {
      final map = jsonDecode(decisionJson) as Map<String, dynamic>;
      final id = map['expense_id'] as String?;
      if (id == null || id.isEmpty) return null;
      return id;
    } on Object {
      return null;
    }
  }

  Future<void> _processOne(PendingHandshake initialRow) async {
    var row = initialRow;
    if (row.expiresAt.isBefore(_now().toUtc())) {
      await _markHandshake(
        row.id,
        state: HandshakeState.failed,
        lastErrorCode: 'expired',
      );
      return;
    }
    if (row.role == HandshakeRole.inviter &&
        row.state == HandshakeState.helloReceived &&
        autoAcceptIncomingHandshakes) {
      await _autoAcceptInviterHello(row);
      return;
    }
    if (row.role == HandshakeRole.invitee &&
        row.state == HandshakeState.dispatchingHello) {
      await _retryInviteeHelloDispatch(row);
      final refreshed = await _db.getPendingHandshake(row.id);
      if (refreshed == null ||
          refreshed.state != HandshakeState.awaitingAck) {
        return;
      }
      row = refreshed;
    }
    final invitationIdBytes = _hexDecode(row.invitationIdHex);
    final nonceBytes = _hexDecode(row.nonceHex);
    final addrInviter = await RelayRouting.inviterHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final addrInvitee = await RelayRouting.inviteeHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );

    final listenAddr = row.role == HandshakeRole.inviter
        ? addrInviter
        : addrInvitee;
    final List<RelayEnvelopeView> envs;
    try {
      debugPrint(
        'handshake poll fetch inbox for ${row.id} '
        'recipient=${RelayRouting.b64(listenAddr)}',
      );
      envs = await _relay.fetchInbox(recipient: listenAddr);
    } on RelayClientError catch (e) {
      // Network issue / 5xx: leave the row alone and try again on the
      // next tick.
      debugPrint('Handshake poll fetch failed for ${row.id}: $e');
      return;
    } on RelayUnreachableException catch (e) {
      debugPrint('Handshake poll fetch timed out for ${row.id}: $e');
      return;
    } on TimeoutException catch (e) {
      debugPrint('Handshake poll fetch timed out for ${row.id}: $e');
      return;
    }
    if (envs.isNotEmpty) {
      debugPrint(
        'Handshake poll fetched ${envs.length} envelope(s) for ${row.id}',
      );
    }
    if (envs.isEmpty) return;

    for (final env in envs) {
      try {
        if (row.role == HandshakeRole.inviter &&
            env.kind == EnvelopeKind.hello) {
          await _handleHelloAsInviter(
            row: row,
            envelope: env,
            invitationIdBytes: invitationIdBytes,
            nonceBytes: nonceBytes,
            listenAddr: addrInviter,
          );
        } else if (row.role == HandshakeRole.invitee &&
            env.kind == EnvelopeKind.ack) {
          await _handleAckAsInvitee(
            row: row,
            envelope: env,
            invitationIdBytes: invitationIdBytes,
            nonceBytes: nonceBytes,
            listenAddr: addrInvitee,
            addrInviter: addrInviter,
            addrInvitee: addrInvitee,
          );
        } else {
          // Unexpected kind — ack on relay so we don't loop forever.
          await _relay.ackEnvelope(
            envelopeId: env.envelopeId,
            recipient: listenAddr,
          );
        }
      } catch (e, st) {
        debugPrint('envelope ${env.envelopeId} failed: $e\n$st');
        if (!_isTransientRelayFailure(e)) {
          try {
            await _relay.ackEnvelope(
              envelopeId: env.envelopeId,
              recipient: listenAddr,
            );
          } catch (_) {
            // ignore secondary ack failures
          }
        }
      }
    }
  }

  Future<void> _handleHelloAsInviter({
    required PendingHandshake row,
    required RelayEnvelopeView envelope,
    required Uint8List invitationIdBytes,
    required Uint8List nonceBytes,
    required Uint8List listenAddr,
  }) async {
    // Validate that the local invitation row is still pending. Once a
    // hello has been validated (whether the inviter accepted or
    // rejected), the nonce is consumed: subsequent hellos referencing
    // the same invitation are dropped here.
    final invitationRow = await (_db.select(
      _db.contactInvitations,
    )..where((t) => t.id.equals(row.invitationIdHex))).getSingleOrNull();
    if (invitationRow == null ||
        invitationRow.status != InvitationStatus.pending) {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: listenAddr,
      );
      return;
    }

    final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final HelloEnvelope hello;
    try {
      hello = await EnvelopeCodec.decryptHello(
        frame: envelope.ciphertext,
        invitationNonce: nonceBytes,
        inviterHandshakePrivateKey: inviterHandshakePriv,
      );
    } on EnvelopeDecryptionError {
      // Bad envelope: ACK to discard it, stay awaiting.
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: listenAddr,
      );
      return;
    }

    // Nonce consumed; further hellos are ignored.
    await _invitations.markUsed(row.invitationIdHex, now: _now().toUtc());
    unawaited(_cancelInvitationExpiryReminders(row.invitationIdHex));

    // Stash the peer identity + profile on the pending row.
    await _markHandshake(
      row.id,
      state: HandshakeState.helloReceived,
      peerLongTermPublicMaterialB64: RelayRouting.b64(
        hello.inviteeLongTermPublicKey,
      ),
      peerDisplayName: hello.displayName,
      peerAvatarId: hello.avatarId,
      peerDeviceBindingId: hello.deviceBindingId,
    );

    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: listenAddr,
    );

    final updatedRow = await _db.getPendingHandshake(row.id);
    if (updatedRow == null) return;

    if (autoAcceptIncomingHandshakes) {
      await _autoAcceptInviterHello(updatedRow);
    } else {
      await RelayActivityLogService(_db).append(
        kind: RelayActivityLogKinds.contactHandshakeReceived,
        initiatorKind: RelayActivityLogService.initiatorContact,
        initiatorContactId: updatedRow.contactStubId,
        initiatorDisplayName: hello.displayName,
        details: {'handshakeId': updatedRow.id},
      );
      await _contactNotifications.contactAddRequestReceived(
        displayName: hello.displayName,
      );
    }
  }

  Future<void> _autoAcceptInviterHello(PendingHandshake row) async {
    if (row.role != HandshakeRole.inviter ||
        row.state != HandshakeState.helloReceived) {
      return;
    }
    final peerPubB64 = row.peerLongTermPublicMaterialB64;
    if (peerPubB64 == null) return;

    final profile = ackProfileForAutoAccept != null
        ? await ackProfileForAutoAccept!()
        : await _loadSelfProfileForAck();

    try {
      final result = await _finalizeInviterAccept(
        handshakeRow: row,
        peerPubBytes: RelayRouting.unb64(peerPubB64),
        peerDisplayName: row.peerDisplayName,
        peerAvatarId: row.peerAvatarId,
        peerDeviceBindingId: row.peerDeviceBindingId,
        selfDisplayName: profile.displayName,
        selfAvatarId: profile.avatarId,
      );
      if (result == InviterHandshakeFinalizeResult.alreadyHandled ||
          result == InviterHandshakeFinalizeResult.rejectedDuplicateModuleAnchor) {
        return;
      }
      final notificationName = row.peerDisplayName.isEmpty
          ? 'Unknown'
          : row.peerDisplayName;
      await _contactNotifications.contactAddedViaInvitation(
        displayName: notificationName,
      );
    } on HandshakeOrchestratorError catch (e) {
      await _markHandshake(row.id, lastErrorCode: e.code);
    }
  }

  Future<void> _handleAckAsInvitee({
    required PendingHandshake row,
    required RelayEnvelopeView envelope,
    required Uint8List invitationIdBytes,
    required Uint8List nonceBytes,
    required Uint8List listenAddr,
    required Uint8List addrInviter,
    required Uint8List addrInvitee,
  }) async {
    final inviteePriv = await _identity.loadOrCreatePrivateKey();
    final AckEnvelope ack;
    try {
      ack = await EnvelopeCodec.decryptAck(
        frame: envelope.ciphertext,
        invitationId: invitationIdBytes,
        invitationNonce: nonceBytes,
        inviteeLongTermPrivateKey: inviteePriv,
      );
    } on EnvelopeDecryptionError {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: listenAddr,
      );
      return;
    }

    if (ack.accepted) {
      final accepted = await _finalizeInviteeAccept(row: row, ack: ack);
      if (!accepted) {
        await _relay.ackEnvelope(
          envelopeId: envelope.envelopeId,
          recipient: listenAddr,
        );
        return;
      }
      final notificationDisplayName = ack.displayName.isEmpty
          ? 'Unknown'
          : ack.displayName;
      await _contactNotifications.contactAddRequestResolved(
        displayName: notificationDisplayName,
        accepted: true,
      );
    } else if (ack.rejectionReason ==
        AckRejectionReason.duplicateModuleAnchor) {
      final peerB64 = RelayRouting.b64(ack.inviterLongTermPublicKey);
      if (!await _claimHandshakeStateIf(
        row.id,
        expected: HandshakeState.awaitingAck,
        state: HandshakeState.rejected,
        peerLongTermPublicMaterialB64: peerB64,
      )) {
        await _relay.ackEnvelope(
          envelopeId: envelope.envelopeId,
          recipient: listenAddr,
        );
        return;
      }
      await _contacts.deleteLocally(row.contactStubId);
      await _contactNotifications.contactDuplicateModuleAnchorRejected();
      pendingContactDuplicateDialog.value = PendingContactDuplicateDialog(
        kind: ContactDuplicateDialogKind.inviteeRejectedAnchor,
        anchorKind:
            ack.duplicateAnchorKind ?? DuplicateModuleAnchorKind.housing,
      );
    } else {
      final peerB64 = RelayRouting.b64(ack.inviterLongTermPublicKey);
      if (!await _claimHandshakeStateIf(
        row.id,
        expected: HandshakeState.awaitingAck,
        state: HandshakeState.rejected,
        peerLongTermPublicMaterialB64: peerB64,
      )) {
        await _relay.ackEnvelope(
          envelopeId: envelope.envelopeId,
          recipient: listenAddr,
        );
        return;
      }
      await _contacts.deleteLocally(row.contactStubId);
      final notificationDisplayName = ack.displayName.isEmpty
          ? 'Unknown'
          : ack.displayName;
      await _contactNotifications.contactAddRequestResolved(
        displayName: notificationDisplayName,
        accepted: false,
      );
    }
    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: listenAddr,
    );
    await _decommissionHandshakeAddresses(
      addrInviter: addrInviter,
      addrInvitee: addrInvitee,
    );
  }

  // ---------------------------------------------------------------------
  // Inviter accept finalisation
  // ---------------------------------------------------------------------

  Future<InviterHandshakeFinalizeResult> _finalizeInviterAccept({
    required PendingHandshake handshakeRow,
    required Uint8List peerPubBytes,
    required String peerDisplayName,
    required String peerAvatarId,
    required String peerDeviceBindingId,
    required String selfDisplayName,
    required String selfAvatarId,
  }) async {
    final duplicateExistingId = await _deviceBindingDuplicateContactId(
      defaultStubId: handshakeRow.contactStubId,
      peerDeviceBindingId: peerDeviceBindingId,
    );
    if (duplicateExistingId != null) {
      final anchorKind = await detectContactDuplicateModuleAnchorKind(
        _db,
        duplicateExistingId,
      );
      if (anchorKind != null) {
        await _finalizeInviterRejectDuplicateModuleAnchor(
          handshakeRow: handshakeRow,
          peerPubBytes: peerPubBytes,
          anchorKind: anchorKind,
        );
        return InviterHandshakeFinalizeResult.rejectedDuplicateModuleAnchor;
      }
    }

    final invitationIdBytes = _hexDecode(handshakeRow.invitationIdHex);
    final nonceBytes = _hexDecode(handshakeRow.nonceHex);
    final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final inviterLongTermPub = await _identity.publicKey();
    final selfBindingId = await _deviceBinding.loadOrComputeId();

    // Encrypt the ack with our LONG-TERM pub in the header so the invitee
    // learns it for the first time. The plaintext carries our chosen
    // display name + avatar so the invitee can render us as a connected
    // contact.
    final ackFrame = await EnvelopeCodec.encryptAck(
      envelope: AckEnvelope(
        invitationId: invitationIdBytes,
        inviterLongTermPublicKey: inviterLongTermPub,
        accepted: true,
        deviceBindingId: selfBindingId,
        displayName: selfDisplayName,
        avatarId: selfAvatarId,
      ),
      invitationNonce: nonceBytes,
      inviterHandshakePrivateKey: inviterHandshakePriv,
      inviteeLongTermPublicKey: peerPubBytes,
    );
    final addrInviter = await RelayRouting.inviterHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final addrInvitee = await RelayRouting.inviteeHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );

    try {
      await _relay.postEnvelope(
        senderIdentity: addrInviter,
        recipientIdentity: addrInvitee,
        idempotencyKey: _randomBytes(16),
        ciphertext: ackFrame,
        kind: EnvelopeKind.ack,
        ttl: _ackTtl,
      );
    } on RelayClientError catch (e) {
      throw HandshakeOrchestratorError('relay_error', e);
    }

    // Register the steady-state routing on the relay.
    final selfListenAddr = await RelayRouting.steadyStateAddress(
      firstPub: inviterLongTermPub,
      secondPub: peerPubBytes,
    );
    final peerListenAddr = await RelayRouting.steadyStateAddress(
      firstPub: peerPubBytes,
      secondPub: inviterLongTermPub,
    );
    try {
      await _relay.establishRouting(
        selfIdentity: selfListenAddr,
        peerIdentity: peerListenAddr,
      );
    } on RelayClientError catch (e) {
      throw HandshakeOrchestratorError('relay_error', e);
    }

    if (!await _claimHandshakeStateIf(
      handshakeRow.id,
      expected: HandshakeState.helloReceived,
      state: HandshakeState.completed,
    )) {
      return InviterHandshakeFinalizeResult.alreadyHandled;
    }

    // Promote the stub Contact and write peer material + routing.
    final promoteContactId = await _resolveHandshakePromoteContactId(
      defaultStubId: handshakeRow.contactStubId,
      peerPublicMaterialB64: RelayRouting.b64(peerPubBytes),
      peerDeviceBindingId: peerDeviceBindingId,
      displayName: peerDisplayName,
      avatarId: peerAvatarId,
    );
    await _contacts.promoteToConnected(
      id: promoteContactId,
      relayRoutingIdB64: RelayRouting.b64(peerListenAddr),
      peerPublicMaterialB64: RelayRouting.b64(peerPubBytes),
      displayName: peerDisplayName,
      avatarId: peerAvatarId,
      peerDeviceBindingId: peerDeviceBindingId,
    );
    if (promoteContactId != handshakeRow.contactStubId) {
      await _contacts.deleteLocally(handshakeRow.contactStubId);
    }

    await _decommissionHandshakeAddresses(
      addrInviter: addrInviter,
      addrInvitee: addrInvitee,
    );
    await refreshIncomingHandshakes();
    // Auto-accept completes without surfacing [incomingHandshakes]; bump so
    // contact list UIs reload promoted rows without a route change.
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    startPolling();
    requestClosedAppPushRegistrationSync();

    if (promoteContactId != handshakeRow.contactStubId) {
      pendingContactDuplicateDialog.value = PendingContactDuplicateDialog(
        kind: ContactDuplicateDialogKind.inviterMerged,
      );
      return InviterHandshakeFinalizeResult.acceptedMergedDuplicate;
    }
    return InviterHandshakeFinalizeResult.accepted;
  }

  Future<void> _finalizeInviterRejectDuplicateModuleAnchor({
    required PendingHandshake handshakeRow,
    required Uint8List peerPubBytes,
    required String anchorKind,
  }) async {
    final invitationIdBytes = _hexDecode(handshakeRow.invitationIdHex);
    final nonceBytes = _hexDecode(handshakeRow.nonceHex);
    final inviterHandshakePriv = await RelayRouting.handshakePrivateKey(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final inviterLongTermPub = await _identity.publicKey();
    final selfBindingId = await _deviceBinding.loadOrComputeId();

    final ackFrame = await EnvelopeCodec.encryptAck(
      envelope: AckEnvelope(
        invitationId: invitationIdBytes,
        inviterLongTermPublicKey: inviterLongTermPub,
        accepted: false,
        deviceBindingId: selfBindingId,
        rejectionReason: AckRejectionReason.duplicateModuleAnchor,
        duplicateAnchorKind: anchorKind,
      ),
      invitationNonce: nonceBytes,
      inviterHandshakePrivateKey: inviterHandshakePriv,
      inviteeLongTermPublicKey: peerPubBytes,
    );
    final addrInviter = await RelayRouting.inviterHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );
    final addrInvitee = await RelayRouting.inviteeHandshakeAddress(
      invitationId: invitationIdBytes,
      nonce: nonceBytes,
    );

    try {
      await _relay.postEnvelope(
        senderIdentity: addrInviter,
        recipientIdentity: addrInvitee,
        idempotencyKey: _randomBytes(16),
        ciphertext: ackFrame,
        kind: EnvelopeKind.ack,
        ttl: _ackTtl,
      );
    } on RelayClientError catch (e) {
      throw HandshakeOrchestratorError('relay_error', e);
    }

    await _contacts.deleteLocally(handshakeRow.contactStubId);
    await _markHandshake(handshakeRow.id, state: HandshakeState.rejected);
    await _decommissionHandshakeAddresses(
      addrInviter: addrInviter,
      addrInvitee: addrInvitee,
    );
    await refreshIncomingHandshakes();
    pendingContactDuplicateDialog.value = PendingContactDuplicateDialog(
      kind: ContactDuplicateDialogKind.inviterRejectedAnchor,
      anchorKind: anchorKind,
    );
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    requestClosedAppPushRegistrationSync();
  }

  Future<bool> _finalizeInviteeAccept({
    required PendingHandshake row,
    required AckEnvelope ack,
  }) async {
    final peerPublicMaterialB64 = RelayRouting.b64(
      ack.inviterLongTermPublicKey,
    );
    final inviteePub = await _identity.publicKey();
    final peerListenAddr = await RelayRouting.steadyStateAddress(
      firstPub: ack.inviterLongTermPublicKey,
      secondPub: inviteePub,
    );
    final selfListenAddr = await RelayRouting.steadyStateAddress(
      firstPub: inviteePub,
      secondPub: ack.inviterLongTermPublicKey,
    );

    try {
      await _relay.establishRouting(
        selfIdentity: selfListenAddr,
        peerIdentity: peerListenAddr,
      );
    } on RelayClientError catch (e) {
      throw HandshakeOrchestratorError('relay_error', e);
    }

    if (!await _claimHandshakeStateIf(
      row.id,
      expected: HandshakeState.awaitingAck,
      state: HandshakeState.completed,
      peerLongTermPublicMaterialB64: peerPublicMaterialB64,
    )) {
      return false;
    }

    final promoteContactId = await _resolveHandshakePromoteContactId(
      defaultStubId: row.contactStubId,
      peerPublicMaterialB64: peerPublicMaterialB64,
      peerDeviceBindingId: ack.deviceBindingId,
      displayName: ack.displayName.isEmpty ? null : ack.displayName,
      avatarId: ack.avatarId.isEmpty ? null : ack.avatarId,
    );
    await _contacts.promoteToConnected(
      id: promoteContactId,
      relayRoutingIdB64: RelayRouting.b64(peerListenAddr),
      peerPublicMaterialB64: peerPublicMaterialB64,
      displayName: ack.displayName.isEmpty ? null : ack.displayName,
      avatarId: ack.avatarId.isEmpty ? null : ack.avatarId,
      peerDeviceBindingId: ack.deviceBindingId,
    );
    if (promoteContactId != row.contactStubId) {
      await _contacts.deleteLocally(row.contactStubId);
    }

    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    startPolling();
    requestClosedAppPushRegistrationSync();
    return true;
  }

  // ---------------------------------------------------------------------
  // Steady-state envelopes
  // ---------------------------------------------------------------------

  /// Sends a `profile_update` envelope to every connected contact in the
  /// local store. Callers should invoke this when the local user changes
  /// their own display name or avatar.
  Future<int> broadcastProfileUpdate({
    required String displayName,
    required String avatarId,
  }) async {
    final all = await _contacts.list();
    final connected = all.where((c) => c.kind == 'connected').toList();
    if (connected.isEmpty) return 0;

    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    var dispatched = 0;
    for (final contact in connected) {
      final peerPubB64 = contact.peerPublicMaterial;
      if (peerPubB64 == null || peerPubB64.isEmpty) continue;
      final peerPub = RelayRouting.unb64(peerPubB64);
      final howLabel = (contact.localDisplayLabel ?? '').trim();
      final frame = await EnvelopeCodec.encryptProfileUpdate(
        envelope: ProfileUpdateEnvelope(
          senderLongTermPublicKey: selfPub,
          displayName: displayName,
          avatarId: avatarId,
          hasHowILabelYou: true,
          howILabelYou: howLabel,
        ),
        senderLongTermPrivateKey: selfPriv,
        peerLongTermPublicKey: peerPub,
      );
      final selfAddr = await RelayRouting.steadyStateAddress(
        firstPub: selfPub,
        secondPub: peerPub,
      );
      final peerAddr = await RelayRouting.steadyStateAddress(
        firstPub: peerPub,
        secondPub: selfPub,
      );
      try {
        await _relay.postEnvelope(
          senderIdentity: selfAddr,
          recipientIdentity: peerAddr,
          idempotencyKey: _randomBytes(16),
          ciphertext: frame,
          kind: EnvelopeKind.profileUpdate,
          ttl: _steadyTtl,
        );
        dispatched++;
      } on RelayClientError catch (e) {
        debugPrint('profile_update to ${contact.id} failed: $e');
      } on RelayUnreachableException {
        // Best-effort; updates flow on next change.
      } on TimeoutException {
        // Best-effort; updates flow on next change.
      }
    }
    return dispatched;
  }

  Future<HousingProposalSendResult> sendHousingProposalToPlanParticipants({
    required String planId,
    required String revisionId,
  }) async {
    final sandboxSim = PeerSimulator.maybeInstance;
    sandboxSim?.pauseReactions();
    try {
      return await _sendHousingProposalToPlanParticipantsBody(
        planId: planId,
        revisionId: revisionId,
      );
    } finally {
      sandboxSim?.resumeReactions();
    }
  }

  Future<HousingProposalSendResult> _sendHousingProposalToPlanParticipantsBody({
    required String planId,
    required String revisionId,
  }) async {
    final participants = (await _db.listParticipants())
        .where((p) => p.id.startsWith('$planId:p'))
        .toList(growable: false);
    if (participants.isEmpty) {
      debugPrint('housing_proposal no participant rows for $planId');
      return const HousingProposalSendResult(
        sentCount: 0,
        failedParticipantIds: <String>[],
        relayStatusByParticipantId: {},
      );
    }

    final transport = HousingProposalTransportService(_db);
    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    final relayReachableContacts = (await _contacts.list())
        .where((c) => !c.id.startsWith('contact:local:'))
        .where((c) {
          final peer = c.peerPublicMaterial;
          return peer != null && peer.isNotEmpty;
        })
        .toList(growable: false);
    var sent = 0;
    final failed = <String>[];
    final relayStatusByParticipantId = <String, String>{};

    for (final participant in participants) {
      final contactId = participant.contactId;
      final contact = contactId == null ? null : await _contacts.get(contactId);
      final targets = _housingProposalTargetContacts(
        participant: participant,
        selectedContact: contact,
        relayReachableContacts: relayReachableContacts,
      );
      if (targets.isEmpty) {
        debugPrint(
          'housing_proposal no relay target for ${participant.id} '
          '(contactId=${contactId ?? '-'}, '
          'relayPeers=${relayReachableContacts.length})',
        );
        failed.add(participant.id);
        relayStatusByParticipantId[participant.id] = 'failed';
        continue;
      }

      var deliveredToAnyTarget = false;
      try {
        final proposalJson = await transport.exportProposalForParticipant(
          planId: planId,
          revisionId: revisionId,
          targetParticipantId: participant.id,
        );
        for (final target in targets) {
          final peerPubB64 = target.peerPublicMaterial;
          if (peerPubB64 == null || peerPubB64.isEmpty) continue;
          try {
            final peerPub = RelayRouting.unb64(peerPubB64);
            final frame = await EnvelopeCodec.encryptHousingProposal(
              envelope: HousingProposalEnvelope(
                senderLongTermPublicKey: selfPub,
                proposalJson: proposalJson,
                targetParticipantId: participant.id,
              ),
              senderLongTermPrivateKey: selfPriv,
              peerLongTermPublicKey: peerPub,
            );
            final selfAddr = await RelayRouting.steadyStateAddress(
              firstPub: selfPub,
              secondPub: peerPub,
            );
            final peerAddr = await RelayRouting.steadyStateAddress(
              firstPub: peerPub,
              secondPub: selfPub,
            );
            await _ensureSteadyRoutingRegistered(
              selfListenAddr: selfAddr,
              peerListenAddr: peerAddr,
            );
            await _postGatedEnvelope(
              senderIdentity: selfAddr,
              recipientIdentity: peerAddr,
              idempotencyKey: _randomBytes(16),
              ciphertext: frame,
              kind: EnvelopeKind.housingProposal,
              ttl: _steadyTtl,
              planId: planId,
              selfParticipantId: '$planId:self',
            );
            debugPrint(
              'housing_proposal posted for ${participant.id} to ${target.id}',
            );
            deliveredToAnyTarget = true;
          } on Object catch (e) {
            debugPrint(
              'housing_proposal to ${participant.id}/${target.id} failed: $e',
            );
          }
        }
      } on Object catch (e) {
        debugPrint('housing_proposal to ${participant.id} failed: $e');
      }
      if (deliveredToAnyTarget) {
        debugPrint('housing_proposal delivered for ${participant.id}');
        sent++;
        relayStatusByParticipantId[participant.id] = 'queued';
      } else {
        failed.add(participant.id);
        relayStatusByParticipantId[participant.id] = 'failed';
      }
    }

    if (sent > 0) {
      unawaited(
        _registerProposalDeadlineRemindersAfterSend(
          planId: planId,
          revisionId: revisionId,
        ),
      );
    }

    return HousingProposalSendResult(
      sentCount: sent,
      failedParticipantIds: List.unmodifiable(failed),
      relayStatusByParticipantId: Map.unmodifiable(relayStatusByParticipantId),
    );
  }

  Future<void> _registerProposalDeadlineRemindersAfterSend({
    required String planId,
    required String revisionId,
  }) async {
    try {
      final rev = await (_db.select(
        _db.proposalRevisions,
      )..where((t) => t.id.equals(revisionId))).getSingleOrNull();
      if (rev == null) return;
      final state = HousingProposalRevisionState.fromJson(rev.payloadJson);
      final expires = state.responseExpiresAtUtc;
      if (expires == null) return;

      final wakeIds = await routingWakeRecipientIdentities();
      if (wakeIds.isEmpty) return;
      final recipientIds = <Uint8List>[...wakeIds];
      final selfPub = await _identity.publicKey();
      final participants = (await _db.listParticipants())
          .where((p) => p.id.startsWith('$planId:'))
          .toList(growable: false);
      for (final p in participants) {
        final contactId = p.contactId;
        if (contactId == null) continue;
        final contact = await _contacts.get(contactId);
        final peerB64 = contact?.peerPublicMaterial;
        if (peerB64 == null || peerB64.isEmpty) continue;
        try {
          final peerPub = RelayRouting.unb64(peerB64);
          recipientIds.add(
            await RelayRouting.steadyStateAddress(
              firstPub: peerPub,
              secondPub: selfPub,
            ),
          );
        } catch (_) {}
      }
      await ProposalDeadlineReminderService(
        relay: _relay,
      ).registerFires(
        senderIdentity: wakeIds.first,
        revisionId: revisionId,
        expiresAtUtc: expires,
        recipientRoutingIds: recipientIds,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('proposal deadline register after send: $e');
      }
    }
  }

  List<Contact> _housingProposalTargetContacts({
    required Participant participant,
    required Contact? selectedContact,
    required List<Contact> relayReachableContacts,
  }) {
    return housingProposalDeliveryTargets(
      participant: participant,
      selectedContact: selectedContact,
      relayReachableContacts: relayReachableContacts,
    );
  }

  Future<void> _postGatedEnvelope({
    required Uint8List senderIdentity,
    required Uint8List recipientIdentity,
    required Uint8List idempotencyKey,
    required Uint8List ciphertext,
    required int kind,
    required Duration ttl,
    required String planId,
    required String selfParticipantId,
    String? expenseId,
    String? revisionId,
    String? decisionKind,
  }) async {
    final gate = await _entitlement?.gateFor(
      planId: planId,
      selfParticipantId: selfParticipantId,
      kind: kind,
      expenseId: expenseId,
      revisionId: revisionId,
      decisionKind: decisionKind,
    );
    await _relay.postEnvelope(
      senderIdentity: senderIdentity,
      recipientIdentity: recipientIdentity,
      idempotencyKey: idempotencyKey,
      ciphertext: ciphertext,
      kind: kind,
      ttl: ttl,
      entitlementGate: gate,
    );
  }

  Future<void> _reportEntitlementRosterAfterActivation({
    required String planId,
    required String revisionId,
  }) async {
    final entitlement = _entitlement;
    if (entitlement == null || !entitlement.httpEnabled) return;
    final participants = (await _db.listParticipants())
        .where((p) => p.id.startsWith('$planId:p') || p.id == '$planId:self')
        .map((p) => p.id)
        .toList(growable: false);
    await entitlement.reportRosterIfComplete(
      planId: planId,
      revisionId: revisionId,
      participantIds: participants,
    );
  }

  Future<HousingProposalSendResult> sendHousingProposalResponse({
    required String planId,
    required ProposalResponseStatus status,
    String message = '',
    String? revisionId,
  }) async {
    final transport = HousingProposalTransportService(_db);
    final selectedRevisionId =
        revisionId ?? await transport.pendingRevisionIdForPlan(planId);
    if (selectedRevisionId == null) {
      throw HandshakeOrchestratorError('unknown');
    }
    final selfParticipantId = '$planId:self';
    if (status == ProposalResponseStatus.accepted) {
      final missing = await listMissingPlanPeerContacts(
        db: _db,
        planId: planId,
      );
      if (missing.isNotEmpty) {
        throw HandshakeOrchestratorError('plan_missing_peer_contacts');
      }
    }
    await transport.expireRevisionIfNeeded(
      planId: planId,
      revisionId: selectedRevisionId,
    );
    await PlanAgreementProposalService(_db).recordResponse(
      revisionId: selectedRevisionId,
      participantId: selfParticipantId,
      status: status,
      message: message,
    );
    final payload = await PlanAgreementProposalService(
      _db,
    ).loadRevisionPayload(selectedRevisionId);
    final sourcePackageId =
        (payload['sourcePackageId'] as String?) ??
        (payload['packageId'] as String?) ??
        '';
    final sourceRevisionId =
        (payload['sourceRevisionId'] as String?) ??
        (payload['revisionId'] as String?) ??
        selectedRevisionId;
    final sourceParticipantId = await transport.sourceParticipantIdForLocal(
      revisionId: selectedRevisionId,
      localParticipantId: selfParticipantId,
    );

    String? responderInstallationId;
    final entitlement = _entitlement;
    if (entitlement != null && entitlement.gateEnabled) {
      final id = await entitlement.installationIdForSnapshot(
        planId: planId,
        participantId: selfParticipantId,
      );
      if (id.isNotEmpty) {
        responderInstallationId = id;
      }
    }

    final response = HousingProposalResponseEnvelope(
      senderLongTermPublicKey: await _identity.publicKey(),
      sourcePackageId: sourcePackageId,
      sourceRevisionId: sourceRevisionId,
      sourceParticipantId: sourceParticipantId,
      status: status.name,
      message: message.trim(),
      participantInstallationId: responderInstallationId,
    );
    final sendResult = await _broadcastHousingProposalResponse(
      planId: planId,
      response: response,
      revisionId: selectedRevisionId,
      status: status,
    );
    await RelayActivityLogService(_db).append(
      kind: RelayActivityLogKinds.housingProposalResponse,
      initiatorKind: RelayActivityLogService.initiatorSelf,
      planId: planId,
      packageId: sourcePackageId,
      revisionId: selectedRevisionId,
      details: {'status': status.name},
    );
    if (status == ProposalResponseStatus.accepted) {
      final outcome = await transport.tryActivatePlanIfUnanimous(
        planId: planId,
        revisionId: selectedRevisionId,
      );
      if (outcome == ProposalActivationOutcome.activated) {
        await _reportEntitlementRosterAfterActivation(
          planId: planId,
          revisionId: selectedRevisionId,
        );
        await _reconcileHousingPaymentRemindersAfterActivation(
          planId: planId,
          revisionId: selectedRevisionId,
        );
        await HousingProposalTransportService(_db).notifyAgreementActivatedIfNeeded(
          planId: planId,
          revisionId: selectedRevisionId,
        );
      }
      await transport.reconcileStalePackagePending(planId);
    } else if (sendResult.sentCount > 0) {
      await transport.archiveInvalidatedProposal(
        planId: planId,
        revisionId: selectedRevisionId,
        status: status,
        responderParticipantId: selfParticipantId,
      );
    }
    unawaited(_cancelProposalDeadlineReminders(selectedRevisionId));
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    return sendResult;
  }

  /// Cancels relay proposal-deadline fires (response / invalidate / expire).
  Future<void> cancelProposalDeadlineReminders(String revisionId) =>
      _cancelProposalDeadlineReminders(revisionId);

  Future<HousingProposalSendResult> _broadcastHousingProposalResponse({
    required String planId,
    required HousingProposalResponseEnvelope response,
    required String revisionId,
    required ProposalResponseStatus status,
  }) async {
    final participants = (await _db.listParticipants())
        .where((p) => p.id.startsWith('$planId:p'))
        .toList(growable: false);
    if (participants.isEmpty) {
      return const HousingProposalSendResult(
        sentCount: 0,
        failedParticipantIds: <String>[],
      );
    }

    final relayReachableContacts = (await _contacts.list())
        .where((c) => !c.id.startsWith('contact:local:'))
        .where((c) {
          final peer = c.peerPublicMaterial;
          return peer != null && peer.isNotEmpty;
        })
        .toList(growable: false);

    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    var sent = 0;
    final failed = <String>[];

    for (final participant in participants) {
      final contactId = participant.contactId;
      final contact = contactId == null ? null : await _contacts.get(contactId);
      final targets = _housingProposalTargetContacts(
        participant: participant,
        selectedContact: contact,
        relayReachableContacts: relayReachableContacts,
      );
      if (targets.isEmpty) {
        debugPrint(
          'housing_proposal_response no relay target for ${participant.id} '
          '(contactId=${contactId ?? '-'}, '
          'relayPeers=${relayReachableContacts.length})',
        );
        failed.add(participant.id);
        continue;
      }

      var deliveredToAnyTarget = false;
      for (final target in targets) {
        final peerPubB64 = target.peerPublicMaterial;
        if (peerPubB64 == null || peerPubB64.isEmpty) continue;
        try {
          final peerPub = RelayRouting.unb64(peerPubB64);
          final frame = await EnvelopeCodec.encryptHousingProposalResponse(
            envelope: response,
            senderLongTermPrivateKey: selfPriv,
            peerLongTermPublicKey: peerPub,
          );
          final selfAddr = await RelayRouting.steadyStateAddress(
            firstPub: selfPub,
            secondPub: peerPub,
          );
          final peerAddr = await RelayRouting.steadyStateAddress(
            firstPub: peerPub,
            secondPub: selfPub,
          );
          await _ensureSteadyRoutingRegistered(
            selfListenAddr: selfAddr,
            peerListenAddr: peerAddr,
          );
          await _postGatedEnvelope(
            senderIdentity: selfAddr,
            recipientIdentity: peerAddr,
            idempotencyKey: _randomBytes(16),
            ciphertext: frame,
            kind: EnvelopeKind.housingProposalResponse,
            ttl: _steadyTtl,
            planId: planId,
            selfParticipantId: '$planId:self',
            revisionId: revisionId,
            decisionKind: status.name,
          );
          debugPrint(
            'housing_proposal_response posted for ${participant.id} '
            'to ${target.id}',
          );
          deliveredToAnyTarget = true;
        } on Object catch (e) {
          debugPrint(
            'housing_proposal_response to ${participant.id}/${target.id} '
            'failed: $e',
          );
        }
      }
      if (deliveredToAnyTarget) {
        sent++;
      } else {
        failed.add(participant.id);
      }
    }

    unawaited(_cancelProposalDeadlineReminders(revisionId));

    return HousingProposalSendResult(
      sentCount: sent,
      failedParticipantIds: List.unmodifiable(failed),
    );
  }

  Future<void> _cancelProposalDeadlineReminders(String revisionId) async {
    try {
      final wakeIds = await routingWakeRecipientIdentities();
      if (wakeIds.isEmpty) return;
      await ProposalDeadlineReminderService(
        relay: _relay,
      ).cancelForRevision(
        senderIdentity: wakeIds.first,
        revisionId: revisionId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('proposal deadline cancel: $e');
      }
    }
  }

  /// Broadcasts a proposed realized expense to connected co-participants.
  Future<void> sendRealizedExpensePropose({required String expenseId}) async {
    final repo = RealizedExpenseRepository(_db);
    final expense = await repo.getById(expenseId);
    if (expense == null) return;

    final attachments = await repo.attachmentsFor(expenseId);
    final expenseJson = await RealizedExpenseSyncService(
      _db,
    ).buildProposeJson(expense: expense, attachments: attachments);
    try {
      final payload = jsonDecode(expenseJson) as Map<String, dynamic>;
      final attachmentNames = attachments
          .map((a) => a.displayFileName)
          .join(',');
      debugPrint(
        'housing_realized_expense qa: propose send expense=$expenseId '
        'kind=${payload['kind']} '
        'sourcePayer=${payload['payer_participant_id']} '
        'sourceBeneficiary=${payload['beneficiary_participant_id']} '
        'localPayer=${expense.payerParticipantId} '
        'localBeneficiary=${expense.beneficiaryParticipantId} '
        'attachments=${attachments.length} names=$attachmentNames '
        'jsonBytes=${expenseJson.length}',
      );
    } on Object catch (e) {
      debugPrint(
        'housing_realized_expense qa: propose send expense=$expenseId '
        'payload decode failed: $e',
      );
    }

    final relayReachableContacts = (await _contacts.list())
        .where((c) {
          final peer = c.peerPublicMaterial;
          return !c.id.startsWith('contact:local:') &&
              peer != null &&
              peer.isNotEmpty;
        })
        .toList(growable: false);
    if (relayReachableContacts.isEmpty) {
      RelayDiagnostics.logHousingRealizedExpense(
        'no relay contacts for ${expense.planId}',
      );
      return;
    }

    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    final seenPeerMaterial = <String>{};

    for (final target in relayReachableContacts) {
      final peerPubB64 = target.peerPublicMaterial;
      if (peerPubB64 == null || peerPubB64.isEmpty) continue;
      if (!seenPeerMaterial.add(peerPubB64)) continue;
      try {
        final peerPub = RelayRouting.unb64(peerPubB64);
        final frame =
            await EnvelopeCodec.encryptHousingRealizedExpensePropose(
              envelope: HousingRealizedExpenseEnvelope(
                senderLongTermPublicKey: selfPub,
                expenseJson: expenseJson,
              ),
              senderLongTermPrivateKey: selfPriv,
              peerLongTermPublicKey: peerPub,
            );
        final selfAddr = await RelayRouting.steadyStateAddress(
          firstPub: selfPub,
          secondPub: peerPub,
        );
        final peerAddr = await RelayRouting.steadyStateAddress(
          firstPub: peerPub,
          secondPub: selfPub,
        );
        await _ensureSteadyRoutingRegistered(
          selfListenAddr: selfAddr,
          peerListenAddr: peerAddr,
        );
        await _postGatedEnvelope(
          senderIdentity: selfAddr,
          recipientIdentity: peerAddr,
          idempotencyKey: _randomBytes(16),
          ciphertext: frame,
          kind: EnvelopeKind.housingRealizedExpensePropose,
          ttl: _steadyTtl,
          planId: expense.planId,
          selfParticipantId: '${expense.planId}:self',
          expenseId: expenseId,
        );
        RelayDiagnostics.logHousingRealizedExpense(
          'posted for ${expense.planId} to ${target.id}',
        );
      } on Object catch (e) {
        debugPrint(
          'housing_realized_expense propose to ${target.id} failed: $e',
        );
      }
    }
    await RealizedExpenseLedgerService(
      _db,
    ).markPlanActiveUseIfNeeded(expense.planId);
  }

  Future<void> sendRealizedExpenseAccept({
    required String expenseId,
    required String participantId,
  }) async {
    debugPrint(
      'housing_realized_expense send accept called for $expenseId '
      '(participantId=$participantId)',
    );
    await _sendRealizedExpenseDecision(
      expenseId: expenseId,
      participantId: participantId,
      decision: RealizedExpenseDecision.accepted,
      kind: EnvelopeKind.housingRealizedExpenseAccept,
    );
  }

  Future<void> sendRealizedExpenseReject({
    required String expenseId,
    required String participantId,
    required String justification,
  }) async {
    debugPrint(
      'housing_realized_expense send reject called for $expenseId '
      '(participantId=$participantId)',
    );
    await _sendRealizedExpenseDecision(
      expenseId: expenseId,
      participantId: participantId,
      decision: RealizedExpenseDecision.rejected,
      kind: EnvelopeKind.housingRealizedExpenseReject,
      justification: justification,
    );
  }

  Future<void> _sendRealizedExpenseDecision({
    required String expenseId,
    required String participantId,
    required String decision,
    required int kind,
    String? justification,
  }) async {
    debugPrint(
      'housing_realized_expense decision build start for $expenseId '
      '(decision=$decision, participantId=$participantId)',
    );
    final expense = await RealizedExpenseRepository(_db).getById(expenseId);
    if (expense == null) {
      debugPrint('housing_realized_expense decision abort: unknown $expenseId');
      return;
    }

    final decisionJson = await RealizedExpenseSyncService(_db)
        .buildDecisionJson(
          expenseId: expenseId,
          packageId: expense.packageId,
          participantId: participantId,
          decision: decision,
          justification: justification,
        );

    final planId = expense.planId;
    final participants = (await _db.listParticipants())
        .where((p) => p.id.startsWith('$planId:p'))
        .toList(growable: false);
    debugPrint(
      'housing_realized_expense decision participants for $expenseId: '
      '${participants.length}',
    );
    if (participants.isEmpty) {
      debugPrint(
        'housing_realized_expense decision no participants for $expenseId '
        '(planId=$planId)',
      );
      return;
    }

    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    final decisionCandidateContacts = (await _contacts.list())
        .where((c) {
          final peer = c.peerPublicMaterial;
          return !c.id.startsWith('contact:local:') &&
              peer != null &&
              peer.isNotEmpty;
        })
        .toList(growable: false);
    debugPrint(
      'housing_realized_expense decision candidate contacts for $expenseId: '
      '${decisionCandidateContacts.length}',
    );

    // Decision JSON is identical for every recipient. Post once per peer
    // pubkey (sandbox fan-out can map several plan slots onto the same peer).
    final postedPeerMaterial = <String>{};

    for (final participant in participants) {
      final contactId = participant.contactId;
      final contact = contactId == null ? null : await _contacts.get(contactId);
      final targets = _housingProposalTargetContacts(
        participant: participant,
        selectedContact: contact,
        relayReachableContacts: decisionCandidateContacts,
      );
      if (targets.isEmpty) {
        debugPrint(
          'housing_realized_expense decision no targets for ${participant.id}'
          ' (contactId=${contactId ?? '-'}, '
          'candidateContacts=${decisionCandidateContacts.length})',
        );
      }
      for (final target in targets) {
        final peerPubB64 = target.peerPublicMaterial;
        if (peerPubB64 == null || peerPubB64.isEmpty) continue;
        if (!postedPeerMaterial.add(peerPubB64)) continue;
        try {
          final peerPub = RelayRouting.unb64(peerPubB64);
          final frame =
              await EnvelopeCodec.encryptHousingRealizedExpenseDecision(
                kind: kind,
                envelope: HousingRealizedExpenseDecisionEnvelope(
                  senderLongTermPublicKey: selfPub,
                  decisionJson: decisionJson,
                ),
                senderLongTermPrivateKey: selfPriv,
                peerLongTermPublicKey: peerPub,
              );
          final selfAddr = await RelayRouting.steadyStateAddress(
            firstPub: selfPub,
            secondPub: peerPub,
          );
          final peerAddr = await RelayRouting.steadyStateAddress(
            firstPub: peerPub,
            secondPub: selfPub,
          );
          await _ensureSteadyRoutingRegistered(
            selfListenAddr: selfAddr,
            peerListenAddr: peerAddr,
          );
          await _postGatedEnvelope(
            senderIdentity: selfAddr,
            recipientIdentity: peerAddr,
            idempotencyKey: _randomBytes(16),
            ciphertext: frame,
            kind: kind,
            ttl: _steadyTtl,
            planId: planId,
            selfParticipantId: participantId,
            expenseId: expenseId,
            decisionKind: decision,
          );
          debugPrint(
            'housing_realized_expense decision posted for $expenseId '
            'to ${participant.id}/${target.id}',
          );
        } on Object catch (e) {
          debugPrint(
            'housing_realized_expense decision to ${participant.id}/'
            '${target.id} failed: $e',
          );
        }
      }
    }
    debugPrint('housing_realized_expense decision send done for $expenseId');
    if (decision == RealizedExpenseDecision.accepted) {
      await _maybeReconcileHousingRemindersAfterExpenseAccept(
        expenseId: expenseId,
        participantId: participantId,
      );
    }
  }

  /// Broadcasts a participation change proposal to connected co-participants.
  Future<void> sendParticipationChangePropose({required String changeId}) async {
    await _broadcastParticipationChange(
      changeId: changeId,
      kind: EnvelopeKind.housingParticipationChangePropose,
      encrypt:
          (json, selfPub, selfPriv, peerPub) =>
              EnvelopeCodec.encryptHousingParticipationChangePropose(
                envelope: HousingParticipationChangeEnvelope(
                  senderLongTermPublicKey: selfPub,
                  changeJson: json,
                ),
                senderLongTermPrivateKey: selfPriv,
                peerLongTermPublicKey: peerPub,
              ),
    );
  }

  /// Broadcasts an informational participation notify (kind 12).
  Future<void> sendParticipationChangeNotify({
    required String changeId,
    String? statusWireOverride,
  }) async {
    await _broadcastParticipationChange(
      changeId: changeId,
      kind: EnvelopeKind.housingParticipationChangeNotify,
      statusWireOverride: statusWireOverride,
      encrypt:
          (json, selfPub, selfPriv, peerPub) =>
              EnvelopeCodec.encryptHousingParticipationChangeNotify(
                envelope: HousingParticipationChangeEnvelope(
                  senderLongTermPublicKey: selfPub,
                  changeJson: json,
                ),
                senderLongTermPrivateKey: selfPriv,
                peerLongTermPublicKey: peerPub,
              ),
    );
  }

  /// Broadcasts voluntary withdrawal cancellation to connected co-participants.
  Future<void> cancelParticipationChangeWithdrawal({
    required String changeId,
    required String participantId,
  }) async {
    final changeSvc = HousingParticipationChangeService(_db);
    if (!await changeSvc.cancelVoluntaryWithdrawal(
      changeId: changeId,
      participantId: participantId,
    )) {
      return;
    }
    await sendParticipationChangeNotify(
      changeId: changeId,
      statusWireOverride:
          HousingParticipationChangeStatus.aborted.wireValue,
    );
  }

  Future<void> sendParticipationChangeDecision({
    required String changeId,
    required String participantId,
    required bool accepted,
  }) async {
    final changeSvc = HousingParticipationChangeService(_db);
    if (!await changeSvc.persistDecision(
      changeId: changeId,
      participantId: participantId,
      accepted: accepted,
    )) {
      return;
    }
    final change = await changeSvc.getById(changeId);
    if (change == null) return;

    final status =
        accepted
            ? HousingParticipationDecisionStatus.accepted.wireValue
            : HousingParticipationDecisionStatus.rejected.wireValue;
    final decisionJson = await HousingParticipationChangeSyncService(
      _db,
    ).buildDecisionJson(
      changeId: changeId,
      participantId: participantId,
      status: status,
    );

    // Relay to peers while this device still treats them as active members.
    await _broadcastParticipationChangeDecision(
      planId: change.planId,
      decisionJson: decisionJson,
    );

    await changeSvc.evaluatePendingSettlement(changeId);
    // Notify peers only after the change actually becomes effective (e.g.
    // voluntary withdrawal: departure date reached + ack conditions met).
    final updated = await changeSvc.getById(changeId);
    if (updated?.status == HousingParticipationChangeStatus.effective.wireValue) {
      await sendParticipationChangeNotify(
        changeId: changeId,
        statusWireOverride:
            HousingParticipationChangeStatus.effective.wireValue,
      );
    }
  }

  Future<void> _broadcastParticipationChange({
    required String changeId,
    required int kind,
    String? statusWireOverride,
    required Future<Uint8List> Function(
      String changeJson,
      Uint8List selfPub,
      Uint8List selfPriv,
      Uint8List peerPub,
    )
    encrypt,
  }) async {
    final change = await HousingParticipationChangeService(_db).getById(
      changeId,
    );
    if (change == null) return;

    final changeJson = await HousingParticipationChangeSyncService(
      _db,
    ).buildProposeJson(change, statusWireOverride: statusWireOverride);
    await _postParticipationChangeToPeers(
      planId: change.planId,
      kind: kind,
      participationChangeKind: HousingParticipationChangeKind.fromWire(
        change.kind,
      ),
      buildFrame:
          (selfPub, selfPriv, peerPub) =>
              encrypt(changeJson, selfPub, selfPriv, peerPub),
    );
  }

  Future<void> _broadcastParticipationChangeDecision({
    required String planId,
    required String decisionJson,
  }) async {
    final changeId = _changeIdFromJson(decisionJson);
    HousingParticipationChangeKind? participationChangeKind;
    if (changeId != null) {
      final change = await HousingParticipationChangeService(_db).getById(
        changeId,
      );
      participationChangeKind = HousingParticipationChangeKind.fromWire(
        change?.kind,
      );
    }
    await _postParticipationChangeToPeers(
      planId: planId,
      kind: EnvelopeKind.housingParticipationChangeDecision,
      participationChangeKind: participationChangeKind,
      buildFrame: (selfPub, selfPriv, peerPub) async {
        return EnvelopeCodec.encryptHousingParticipationChangeDecision(
          envelope: HousingParticipationChangeDecisionEnvelope(
            senderLongTermPublicKey: selfPub,
            decisionJson: decisionJson,
          ),
          senderLongTermPrivateKey: selfPriv,
          peerLongTermPublicKey: peerPub,
        );
      },
    );
  }

  Future<void> _postParticipationChangeToPeers({
    required String planId,
    required int kind,
    HousingParticipationChangeKind? participationChangeKind,
    required Future<Uint8List> Function(
      Uint8List selfPub,
      Uint8List selfPriv,
      Uint8List peerPub,
    )
    buildFrame,
  }) async {
    final relayReachableContacts = (await _contacts.list())
        .where(isRelayReachableContact)
        .toList(growable: false);
    if (relayReachableContacts.isEmpty) return;

    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    final seenPeerMaterial = <String>{};

    Future<void> postToContact(Contact target) async {
      final peerPubB64 = target.peerPublicMaterial;
      if (peerPubB64 == null || peerPubB64.isEmpty) return;
      if (!seenPeerMaterial.add(peerPubB64)) return;
      try {
        final peerPub = RelayRouting.unb64(peerPubB64);
        final frame = await buildFrame(selfPub, selfPriv, peerPub);
        final selfAddr = await RelayRouting.steadyStateAddress(
          firstPub: selfPub,
          secondPub: peerPub,
        );
        final peerAddr = await RelayRouting.steadyStateAddress(
          firstPub: peerPub,
          secondPub: selfPub,
        );
        await _ensureSteadyRoutingRegistered(
          selfListenAddr: selfAddr,
          peerListenAddr: peerAddr,
        );
        await _relay.postEnvelope(
          senderIdentity: selfAddr,
          recipientIdentity: peerAddr,
          idempotencyKey: _randomBytes(16),
          ciphertext: frame,
          kind: kind,
          ttl: _steadyTtl,
        );
      } on Object catch (e) {
        debugPrint('housing_participation_change post failed: $e');
      }
    }

    for (final target in relayReachableContacts) {
      await postToContact(target);
    }
  }

  Future<void> _applyHousingProposalResponse(
    HousingProposalResponseEnvelope response, {
    required String senderDisplayName,
  }) async {
    final revision = await _matchingHousingRevision(response.sourceRevisionId);
    if (revision == null) return;
    final transport = HousingProposalTransportService(_db);
    final pkgEarly = await (_db.select(
      _db.proposalPackages,
    )..where((t) => t.id.equals(revision.packageId))).getSingleOrNull();
    if (pkgEarly != null) {
      await transport.expireRevisionIfNeeded(
        planId: pkgEarly.planId,
        revisionId: revision.id,
      );
    }
    final revisionPayload =
        jsonDecode(revision.payloadJson) as Map<String, dynamic>;
    if (revisionPayload['lifecycleState'] == 'archived') return;

    ProposalResponseStatus? status;
    for (final candidate in ProposalResponseStatus.values) {
      if (candidate.name == response.status) {
        status = candidate;
        break;
      }
    }
    if (status == null) return;
    final participantId = await transport.localParticipantIdForSource(
      revisionId: revision.id,
      sourceParticipantId: response.sourceParticipantId,
    );
    if (participantId == null) return;
    final responseRowId = 'resp:${revision.id}:$participantId';
    final priorResponse = await (_db.select(
      _db.proposalResponses,
    )..where((t) => t.id.equals(responseRowId))).getSingleOrNull();
    final alreadyRecordedSameStatus = priorResponse?.status == status.name;
    final planId = pkgEarly?.planId;
    final responderInstallationId = response.participantInstallationId;
    if (planId != null &&
        responderInstallationId != null &&
        responderInstallationId.isNotEmpty) {
      await EntitlementCoordinator.maybeInstance?.ingestParticipantSnapshot(
        planId: planId,
        participantId: participantId,
        installationId: responderInstallationId,
      );
    }
    await PlanAgreementProposalService(_db).recordResponse(
      revisionId: revision.id,
      participantId: participantId,
      status: status,
      message: response.message,
    );
    final pkg = await (_db.select(
      _db.proposalPackages,
    )..where((t) => t.id.equals(revision.packageId))).getSingleOrNull();
    String? activatedPlanId;
    if (pkg != null) {
      if (status == ProposalResponseStatus.accepted) {
        final outcome = await transport.tryActivatePlanIfUnanimous(
          planId: pkg.planId,
          revisionId: revision.id,
        );
        if (outcome == ProposalActivationOutcome.activated) {
          activatedPlanId = pkg.planId;
          await _reportEntitlementRosterAfterActivation(
            planId: pkg.planId,
            revisionId: revision.id,
          );
          await _reconcileHousingPaymentRemindersAfterActivation(
            planId: pkg.planId,
            revisionId: revision.id,
          );
          HousingNavigationIntent.requestOpenActiveHub(pkg.planId);
        }
      } else {
        await transport.archiveInvalidatedProposal(
          planId: pkg.planId,
          revisionId: revision.id,
          status: status,
          responderParticipantId: participantId,
        );
        unawaited(_cancelProposalDeadlineReminders(revision.id));
      }
      await transport.reconcileStalePackagePending(pkg.planId);
    }
    // Decision (#7) before activation (#9) so OS shade order matches causality.
    // Claim response row id so concurrent polls cannot double-notify.
    final shouldNotifyDecision = !alreadyRecordedSameStatus &&
        _ownsDeviceHousingNotifications &&
        _housingDecisionNotifiedResponseIds.add(responseRowId);
    if (shouldNotifyDecision) {
      final isAmendment = HousingAmendmentTypeWire.parse(
            revisionPayload['amendmentType'] as String?,
          ) !=
          null;
      debugPrint(
        'housing_proposal_response notify #7 sender=$senderDisplayName '
        'participant=$participantId revision=${revision.id} '
        'amendment=$isAmendment',
      );
      await PushNotificationService.showLocalHousingDecisionNotification(
        senderDisplayName: senderDisplayName,
        planId: pkg?.planId,
        revisionId: revision.id,
        isAmendment: isAmendment,
      );
    }
    if (activatedPlanId != null) {
      await transport.notifyAgreementActivatedIfNeeded(
        planId: activatedPlanId,
        revisionId: revision.id,
      );
    }
  }

  Future<ProposalRevision?> _matchingHousingRevision(
    String sourceRevisionId,
  ) async {
    final direct = await (_db.select(
      _db.proposalRevisions,
    )..where((t) => t.id.equals(sourceRevisionId))).getSingleOrNull();
    if (direct != null) return direct;
    final revisions = await _db.select(_db.proposalRevisions).get();
    for (final revision in revisions) {
      try {
        final payload =
            jsonDecode(revision.payloadJson) as Map<String, dynamic>;
        if (payload['sourceRevisionId'] == sourceRevisionId) {
          return revision;
        }
      } catch (_) {
        // Ignore malformed historical payloads.
      }
    }
    return null;
  }

  /// Pushes the local user's canonical profile plus how they list [contactId]
  /// on this device, so the peer can surface it under profile appearances.
  Future<void> notifyPeerOfLocalDisplayLabelChange(String contactId) async {
    final contact = await _contacts.get(contactId);
    if (contact == null || contact.kind != 'connected') return;
    final peerPubB64 = contact.peerPublicMaterial;
    if (peerPubB64 == null || peerPubB64.isEmpty) return;

    final prefs = await AppPreferences.load();
    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    final peerPub = RelayRouting.unb64(peerPubB64);
    final howLabel = (contact.localDisplayLabel ?? '').trim();
    final frame = await EnvelopeCodec.encryptProfileUpdate(
      envelope: ProfileUpdateEnvelope(
        senderLongTermPublicKey: selfPub,
        displayName: prefs.displayName,
        avatarId: prefs.avatarId,
        hasHowILabelYou: true,
        howILabelYou: howLabel,
      ),
      senderLongTermPrivateKey: selfPriv,
      peerLongTermPublicKey: peerPub,
    );
    final selfAddr = await RelayRouting.steadyStateAddress(
      firstPub: selfPub,
      secondPub: peerPub,
    );
    final peerAddr = await RelayRouting.steadyStateAddress(
      firstPub: peerPub,
      secondPub: selfPub,
    );
    try {
      await _relay.postEnvelope(
        senderIdentity: selfAddr,
        recipientIdentity: peerAddr,
        idempotencyKey: _randomBytes(16),
        ciphertext: frame,
        kind: EnvelopeKind.profileUpdate,
        ttl: _steadyTtl,
      );
      steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    } on RelayClientError catch (e) {
      debugPrint('profile_update (label) to $contactId failed: $e');
    } on RelayUnreachableException {
      // best-effort
    } on TimeoutException {
      // best-effort
    }
  }

  /// Sends a `disconnect` envelope to a single connected contact and
  /// demotes the local row back to `local-only`.
  Future<void> sendDisconnect(String contactId) async {
    final contact = await _contacts.get(contactId);
    if (contact == null || contact.kind != 'connected') {
      throw HandshakeOrchestratorError('unknown');
    }
    final peerPubB64 = contact.peerPublicMaterial;
    if (peerPubB64 == null || peerPubB64.isEmpty) {
      throw HandshakeOrchestratorError('unknown');
    }
    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    final peerPub = RelayRouting.unb64(peerPubB64);

    final frame = await EnvelopeCodec.encryptDisconnect(
      envelope: DisconnectEnvelope(senderLongTermPublicKey: selfPub),
      senderLongTermPrivateKey: selfPriv,
      peerLongTermPublicKey: peerPub,
    );
    final selfAddr = await RelayRouting.steadyStateAddress(
      firstPub: selfPub,
      secondPub: peerPub,
    );
    final peerAddr = await RelayRouting.steadyStateAddress(
      firstPub: peerPub,
      secondPub: selfPub,
    );

    try {
      await _relay.postEnvelope(
        senderIdentity: selfAddr,
        recipientIdentity: peerAddr,
        idempotencyKey: _randomBytes(16),
        ciphertext: frame,
        kind: EnvelopeKind.disconnect,
        ttl: _steadyTtl,
      );
      // Best-effort: also tell the relay our side is going down for this
      // pair, so future envelopes from us are rejected.
      await _relay.disconnectRouting(
        selfIdentity: selfAddr,
        peerIdentity: peerAddr,
      );
    } on RelayClientError catch (e) {
      throw HandshakeOrchestratorError('relay_error', e);
    } on RelayUnreachableException catch (e) {
      throw HandshakeOrchestratorError('relay_unavailable', e);
    } on TimeoutException catch (e) {
      throw HandshakeOrchestratorError('relay_unavailable', e);
    }

    await _contacts.demoteToLocalOnly(contactId);
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    requestClosedAppPushRegistrationSync();
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  Future<void> _decommissionHandshakeAddresses({
    required Uint8List addrInviter,
    required Uint8List addrInvitee,
  }) async {
    // The relay's /v1/disconnect marks a routing relationship as
    // "disconnecting": existing envelopes can still be ack'd but no new
    // ones will be accepted. We tear down both directions of the
    // handshake pair so a leaked code cannot inject further hellos.
    try {
      await _relay.disconnectRouting(
        selfIdentity: addrInvitee,
        peerIdentity: addrInviter,
      );
    } on RelayClientError catch (e) {
      debugPrint('handshake decommission (invitee->inviter) failed: $e');
    }
    try {
      await _relay.disconnectRouting(
        selfIdentity: addrInviter,
        peerIdentity: addrInvitee,
      );
    } on RelayClientError catch (e) {
      debugPrint('handshake decommission (inviter->invitee) failed: $e');
    }
  }

  /// Atomically moves a handshake from [expected] to [state]. Returns false when
  /// another poll already handled the same ack (prevents duplicate notifications).
  Future<bool> _claimHandshakeStateIf(
    String id, {
    required String expected,
    required String state,
    String? peerLongTermPublicMaterialB64,
  }) async {
    final now = _now().toUtc();
    final updated = await (_db.update(_db.pendingHandshakes)
          ..where((t) => t.id.equals(id) & t.state.equals(expected)))
        .write(
      PendingHandshakesCompanion(
        state: drift.Value(state),
        peerLongTermPublicMaterialB64: peerLongTermPublicMaterialB64 == null
            ? const drift.Value.absent()
            : drift.Value(peerLongTermPublicMaterialB64),
        updatedAt: drift.Value(now),
      ),
    );
    return updated > 0;
  }

  Future<void> _markHandshake(
    String id, {
    String? state,
    String? peerLongTermPublicMaterialB64,
    String? peerDisplayName,
    String? peerAvatarId,
    String? peerDeviceBindingId,
    String? lastErrorCode,
  }) async {
    final now = _now().toUtc();
    await (_db.update(
      _db.pendingHandshakes,
    )..where((t) => t.id.equals(id))).write(
      PendingHandshakesCompanion(
        state: state == null ? const drift.Value.absent() : drift.Value(state),
        peerLongTermPublicMaterialB64: peerLongTermPublicMaterialB64 == null
            ? const drift.Value.absent()
            : drift.Value(peerLongTermPublicMaterialB64),
        peerDisplayName: peerDisplayName == null
            ? const drift.Value.absent()
            : drift.Value(peerDisplayName),
        peerAvatarId: peerAvatarId == null
            ? const drift.Value.absent()
            : drift.Value(peerAvatarId),
        peerDeviceBindingId: peerDeviceBindingId == null
            ? const drift.Value.absent()
            : drift.Value(peerDeviceBindingId),
        lastErrorCode: lastErrorCode == null
            ? const drift.Value.absent()
            : drift.Value(lastErrorCode),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<String?> _deviceBindingDuplicateContactId({
    required String defaultStubId,
    required String peerDeviceBindingId,
  }) async {
    if (peerDeviceBindingId.isEmpty) return null;
    final connected = await _contacts.connectedByDeviceBinding(
      peerDeviceBindingId,
    );
    if (connected != null && connected.id != defaultStubId) {
      return connected.id;
    }
    return null;
  }

  Future<String> _resolveHandshakePromoteContactId({
    required String defaultStubId,
    required String peerPublicMaterialB64,
    required String peerDeviceBindingId,
    String? displayName,
    String? avatarId,
  }) async {
    final duplicateId = await _deviceBindingDuplicateContactId(
      defaultStubId: defaultStubId,
      peerDeviceBindingId: peerDeviceBindingId,
    );
    if (duplicateId != null) {
      return duplicateId;
    }
    final disconnected = await _contacts.disconnectedReconnectCandidate(
      peerPublicMaterialB64: peerPublicMaterialB64,
      displayName: displayName,
      avatarId: avatarId,
    );
    return disconnected?.id ?? defaultStubId;
  }

  Future<IncomingHandshakeView?> incomingHandshakeForContact(
    String contactId,
  ) async {
    await refreshIncomingHandshakes();
    for (final view in incomingHandshakes.value) {
      if (view.contactStubId == contactId) return view;
    }
    return null;
  }

  Future<void> refreshIncomingHandshakes() async {
    final rows = await _db.listPendingHandshakes(
      statesIn: const [HandshakeState.helloReceived],
    );
    final views = <IncomingHandshakeView>[];
    for (final row in rows) {
      if (row.role != HandshakeRole.inviter) continue;
      final peerPubB64 = row.peerLongTermPublicMaterialB64;
      if (peerPubB64 == null) continue;
      views.add(
        IncomingHandshakeView(
          handshakeId: row.id,
          invitationIdHex: row.invitationIdHex,
          peerDisplayName: row.peerDisplayName,
          peerAvatarId: row.peerAvatarId,
          peerPublicMaterialB64: peerPubB64,
          contactStubId: row.contactStubId,
          receivedAt: row.updatedAt,
        ),
      );
    }
    incomingHandshakes.value = List.unmodifiable(views);
  }

  String _pendingHandshakeId(String invitationIdHex, String role) =>
      '$invitationIdHex:$role';

  Uint8List _hexDecode(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  Uint8List _randomBytes(int count) {
    final r = Random.secure();
    final out = Uint8List(count);
    for (var i = 0; i < count; i++) {
      out[i] = r.nextInt(256);
    }
    return out;
  }

  /// Re-load the inviter's display name / avatar from a Contact row so
  /// the ack envelope carries them. Exposed as a hook so future updates
  /// to the local user's profile can flow through without rewiring.
  @visibleForTesting
  Future<({String displayName, String avatarId})> readLocalProfile(
    String stubContactId,
  ) async {
    final c = await _contacts.get(stubContactId);
    return (displayName: c?.displayName ?? '', avatarId: c?.avatarId ?? '');
  }

  Future<({String displayName, String avatarId})> _loadSelfProfileForAck() async {
    final prefs = await AppPreferences.load();
    return (
      displayName: prefs.displayName.isEmpty ? 'Unknown' : prefs.displayName,
      avatarId: prefs.avatarId.isEmpty ? 'a01' : prefs.avatarId,
    );
  }

  // ---------------------------------------------------------------------
  // Plan-mediated peer contact establishment
  // ---------------------------------------------------------------------

  /// Sends an encrypted establishment request to a missing plan co-participant
  /// whose public key was learned from `participantSnapshots`.
  Future<void> sendPlanPeerEstablishmentRequest({
    required String planId,
    required String participantId,
  }) async {
    final service = PlanPeerEstablishmentService(_db);
    final row = await service.rowForParticipant(
      planId: planId,
      participantId: participantId,
    );
    if (row == null) {
      throw HandshakeOrchestratorError(
        'missing_peer_key',
        StateError('No establishment row for $participantId'),
      );
    }
    if (row.outboundPendingAt != null) return;

    final selfProfile = await _loadSelfProfileForAck();
    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    final peerPub = RelayRouting.unb64(row.peerPublicMaterialB64);
    final selfAddr = await RelayRouting.steadyStateAddress(
      firstPub: selfPub,
      secondPub: peerPub,
    );
    final peerAddr = await RelayRouting.steadyStateAddress(
      firstPub: peerPub,
      secondPub: selfPub,
    );
    await _ensureSteadyRoutingRegistered(
      selfListenAddr: selfAddr,
      peerListenAddr: peerAddr,
    );

    final frame = await EnvelopeCodec.encryptContactEstablishmentRequest(
      envelope: ContactEstablishmentRequestEnvelope(
        senderLongTermPublicKey: selfPub,
        requesterDisplayName: selfProfile.displayName,
        requesterAvatarId: selfProfile.avatarId,
        proposerDisplayName: row.proposerDisplayName,
        receivedPlanId: planId,
        revisionId: row.revisionId ?? '',
      ),
      senderLongTermPrivateKey: selfPriv,
      peerLongTermPublicKey: peerPub,
    );

    try {
      await _relay.postEnvelope(
        senderIdentity: selfAddr,
        recipientIdentity: peerAddr,
        idempotencyKey: _randomBytes(16),
        ciphertext: frame,
        kind: EnvelopeKind.contactEstablishmentRequest,
        ttl: _steadyTtl,
      );
    } on RelayClientError catch (e) {
      throw HandshakeOrchestratorError('relay_error', e);
    }

    await service.markOutboundPending(row.id);
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    startPolling();
    requestClosedAppPushRegistrationSync();
  }

  /// Target accepts or refuses an inbound plan-mediated establishment request.
  Future<void> respondPlanPeerEstablishmentRequest({
    required String establishmentId,
    required bool accepted,
  }) async {
    final row = await _db.getPlanPeerEstablishment(establishmentId);
    if (row == null || row.inboundPendingAt == null) return;

    final service = PlanPeerEstablishmentService(_db);
    final selfProfile = await _loadSelfProfileForAck();
    final peerPub = RelayRouting.unb64(row.peerPublicMaterialB64);
    await _postContactEstablishmentResponse(
      peerPub: peerPub,
      accepted: accepted,
      responderDisplayName: selfProfile.displayName,
      responderAvatarId: selfProfile.avatarId,
    );

    await service.clearInboundPending(row.id);
    if (accepted) {
      await _promotePlanPeerContact(
        planId: row.planId,
        participantId: row.participantId,
        peerPub: peerPub,
        peerDisplayName: row.inboundRequesterDisplayName ?? row.peerDisplayName,
        peerAvatarId: row.inboundRequesterAvatarId ?? row.peerAvatarId,
      );
      await _contactNotifications.contactAddRequestResolved(
        displayName: row.inboundRequesterDisplayName ?? row.peerDisplayName,
        accepted: true,
      );
    }
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
    startPolling();
    requestClosedAppPushRegistrationSync();
  }

  Future<void> _handleInboundContactEstablishmentRequest({
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
    required PlanPeerEstablishment? establishment,
  }) async {
    final ContactEstablishmentRequestEnvelope decrypted;
    try {
      decrypted = await EnvelopeCodec.decryptContactEstablishmentRequest(
        frame: envelope.ciphertext,
        receiverLongTermPrivateKey: selfPriv,
      );
    } on EnvelopeDecryptionError {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }

    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );

    final peerB64 = RelayRouting.b64(peerPub);
    final service = PlanPeerEstablishmentService(_db);
    var row =
        establishment ??
        await _db.getPlanPeerEstablishmentByPeer(peerB64) ??
        await _findEstablishmentRowForPeer(planIdHint: decrypted.receivedPlanId, peerB64: peerB64);

    if (row != null && row.outboundPendingAt != null) {
      final selfProfile = await _loadSelfProfileForAck();
      if (planMediatedPeerNameMismatch(
        storedName: row.peerDisplayName,
        incomingName: decrypted.requesterDisplayName,
      )) {
        await reconcilePlanMediatedPeerIdentity(
          db: _db,
          peerPublicMaterialB64: peerB64,
          displayName: decrypted.requesterDisplayName,
          avatarId: decrypted.requesterAvatarId,
          planId: row.planId,
          participantId: row.participantId,
        );
      }
      await _postContactEstablishmentResponse(
        peerPub: peerPub,
        accepted: true,
        responderDisplayName: selfProfile.displayName,
        responderAvatarId: selfProfile.avatarId,
      );
      await service.clearOutboundPending(row.id);
      await _promotePlanPeerContact(
        planId: row.planId,
        participantId: row.participantId,
        peerPub: peerPub,
        peerDisplayName: decrypted.requesterDisplayName,
        peerAvatarId: decrypted.requesterAvatarId,
      );
      steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
      return;
    }

    if (row == null) {
      final planId = decrypted.receivedPlanId;
      if (planId.isEmpty) return;
      final participantId = await _participantIdForPeerOnPlan(planId, peerB64);
      if (participantId == null) return;
      final rowId = '$planId:${participantId.split(':').last}';
      final now = DateTime.now().toUtc();
      await _db.upsertPlanPeerEstablishment(
        PlanPeerEstablishmentsCompanion.insert(
          id: rowId,
          planId: planId,
          participantId: participantId,
          peerPublicMaterialB64: peerB64,
          peerDisplayName: decrypted.requesterDisplayName,
          peerAvatarId: decrypted.requesterAvatarId,
          proposerDisplayName: decrypted.proposerDisplayName,
          revisionId: drift.Value(
            decrypted.revisionId.isEmpty ? null : decrypted.revisionId,
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );
      row = await _db.getPlanPeerEstablishment(rowId);
    }
    if (row == null) return;

    if (planMediatedPeerNameMismatch(
      storedName: row.peerDisplayName,
      incomingName: decrypted.requesterDisplayName,
    )) {
      await reconcilePlanMediatedPeerIdentity(
        db: _db,
        peerPublicMaterialB64: peerB64,
        displayName: decrypted.requesterDisplayName,
        avatarId: decrypted.requesterAvatarId,
        planId: row.planId,
        participantId: row.participantId,
      );
      row = await _db.getPlanPeerEstablishment(row.id);
      if (row == null) return;
    }

    await service.markInboundPending(
      establishmentId: row.id,
      requesterDisplayName: decrypted.requesterDisplayName,
      requesterAvatarId: decrypted.requesterAvatarId,
    );
    await _contactNotifications.planPeerEstablishmentRequestReceived(
      requesterDisplayName: decrypted.requesterDisplayName,
      proposerDisplayName: decrypted.proposerDisplayName,
      planId: row.planId,
    );
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
  }

  Future<void> _handleInboundContactEstablishmentResponse({
    required RelayEnvelopeView envelope,
    required Uint8List myListenAddr,
    required Uint8List selfPriv,
    required Uint8List peerPub,
    required PlanPeerEstablishment? establishment,
  }) async {
    final ContactEstablishmentResponseEnvelope decrypted;
    try {
      decrypted = await EnvelopeCodec.decryptContactEstablishmentResponse(
        frame: envelope.ciphertext,
        receiverLongTermPrivateKey: selfPriv,
      );
    } on EnvelopeDecryptionError {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }
    if (!_bytesEqual(decrypted.senderLongTermPublicKey, peerPub)) {
      await _relay.ackEnvelope(
        envelopeId: envelope.envelopeId,
        recipient: myListenAddr,
      );
      return;
    }

    await _relay.ackEnvelope(
      envelopeId: envelope.envelopeId,
      recipient: myListenAddr,
    );

    final peerB64 = RelayRouting.b64(peerPub);
    final service = PlanPeerEstablishmentService(_db);
    var row =
        establishment ??
        await _db.getPlanPeerEstablishmentByPeer(peerB64);
    if (row == null) return;

    await service.clearOutboundPending(row.id);
    if (decrypted.accepted) {
      final responderName = decrypted.responderDisplayName.isEmpty
          ? row.peerDisplayName
          : decrypted.responderDisplayName;
      final responderAvatar = decrypted.responderAvatarId.isEmpty
          ? row.peerAvatarId
          : decrypted.responderAvatarId;
      if (planMediatedPeerNameMismatch(
        storedName: row.peerDisplayName,
        incomingName: responderName,
      )) {
        await reconcilePlanMediatedPeerIdentity(
          db: _db,
          peerPublicMaterialB64: peerB64,
          displayName: responderName,
          avatarId: responderAvatar,
          planId: row.planId,
          participantId: row.participantId,
        );
        row = await _db.getPlanPeerEstablishment(row.id);
        if (row == null) return;
      }
      await _promotePlanPeerContact(
        planId: row.planId,
        participantId: row.participantId,
        peerPub: peerPub,
        peerDisplayName: responderName,
        peerAvatarId: responderAvatar,
      );
      await _contactNotifications.contactAddRequestResolved(
        displayName: responderName,
        accepted: true,
      );
    } else {
      await service.markRefused(row.id, DateTime.now().toUtc());
      await _contactNotifications.contactAddRequestResolved(
        displayName: row.peerDisplayName,
        accepted: false,
      );
    }
    steadyStateInboxTick.value = steadyStateInboxTick.value + 1;
  }

  Future<void> _postContactEstablishmentResponse({
    required Uint8List peerPub,
    required bool accepted,
    required String responderDisplayName,
    required String responderAvatarId,
  }) async {
    final selfPriv = await _identity.loadOrCreatePrivateKey();
    final selfPub = await _identity.publicKey();
    final selfAddr = await RelayRouting.steadyStateAddress(
      firstPub: selfPub,
      secondPub: peerPub,
    );
    final peerAddr = await RelayRouting.steadyStateAddress(
      firstPub: peerPub,
      secondPub: selfPub,
    );
    await _ensureSteadyRoutingRegistered(
      selfListenAddr: selfAddr,
      peerListenAddr: peerAddr,
    );
    final frame = await EnvelopeCodec.encryptContactEstablishmentResponse(
      envelope: ContactEstablishmentResponseEnvelope(
        senderLongTermPublicKey: selfPub,
        accepted: accepted,
        responderDisplayName: responderDisplayName,
        responderAvatarId: responderAvatarId,
      ),
      senderLongTermPrivateKey: selfPriv,
      peerLongTermPublicKey: peerPub,
    );
    await _relay.postEnvelope(
      senderIdentity: selfAddr,
      recipientIdentity: peerAddr,
      idempotencyKey: _randomBytes(16),
      ciphertext: frame,
      kind: EnvelopeKind.contactEstablishmentResponse,
      ttl: _steadyTtl,
    );
  }

  Future<void> _promotePlanPeerContact({
    required String planId,
    required String participantId,
    required Uint8List peerPub,
    required String peerDisplayName,
    required String peerAvatarId,
  }) async {
    final peerB64 = RelayRouting.b64(peerPub);
    final selfPub = await _identity.publicKey();
    final peerListenAddr = await RelayRouting.steadyStateAddress(
      firstPub: peerPub,
      secondPub: selfPub,
    );
    final selfListenAddr = await RelayRouting.steadyStateAddress(
      firstPub: selfPub,
      secondPub: peerPub,
    );
    await _ensureSteadyRoutingRegistered(
      selfListenAddr: selfListenAddr,
      peerListenAddr: peerListenAddr,
    );

    final reconnect = await _contacts.disconnectedReconnectCandidate(
      peerPublicMaterialB64: peerB64,
      displayName: peerDisplayName,
      avatarId: peerAvatarId,
    );
    final stubId =
        reconnect?.id ??
        'contact:plan-est:${participantId.replaceAll(':', '_')}';
    if (reconnect == null) {
      final existing = await _contacts.get(stubId);
      if (existing == null) {
        await _contacts.upsertLocalOnly(
          id: stubId,
          displayName: peerDisplayName,
          avatarId: peerAvatarId,
        );
      }
    }

    await _contacts.promoteToConnected(
      id: stubId,
      relayRoutingIdB64: RelayRouting.b64(peerListenAddr),
      peerPublicMaterialB64: peerB64,
      displayName: peerDisplayName,
      avatarId: peerAvatarId,
    );

    await (_db.update(_db.participants)..where((t) => t.id.equals(participantId)))
        .write(ParticipantsCompanion(contactId: drift.Value(stubId)));

    final rowId = '$planId:${participantId.split(':').last}';
    await PlanPeerEstablishmentService(_db).removeRow(rowId);
  }

  Future<PlanPeerEstablishment?> _findEstablishmentRowForPeer({
    required String planIdHint,
    required String peerB64,
  }) async {
    if (planIdHint.isNotEmpty) {
      final rows = await _db.listPlanPeerEstablishmentsForPlan(planIdHint);
      for (final row in rows) {
        if (row.peerPublicMaterialB64 == peerB64) return row;
      }
    }
    return _db.getPlanPeerEstablishmentByPeer(peerB64);
  }

  Future<String?> _participantIdForPeerOnPlan(
    String planId,
    String peerB64,
  ) async {
    final rows = await _db.listPlanPeerEstablishmentsForPlan(planId);
    for (final row in rows) {
      if (row.peerPublicMaterialB64 == peerB64) return row.participantId;
    }
    return null;
  }

  Future<HousingPaymentReminderService> _housingPaymentReminderService() async {
    if (_cachedReminderService != null) return _cachedReminderService!;
    _cachedPrefs ??= await AppPreferences.load();
    _cachedReminderService = HousingPaymentReminderService(
      db: _db,
      relay: _relay,
      prefs: _cachedPrefs!,
      orchestrator: this,
      contacts: _contacts,
    );
    return _cachedReminderService!;
  }

  Future<void> _pollHousingPaymentReminders() async {
    if (kIsWeb) return;
    try {
      final service = await _housingPaymentReminderService();
      await service.pollAndDeliverPendingReminders();
    } catch (e, st) {
      debugPrint('pollHousingPaymentReminders: $e\n$st');
    }
  }

  Future<void> _reconcileHousingPaymentRemindersAfterActivation({
    required String planId,
    required String revisionId,
  }) async {
    if (kIsWeb) return;
    final service = await _housingPaymentReminderService();
    await service.upsertSelfTimezoneOnRelay();
    final selfPub = await selfLongTermPublicKey();
    final peers = await _db.listPlanPeerEstablishmentsForPlan(planId);
    Uint8List? senderRouting;
    for (final row in peers) {
      try {
        final peerPub = RelayRouting.unb64(row.peerPublicMaterialB64);
        senderRouting = await RelayRouting.steadyStateAddress(
          firstPub: selfPub,
          secondPub: peerPub,
        );
        break;
      } catch (_) {
        continue;
      }
    }
    if (senderRouting == null) return;
    await service.reconcilePlanSchedule(
      planId: planId,
      revisionId: revisionId,
      senderRoutingId: senderRouting,
    );
  }

  Future<void> _maybeReconcileHousingRemindersAfterExpenseAccept({
    required String expenseId,
    required String participantId,
  }) async {
    if (kIsWeb) return;
    final expense = await RealizedExpenseRepository(_db).getById(expenseId);
    if (expense == null ||
        expense.status != RealizedExpenseStatus.published) {
      return;
    }
    final service = await _housingPaymentReminderService();
    final selfPub = await selfLongTermPublicKey();
    final peers = await _db.listPlanPeerEstablishmentsForPlan(expense.planId);
    Uint8List? senderRouting;
    for (final row in peers) {
      try {
        final peerPub = RelayRouting.unb64(row.peerPublicMaterialB64);
        senderRouting = await RelayRouting.steadyStateAddress(
          firstPub: selfPub,
          secondPub: peerPub,
        );
        break;
      } catch (_) {
        continue;
      }
    }
    if (senderRouting == null) return;
    await service.reconcilePlanSchedule(
      planId: expense.planId,
      revisionId: 'coverage:$expenseId',
      senderRoutingId: senderRouting,
    );
  }

  /// Task 2.2b — relay timezone upsert when user changes notification timezone.
  Future<void> syncHousingPaymentReminderTimezone() async {
    if (kIsWeb) return;
    try {
      final service = await _housingPaymentReminderService();
      await service.onTimeZonePreferenceChanged();
    } catch (e, st) {
      debugPrint('syncHousingPaymentReminderTimezone: $e\n$st');
    }
  }

}
