import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../../housing/participation/housing_inactive_participant_service.dart';
import '../../housing/participation/housing_participation_membership_service.dart';
import '../../entitlement/entitlement_coordinator.dart';
import '../../entitlement/housing_license_lifecycle_sync.dart';
import '../../prefs/app_preferences.dart';
import 'realized_expense_balance.dart';
import 'realized_expense_line_snapshot.dart';
import 'realized_expense_participants.dart';
import 'realized_expense_repository.dart';
import 'realized_expense_status.dart';

/// Review visibility for the local participant.
enum RealizedExpenseReviewVisibility {
  waitingForYou,
  waitingForOthers,
  published,
  rejected,
}

class RealizedExpenseReviewItem {
  const RealizedExpenseReviewItem({
    required this.expense,
    required this.visibility,
  });

  final RealizedExpense expense;
  final RealizedExpenseReviewVisibility visibility;
}

class RealizedExpensePendingSummary {
  const RealizedExpensePendingSummary({
    required this.waitingForYouCount,
    required this.waitingForOthersCount,
  });

  final int waitingForYouCount;
  final int waitingForOthersCount;

  int get totalPendingCount => waitingForYouCount + waitingForOthersCount;
}

/// Ledger queries and balance helpers (pass 3).
class RealizedExpenseLedgerService {
  RealizedExpenseLedgerService(this._db);

  final AppDatabase _db;

  String selfIdForPlan(String planId) => selfParticipantIdForPlan(planId);

  bool _shouldHideTransferUntilPublished(
    RealizedExpense expense,
    String selfParticipantId,
  ) {
    if (expense.kind != RealizedExpenseKind.transfer) return false;
    if (expense.status == RealizedExpenseStatus.published) return false;
    return selfParticipantId != expense.payerParticipantId &&
        selfParticipantId != expense.beneficiaryParticipantId;
  }

  bool _shouldShowInReviewQueue(
    RealizedExpense expense,
    String selfParticipantId,
  ) => !_shouldHideTransferUntilPublished(expense, selfParticipantId);

  Future<RealizedExpenseReviewVisibility> visibilityFor({
    required RealizedExpense expense,
    required String selfParticipantId,
  }) async {
    await RealizedExpenseRepository(_db).ensurePayerAcceptedIfPending(expense);
    final current = await RealizedExpenseRepository(_db).getById(expense.id);
    final row = current ?? expense;

    if (_shouldHideTransferUntilPublished(row, selfParticipantId)) {
      return RealizedExpenseReviewVisibility.waitingForOthers;
    }

    if (row.status == RealizedExpenseStatus.published) {
      return RealizedExpenseReviewVisibility.published;
    }
    if (row.status == RealizedExpenseStatus.rejected) {
      return RealizedExpenseReviewVisibility.rejected;
    }
    if (row.status == RealizedExpenseStatus.draft) {
      return RealizedExpenseReviewVisibility.waitingForOthers;
    }

    // The submitter does not review their own proposal.
    if (row.payerParticipantId == selfParticipantId) {
      return RealizedExpenseReviewVisibility.waitingForOthers;
    }

    final acceptances = await RealizedExpenseRepository(
      _db,
    ).acceptancesFor(row.id);
    String? mine;
    for (final a in acceptances) {
      if (a.participantId == selfParticipantId) {
        mine = a.decision;
        break;
      }
    }
    if (mine == RealizedExpenseDecision.rejected) {
      return RealizedExpenseReviewVisibility.rejected;
    }
    if (mine == RealizedExpenseDecision.pending) {
      return RealizedExpenseReviewVisibility.waitingForYou;
    }
    if (acceptances.any((a) => a.decision == RealizedExpenseDecision.pending)) {
      return RealizedExpenseReviewVisibility.waitingForOthers;
    }
    if (acceptances.every(
      (a) => a.decision == RealizedExpenseDecision.accepted,
    )) {
      return RealizedExpenseReviewVisibility.published;
    }
    return RealizedExpenseReviewVisibility.waitingForOthers;
  }

