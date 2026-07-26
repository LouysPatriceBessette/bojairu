import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:compartarenta/contacts/contact_invitations_repository.dart';
import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/contacts_repository.dart';
import 'package:compartarenta/device/device_binding_service.dart';
import 'package:compartarenta/housing/realized_expense/realized_expense_repository.dart';
import 'package:compartarenta/housing/realized_expense/realized_expense_status.dart';
import 'package:compartarenta/housing/proposals/housing_proposal_transport_service.dart';
import 'package:compartarenta/housing/proposals/plan_agreement_proposal_service.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/relay/handshake_orchestrator.dart';
import 'package:compartarenta/relay/identity_keystore.dart';
import 'package:compartarenta/relay/routing.dart';
import 'package:compartarenta/sandbox/peer_simulator.dart';
import 'package:compartarenta/sandbox/sandbox_relay.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Db extends AppDatabase {
  _Db(super.e) : super.forTesting();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PeerSimulator inviteNextBot connects catalog bot via FakeRelay',
    () async {
      SharedPreferences.setMockInitialValues({'sandbox.mode': true});
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
        ),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting('sandbox-human'),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final bot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(bot, isNotNull);
      expect(bot!.displayName, 'Louys');
      final contacts = await ContactsRepository(humanDb).list();
      expect(contacts.where((c) => c.kind == 'connected'), isNotEmpty);

      final bot2 = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(bot2, isNotNull);
      expect(bot2!.displayName, 'Monica');
      final afterEngineRestart = PeerSimulator.ensureInstalled(
        relay: SandboxRelay.instance,
        prefs: prefs,
      );
      expect(afterEngineRestart, same(sim));
      expect(afterEngineRestart.invitedCount, 2);
      final bot2Pub = await bot2.identity.publicKeyB64();
      final bot1Contacts = await bot.contacts.list();
      expect(
        bot1Contacts.any(
          (c) =>
              c.kind == 'connected' && (c.peerPublicMaterial ?? '') == bot2Pub,
        ),
        isTrue,
        reason: 'bots must mesh so multi-peer proposal accept can succeed',
      );

      final meshAfterInvite = sim.botPairConnectAttempts;
      expect(meshAfterInvite, greaterThanOrEqualTo(1));

      // Envelope storm must not re-run bot↔bot mesh (ANR path).
      final sender = Uint8List.fromList(List<int>.filled(32, 1));
      final recipient = Uint8List.fromList(List<int>.filled(32, 2));
      await relay.establishRouting(
        selfIdentity: sender,
        peerIdentity: recipient,
      );
      sim.pauseReactions();
      for (var i = 0; i < 5; i++) {
        await relay.postEnvelope(
          senderIdentity: sender,
          recipientIdentity: recipient,
          idempotencyKey: Uint8List.fromList(
            List<int>.generate(16, (j) => i + j),
          ),
          ciphertext: Uint8List.fromList([1, 2, 3]),
          kind: 1,
          ttl: const Duration(hours: 1),
        );
      }
      sim.resumeReactions();
      await sim.reactOnce();
      expect(
        sim.botPairConnectAttempts,
        meshAfterInvite,
        reason: 'reactOnce must not start new bot↔bot handshakes',
      );
      expect(await sim.botsAreConnectedForTest(bot, bot2), isTrue);

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'restoreInvitedBotsIfNeeded rebuilds catalog bots after process cold start',
    () async {
      SharedPreferences.setMockInitialValues({
        'sandbox.mode': true,
        'profile.displayName': 'Human',
        'profile.avatarId': 'mdi:0',
      });
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_cold_restore.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      AppDatabase.bindProcessScope(humanDb);
      final humanSeed = Uint8List.fromList(
        List<int>.generate(32, (i) => i + 11),
      );
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(seed: humanSeed),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-cold-restore',
        ),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final bot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      final bot2 = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(bot, isNotNull);
      expect(bot2, isNotNull);
      expect(prefs.sandboxInvitedBotCount, 2);

      // Process death: bots + FakeRelay gone; human DB + prefs remain.
      PeerSimulator.clearInstalled();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      final coldRelay = SandboxRelay.ensureFresh();
      final coldHumanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(seed: humanSeed),
        relay: coldRelay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-cold-restore',
        ),
      );
      coldHumanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(coldHumanOrch);
      final coldSim = PeerSimulator.ensureInstalled(
        relay: coldRelay,
        prefs: prefs,
      );
      expect(coldSim.invitedCount, 0);

      final restored = await coldSim.restoreInvitedBotsIfNeeded(
        humanOrchestrator: coldHumanOrch,
      );
      expect(restored, 2);
      expect(coldSim.invitedCount, 2);
      expect(coldSim.bots[0].displayName, 'Louys');
      expect(coldSim.bots[1].displayName, 'Monica');
      expect(
        await coldSim.botsAreConnectedForTest(
          coldSim.bots[0],
          coldSim.bots[1],
        ),
        isTrue,
      );

      final humanPubB64 = RelayRouting.b64(
        await coldHumanOrch.selfLongTermPublicKey(),
      );
      final louysContacts = await coldSim.bots[0].contacts.list();
      expect(
        louysContacts.any(
          (c) =>
              c.kind == 'connected' &&
              (c.peerPublicMaterial ?? '') == humanPubB64,
        ),
        isTrue,
        reason: 'restored bot must have the human as a connected contact',
      );

      // Idempotent when bots already live (engine-restart path).
      expect(
        await coldSim.restoreInvitedBotsIfNeeded(
          humanOrchestrator: coldHumanOrch,
        ),
        2,
      );

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      AppDatabase.clearProcessScopeIfReferencing(humanDb);
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'restoreInvitedBotsIfNeeded skips disconnected catalogue bots and keeps connected',
    () async {
      SharedPreferences.setMockInitialValues({
        'sandbox.mode': true,
        'profile.displayName': 'Human',
        'profile.avatarId': 'mdi:0',
      });
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_partial_restore.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      AppDatabase.bindProcessScope(humanDb);
      final humanSeed = Uint8List.fromList(
        List<int>.generate(32, (i) => i + 21),
      );
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(seed: humanSeed),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-partial-restore',
        ),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(prefs.sandboxInvitedBotCount, 3);

      final humanContacts = ContactsRepository(humanDb);
      final louys = (await humanContacts.list()).firstWhere(
        (c) => c.displayName == 'Louys' && c.kind == 'connected',
      );
      await humanOrch.sendDisconnect(louys.id);
      expect(
        (await humanContacts.get(louys.id))?.kind,
        'local-only',
      );
      expect(prefs.sandboxInvitedBotCount, 3);

      PeerSimulator.clearInstalled();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      final coldRelay = SandboxRelay.ensureFresh();
      final coldHumanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(seed: humanSeed),
        relay: coldRelay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-partial-restore',
        ),
      );
      coldHumanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(coldHumanOrch);
      final coldSim = PeerSimulator.ensureInstalled(
        relay: coldRelay,
        prefs: prefs,
      );

      final restored = await coldSim.restoreInvitedBotsIfNeeded(
        humanOrchestrator: coldHumanOrch,
      );
      expect(restored, 2);
      expect(coldSim.invitedCount, 2);
      expect(
        coldSim.bots.map((b) => b.displayName).toList(),
        ['Monica', 'Ròberr'],
      );
      expect(
        await coldSim.botsAreConnectedForTest(
          coldSim.bots[0],
          coldSim.bots[1],
        ),
        isTrue,
      );
      // High-water catalogue slot preserved for next invite (Liuva, not Ròberr).
      expect(prefs.sandboxInvitedBotCount, 3);
      final next = await coldSim.inviteNextBot(
        humanOrchestrator: coldHumanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(next?.displayName, 'Liuva');

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      AppDatabase.clearProcessScopeIfReferencing(humanDb);
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'auto-accept skips when bot self already responded (no re-accept storm)',
    () async {
      SharedPreferences.setMockInitialValues({'sandbox.mode': true});
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_accept_guard.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 3)),
        ),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting('sandbox-human-guard'),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final bot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(bot, isNotNull);

      const planId = 'plan:sandbox-guard';
      const revisionId = 'rev:sandbox-guard';
      final now = DateTime.utc(2026, 7, 16);
      await bot!.db
          .into(bot.db.plans)
          .insert(
            PlansCompanion.insert(id: planId, type: 'housing', createdAt: now),
          );
      await bot.db
          .into(bot.db.participants)
          .insert(
            ParticipantsCompanion.insert(
              id: '$planId:self',
              displayName: bot.displayName,
              avatarId: bot.avatarId,
              createdAt: now,
            ),
          );
      await bot.db
          .into(bot.db.proposalPackages)
          .insert(
            ProposalPackagesCompanion.insert(
              id: 'pkg:$planId',
              planId: planId,
              createdAt: now,
              pendingRevisionId: const drift.Value(revisionId),
            ),
          );
      await bot.db
          .into(bot.db.proposalRevisions)
          .insert(
            ProposalRevisionsCompanion.insert(
              id: revisionId,
              packageId: 'pkg:$planId',
              contentHash: 'hash:$revisionId',
              proposerParticipantId: '$planId:p0',
              payloadJson: jsonEncode({
                'kind': PlanAgreementProposalService.kind,
                'lifecycleState': 'open',
              }),
              createdAt: now,
            ),
          );

      expect(
        await sim.botStillNeedsToAcceptForTest(
          bot,
          planId: planId,
          revisionId: revisionId,
        ),
        isTrue,
        reason: 'pending self response may still accept',
      );

      await bot.db
          .into(bot.db.proposalResponses)
          .insert(
            ProposalResponsesCompanion.insert(
              id: 'resp:$revisionId:$planId:self',
              revisionId: revisionId,
              participantId: '$planId:self',
              status: ProposalResponseStatus.accepted.name,
              respondedAt: drift.Value(now),
            ),
          );

      expect(
        await sim.botStillNeedsToAcceptForTest(
          bot,
          planId: planId,
          revisionId: revisionId,
        ),
        isFalse,
        reason: 'already-accepted must not re-enter auto-accept',
      );

      final postsBefore = relay.postEnvelopeCallCount;
      await sim.reactOnce();
      await sim.reactOnce();
      expect(
        relay.postEnvelopeCallCount,
        postsBefore,
        reason: 'reactOnce must not re-broadcast accept for settled self',
      );

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'realized expense bot review accepts pending self after human decision',
    () async {
      SharedPreferences.setMockInitialValues({'sandbox.mode': true});
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_expense_review.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 5)),
        ),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-expense-review',
        ),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final bot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(bot, isNotNull);

      const planId = 'received:expense-review';
      const expenseId = 'realized:expense-review';
      final now = DateTime.utc(2026, 7, 16, 16);
      await bot!.db
          .into(bot.db.participants)
          .insert(
            ParticipantsCompanion.insert(
              id: '$planId:self',
              displayName: bot.displayName,
              avatarId: bot.avatarId,
              createdAt: now,
            ),
          );
      await bot.db
          .into(bot.db.participants)
          .insert(
            ParticipantsCompanion.insert(
              id: '$planId:p0',
              displayName: 'Human',
              avatarId: 'mdi:0',
              createdAt: now,
            ),
          );
      await bot.db
          .into(bot.db.realizedExpenses)
          .insert(
            RealizedExpensesCompanion.insert(
              id: expenseId,
              packageId: 'pkg:$planId',
              planId: planId,
              planLineId: 'line:$planId:rent',
              status: RealizedExpenseStatus.rejected,
              amountMinor: 9313,
              currency: 'CAD',
              paymentDate: now,
              payerParticipantId: '$planId:p0',
              kind: RealizedExpenseKind.normal,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await bot.db
          .into(bot.db.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$planId:p0',
              decision: RealizedExpenseDecision.rejected,
              decidedAt: drift.Value(now),
            ),
          );
      await bot.db
          .into(bot.db.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$planId:self',
              decision: RealizedExpenseDecision.pending,
            ),
          );

      expect(
        await sim.botStillNeedsToAcceptRealizedExpenseForTest(
          bot,
          expenseId: expenseId,
        ),
        isTrue,
      );

      await sim.acceptPendingRealizedExpenseReviewsAfterHumanDecision(
        expenseId: expenseId,
        initialDelay: Duration.zero,
        betweenBotDelay: Duration.zero,
      );

      final acceptances = await RealizedExpenseRepository(
        bot.db,
      ).acceptancesFor(expenseId);
      expect(
        acceptances
            .where((a) => a.participantId == '$planId:self')
            .single
            .decision,
        RealizedExpenseDecision.accepted,
      );
      expect(
        await sim.botStillNeedsToAcceptRealizedExpenseForTest(
          bot,
          expenseId: expenseId,
        ),
        isFalse,
        reason: 'a settled bot row must not be accepted again',
      );

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'realized expense review accepts every pending bot after human decision',
    () async {
      SharedPreferences.setMockInitialValues({'sandbox.mode': true});
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_expense_multi.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 7)),
        ),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-expense-multi',
        ),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final bot1 = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      final bot2 = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(bot1, isNotNull);
      expect(bot2, isNotNull);

      const planId = 'received:expense-review-multi';
      const expenseId = 'realized:expense-review-multi';
      final now = DateTime.utc(2026, 7, 16, 16);

      Future<void> seedPendingExpense(SandboxBotPeer bot) async {
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$planId:self',
                displayName: bot.displayName,
                avatarId: bot.avatarId,
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$planId:p0',
                displayName: 'Human',
                avatarId: 'mdi:0',
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.realizedExpenses)
            .insert(
              RealizedExpensesCompanion.insert(
                id: expenseId,
                packageId: 'pkg:$planId',
                planId: planId,
                planLineId: 'line:$planId:rent',
                status: RealizedExpenseStatus.proposed,
                amountMinor: 4200,
                currency: 'CAD',
                paymentDate: now,
                payerParticipantId: '$planId:p0',
                kind: RealizedExpenseKind.normal,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await bot.db
            .into(bot.db.realizedExpenseAcceptances)
            .insert(
              RealizedExpenseAcceptancesCompanion.insert(
                expenseId: expenseId,
                participantId: '$planId:p0',
                decision: RealizedExpenseDecision.accepted,
                decidedAt: drift.Value(now),
              ),
            );
        await bot.db
            .into(bot.db.realizedExpenseAcceptances)
            .insert(
              RealizedExpenseAcceptancesCompanion.insert(
                expenseId: expenseId,
                participantId: '$planId:self',
                decision: RealizedExpenseDecision.pending,
              ),
            );
      }

      await seedPendingExpense(bot1!);
      await seedPendingExpense(bot2!);

      expect(
        await sim.botStillNeedsToAcceptRealizedExpenseForTest(
          bot1,
          expenseId: expenseId,
        ),
        isTrue,
      );
      expect(
        await sim.botStillNeedsToAcceptRealizedExpenseForTest(
          bot2,
          expenseId: expenseId,
        ),
        isTrue,
      );

      await sim.acceptPendingRealizedExpenseReviewsAfterHumanDecision(
        expenseId: expenseId,
        initialDelay: Duration.zero,
        betweenBotDelay: Duration.zero,
      );

      for (final bot in [bot1, bot2]) {
        final acceptances = await RealizedExpenseRepository(
          bot.db,
        ).acceptancesFor(expenseId);
        expect(
          acceptances
              .where((a) => a.participantId == '$planId:self')
              .single
              .decision,
          RealizedExpenseDecision.accepted,
          reason: '${bot.displayName} must accept its own pending review',
        );
      }

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'realized expense review backfills missing propose then accepts peer bot',
    () async {
      SharedPreferences.setMockInitialValues({'sandbox.mode': true});
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_expense_backfill.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 11)),
        ),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-expense-backfill',
        ),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final payerBot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      final peerBot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(payerBot, isNotNull);
      expect(peerBot, isNotNull);

      const planId = 'received:expense-backfill';
      const expenseId = 'realized:expense-backfill';
      const revisionId = 'rev:expense-backfill';
      final now = DateTime.utc(2026, 7, 16, 17);

      Future<void> seedPlanShell(
        SandboxBotPeer bot, {
        required String peerDisplayName,
        required String peerAvatarId,
      }) async {
        await bot.db
            .into(bot.db.plans)
            .insert(
              PlansCompanion.insert(
                id: planId,
                type: 'housing',
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$planId:self',
                displayName: bot.displayName,
                avatarId: bot.avatarId,
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$planId:p0',
                displayName: 'Human',
                avatarId: 'mdi:0',
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$planId:p1',
                displayName: peerDisplayName,
                avatarId: peerAvatarId,
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.proposalPackages)
            .insert(
              ProposalPackagesCompanion.insert(
                id: 'pkg:$planId',
                planId: planId,
                createdAt: now,
                activeRevisionId: const drift.Value(revisionId),
              ),
            );
        await bot.db
            .into(bot.db.proposalRevisions)
            .insert(
              ProposalRevisionsCompanion.insert(
                id: revisionId,
                packageId: 'pkg:$planId',
                contentHash: 'hash:$revisionId',
                proposerParticipantId: '$planId:self',
                payloadJson: jsonEncode({
                  'kind': PlanAgreementProposalService.kind,
                  'lifecycleState': 'open',
                }),
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.planLines)
            .insert(
              PlanLinesCompanion.insert(
                id: 'line:$planId:hydro',
                planId: planId,
                isRecurring: true,
                title: 'Hydro',
                currency: 'CAD',
                createdAt: now,
              ),
            );
      }

      await seedPlanShell(
        payerBot!,
        peerDisplayName: peerBot!.displayName,
        peerAvatarId: peerBot.avatarId,
      );
      await seedPlanShell(
        peerBot,
        peerDisplayName: payerBot.displayName,
        peerAvatarId: payerBot.avatarId,
      );

      // Only the payer bot has the expense — peer missed FakeRelay delivery.
      await payerBot.db
          .into(payerBot.db.realizedExpenses)
          .insert(
            RealizedExpensesCompanion.insert(
              id: expenseId,
              packageId: 'pkg:$planId',
              planId: planId,
              planLineId: 'line:$planId:hydro',
              status: RealizedExpenseStatus.proposed,
              amountMinor: 3000,
              currency: 'CAD',
              paymentDate: now,
              payerParticipantId: '$planId:self',
              kind: RealizedExpenseKind.normal,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await payerBot.db
          .into(payerBot.db.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$planId:self',
              decision: RealizedExpenseDecision.accepted,
              decidedAt: drift.Value(now),
            ),
          );
      await payerBot.db
          .into(payerBot.db.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$planId:p0',
              decision: RealizedExpenseDecision.pending,
            ),
          );
      await payerBot.db
          .into(payerBot.db.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$planId:p1',
              decision: RealizedExpenseDecision.pending,
            ),
          );

      expect(
        await RealizedExpenseRepository(peerBot.db).getById(expenseId),
        isNull,
        reason: 'peer starts without the propose (delivery miss)',
      );

      await sim.acceptPendingRealizedExpenseReviewsAfterHumanDecision(
        expenseId: expenseId,
        initialDelay: Duration.zero,
        betweenBotDelay: Duration.zero,
      );

      expect(
        await RealizedExpenseRepository(peerBot.db).getById(expenseId),
        isNotNull,
        reason: 'sequence must backfill the missing propose onto the peer',
      );
      final peerAcceptances = await RealizedExpenseRepository(
        peerBot.db,
      ).acceptancesFor(expenseId);
      expect(
        peerAcceptances
            .where((a) => a.participantId == '$planId:self')
            .single
            .decision,
        RealizedExpenseDecision.accepted,
        reason: 'peer bot must accept after backfill',
      );

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'realized expense review activates pending-only peer then backfills',
    () async {
      SharedPreferences.setMockInitialValues({'sandbox.mode': true});
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_expense_pending_only.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 21)),
        ),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-expense-pending-only',
        ),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final payerBot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      final peerBot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(payerBot, isNotNull);
      expect(peerBot, isNotNull);

      const planId = 'received:expense-pending-only';
      const expenseId = 'realized:expense-pending-only';
      const revisionId = 'rev:expense-pending-only';
      final now = DateTime.utc(2026, 7, 16, 18);

      Future<void> seedPlanShell(
        SandboxBotPeer bot, {
        required bool active,
        required String peerDisplayName,
        required String peerAvatarId,
      }) async {
        await bot.db
            .into(bot.db.plans)
            .insert(
              PlansCompanion.insert(
                id: planId,
                type: 'housing',
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$planId:self',
                displayName: bot.displayName,
                avatarId: bot.avatarId,
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$planId:p0',
                displayName: 'Human',
                avatarId: 'mdi:0',
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$planId:p1',
                displayName: peerDisplayName,
                avatarId: peerAvatarId,
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.proposalPackages)
            .insert(
              ProposalPackagesCompanion.insert(
                id: 'pkg:$planId',
                planId: planId,
                createdAt: now,
                activeRevisionId: active
                    ? const drift.Value(revisionId)
                    : const drift.Value.absent(),
                pendingRevisionId: active
                    ? const drift.Value.absent()
                    : const drift.Value(revisionId),
              ),
            );
        await bot.db
            .into(bot.db.proposalRevisions)
            .insert(
              ProposalRevisionsCompanion.insert(
                id: revisionId,
                packageId: 'pkg:$planId',
                contentHash: 'hash:$revisionId',
                proposerParticipantId: '$planId:p0',
                payloadJson: jsonEncode({
                  'kind': PlanAgreementProposalService.kind,
                  'lifecycleState': active ? 'archived' : 'open',
                  'agreement': {
                    'periodStart': '2026-07-16',
                    'periodEnd': '2027-01-12',
                  },
                  'plan': {
                    'lines': [
                      {
                        'id': 'line:$planId:rent',
                        'title': 'Loyer',
                        'isRecurring': true,
                        'currency': 'CAD',
                      },
                    ],
                  },
                }),
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.planLines)
            .insert(
              PlanLinesCompanion.insert(
                id: 'line:$planId:rent',
                planId: planId,
                isRecurring: true,
                title: 'Loyer',
                currency: 'CAD',
                createdAt: now,
              ),
            );
      }

      await seedPlanShell(
        payerBot!,
        active: true,
        peerDisplayName: peerBot!.displayName,
        peerAvatarId: peerBot.avatarId,
      );
      // Peer matches terminal.log Ròberr: proposal accepted locally but never
      // flipped to activeRevisionId — expense import then skips.
      await seedPlanShell(
        peerBot,
        active: false,
        peerDisplayName: payerBot.displayName,
        peerAvatarId: payerBot.avatarId,
      );

      await payerBot.db
          .into(payerBot.db.realizedExpenses)
          .insert(
            RealizedExpensesCompanion.insert(
              id: expenseId,
              packageId: 'pkg:$planId',
              planId: planId,
              planLineId: 'line:$planId:rent',
              status: RealizedExpenseStatus.proposed,
              amountMinor: 5000,
              currency: 'CAD',
              paymentDate: now,
              payerParticipantId: '$planId:self',
              kind: RealizedExpenseKind.normal,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await payerBot.db
          .into(payerBot.db.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$planId:self',
              decision: RealizedExpenseDecision.accepted,
              decidedAt: drift.Value(now),
            ),
          );
      await payerBot.db
          .into(payerBot.db.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$planId:p0',
              decision: RealizedExpenseDecision.pending,
            ),
          );
      await payerBot.db
          .into(payerBot.db.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$planId:p1',
              decision: RealizedExpenseDecision.pending,
            ),
          );

      expect(
        await HousingProposalTransportService(peerBot.db).hasActiveRevision(
          planId,
        ),
        isFalse,
      );

      await sim.acceptPendingRealizedExpenseReviewsAfterHumanDecision(
        expenseId: expenseId,
        initialDelay: Duration.zero,
        betweenBotDelay: Duration.zero,
      );

      expect(
        await HousingProposalTransportService(peerBot.db).hasActiveRevision(
          planId,
        ),
        isTrue,
        reason: 'pending-only peer must mirror activation before import',
      );
      expect(
        await RealizedExpenseRepository(peerBot.db).getById(expenseId),
        isNotNull,
      );
      final peerAcceptances = await RealizedExpenseRepository(
        peerBot.db,
      ).acceptancesFor(expenseId);
      expect(
        peerAcceptances
            .where((a) => a.participantId == '$planId:self')
            .single
            .decision,
        RealizedExpenseDecision.accepted,
      );

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'realized expense review backfills from human payer then bots accept',
    () async {
      SharedPreferences.setMockInitialValues({'sandbox.mode': true});
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_expense_payer.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      AppDatabase.bindProcessScope(humanDb);
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 31)),
        ),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-expense-payer',
        ),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final peerBot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(peerBot, isNotNull);

      const bare = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
      const housingPlanId = 'housing:$bare';
      const receivedPlanId = 'received:$bare';
      const expenseId = 'realized:expense-human-payer';
      const revisionId = 'rev:expense-human-payer';
      final now = DateTime.utc(2026, 7, 16, 19);

      Future<void> seedHumanPlan() async {
        await humanDb
            .into(humanDb.plans)
            .insert(
              PlansCompanion.insert(
                id: housingPlanId,
                type: 'housing',
                createdAt: now,
              ),
            );
        await humanDb
            .into(humanDb.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$housingPlanId:self',
                displayName: 'Human',
                avatarId: 'mdi:0',
                createdAt: now,
              ),
            );
        await humanDb
            .into(humanDb.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$housingPlanId:p0',
                displayName: peerBot!.displayName,
                avatarId: peerBot.avatarId,
                createdAt: now,
              ),
            );
        await humanDb
            .into(humanDb.proposalPackages)
            .insert(
              ProposalPackagesCompanion.insert(
                id: 'pkg:$housingPlanId',
                planId: housingPlanId,
                createdAt: now,
                activeRevisionId: const drift.Value(revisionId),
              ),
            );
        await humanDb
            .into(humanDb.proposalRevisions)
            .insert(
              ProposalRevisionsCompanion.insert(
                id: revisionId,
                packageId: 'pkg:$housingPlanId',
                contentHash: 'hash:$revisionId',
                proposerParticipantId: '$housingPlanId:self',
                payloadJson: jsonEncode({
                  'kind': PlanAgreementProposalService.kind,
                  'lifecycleState': 'archived',
                  'agreement': {
                    'periodStart': '2026-07-16',
                    'periodEnd': '2027-01-12',
                  },
                  'plan': {
                    'lines': [
                      {
                        'id': 'line:$housingPlanId:rent',
                        'title': 'Loyer',
                        'isRecurring': true,
                        'currency': 'CAD',
                      },
                    ],
                  },
                }),
                createdAt: now,
              ),
            );
        await humanDb
            .into(humanDb.planLines)
            .insert(
              PlanLinesCompanion.insert(
                id: 'line:$housingPlanId:rent',
                planId: housingPlanId,
                isRecurring: true,
                title: 'Loyer',
                currency: 'CAD',
                createdAt: now,
              ),
            );
      }

      Future<void> seedBotPlan(SandboxBotPeer bot) async {
        await bot.db
            .into(bot.db.plans)
            .insert(
              PlansCompanion.insert(
                id: receivedPlanId,
                type: 'housing',
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$receivedPlanId:self',
                displayName: bot.displayName,
                avatarId: bot.avatarId,
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.participants)
            .insert(
              ParticipantsCompanion.insert(
                id: '$receivedPlanId:p0',
                displayName: 'Human',
                avatarId: 'mdi:0',
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.proposalPackages)
            .insert(
              ProposalPackagesCompanion.insert(
                id: 'pkg:$receivedPlanId',
                planId: receivedPlanId,
                createdAt: now,
                activeRevisionId: const drift.Value(revisionId),
              ),
            );
        await bot.db
            .into(bot.db.proposalRevisions)
            .insert(
              ProposalRevisionsCompanion.insert(
                id: revisionId,
                packageId: 'pkg:$receivedPlanId',
                contentHash: 'hash:$revisionId',
                proposerParticipantId: '$receivedPlanId:p0',
                payloadJson: jsonEncode({
                  'kind': PlanAgreementProposalService.kind,
                  'lifecycleState': 'archived',
                  'agreement': {
                    'periodStart': '2026-07-16',
                    'periodEnd': '2027-01-12',
                  },
                  'plan': {
                    'lines': [
                      {
                        'id': 'line:$receivedPlanId:rent',
                        'title': 'Loyer',
                        'isRecurring': true,
                        'currency': 'CAD',
                      },
                    ],
                  },
                }),
                createdAt: now,
              ),
            );
        await bot.db
            .into(bot.db.planLines)
            .insert(
              PlanLinesCompanion.insert(
                id: 'line:$receivedPlanId:rent',
                planId: receivedPlanId,
                isRecurring: true,
                title: 'Loyer',
                currency: 'CAD',
                createdAt: now,
              ),
            );
      }

      await seedHumanPlan();
      await seedBotPlan(peerBot!);

      await humanDb
          .into(humanDb.realizedExpenses)
          .insert(
            RealizedExpensesCompanion.insert(
              id: expenseId,
              packageId: 'pkg:$housingPlanId',
              planId: housingPlanId,
              planLineId: 'line:$housingPlanId:rent',
              status: RealizedExpenseStatus.proposed,
              amountMinor: 1000,
              currency: 'CAD',
              paymentDate: now,
              payerParticipantId: '$housingPlanId:self',
              kind: RealizedExpenseKind.normal,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await humanDb
          .into(humanDb.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$housingPlanId:self',
              decision: RealizedExpenseDecision.accepted,
              decidedAt: drift.Value(now),
            ),
          );
      await humanDb
          .into(humanDb.realizedExpenseAcceptances)
          .insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$housingPlanId:p0',
              decision: RealizedExpenseDecision.pending,
            ),
          );

      expect(
        await RealizedExpenseRepository(peerBot.db).getById(expenseId),
        isNull,
      );

      await sim.acceptPendingRealizedExpenseReviewsAfterHumanDecision(
        expenseId: expenseId,
        initialDelay: Duration.zero,
        betweenBotDelay: Duration.zero,
      );

      expect(
        await RealizedExpenseRepository(peerBot.db).getById(expenseId),
        isNotNull,
        reason: 'bot must backfill propose from human payer',
      );
      final peerAcceptances = await RealizedExpenseRepository(
        peerBot.db,
      ).acceptancesFor(expenseId);
      expect(
        peerAcceptances
            .where((a) => a.participantId == '$receivedPlanId:self')
            .single
            .decision,
        RealizedExpenseDecision.accepted,
      );

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      AppDatabase.clearProcessScopeIfReferencing(humanDb);
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'bot-payer expense missing on bots after wipe backfills from human copy',
    () async {
      // Cold restore wipes bot sqlite while the human keeps Monica's propose.
      // Peer (Ròberr) must still accept and land on the human review table.
      SharedPreferences.setMockInitialValues({'sandbox.mode': true});
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_bot_payer_wipe.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      AppDatabase.bindProcessScope(humanDb);
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 41)),
        ),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-bot-payer-wipe',
        ),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final payerBot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      final peerBot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(payerBot, isNotNull);
      expect(peerBot, isNotNull);

      const bare = 'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff';
      const housingPlanId = 'housing:$bare';
      const receivedPlanId = 'received:$bare';
      const expenseId = 'realized:expense-bot-payer-wipe';
      const revisionId = 'rev:expense-bot-payer-wipe';
      final now = DateTime.utc(2026, 7, 26, 17);

      final humanContacts = await ContactsRepository(humanDb).list();
      final payerContact = humanContacts.firstWhere(
        (c) =>
            c.kind == 'connected' &&
            c.displayName == payerBot!.displayName,
      );
      final peerContact = humanContacts.firstWhere(
        (c) =>
            c.kind == 'connected' &&
            c.displayName == peerBot!.displayName,
      );

      Future<void> seedBotPlan(SandboxBotPeer bot) async {
        await bot.db.into(bot.db.plans).insert(
              PlansCompanion.insert(
                id: receivedPlanId,
                type: 'housing',
                createdAt: now,
              ),
            );
        await bot.db.into(bot.db.participants).insert(
              ParticipantsCompanion.insert(
                id: '$receivedPlanId:self',
                displayName: bot.displayName,
                avatarId: bot.avatarId,
                createdAt: now,
              ),
            );
        await bot.db.into(bot.db.participants).insert(
              ParticipantsCompanion.insert(
                id: '$receivedPlanId:p0',
                displayName: 'Human',
                avatarId: 'mdi:0',
                createdAt: now,
              ),
            );
        final other = identical(bot, payerBot) ? peerBot! : payerBot!;
        await bot.db.into(bot.db.participants).insert(
              ParticipantsCompanion.insert(
                id: '$receivedPlanId:p1',
                displayName: other.displayName,
                avatarId: other.avatarId,
                createdAt: now,
              ),
            );
        await bot.db.into(bot.db.proposalPackages).insert(
              ProposalPackagesCompanion.insert(
                id: 'pkg:$receivedPlanId',
                planId: receivedPlanId,
                createdAt: now,
                activeRevisionId: const drift.Value(revisionId),
              ),
            );
        await bot.db.into(bot.db.proposalRevisions).insert(
              ProposalRevisionsCompanion.insert(
                id: revisionId,
                packageId: 'pkg:$receivedPlanId',
                contentHash: 'hash:$revisionId',
                proposerParticipantId: '$receivedPlanId:self',
                payloadJson: jsonEncode({
                  'kind': PlanAgreementProposalService.kind,
                  'lifecycleState': 'archived',
                }),
                createdAt: now,
              ),
            );
        await bot.db.into(bot.db.planLines).insert(
              PlanLinesCompanion.insert(
                id: 'line:$receivedPlanId:hydro',
                planId: receivedPlanId,
                isRecurring: true,
                title: 'Hydro',
                currency: 'CAD',
                createdAt: now,
              ),
            );
      }

      await seedBotPlan(payerBot!);
      await seedBotPlan(peerBot!);

      await humanDb.into(humanDb.plans).insert(
            PlansCompanion.insert(
              id: housingPlanId,
              type: 'housing',
              createdAt: now,
            ),
          );
      await humanDb.into(humanDb.participants).insert(
            ParticipantsCompanion.insert(
              id: '$housingPlanId:self',
              displayName: 'Human',
              avatarId: 'mdi:0',
              createdAt: now,
            ),
          );
      await humanDb.into(humanDb.participants).insert(
            ParticipantsCompanion.insert(
              id: '$housingPlanId:p0',
              displayName: payerBot.displayName,
              avatarId: payerBot.avatarId,
              createdAt: now,
              contactId: drift.Value(payerContact.id),
            ),
          );
      await humanDb.into(humanDb.participants).insert(
            ParticipantsCompanion.insert(
              id: '$housingPlanId:p1',
              displayName: peerBot.displayName,
              avatarId: peerBot.avatarId,
              createdAt: now,
              contactId: drift.Value(peerContact.id),
            ),
          );
      await humanDb.into(humanDb.proposalPackages).insert(
            ProposalPackagesCompanion.insert(
              id: 'pkg:$housingPlanId',
              planId: housingPlanId,
              createdAt: now,
              activeRevisionId: const drift.Value(revisionId),
            ),
          );
      await humanDb.into(humanDb.proposalRevisions).insert(
            ProposalRevisionsCompanion.insert(
              id: revisionId,
              packageId: 'pkg:$housingPlanId',
              contentHash: 'hash:$revisionId',
              proposerParticipantId: '$housingPlanId:self',
              payloadJson: jsonEncode({
                'kind': PlanAgreementProposalService.kind,
                'lifecycleState': 'archived',
              }),
              createdAt: now,
            ),
          );
      await humanDb.into(humanDb.planLines).insert(
            PlanLinesCompanion.insert(
              id: 'line:$housingPlanId:hydro',
              planId: housingPlanId,
              isRecurring: true,
              title: 'Hydro',
              currency: 'CAD',
              createdAt: now,
            ),
          );

      // Human has Monica's imported propose; both bot DBs have no expense row
      // (payer wipe + peer miss) — matches cold restore after bot expense.
      await humanDb.into(humanDb.realizedExpenses).insert(
            RealizedExpensesCompanion.insert(
              id: expenseId,
              packageId: 'pkg:$housingPlanId',
              planId: housingPlanId,
              planLineId: 'line:$housingPlanId:hydro',
              status: RealizedExpenseStatus.proposed,
              amountMinor: 3000,
              currency: 'CAD',
              paymentDate: now,
              payerParticipantId: '$housingPlanId:p0',
              kind: RealizedExpenseKind.normal,
              description: const drift.Value('Dépense simulée'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await humanDb.into(humanDb.realizedExpenseAcceptances).insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$housingPlanId:p0',
              decision: RealizedExpenseDecision.accepted,
              decidedAt: drift.Value(now),
            ),
          );
      await humanDb.into(humanDb.realizedExpenseAcceptances).insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$housingPlanId:self',
              decision: RealizedExpenseDecision.accepted,
              decidedAt: drift.Value(now),
            ),
          );
      await humanDb.into(humanDb.realizedExpenseAcceptances).insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$housingPlanId:p1',
              decision: RealizedExpenseDecision.pending,
            ),
          );

      expect(
        await RealizedExpenseRepository(payerBot.db).getById(expenseId),
        isNull,
      );
      expect(
        await RealizedExpenseRepository(peerBot.db).getById(expenseId),
        isNull,
      );

      await sim.acceptPendingRealizedExpenseReviewsAfterHumanDecision(
        expenseId: expenseId,
        initialDelay: Duration.zero,
        betweenBotDelay: Duration.zero,
      );

      expect(
        await RealizedExpenseRepository(peerBot.db).getById(expenseId),
        isNotNull,
        reason: 'peer must backfill from human copy of bot-payer expense',
      );
      final peerAcceptances = await RealizedExpenseRepository(
        peerBot.db,
      ).acceptancesFor(expenseId);
      expect(
        peerAcceptances
            .where((a) => a.participantId == '$receivedPlanId:self')
            .single
            .decision,
        RealizedExpenseDecision.accepted,
      );

      final humanPeerDecision = (await RealizedExpenseRepository(
        humanDb,
      ).acceptancesFor(expenseId))
          .where((a) => a.participantId == '$housingPlanId:p1')
          .single;
      expect(
        humanPeerDecision.decision,
        RealizedExpenseDecision.accepted,
        reason: 'human UI must show peer bot accepted (not stuck on ?)',
      );

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      AppDatabase.clearProcessScopeIfReferencing(humanDb);
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );

  test(
    'human-payer expense after cold empty bot mirrors agreement then accepts',
    () async {
      // Matches terminal.log 2026-07-26: restore bots=2 with empty sqlite;
      // human still has active plan + expense; import skipped with
      // "no local active agreement" until human agreement is mirrored.
      SharedPreferences.setMockInitialValues({'sandbox.mode': true});
      final prefs = await AppPreferences.load();
      final relay = SandboxRelay.ensureFresh();
      final humanFile = File(
        '${Directory.systemTemp.path}/sandbox_peer_human_expense_cold_empty.sqlite',
      );
      if (humanFile.existsSync()) humanFile.deleteSync();
      final humanDb = _Db(NativeDatabase(humanFile));
      AppDatabase.bindProcessScope(humanDb);
      final humanOrch = HandshakeOrchestrator(
        db: humanDb,
        identity: InMemoryIdentityKeystore(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 51)),
        ),
        relay: relay,
        contacts: ContactsRepository(humanDb),
        invitations: ContactInvitationsRepository(humanDb),
        pollInterval: const Duration(days: 1),
        deviceBinding: DeviceBindingService.forTesting(
          'sandbox-human-expense-cold-empty',
        ),
      );
      humanOrch.enableSandboxPeerAutoAccept(
        profile: () async => (displayName: 'Human', avatarId: 'mdi:0'),
      );
      HandshakeOrchestrator.install(humanOrch);
      final sim = PeerSimulator.install(relay: relay, prefs: prefs);

      final peerBot = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      final peerBot2 = await sim.inviteNextBot(
        humanOrchestrator: humanOrch,
        humanDisplayName: 'Human',
        humanAvatarId: 'mdi:0',
      );
      expect(peerBot, isNotNull);
      expect(peerBot2, isNotNull);

      const bare = 'cccccccc-dddd-4eee-8fff-000000000001';
      const housingPlanId = 'housing:$bare';
      const receivedPlanId = 'received:$bare';
      const expenseId = 'realized:expense-human-cold-empty';
      const revisionId = 'rev:expense-human-cold-empty';
      final now = DateTime.utc(2026, 7, 26, 18);

      final humanContacts = await ContactsRepository(humanDb).list();
      final peerContact = humanContacts.firstWhere(
        (c) => c.kind == 'connected' && c.displayName == peerBot!.displayName,
      );
      final peerContact2 = humanContacts.firstWhere(
        (c) => c.kind == 'connected' && c.displayName == peerBot2!.displayName,
      );

      await humanDb.into(humanDb.plans).insert(
            PlansCompanion.insert(
              id: housingPlanId,
              type: 'housing',
              createdAt: now,
            ),
          );
      await humanDb.into(humanDb.participants).insert(
            ParticipantsCompanion.insert(
              id: '$housingPlanId:self',
              displayName: 'Human',
              avatarId: 'mdi:0',
              createdAt: now,
            ),
          );
      await humanDb.into(humanDb.participants).insert(
            ParticipantsCompanion.insert(
              id: '$housingPlanId:p0',
              displayName: peerBot!.displayName,
              avatarId: peerBot.avatarId,
              createdAt: now,
              contactId: drift.Value(peerContact.id),
            ),
          );
      await humanDb.into(humanDb.participants).insert(
            ParticipantsCompanion.insert(
              id: '$housingPlanId:p1',
              displayName: peerBot2!.displayName,
              avatarId: peerBot2.avatarId,
              createdAt: now,
              contactId: drift.Value(peerContact2.id),
            ),
          );
      await humanDb.into(humanDb.proposalPackages).insert(
            ProposalPackagesCompanion.insert(
              id: 'pkg:$housingPlanId',
              planId: housingPlanId,
              createdAt: now,
              activeRevisionId: const drift.Value(revisionId),
            ),
          );
      await humanDb.into(humanDb.proposalRevisions).insert(
            ProposalRevisionsCompanion.insert(
              id: revisionId,
              packageId: 'pkg:$housingPlanId',
              contentHash: 'hash:$revisionId',
              proposerParticipantId: '$housingPlanId:self',
              payloadJson: jsonEncode({
                'kind': PlanAgreementProposalService.kind,
                'packageId': 'pkg:$housingPlanId',
                'revisionId': revisionId,
                'lifecycleState': 'archived',
                'proposerParticipantId': '$housingPlanId:self',
                'agreement': {
                  'periodStart': '2026-07-16',
                  'periodEnd': '2027-01-12',
                },
                'plan': {
                  'lines': [
                    {
                      'id': 'line:$housingPlanId:rent',
                      'title': 'Loyer',
                      'isRecurring': true,
                      'currency': 'CAD',
                    },
                  ],
                },
                'participantSnapshots': [
                  {
                    'id': '$housingPlanId:self',
                    'displayName': 'Human',
                    'avatarId': 'mdi:0',
                  },
                  {
                    'id': '$housingPlanId:p0',
                    'displayName': peerBot.displayName,
                    'avatarId': peerBot.avatarId,
                    'contactId': peerContact.id,
                  },
                  {
                    'id': '$housingPlanId:p1',
                    'displayName': peerBot2.displayName,
                    'avatarId': peerBot2.avatarId,
                    'contactId': peerContact2.id,
                  },
                ],
              }),
              createdAt: now,
            ),
          );
      await humanDb.into(humanDb.planLines).insert(
            PlanLinesCompanion.insert(
              id: 'line:$housingPlanId:rent',
              planId: housingPlanId,
              isRecurring: true,
              title: 'Loyer',
              currency: 'CAD',
              createdAt: now,
            ),
          );

      await humanDb.into(humanDb.realizedExpenses).insert(
            RealizedExpensesCompanion.insert(
              id: expenseId,
              packageId: 'pkg:$housingPlanId',
              planId: housingPlanId,
              planLineId: 'line:$housingPlanId:rent',
              status: RealizedExpenseStatus.proposed,
              amountMinor: 1000,
              currency: 'CAD',
              paymentDate: now,
              payerParticipantId: '$housingPlanId:self',
              kind: RealizedExpenseKind.normal,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await humanDb.into(humanDb.realizedExpenseAcceptances).insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$housingPlanId:self',
              decision: RealizedExpenseDecision.accepted,
              decidedAt: drift.Value(now),
            ),
          );
      await humanDb.into(humanDb.realizedExpenseAcceptances).insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$housingPlanId:p0',
              decision: RealizedExpenseDecision.pending,
            ),
          );
      await humanDb.into(humanDb.realizedExpenseAcceptances).insert(
            RealizedExpenseAcceptancesCompanion.insert(
              expenseId: expenseId,
              participantId: '$housingPlanId:p1',
              decision: RealizedExpenseDecision.pending,
            ),
          );

      // Bots have contacts only — no plan rows (cold restore).
      expect(await peerBot.db.listPlans(), isEmpty);
      expect(await peerBot2.db.listPlans(), isEmpty);

      await sim.acceptPendingRealizedExpenseReviewsAfterHumanDecision(
        expenseId: expenseId,
        initialDelay: Duration.zero,
        betweenBotDelay: Duration.zero,
      );

      for (final bot in [peerBot, peerBot2]) {
        expect(
          await HousingProposalTransportService(bot.db).hasActiveRevision(
            receivedPlanId,
          ),
          isTrue,
          reason:
              '${bot.displayName} must mirror human agreement (incl. 2nd bot '
              'after peer-mirror missing-revision)',
        );
        expect(
          await RealizedExpenseRepository(bot.db).getById(expenseId),
          isNotNull,
        );
        expect(
          (await RealizedExpenseRepository(bot.db).acceptancesFor(expenseId))
              .where((a) => a.participantId == '$receivedPlanId:self')
              .single
              .decision,
          RealizedExpenseDecision.accepted,
        );
      }
      expect(
        (await RealizedExpenseRepository(humanDb).acceptancesFor(expenseId))
            .where((a) => a.participantId == '$housingPlanId:p0')
            .single
            .decision,
        RealizedExpenseDecision.accepted,
      );
      expect(
        (await RealizedExpenseRepository(humanDb).acceptancesFor(expenseId))
            .where((a) => a.participantId == '$housingPlanId:p1')
            .single
            .decision,
        RealizedExpenseDecision.accepted,
        reason: '2nd bot (Ròberr-class) must land on human review table',
      );

      PeerSimulator.clearInstalled();
      SandboxRelay.clear();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
      AppDatabase.clearProcessScopeIfReferencing(humanDb);
      await humanDb.close();
      if (humanFile.existsSync()) humanFile.deleteSync();
    },
  );
}
