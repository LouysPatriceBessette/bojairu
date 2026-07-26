import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';

import '../contacts/contact_invitations_repository.dart';
import '../contacts/invitation_code.dart';
import '../db/app_database.dart';
import '../db/repositories/contacts_repository.dart';
import '../device/device_binding_service.dart';
import '../housing/housing_plan_id.dart';
import '../housing/realized_expense/realized_expense_participants.dart';
import '../housing/realized_expense/realized_expense_repository.dart';
import '../housing/realized_expense/realized_expense_status.dart';
import '../housing/realized_expense/realized_expense_sync_service.dart';
import '../housing/proposals/housing_proposal_revision_state.dart';
import '../housing/proposals/housing_proposal_transport_service.dart';
import '../housing/proposals/plan_agreement_proposal_service.dart';
import '../notifications/push_notification_service.dart';
import '../prefs/app_preferences.dart';
import '../relay/handshake_orchestrator.dart';
import '../relay/identity_keystore.dart';
import '../relay/routing.dart';
import '../relay/testing/fake_relay_client.dart';
import 'sandbox_bot_catalog.dart';
import 'sandbox_mode.dart';
import 'sandbox_relay.dart';

class _SandboxDb extends AppDatabase {
  _SandboxDb(super.e) : super.forTesting();
}

/// One simulated peer installation in the same process.
class SandboxBotPeer {
  SandboxBotPeer({
    required this.displayName,
    required this.avatarId,
    required this.db,
    required this.dbFile,
    required this.identity,
    required this.orchestrator,
    required this.contacts,
  });

  final String displayName;
  final String avatarId;
  final AppDatabase db;
  final File dbFile;
  final IdentityKeystore identity;
  final HandshakeOrchestrator orchestrator;
  final ContactsRepository contacts;
}

/// Spawns bot peers on [SandboxRelay], auto-accepts in-scope peer decisions.
class PeerSimulator {
  PeerSimulator._({
    required FakeRelayClient relay,
    required AppPreferences prefs,
  }) : _relay = relay,
       _prefs = prefs;

  static PeerSimulator? _instance;

  static PeerSimulator? get maybeInstance => _instance;