  Future<List<RealizedExpenseReviewItem>> listReviewItems({
    required String packageId,
    required String planId,
  }) async {
    final selfId = selfIdForPlan(planId);
    final rows =
        await (_db.select(_db.realizedExpenses)
              ..where((t) => t.packageId.equals(packageId))
              ..where(
                (t) => t.status.isIn([
                  RealizedExpenseStatus.proposed,
                  RealizedExpenseStatus.published,
                  RealizedExpenseStatus.rejected,
                ]),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();

    final out = <RealizedExpenseReviewItem>[];
    for (final expense in rows) {
      final visibility = await visibilityFor(
        expense: expense,
        selfParticipantId: selfId,
      );
      if (!_shouldShowInReviewQueue(expense, selfId)) continue;
      if (visibility != RealizedExpenseReviewVisibility.waitingForYou &&
          visibility != RealizedExpenseReviewVisibility.waitingForOthers) {
        continue;
      }
      out.add(
        RealizedExpenseReviewItem(expense: expense, visibility: visibility),
      );
    }
    return out;
  }

  Future<bool> shouldNotifyImportedProposal({
    required RealizedExpense expense,
    required String selfParticipantId,
  }) async {
    final visibility = await visibilityFor(
      expense: expense,
      selfParticipantId: selfParticipantId,
    );
    return visibility == RealizedExpenseReviewVisibility.waitingForYou;
  }

  Future<bool> shouldNotifyRejectedDecision({
    required RealizedExpense expense,
    required String selfParticipantId,
  }) => Future.value(expense.payerParticipantId == selfParticipantId);

  Future<bool> shouldNotifyAcceptedDecision({
    required RealizedExpense expense,
    required String selfParticipantId,
  }) => Future.value(expense.payerParticipantId == selfParticipantId);

  Future<int> countWaitingForYou({
    required String packageId,
    required String planId,
  }) async {
    final summary = await pendingSummary(packageId: packageId, planId: planId);
    return summary.waitingForYouCount;
  }

  Future<int> countWaitingForOthers({
    required String packageId,
    required String planId,
  }) async {
    final summary = await pendingSummary(packageId: packageId, planId: planId);
    return summary.waitingForOthersCount;
  }

  Future<RealizedExpensePendingSummary> pendingSummary({
    required String packageId,
    required String planId,
  }) async {
    final items = await listReviewItems(packageId: packageId, planId: planId);
    var waitingForYou = 0;
    var waitingForOthers = 0;
    for (final item in items) {
      if (item.visibility == RealizedExpenseReviewVisibility.waitingForYou) {
        waitingForYou++;
      } else if (item.visibility ==
          RealizedExpenseReviewVisibility.waitingForOthers) {
        waitingForOthers++;
      }
    }
    return RealizedExpensePendingSummary(
      waitingForYouCount: waitingForYou,
      waitingForOthersCount: waitingForOthers,
    );
  }

  Future<List<RealizedExpense>> listPublishedForMonth({
    required String packageId,
    required int year,
    required int month,
  }) async {
    final start = DateTime.utc(year, month, 1);
    final end = month == 12
        ? DateTime.utc(year + 1, 1, 1)
        : DateTime.utc(year, month + 1, 1);
    final rows =
        await (_db.select(_db.realizedExpenses)
              ..where((t) => t.packageId.equals(packageId))
              ..where((t) => t.status.equals(RealizedExpenseStatus.published))
              ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)]))
            .get();
    return rows
        .where((e) {
          final d = e.paymentDate.toUtc();
          return !d.isBefore(start) && d.isBefore(end);
        })
        .toList(growable: false);
  }

  /// All published expenses for one plan line (any payment date).
  Future<List<RealizedExpense>> listPublishedForPlanLine({
    required String packageId,
    required String planId,
    required String planLineId,
  }) async {
    final rows =
        await (_db.select(_db.realizedExpenses)
              ..where((t) => t.packageId.equals(packageId))
              ..where((t) => t.planId.equals(planId))
              ..where((t) => t.planLineId.equals(planLineId))
              ..where((t) => t.status.equals(RealizedExpenseStatus.published))
              ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)]))
            .get();
    return rows
        .where((e) => RealizedExpenseKind.usesPlanLine(e.kind))
        .toList(growable: false);
  }

  Future<List<RealizedExpense>> listRejectedForMonth({
    required String packageId,
    required String planId,
    required int year,
    required int month,
  }) async {
    final selfId = selfIdForPlan(planId);
    final start = DateTime.utc(year, month, 1);
    final end = month == 12
        ? DateTime.utc(year + 1, 1, 1)
        : DateTime.utc(year, month + 1, 1);
    final rows =
        await (_db.select(_db.realizedExpenses)
              ..where((t) => t.packageId.equals(packageId))
              ..where((t) => t.status.equals(RealizedExpenseStatus.rejected))
              ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)]))
            .get();
    return rows
        .where((e) {
          final d = e.paymentDate.toUtc();
          return !_shouldShowInReviewQueue(e, selfId)
              ? false
              : !d.isBefore(start) && d.isBefore(end);
        })
        .toList(growable: false);
  }

  Future<int> sumPublishedMinorForLineMonth({
    required String packageId,
    required String planId,
    required String planLineId,
    required int year,
    required int month,
  }) async {
    final published = await listPublishedForMonth(
      packageId: packageId,
      year: year,
      month: month,
    );
    return published
        .where((e) => e.planId == planId && e.planLineId == planLineId)
        .fold<int>(0, (sum, e) => sum + e.amountMinor);
  }

  Future<List<PairwiseBalanceEntry>> pairwiseBalancesForPlan(
    String planId,
  ) async {
    final data = await balanceDataForPlan(planId);
    return data.optimizedMode.edges;
  }

  Future<bool> hasNonZeroOptimizedBalances(String planId) async {
    final data = await balanceDataForPlan(planId);
    return data.optimizedMode.edges.any((e) => e.amountMinor > 0);
  }

  Future<HousingBalanceData> balanceDataForPlan(String planId) async {
    await HousingInactiveParticipantService(
      _db,
    ).ensureInactiveForDepartedMembers(planId);
    final membership = HousingParticipationMembershipService(_db);
    final roster = sortParticipantsByDisplayName(
      await membership.activeParticipantsForPlan(planId),
    );
    final inactiveRows =
        await HousingInactiveParticipantService(_db).listUncleared(planId);
    inactiveRows.sort((a, b) {
      final order = compareParticipantDisplayNames(
        a.displayNameSnapshot,
        b.displayNameSnapshot,
      );
      if (order != 0) return order;
      return a.id.compareTo(b.id);
    });
    final departedSourceToInactiveId = {
      for (final row in inactiveRows) row.sourceParticipantId: row.id,
    };
    final published =
        await (_db.select(_db.realizedExpenses)
              ..where((t) => t.planId.equals(planId))
              ..where((t) => t.status.equals(RealizedExpenseStatus.published)))
            .get();
    final ratios = await _db.listPlanRatios(planId);
    final ratiosByExpenseId = await resolveRatiosByExpenseId(
      db: _db,
      planId: planId,
      expenses: published,
      currentRatios: ratios,
    );
    final participants = <HousingBalanceParticipant>[
      for (var i = 0; i < roster.length; i++)
        HousingBalanceParticipant(
          participantId: roster[i].id,
          displayName: displayNameForParticipant(roster[i].id, roster),
          letter: String.fromCharCode(65 + i),
          orderIndex: i,
        ),
      for (var j = 0; j < inactiveRows.length; j++)
        HousingBalanceParticipant(
          participantId: inactiveRows[j].id,
          displayName: inactiveRows[j].displayNameSnapshot,
          letter: String.fromCharCode(65 + roster.length + j),
          orderIndex: roster.length + j,
          isInactive: true,
        ),
    ];
    return computeHousingBalanceData(
      publishedExpenses: published,
      planRatios: ratios,
      participants: participants,
      ratiosByExpenseId: ratiosByExpenseId,
      departedSourceToInactiveId: departedSourceToInactiveId,
    );
  }

  /// Net balance for [inactiveParticipantId] in optimized mode.
  ///
  /// Positive: inactive is a net creditor. Negative: inactive is a net debtor.
  Future<int> netBalanceMinorForInactive({
    required String planId,
    required String inactiveParticipantId,
  }) async {
    final data = await balanceDataForPlan(planId);
    final optimized = data.optimizedMode;
    var incoming = 0;
    var outgoing = 0;
    for (final edge in optimized.edges) {
      if (edge.fromParticipantId == inactiveParticipantId) {
        outgoing += edge.amountMinor;
      }
      if (edge.toParticipantId == inactiveParticipantId) {
        incoming += edge.amountMinor;
      }
    }
    return incoming - outgoing;
  }

  Future<void> markPlanActiveUseIfNeeded(String planId) async {
    final prefs = await AppPreferences.load();
    final alreadyStarted = prefs.isHousingPlanActiveUseStarted(planId);
    if (!alreadyStarted) {
      await prefs.markHousingPlanActiveUseStarted(planId);
    }

    try {
      await HousingLicenseLifecycleSync.consumeTrialIfEligible(
        db: _db,
        planId: planId,
        selfParticipantId: selfIdForPlan(planId),
      );
      if (!alreadyStarted) {
        final coordinator = EntitlementCoordinator.maybeInstance;
        if (coordinator != null) {
          await coordinator.reportActiveUse(planId: planId);
        }
      }
    } on Object catch (e, st) {
      debugPrint('housing: trial consumption on active use skipped: $e\n$st');
    }

    await HousingLicenseLifecycleSync.apply(
      prefs: prefs,
      db: _db,
      showDueImmediatelyForPlanId: alreadyStarted ? null : planId,
    );
  }
}
