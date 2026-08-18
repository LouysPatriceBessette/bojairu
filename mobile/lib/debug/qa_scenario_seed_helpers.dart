import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart' show DateUtils;

import '../db/app_database.dart';
import '../housing/participation/housing_participation_change_kind.dart';
import '../housing/participation/housing_participation_membership_service.dart';
import '../housing/proposals/plan_agreement_proposal_service.dart';
import '../housing/realized_expense/realized_expense_ledger_service.dart';
import '../housing/realized_expense/realized_expense_status.dart';
import '../housing/settlement/housing_settlement_window.dart';

/// Shared agreement anchor for QA drafts that still need a fixed calendar
/// (FCM wake housing draft). Hub-gating scenarios and
/// `proposal_wizard_expenses` do **not** use these — they seed relative to
/// [DateTime.now].
final kQaAnchorPeriodStart = DateTime.utc(2027, 1, 1, 12);
final kQaAnchorPeriodEnd = DateTime.utc(2027, 8, 10, 12);
final kQaSeedCreatedAt = DateTime.utc(2027, 1, 1);

DateTime qaLocalDateOnly(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime qaNoonUtcOnLocalCalendarDate(DateTime localDate) {
  final d = DateTime(localDate.year, localDate.month, localDate.day);
  return DateTime.utc(d.year, d.month, d.day, 12);
}

DateTime qaAddCalendarMonths(DateTime localDate, int months) {
  final d = DateTime(localDate.year, localDate.month, localDate.day);
  var year = d.year;
  var month = d.month + months;
  while (month > 12) {
    month -= 12;
    year++;
  }
  while (month < 1) {
    month += 12;
    year--;
  }
  final daysInMonth = DateUtils.getDaysInMonth(year, month);
  final day = d.day <= daysInMonth ? d.day : daysInMonth;
  return DateTime(year, month, day);
}

/// `periodEnd` = yesterday local — today is the first day after the term.
DateTime qaPeriodEndYesterdayNoonUtc(DateTime now) {
  final yesterday = qaLocalDateOnly(now).subtract(const Duration(days: 1));
  return qaNoonUtcOnLocalCalendarDate(yesterday);
}

DateTime qaPeriodStartBeforeEnd(DateTime periodEndUtc, {int months = 7}) {
  final endLocal = DateUtils.dateOnly(periodEndUtc.toLocal());
  return qaNoonUtcOnLocalCalendarDate(qaAddCalendarMonths(endLocal, -months));
}

/// `periodEnd` one calendar month before today, so today is the last
/// inclusive settlement-window day when the day-of-month round-trips.
DateTime qaPeriodEndForSettlementLastDayNoonUtc(DateTime now) {
  final today = qaLocalDateOnly(now);
  return qaNoonUtcOnLocalCalendarDate(qaAddCalendarMonths(today, -1));
}

/// Window last day = yesterday → settlement is closed today.
DateTime qaPeriodEndForSettlementClosedNoonUtc(DateTime now) {
  final yesterday = qaLocalDateOnly(now).subtract(const Duration(days: 1));
  return qaNoonUtcOnLocalCalendarDate(qaAddCalendarMonths(yesterday, -1));
}

DateTime qaExpenseDuringPeriodNoonUtc(DateTime periodStart, DateTime periodEnd) {
  final startLocal = DateUtils.dateOnly(periodStart.toLocal());
  final endLocal = DateUtils.dateOnly(periodEnd.toLocal());
  final mid = startLocal.add(const Duration(days: 14));
  final chosen = mid.isAfter(endLocal) ? startLocal : mid;
  return qaNoonUtcOnLocalCalendarDate(chosen);
}

bool qaSettlementLastDayRoundTrips(DateTime now) {
  final today = qaLocalDateOnly(now);
  final periodEnd = qaPeriodEndForSettlementLastDayNoonUtc(now);
  final lastDay = settlementWindowLastDayInclusive(periodEnd);
  return lastDay.year == today.year &&
      lastDay.month == today.month &&
      lastDay.day == today.day;
}

/// Plan id for the [settlement_open] QA scenario.
const kQaSettlementOpenPlanId = 'housing:qa-settlement-open';

String qaPlanIdForScenario(String scenarioId) {
  return switch (scenarioId) {
    'period_end_day' => 'housing:qa-period-end-day',
    'settlement_open' => kQaSettlementOpenPlanId,
    'settlement_last_day' => 'housing:qa-settlement-last-day',
    'settlement_closed' => 'housing:qa-settlement-closed',
    'renewal_fork_visible' => 'housing:qa-renewal-fork',
    'voluntary_withdrawal_ack_j5' => 'housing:qa-withdraw-ack',
    'voluntary_withdrawal_effective' => 'housing:qa-withdraw-effective',
    'proposal_response_expired' => 'housing:qa-proposal-expired',
    'proposal_wizard_expenses' => 'housing:qa-proposal-wizard',
    _ => throw ArgumentError('Unknown QA scenario: $scenarioId'),
  };
}

/// Orphan housing draft: participants + agreement dates, no expenses yet (wizard step 2).
///
/// Period starts on the 1st of [now]'s month and ends eight months later so the
/// recurrence picker (`firstDate` = 1st of current month, `lastDate` = period
/// end) always includes the 15th and 20th of the current month.
Future<void> seedQaProposalWizardDraft({
  required AppDatabase db,
  required String planId,
  required DateTime now,
}) async {
  const coContactId = 'contact:qa:wizard-co';
  final today = qaLocalDateOnly(now);
  final createdAt = qaNoonUtcOnLocalCalendarDate(today);
  final periodStart = qaNoonUtcOnLocalCalendarDate(
    DateTime(today.year, today.month, 1),
  );
  final periodEnd = qaNoonUtcOnLocalCalendarDate(qaAddCalendarMonths(today, 8));
  final selfId = '$planId:self';
  final coId = '$planId:p0';

  await db.upsertContact(
    ContactsCompanion.insert(
      id: coContactId,
      kind: 'connected',
      displayName: 'Louys QA',
      avatarId: 'mdi:1',
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );
  await db.upsertPlan(
    PlansCompanion.insert(
      id: planId,
      type: 'housing',
      createdAt: createdAt,
      title: const drift.Value('Entente QA wizard dépenses'),
      currency: const drift.Value('CAD'),
      notes: const drift.Value.absent(),
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: selfId,
      displayName: 'Monica QA',
      avatarId: 'mdi:0',
      createdAt: createdAt,
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: coId,
      displayName: 'Louys QA',
      avatarId: 'mdi:1',
      contactId: const drift.Value(coContactId),
      createdAt: createdAt,
    ),
  );
  await db.upsertAgreement(
    AgreementsCompanion.insert(
      id: 'agreement:$planId',
      planId: planId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      minNoticeDays: const drift.Value(30),
      penaltyMinor: const drift.Value(0),
      clauses: const drift.Value(''),
      withdrawalSameForAll: const drift.Value('true'),
      withdrawalPerParticipantJson: const drift.Value('{}'),
      agreementRulesJson: const drift.Value('{}'),
      version: const drift.Value(1),
      createdAt: createdAt,
    ),
  );
}

/// Seeds Monica (self) + Louys with an in-force housing plan and optional expense.
Future<void> seedQaInForceHousingPlan({
  required AppDatabase db,
  required String planId,
  required String title,
  DateTime? periodStart,
  DateTime? periodEnd,
  bool withPublishedExpense = false,
}) async {
  final start = periodStart ?? kQaAnchorPeriodStart;
  final end = periodEnd ?? kQaAnchorPeriodEnd;
  final packageId = 'pkg:$planId';
  final revisionId = 'rev:$planId:active';
  final lineId = 'line:$planId:rent';
  final selfId = '$planId:self';
  final coId = '$planId:p0';
  final createdAt = start;

  await db.upsertPlan(
    PlansCompanion.insert(
      id: planId,
      type: 'housing',
      createdAt: createdAt,
      title: drift.Value(title),
      currency: const drift.Value('CAD'),
      notes: const drift.Value.absent(),
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: selfId,
      displayName: 'Monica QA',
      avatarId: 'mdi:0',
      createdAt: createdAt,
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: coId,
      displayName: 'Louys QA',
      avatarId: 'mdi:1',
      createdAt: createdAt,
    ),
  );
  await db.upsertAgreement(
    AgreementsCompanion.insert(
      id: 'agreement:$planId',
      planId: planId,
      periodStart: start,
      periodEnd: end,
      minNoticeDays: const drift.Value(30),
      penaltyMinor: const drift.Value(0),
      clauses: const drift.Value(''),
      withdrawalSameForAll: const drift.Value('true'),
      withdrawalPerParticipantJson: const drift.Value('{}'),
      agreementRulesJson: const drift.Value('{}'),
      version: const drift.Value(1),
      createdAt: createdAt,
    ),
  );
  await db.upsertPlanLine(
    PlanLinesCompanion.insert(
      id: lineId,
      planId: planId,
      isRecurring: true,
      title: 'Loyer',
      currency: 'CAD',
      amountMinor: const drift.Value(100000),
      recurrenceDayOfMonth: const drift.Value(1),
      sortOrder: const drift.Value(0),
      createdAt: createdAt,
    ),
  );
  for (final pid in [selfId, coId]) {
    await db.upsertPlanRatio(
      PlanRatiosCompanion.insert(
        id: 'ratio:$lineId:$pid',
        planId: planId,
        lineId: drift.Value(lineId),
        participantId: pid,
        weight: 5000,
        createdAt: createdAt,
      ),
    );
  }

  final payload = <String, Object?>{
    'kind': PlanAgreementProposalService.kind,
    'lifecycleState': 'archived',
    'agreement': {
      'periodStart': start.toUtc().toIso8601String(),
      'periodEnd': end.toUtc().toIso8601String(),
    },
  };
  await db.into(db.proposalPackages).insertOnConflictUpdate(
    ProposalPackagesCompanion.insert(
      id: packageId,
      planId: planId,
      createdAt: createdAt,
      activeRevisionId: drift.Value(revisionId),
      pendingRevisionId: const drift.Value.absent(),
    ),
  );
  await db.into(db.proposalRevisions).insert(
    ProposalRevisionsCompanion.insert(
      id: revisionId,
      packageId: packageId,
      contentHash: 'qa:$revisionId',
      proposerParticipantId: selfId,
      payloadJson: jsonEncode(payload),
      createdAt: createdAt,
    ),
  );

  if (withPublishedExpense) {
    final expenseAt = qaExpenseDuringPeriodNoonUtc(start, end);
    await db.into(db.realizedExpenses).insert(
      RealizedExpensesCompanion.insert(
        id: 'expense:$planId:1',
        packageId: packageId,
        planId: planId,
        planLineId: lineId,
        amountMinor: 20000,
        currency: 'CAD',
        paymentDate: expenseAt,
        payerParticipantId: selfId,
        kind: RealizedExpenseKind.normal,
        status: RealizedExpenseStatus.published,
        createdAt: expenseAt,
        updatedAt: expenseAt,
      ),
    );
  }

  await HousingParticipationMembershipService(db).ensureMembershipsForPlan(planId);
}

Future<void> seedQaVoluntaryWithdrawal({
  required AppDatabase db,
  required String planId,
  required String changeId,
  required DateTime noticeAt,
  required DateTime departureDate,
  required bool monicaAcknowledged,
}) async {
  final packageId = 'pkg:$planId';
  final louysId = '$planId:p0';
  final monicaId = '$planId:self';

  await db.into(db.housingParticipationChanges).insert(
    HousingParticipationChangesCompanion.insert(
      id: changeId,
      planId: planId,
      packageId: packageId,
      kind: HousingParticipationChangeKind.voluntaryWithdrawal.wireValue,
      initiatorParticipantId: louysId,
      targetParticipantId: drift.Value(louysId),
      departureDate: drift.Value(departureDate),
      status: HousingParticipationChangeStatus.pending.wireValue,
      createdAt: noticeAt,
    ),
  );

  if (monicaAcknowledged) {
    await db.into(db.housingParticipationDecisions).insertOnConflictUpdate(
      HousingParticipationDecisionsCompanion.insert(
        changeId: changeId,
        participantId: monicaId,
        status: HousingParticipationDecisionStatus.accepted.wireValue,
        decidedAt: drift.Value(noticeAt),
      ),
    );
  }
}

/// Open proposal past [responseExpiresAt] with no active revision (expires on module entry).
Future<void> seedQaExpiredPendingProposal({
  required AppDatabase db,
  required String planId,
  required String title,
  required DateTime responseExpiresAt,
  DateTime? createdAt,
  DateTime? periodStart,
  DateTime? periodEnd,
}) async {
  final packageId = 'pkg:$planId';
  final revisionId = 'rev:$planId:pending';
  final selfId = '$planId:self';
  final coId = '$planId:p0';
  final created = createdAt ?? kQaSeedCreatedAt;
  final start = periodStart ?? kQaAnchorPeriodStart;
  final end = periodEnd ?? kQaAnchorPeriodEnd;

  await db.upsertPlan(
    PlansCompanion.insert(
      id: planId,
      type: 'housing',
      createdAt: created,
      title: drift.Value(title),
      currency: const drift.Value('CAD'),
      notes: const drift.Value.absent(),
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: selfId,
      displayName: 'Monica QA',
      avatarId: 'mdi:0',
      createdAt: created,
    ),
  );
  await db.upsertParticipant(
    ParticipantsCompanion.insert(
      id: coId,
      displayName: 'Louys QA',
      avatarId: 'mdi:1',
      createdAt: created,
    ),
  );
  await db.upsertAgreement(
    AgreementsCompanion.insert(
      id: 'agreement:$planId',
      planId: planId,
      periodStart: start,
      periodEnd: end,
      minNoticeDays: const drift.Value(30),
      penaltyMinor: const drift.Value(0),
      clauses: const drift.Value(''),
      withdrawalSameForAll: const drift.Value('true'),
      withdrawalPerParticipantJson: const drift.Value('{}'),
      agreementRulesJson: const drift.Value('{}'),
      version: const drift.Value(1),
      createdAt: created,
    ),
  );

  final payload = <String, Object?>{
    'kind': PlanAgreementProposalService.kind,
    'lifecycleState': 'open',
    'responseExpiresAt': responseExpiresAt.toUtc().toIso8601String(),
    'plan': {'title': title},
    'agreement': {
      'periodStart': start.toUtc().toIso8601String(),
      'periodEnd': end.toUtc().toIso8601String(),
    },
  };
  await db.into(db.proposalPackages).insertOnConflictUpdate(
    ProposalPackagesCompanion.insert(
      id: packageId,
      planId: planId,
      createdAt: created,
      pendingRevisionId: drift.Value(revisionId),
    ),
  );
  await db.into(db.proposalRevisions).insert(
    ProposalRevisionsCompanion.insert(
      id: revisionId,
      packageId: packageId,
      contentHash: 'qa:$revisionId',
      proposerParticipantId: selfId,
      payloadJson: jsonEncode(payload),
      createdAt: created,
    ),
  );
}

Future<bool> qaPlanHasNonZeroBalances(AppDatabase db, String planId) {
  return RealizedExpenseLedgerService(db).hasNonZeroOptimizedBalances(planId);
}