  static PeerSimulator get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('PeerSimulator.install(...) during sandbox bootstrap.');
    }
    return i;
  }

  static PeerSimulator install({
    required FakeRelayClient relay,
    required AppPreferences prefs,
  }) {
    _instance?.dispose();
    final sim = PeerSimulator._(relay: relay, prefs: prefs);
    _instance = sim;
    relay.onEnvelopeStored = sim._onEnvelopeStored;
    return sim;
  }

  static PeerSimulator ensureInstalled({
    required FakeRelayClient relay,
    required AppPreferences prefs,
  }) {
    final current = _instance;
    if (current != null && identical(current._relay, relay)) {
      return current;
    }
    return install(relay: relay, prefs: prefs);
  }

  static void clearInstalled() {
    _instance?.dispose();
    _instance = null;
  }

  static const Duration _reactDebounce = Duration(milliseconds: 200);
  static const Duration _realizedExpenseBotDecisionDelay = Duration(seconds: 1);

  final FakeRelayClient _relay;
  final AppPreferences _prefs;
  final List<SandboxBotPeer> _bots = <SandboxBotPeer>[];
  final Set<String> _realizedExpenseReviewSequencesInFlight = <String>{};
  Timer? _reactDebounceTimer;
  bool _reactRunning = false;
  bool _reactNeededAfterRun = false;
  int _reactionsPaused = 0;
  bool _disposed = false;
  int _botSeq = 0;

  /// Test/observability: bot↔bot connect attempts (mesh at invite only).
  @visibleForTesting
  int botPairConnectAttempts = 0;

  List<SandboxBotPeer> get bots => List.unmodifiable(_bots);

  int get invitedCount => _bots.length;

  /// Rebuild in-memory bot peers after a process cold start.
  ///
  /// Human SQLite + [AppPreferences.sandboxInvitedBotCount] survive APK
  /// reinstall / process death; [SandboxRelay] and bot DBs do not. Catalog
  /// bots use deterministic identity seeds, so respawning catalogue index `i`
  /// restores the same long-term keys as the persisted human contacts.
  ///
  /// Catalogue slots without a matching **connected** human contact (deleted,
  /// disconnected, or never completed) are **skipped** — remaining connected
  /// bots are still restored. Do not abort the whole restore on one miss.
  Future<int> restoreInvitedBotsIfNeeded({
    required HandshakeOrchestrator humanOrchestrator,
  }) async {
    if (_disposed) return 0;
    if (!SandboxMode.isActive(_prefs)) return 0;
    if (_bots.isNotEmpty) return _bots.length;

    final target = _prefs.sandboxInvitedBotCount.clamp(
      0,
      SandboxBotCatalog.maxBots,
    );
    if (target <= 0) return 0;

    final humanDb = AppDatabase.maybeProcessScope;
    if (humanDb == null) {
      debugPrint('PeerSimulator restore skipped: no human AppDatabase');
      return 0;
    }
    final humanContacts = ContactsRepository(humanDb);
    final humanRows = await humanContacts.list();
    final humanPub = await humanOrchestrator.selfLongTermPublicKey();
    final humanPubB64 = RelayRouting.b64(humanPub);
    final humanName = _prefs.displayName.trim().isEmpty
        ? 'Human'
        : _prefs.displayName.trim();
    final humanAvatar = _prefs.avatarId.trim().isEmpty
        ? 'mdi:0'
        : _prefs.avatarId.trim();

    debugPrint('PeerSimulator restore start target=$target');
    pauseReactions();
    try {
      for (var i = 0; i < target; i++) {
        final name = SandboxBotCatalog.displayNames[i];
        final avatar = SandboxBotCatalog.avatarIdForCatalogIndex(i);
        final bot = await _spawnBot(
          displayName: name,
          avatarId: avatar,
          catalogIndex: i,
        );
        final botPubB64 = await bot.identity.publicKeyB64();
        final matched = humanRows.any(
          (c) =>
              c.kind == 'connected' &&
              (c.peerPublicMaterial ?? '') == botPubB64,
        );
        if (!matched) {
          debugPrint(
            'PeerSimulator restore: skip $name (no connected human '
            'contact for catalogue index $i)',
          );
          await _disposeBotPeer(bot);
          continue;
        }
        await _injectConnectedPeer(
          owner: bot,
          contactId: 'contact:sandbox:restored:human',
          peerPublicKey: humanPub,
          peerPublicB64: humanPubB64,
          displayName: humanName,
          avatarId: humanAvatar,
        );
        _bots.add(bot);
      }

      for (var i = 0; i < _bots.length; i++) {
        for (var j = i + 1; j < _bots.length; j++) {
          await _rebindBotPair(a: _bots[i], b: _bots[j]);
        }
      }
    } finally {
      resumeReactions();
    }

    debugPrint('PeerSimulator restore end bots=${_bots.length}');
    return _bots.length;
  }

  /// Suppress inbox reactions while the human send path posts envelopes.
  void pauseReactions() {
    _reactionsPaused++;
    _reactDebounceTimer?.cancel();
    _reactDebounceTimer = null;
  }

  /// Resume reactions and schedule one coalesced [reactOnce] if paused depth hits 0.
  void resumeReactions() {
    if (_reactionsPaused > 0) {
      _reactionsPaused--;
    }
    if (_reactionsPaused == 0) {
      _scheduleReactDebounced();
    }
  }

  void dispose() {
    _disposed = true;
    _reactDebounceTimer?.cancel();
    _reactDebounceTimer = null;
    _relay.onEnvelopeStored = null;
    for (final bot in _bots) {
      bot.orchestrator.stopPolling();
      unawaited(bot.db.close());
      try {
        if (bot.dbFile.existsSync()) bot.dbFile.deleteSync();
      } catch (_) {}
    }
    _bots.clear();
  }

  void _onEnvelopeStored() {
    if (_disposed) return;
    if (_reactionsPaused > 0) return;
    _scheduleReactDebounced();
  }

  void _scheduleReactDebounced() {
    if (_disposed) return;
    if (_reactionsPaused > 0) return;
    _reactDebounceTimer?.cancel();
    _reactDebounceTimer = Timer(_reactDebounce, () {
      _reactDebounceTimer = null;
      unawaited(_runReactSerialized());
    });
  }

  Future<void> _runReactSerialized() async {
    if (_disposed || _reactionsPaused > 0) return;
    if (_reactRunning) {
      _reactNeededAfterRun = true;
      return;
    }
    _reactRunning = true;
    try {
      do {
        _reactNeededAfterRun = false;
        await reactOnce();
      } while (_reactNeededAfterRun && !_disposed && _reactionsPaused == 0);
    } finally {
      _reactRunning = false;
    }
  }

  /// Poll bot + human inboxes and auto-accept pending housing proposals.
  ///
  /// Does not heal bot↔bot mesh (that runs only in [inviteNextBot]).
  Future<void> reactOnce() async {
    if (_disposed) return;
    final sw = Stopwatch()..start();
    debugPrint('PeerSimulator react start bots=${_bots.length}');
    var acceptedAnyProposal = false;
    for (final bot in List<SandboxBotPeer>.from(_bots)) {
      try {
        await bot.orchestrator.processAllPendingHandshakes();
        await bot.orchestrator.pollSteadyStateInboxes();
        if (acceptedAnyProposal &&
            _realizedExpenseBotDecisionDelay > Duration.zero) {
          debugPrint(
            'PeerSimulator proposal/amendment betweenBotDelay='
            '${_realizedExpenseBotDecisionDelay.inMilliseconds}ms '
            'before ${bot.displayName}',
          );
          await Future<void>.delayed(_realizedExpenseBotDecisionDelay);
        }
        final accepted = await _autoAcceptPendingProposals(bot);
        if (accepted) acceptedAnyProposal = true;
        // Expense propose import requires activeRevisionId; sandbox mesh can
        // leave a bot pending-only after peers already activated.
        await _ensureBotPendingHousingPlansActivated(bot);
      } catch (e, st) {
        debugPrint(
          'PeerSimulator bot ${bot.displayName} react failed: $e\n$st',
        );
      }
    }
    final human = HandshakeOrchestrator.maybeInstance;
    if (human != null) {
      try {
        await human.processAllPendingHandshakes();
        await human.pollSteadyStateInboxes();
      } catch (e, st) {
        debugPrint('PeerSimulator human poll failed: $e\n$st');
      }
    }
    sw.stop();
    debugPrint('PeerSimulator react end ${sw.elapsedMilliseconds}ms');
  }

  /// After a realized expense needs peer reviews, each bot that still must
  /// accept does so in order (1s after trigger, then 1s between bots).
  ///
  /// Used both when the human reviews a bot expense and when the human
  /// proposes an expense that bots must accept.
  Future<void> acceptPendingRealizedExpenseReviewsAfterHumanDecision({
    required String expenseId,
    Duration initialDelay = _realizedExpenseBotDecisionDelay,
    Duration betweenBotDelay = _realizedExpenseBotDecisionDelay,
  }) async {
    if (_disposed) return;
    if (!_realizedExpenseReviewSequencesInFlight.add(expenseId)) {
      debugPrint(
        'PeerSimulator realized-expense review $expenseId already in flight',
      );
      return;
    }
    pauseReactions();
    try {
      await _acceptPendingRealizedExpenseReviewsBody(
        expenseId: expenseId,
        initialDelay: initialDelay,
        betweenBotDelay: betweenBotDelay,
      );
    } finally {
      resumeReactions();
      _realizedExpenseReviewSequencesInFlight.remove(expenseId);
    }
  }

  Future<void> _acceptPendingRealizedExpenseReviewsBody({
    required String expenseId,
    required Duration initialDelay,
    required Duration betweenBotDelay,
  }) async {
    if (_disposed) return;
    if (initialDelay > Duration.zero) {
      debugPrint(
        'PeerSimulator realized-expense review $expenseId '
        'initialDelay=${initialDelay.inMilliseconds}ms',
      );
      await Future<void>.delayed(initialDelay);
    }

    final humanIsPayer = await _humanIsPayerOfExpense(expenseId);
    var acceptedAnyBot = false;
    for (final bot in List<SandboxBotPeer>.from(_bots)) {
      if (_disposed) return;
      try {
        await bot.orchestrator.pollSteadyStateInboxes();
        // Propose delivery can miss a peer; backfill from the payer's local
        // copy (bot or human) so every pending reviewer can still accept.
        await _ensureBotHasRealizedExpense(bot, expenseId: expenseId);
        final needsAccept = await _botStillNeedsToAcceptRealizedExpense(
          bot,
          expenseId: expenseId,
        );
        // Bot may already have accepted locally while the human never got the
        // decision envelope (mesh miss / mapping skip) — re-send when the
        // human review table still shows this bot pending.
        final humanAwaits = await _humanStillAwaitsBotDecision(
          bot,
          expenseId: expenseId,
        );
        final hasExpense =
            await RealizedExpenseRepository(bot.db).getById(expenseId) != null;
        debugPrint(
          'PeerSimulator realized-expense review $expenseId bot='
          '${bot.displayName} hasExpense=$hasExpense needsAccept=$needsAccept '
          'humanAwaits=$humanAwaits',
        );
        if (!needsAccept && !humanAwaits) continue;
        if (!hasExpense) {
          debugPrint(
            'PeerSimulator realized-expense review $expenseId bot='
            '${bot.displayName} skip: missing expense after backfill',
          );
          continue;
        }
        if (acceptedAnyBot && betweenBotDelay > Duration.zero) {
          debugPrint(
            'PeerSimulator realized-expense review $expenseId '
            'betweenBotDelay=${betweenBotDelay.inMilliseconds}ms '
            'before ${bot.displayName}',
          );
          await Future<void>.delayed(betweenBotDelay);
        }
        if (_disposed) return;
        await _acceptPendingRealizedExpense(bot, expenseId: expenseId);
        acceptedAnyBot = true;
        final human = HandshakeOrchestrator.maybeInstance;
        await human?.pollSteadyStateInboxes();
        // When the human is the payer, the inbound accept handler already
        // notifies. When the human is only a reviewer (bot expense), that
        // payer gate never fires — surface each bot accept explicitly.
        if (!humanIsPayer) {
          try {
            final humanDb = AppDatabase.maybeProcessScope;
            String expenseKind = RealizedExpenseKind.normal;
            String? payerDisplayName;
            if (humanDb != null) {
              final humanExpense = await RealizedExpenseRepository(
                humanDb,
              ).getById(expenseId);
              if (humanExpense != null) {
                expenseKind = humanExpense.kind;
                final roster = await participantsForPlan(
                  humanDb,
                  humanExpense.planId,
                );
                payerDisplayName = displayNameForParticipant(
                  humanExpense.payerParticipantId,
                  roster,
                );
              }
            }
            await PushNotificationService.showLocalHousingRealizedExpenseAcceptedNotification(
              senderDisplayName: bot.displayName,
              expenseId: expenseId,
              expenseKind: expenseKind,
              localUserIsPayer: false,
              payerDisplayName: payerDisplayName,
            );
          } catch (e, st) {
            debugPrint(
              'PeerSimulator bot ${bot.displayName} accept notification '
              'failed for $expenseId: $e\n$st',
            );
          }
        }
      } catch (e, st) {
        debugPrint(
          'PeerSimulator bot ${bot.displayName} realized-expense review '
          'failed for $expenseId: $e\n$st',
        );
      }
    }
  }

  Future<bool> _humanIsPayerOfExpense(String expenseId) async {
    final humanDb = AppDatabase.maybeProcessScope;
    if (humanDb == null) return false;
    final expense = await RealizedExpenseRepository(humanDb).getById(expenseId);
    if (expense == null) return false;
    final selfId = selfParticipantIdForPlan(expense.planId);
    return expense.payerParticipantId == selfId;
  }

  /// Imports [expenseId] onto [bot] from the payer (bot or human) when inbox
  /// delivery did not leave a local row (sandbox mesh gap).
  Future<bool> _ensureBotHasRealizedExpense(
    SandboxBotPeer bot, {
    required String expenseId,
  }) async {
    final repo = RealizedExpenseRepository(bot.db);
    if (await repo.getById(expenseId) != null) return true;

    await bot.orchestrator.pollSteadyStateInboxes();
    if (await repo.getById(expenseId) != null) return true;

    final source = await _expenseProposeSource(expenseId);
    if (source == null) {
      debugPrint(
        'PeerSimulator cannot backfill expense $expenseId for '
        '${bot.displayName}: no payer source',
      );
      return false;
    }
    if (identical(source.db, bot.db)) return true;

    final sourceRepo = RealizedExpenseRepository(source.db);
    final expense = await sourceRepo.getById(expenseId);
    if (expense == null) return false;

    // Bots store the agreement as received:<uuid>; human uses housing:<uuid>.
    final botPlanId = expense.planId.startsWith(kReceivedPlanIdPrefix)
        ? expense.planId
        : receivedPlanIdForAuthorPlan(expense.planId);
    await _ensureBotHousingPlanActive(bot, planId: botPlanId);

    final attachments = await sourceRepo.attachmentsFor(expenseId);
    final expenseJson = await RealizedExpenseSyncService(
      source.db,
    ).buildProposeJson(expense: expense, attachments: attachments);

    final contacts = await bot.contacts.list();
    final senderContact = contacts
        .where(
          (c) =>
              c.kind == 'connected' &&
              (c.peerPublicMaterial ?? '') == source.publicKeyB64,
        )
        .firstOrNull;
    if (senderContact == null) {
      debugPrint(
        'PeerSimulator ${bot.displayName} has no connected contact for '
        'payer ${source.label}; cannot backfill $expenseId',
      );
      return false;
    }

    final imported = await RealizedExpenseSyncService(bot.db)
        .importProposedFromPeer(
          expenseJson: expenseJson,
          senderContactId: senderContact.id,
        );
    final hasExpense = await repo.getById(expenseId) != null;
    debugPrint(
      'PeerSimulator backfill expense $expenseId for ${bot.displayName} '
      'from ${source.label} imported=$imported hasExpense=$hasExpense',
    );
    return hasExpense;
  }

  Future<({AppDatabase db, String publicKeyB64, String label})?>
  _expenseProposeSource(String expenseId) async {
    for (final bot in List<SandboxBotPeer>.from(_bots)) {
      final expense = await RealizedExpenseRepository(
        bot.db,
      ).getById(expenseId);
      if (expense == null) continue;
      final selfId = selfParticipantIdForPlan(expense.planId);
      if (expense.payerParticipantId != selfId) continue;
      return (
        db: bot.db,
        publicKeyB64: await bot.identity.publicKeyB64(),
        label: bot.displayName,
      );
    }

    final human = HandshakeOrchestrator.maybeInstance;
    if (human == null) return null;
    final humanDb = AppDatabase.maybeProcessScope;
    if (humanDb == null) return null;
    final expense = await RealizedExpenseRepository(humanDb).getById(expenseId);
    if (expense == null) return null;
    final selfId = selfParticipantIdForPlan(expense.planId);
    if (expense.payerParticipantId == selfId) {
      final pub = await human.selfLongTermPublicKey();
      return (
        db: humanDb,
        publicKeyB64: base64Url.encode(pub).replaceAll('=', ''),
        label: 'human',
      );
    }

    // Bot payer row was wiped (cold restore recreates empty bot sqlite) while
    // the human still holds the imported propose. Backfill peers from that
    // human copy, using the payer bot's long-term key as the synthetic sender
    // so importProposedFromPeer maps the payer correctly.
    final roster = await participantsForPlan(humanDb, expense.planId);
    final payerName = displayNameForParticipant(
      expense.payerParticipantId,
      roster,
    ).trim().toLowerCase();
    if (payerName.isEmpty) return null;
    for (final bot in List<SandboxBotPeer>.from(_bots)) {
      if (bot.displayName.trim().toLowerCase() != payerName) continue;
      return (
        db: humanDb,
        publicKeyB64: await bot.identity.publicKeyB64(),
        label: '${bot.displayName} via human copy',
      );
    }
    return null;
  }

  /// True when the human review table still shows [bot] as pending/unanswered.
  Future<bool> _humanStillAwaitsBotDecision(
    SandboxBotPeer bot, {
    required String expenseId,
  }) async {
    final humanDb = AppDatabase.maybeProcessScope;
    if (humanDb == null) return false;
    final expense = await RealizedExpenseRepository(humanDb).getById(expenseId);
    if (expense == null) return false;
    final roster = await participantsForPlan(humanDb, expense.planId);
    final botName = bot.displayName.trim().toLowerCase();
    Participant? botParticipant;
    for (final p in roster) {
      if (p.displayName.trim().toLowerCase() != botName) continue;
      botParticipant = p;
      break;
    }
    if (botParticipant == null) return false;
    if (expense.payerParticipantId == botParticipant.id) return false;
    final repo = RealizedExpenseRepository(humanDb);
    if (!repo.isTransferReviewParticipant(expense, botParticipant.id)) {
      return false;
    }
    final decision = (await repo.acceptancesFor(expenseId))
        .where((a) => a.participantId == botParticipant!.id)
        .map((a) => a.decision)
        .firstOrNull;
    return decision == null || decision == RealizedExpenseDecision.pending;
  }

  Future<void> _ensureBotPendingHousingPlansActivated(SandboxBotPeer bot) async {
    final plans = await bot.db.listPlans();
    for (final plan in plans) {
      if (plan.type != 'housing') continue;
      await _ensureBotHousingPlanActive(bot, planId: plan.id);
    }
  }

  /// Ensures [bot] has [ProposalPackage.activeRevisionId] for [planId].
  ///
  /// Terminal evidence (2026-07-16): Ròberr stayed pending-only after peers
  /// activated, so expense propose/backfill hit
  /// `import skip: no local active agreement`.
  Future<bool> _ensureBotHousingPlanActive(
    SandboxBotPeer bot, {
    required String planId,
  }) async {
    final transport = HousingProposalTransportService(bot.db);
    if (await transport.hasActiveRevision(planId)) return true;

    final pendingId = await transport.pendingRevisionIdForPlan(planId);
    if (pendingId != null) {
      final outcome = await transport.tryActivatePlanIfUnanimous(
        planId: planId,
        revisionId: pendingId,
      );
      if (outcome == ProposalActivationOutcome.activated) {
        debugPrint(
          'PeerSimulator ${bot.displayName} repaired activation for $planId',
        );
        return true;
      }
    }

    // Another bot already activated the same received plan; mirror locally so
    // expense import can proceed (sandbox mesh race).
    String? peerActiveRevisionId;
    for (final peer in List<SandboxBotPeer>.from(_bots)) {
      if (identical(peer, bot)) continue;
      final peerTransport = HousingProposalTransportService(peer.db);
      final activeId = await peerTransport.resolveActiveRevisionIdForPlan(
        planId,
      );
      if (activeId != null && activeId.isNotEmpty) {
        peerActiveRevisionId = activeId;
        break;
      }
    }
    if (peerActiveRevisionId != null) {
      final revisionId = pendingId ?? peerActiveRevisionId;
      final mirrored = await _forceActivateBotRevision(
        bot,
        planId: planId,
        revisionId: revisionId,
        reason: 'peer mirror',
      );
      if (mirrored) return true;
      // Peer has an active revision id this bot never imported (cold restore:
      // first bot got a human agreement mirror; later bots only see that peer
      // active id and hit "missing revision"). Fall through to human clone.
    }

    // Cold restore: every bot sqlite is empty and FakeRelay lost in-memory
    // envelopes. Clone the human's still-active agreement so expense backfill
    // can import (terminal.log 2026-07-26: no local active agreement).
    return _mirrorActiveHousingAgreementFromHuman(bot, planId: planId);
  }

  /// Imports the human's active `housing:<uuid>` agreement onto [bot] as
  /// `received:<uuid>` and force-activates it (sandbox recover after restore).
  Future<bool> _mirrorActiveHousingAgreementFromHuman(
    SandboxBotPeer bot, {
    required String planId,
  }) async {
    final humanDb = AppDatabase.maybeProcessScope;
    final humanOrch = HandshakeOrchestrator.maybeInstance;
    if (humanDb == null || humanOrch == null) return false;

    final humanPlanId = localAuthorPlanId(planId);
    final humanTransport = HousingProposalTransportService(humanDb);
    final humanActiveId = await humanTransport.resolveActiveRevisionIdForPlan(
      humanPlanId,
    );
    if (humanActiveId == null || humanActiveId.isEmpty) {
      debugPrint(
        'PeerSimulator ${bot.displayName} cannot mirror agreement: human '
        'has no active revision for $humanPlanId',
      );
      return false;
    }

    final roster = await participantsForPlan(humanDb, humanPlanId);
    final botName = bot.displayName.trim().toLowerCase();
    final botParticipant = roster
        .where((p) => p.displayName.trim().toLowerCase() == botName)
        .firstOrNull;
    if (botParticipant == null) {
      debugPrint(
        'PeerSimulator ${bot.displayName} not on human roster for $humanPlanId',
      );
      return false;
    }

    final humanPubB64 = RelayRouting.b64(
      await humanOrch.selfLongTermPublicKey(),
    );
    final humanContact = (await bot.contacts.list())
        .where(
          (c) =>
              c.kind == 'connected' &&
              (c.peerPublicMaterial ?? '') == humanPubB64,
        )
        .firstOrNull;
    if (humanContact == null) {
      debugPrint(
        'PeerSimulator ${bot.displayName} has no connected human contact; '
        'cannot mirror agreement',
      );
      return false;
    }

    final proposalJson = await humanTransport.exportProposalForParticipant(
      planId: humanPlanId,
      revisionId: humanActiveId,
      targetParticipantId: botParticipant.id,
    );
    final imported = await HousingProposalTransportService(
      bot.db,
    ).importReceivedProposal(
      proposalJson: proposalJson,
      targetParticipantId: botParticipant.id,
      senderContactId: humanContact.id,
      senderDisplayName: humanContact.displayName,
      senderAvatarId: humanContact.avatarId,
    );
    debugPrint(
      'PeerSimulator ${bot.displayName} imported human agreement '
      'plan=${imported.planId} rev=${imported.revisionId}',
    );
    return _forceActivateBotRevision(
      bot,
      planId: imported.planId,
      revisionId: imported.revisionId,
      reason: 'human agreement mirror',
    );
  }

  Future<bool> _forceActivateBotRevision(
    SandboxBotPeer bot, {
    required String planId,
    required String revisionId,
    required String reason,
  }) async {
    final transport = HousingProposalTransportService(bot.db);
    final localRev = await (bot.db.select(
      bot.db.proposalRevisions,
    )..where((t) => t.id.equals(revisionId))).getSingleOrNull();
    if (localRev == null) {
      debugPrint(
        'PeerSimulator ${bot.displayName} cannot $reason for '
        '$planId: missing revision $revisionId',
      );
      return false;
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(localRev.payloadJson) as Map<String, dynamic>;
    } catch (_) {
      payload = <String, dynamic>{};
    }
    payload['lifecycleState'] = 'archived';
    payload.remove('invalidatedByStatus');
    payload.remove('invalidatedByParticipantId');

    await (bot.db.update(
      bot.db.proposalRevisions,
    )..where((t) => t.id.equals(revisionId))).write(
      ProposalRevisionsCompanion(
        payloadJson: drift.Value(jsonEncode(payload)),
      ),
    );
    await (bot.db.update(
      bot.db.proposalPackages,
    )..where((t) => t.planId.equals(planId))).write(
      ProposalPackagesCompanion(
        activeRevisionId: drift.Value(revisionId),
        pendingRevisionId: const drift.Value(null),
      ),
    );
    await transport.applyActiveRevisionPayloadToPlan(
      planId: planId,
      revisionId: revisionId,
    );
    final active = await transport.hasActiveRevision(planId);
    debugPrint(
      'PeerSimulator ${bot.displayName} $reason for $planId '
      'rev=$revisionId active=$active',
    );
    return active;
  }

  @visibleForTesting
  Future<bool> ensureBotHousingPlanActiveForTest(
    SandboxBotPeer bot, {
    required String planId,
  }) => _ensureBotHousingPlanActive(bot, planId: planId);

  Future<void> _acceptPendingRealizedExpense(
    SandboxBotPeer bot, {
    required String expenseId,
  }) async {
    final repo = RealizedExpenseRepository(bot.db);
    final expense = await repo.getById(expenseId);
    if (expense == null) return;
    final selfId = selfParticipantIdForPlan(expense.planId);
    final hasSelfRow = (await repo.acceptancesFor(
      expenseId,
    )).any((a) => a.participantId == selfId);
    if (!hasSelfRow) {
      final now = DateTime.now().toUtc();
      await bot.db
          .into(bot.db.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: selfId,
              decision: RealizedExpenseDecision.pending,
            ),
          );
      debugPrint(
        'PeerSimulator ${bot.displayName} seeded missing acceptance row '
        'for $expenseId at $now',
      );
    }
    await repo.recordLocalAccept(expenseId: expenseId, participantId: selfId);
    await bot.orchestrator.sendRealizedExpenseAccept(
      expenseId: expenseId,
      participantId: selfId,
    );
    debugPrint(
      'PeerSimulator ${bot.displayName} accepted realized expense $expenseId',
    );
  }

  Future<bool> _botStillNeedsToAcceptRealizedExpense(
    SandboxBotPeer bot, {
    required String expenseId,
  }) async {
    final repo = RealizedExpenseRepository(bot.db);
    final expense = await repo.getById(expenseId);
    if (expense == null) return false;
    final selfId = selfParticipantIdForPlan(expense.planId);
    if (expense.payerParticipantId == selfId) return false;
    if (!repo.isTransferReviewParticipant(expense, selfId)) return false;
    final acceptances = await repo.acceptancesFor(expenseId);
    final selfDecision = acceptances
        .where((a) => a.participantId == selfId)
        .map((a) => a.decision)
        .firstOrNull;
    // Missing acceptance row must still be treated as "needs accept" — otherwise
    // a partial import leaves the bot permanently silent on the human UI.
    return selfDecision == null ||
        selfDecision == RealizedExpenseDecision.pending;
  }

  @visibleForTesting
  Future<bool> botStillNeedsToAcceptRealizedExpenseForTest(
    SandboxBotPeer bot, {
    required String expenseId,
  }) => _botStillNeedsToAcceptRealizedExpense(bot, expenseId: expenseId);

  @visibleForTesting
  Future<bool> ensureBotHasRealizedExpenseForTest(
    SandboxBotPeer bot, {
    required String expenseId,
  }) => _ensureBotHasRealizedExpense(bot, expenseId: expenseId);

  /// Returns true when this bot newly accepted at least one pending proposal.
  Future<bool> _autoAcceptPendingProposals(SandboxBotPeer bot) async {
    final transport = HousingProposalTransportService(bot.db);
    final plans = await bot.db.listPlans();
    var acceptedAny = false;
    for (final plan in plans) {
      if (plan.type != 'housing') continue;
      final revisionId = await transport.pendingRevisionIdForPlan(plan.id);
      if (revisionId == null) continue;
      // pendingRevisionId stays set until unanimous activation — not until
      // this bot responds. Re-accepting every reactOnce floods FakeRelay and
      // notifications (see terminal.log storm: dozens of accepts / 1000+ notifies).
      if (!await _botStillNeedsToAccept(
        bot,
        planId: plan.id,
        revisionId: revisionId,
      )) {
        continue;
      }
      try {
        await bot.orchestrator.sendHousingProposalResponse(
          planId: plan.id,
          status: ProposalResponseStatus.accepted,
          revisionId: revisionId,
        );
        acceptedAny = true;
        debugPrint(
          'PeerSimulator ${bot.displayName} accepted proposal ${plan.id} '
          'rev=$revisionId',
        );
      } catch (e, st) {
        debugPrint(
          'PeerSimulator auto-accept proposal ${plan.id} '
          '(${bot.displayName}) failed: $e\n$st',
        );
      }
    }
    return acceptedAny;
  }

  /// True when this bot's `:self` row may still Accept (status pending).
  Future<bool> _botStillNeedsToAccept(
    SandboxBotPeer bot, {
    required String planId,
    required String revisionId,
  }) async {
    final rev = await (bot.db.select(
      bot.db.proposalRevisions,
    )..where((t) => t.id.equals(revisionId))).getSingleOrNull();
    if (rev == null) return false;
    final state = HousingProposalRevisionState.fromJson(rev.payloadJson);
    final selfId = '$planId:self';
    final responses = await (bot.db.select(
      bot.db.proposalResponses,
    )..where((t) => t.revisionId.equals(revisionId))).get();
    final selfStatus =
        responses
            .where((r) => r.participantId == selfId)
            .map((r) => r.status)
            .firstOrNull ??
        ProposalResponseStatus.pending.name;
    return housingParticipantMayRespond(
      revision: state,
      participantResponseStatus: selfStatus,
      proposerParticipantId: rev.proposerParticipantId,
      participantId: selfId,
    );
  }

  @visibleForTesting
  Future<bool> botStillNeedsToAcceptForTest(
    SandboxBotPeer bot, {
    required String planId,
    required String revisionId,
  }) => _botStillNeedsToAccept(bot, planId: planId, revisionId: revisionId);

  /// Invite the next catalog bot via generate → redeem → poll (no code UI).
  Future<SandboxBotPeer?> inviteNextBot({
    required HandshakeOrchestrator humanOrchestrator,
    required String humanDisplayName,
    required String humanAvatarId,
  }) async {
    if (!SandboxMode.isActive(_prefs)) {
      throw StateError('inviteNextBot requires sandboxMode');
    }
    // High-water catalogue slot (survives partial restore when a prior bot was
    // deleted/disconnected). Do not use [_bots.length] — that would re-issue a
    // skipped catalogue name after cold restore.
    final index = _prefs.sandboxInvitedBotCount;
    if (index >= SandboxBotCatalog.maxBots ||
        _bots.length >= SandboxBotCatalog.maxBots) {
      return null;
    }
    final name = SandboxBotCatalog.displayNames[index];
    final avatar = SandboxBotCatalog.avatarIdForCatalogIndex(index);
    final bot = await _spawnBot(
      displayName: name,
      avatarId: avatar,
      catalogIndex: index,
    );
    final priorBots = List<SandboxBotPeer>.from(_bots);
    _bots.add(bot);
    await _prefs.setSandboxInvitedBotCount(index + 1);

    final invite = await humanOrchestrator.generateInvitation(
      validFor: const Duration(hours: 24),
      stubDisplayName: name,
      stubAvatarId: avatar,
    );
    final parsed = parseInvitationCode(invite.shortCode);
    if (parsed is! InvitationCodeOk) {
      throw StateError('sandbox invite short code parse failed');
    }
    await bot.orchestrator.redeemInvitation(
      code: parsed.code,
      selfDisplayName: name,
      selfAvatarId: avatar,
    );
    await humanOrchestrator.processAllPendingHandshakes();
    await bot.orchestrator.processAllPendingHandshakes();
    await humanOrchestrator.processAllPendingHandshakes();
    await bot.orchestrator.processAllPendingHandshakes();

    // Bots must be relay-reachable to each other or proposal accept fails
    // (plan_missing_peer_contacts) when the roster has multiple peers.
    pauseReactions();
    try {
      for (final other in priorBots) {
        await _connectBotPair(inviter: other, invitee: bot);
      }
    } finally {
      resumeReactions();
    }

    await reactOnce();
    return bot;
  }

  /// Full handshake between two sandbox bots on the shared FakeRelay.
  Future<void> _connectBotPair({
    required SandboxBotPeer inviter,
    required SandboxBotPeer invitee,
  }) async {
    botPairConnectAttempts++;
    final invite = await inviter.orchestrator.generateInvitation(
      validFor: const Duration(hours: 24),
      stubDisplayName: invitee.displayName,
      stubAvatarId: invitee.avatarId,
    );
    final parsed = parseInvitationCode(invite.shortCode);
    if (parsed is! InvitationCodeOk) {
      throw StateError('sandbox bot-bot invite short code parse failed');
    }
    await invitee.orchestrator.redeemInvitation(
      code: parsed.code,
      selfDisplayName: invitee.displayName,
      selfAvatarId: invitee.avatarId,
    );
    await inviter.orchestrator.processAllPendingHandshakes();
    await invitee.orchestrator.processAllPendingHandshakes();
    await inviter.orchestrator.processAllPendingHandshakes();
    await invitee.orchestrator.processAllPendingHandshakes();
  }

  /// Cold-start mesh: inject contacts + FakeRelay routing without handshake.
  Future<void> _rebindBotPair({
    required SandboxBotPeer a,
    required SandboxBotPeer b,
  }) async {
    botPairConnectAttempts++;
    final aPub = await a.identity.publicKey();
    final bPub = await b.identity.publicKey();
    final aPubB64 = RelayRouting.b64(aPub);
    final bPubB64 = RelayRouting.b64(bPub);
    await _injectConnectedPeer(
      owner: a,
      contactId: 'contact:sandbox:restored:${b.displayName}',
      peerPublicKey: bPub,
      peerPublicB64: bPubB64,
      displayName: b.displayName,
      avatarId: b.avatarId,
    );
    await _injectConnectedPeer(
      owner: b,
      contactId: 'contact:sandbox:restored:${a.displayName}',
      peerPublicKey: aPub,
      peerPublicB64: aPubB64,
      displayName: a.displayName,
      avatarId: a.avatarId,
    );
  }

  Future<void> _injectConnectedPeer({
    required SandboxBotPeer owner,
    required String contactId,
    required Uint8List peerPublicKey,
    required String peerPublicB64,
    required String displayName,
    required String avatarId,
  }) async {
    final selfPub = await owner.identity.publicKey();
    final selfListen = await RelayRouting.steadyStateAddress(
      firstPub: selfPub,
      secondPub: peerPublicKey,
    );
    final peerListen = await RelayRouting.steadyStateAddress(
      firstPub: peerPublicKey,
      secondPub: selfPub,
    );
    await _relay.establishRouting(
      selfIdentity: selfListen,
      peerIdentity: peerListen,
    );
    await _relay.establishRouting(
      selfIdentity: peerListen,
      peerIdentity: selfListen,
    );
    final now = DateTime.now().toUtc();
    await owner.db.upsertContact(
      ContactsCompanion.insert(
        id: contactId,
        kind: 'connected',
        displayName: displayName,
        avatarId: avatarId,
        relayRoutingId: drift.Value(RelayRouting.b64(peerListen)),
        peerPublicMaterial: drift.Value(peerPublicB64),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _disposeBotPeer(SandboxBotPeer bot) async {
    bot.orchestrator.stopPolling();
    await bot.db.close();
    try {
      if (bot.dbFile.existsSync()) bot.dbFile.deleteSync();
    } catch (_) {}
  }

  @visibleForTesting
  Future<bool> botsAreConnectedForTest(SandboxBotPeer a, SandboxBotPeer b) =>
      _botsAreConnected(a, b);

  Future<bool> _botsAreConnected(SandboxBotPeer a, SandboxBotPeer b) async {
    final bPub = await b.identity.publicKeyB64();
    final contacts = await a.contacts.list();
    return contacts.any(
      (c) => c.kind == 'connected' && (c.peerPublicMaterial ?? '') == bPub,
    );
  }

  Future<SandboxBotPeer> _spawnBot({
    required String displayName,
    required String avatarId,
    required int catalogIndex,
  }) async {
    // Unique temp DB path per spawn; identity seed is catalogue-stable.
    final seq = _botSeq++;
    final dbFile = File(
      '${Directory.systemTemp.path}/compartarenta_sandbox_bot_'
      '${catalogIndex}_$seq.sqlite',
    );
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
    final seed = Uint8List.fromList(
      List<int>.generate(
        32,
        (i) => (catalogIndex * 37 + i * 13 + 7) & 0xff,
      ),
    );
    final db = _SandboxDb(NativeDatabase(dbFile));
    final identity = InMemoryIdentityKeystore(seed: seed);
    final contacts = ContactsRepository(db);
    final invitations = ContactInvitationsRepository(db);
    final orchestrator = HandshakeOrchestrator(
      db: db,
      identity: identity,
      relay: _relay,
      contacts: contacts,
      invitations: invitations,
      pollInterval: const Duration(days: 365),
      deviceBinding: DeviceBindingService.forTesting(
        'sandbox-bot-$catalogIndex',
      ),
    );
    orchestrator.enableSandboxPeerAutoAccept(
      profile: () async => (displayName: displayName, avatarId: avatarId),
    );
    return SandboxBotPeer(
      displayName: displayName,
      avatarId: avatarId,
      db: db,
      dbFile: dbFile,
      identity: identity,
      orchestrator: orchestrator,
      contacts: contacts,
    );
  }
}
