import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../db/repositories/vehicles_repository.dart';
import '../prefs/app_preferences.dart';
import '../prefs/time_zone_policy_field.dart';
import '../vehicle/vehicle_consumption_estimation_mode.dart';
import '../vehicle/vehicle_maintenance_categories.dart';
import '../housing/amendment/housing_active_agreement_service.dart';
import '../housing/participation/housing_participation_change_kind.dart';
import '../housing/participation/housing_participation_change_service.dart';
import '../housing/participation/housing_participation_hub_gates.dart';
import '../housing/participation/housing_participation_membership_service.dart';
import '../housing/participation/housing_voluntary_withdrawal_ack.dart';
import '../housing/proposals/housing_proposal_revision_state.dart';
import '../housing/proposals/housing_proposal_transport_service.dart';
import '../housing/settlement/housing_hub_expense_entry.dart';
import '../housing/settlement/housing_settlement_window.dart';
import 'qa_e2e_environment.dart';
import 'qa_e2e_meter_photo.dart';
import 'qa_fcm_wake_push_seed.dart';
import 'qa_payment_reminder_seed.dart';
import 'qa_scenario_seed_helpers.dart';
import 'qa_vehicle_consumption_seed.dart';
import 'qa_vehicle_sale_portability_seed.dart';
import 'qa_vehicle_seed_helpers.dart';
import 'qa_vehicle_sharing_active_seed.dart';
import 'qa_vehicle_sharing_offer_seed.dart';
import 'qa_vehicle_sharing_usage_history_2nd_fill_seed.dart';
import 'qa_vehicle_sharing_usage_history_3rd_fill_seed.dart';
import 'web_dev_db_snapshot.dart';

export 'qa_scenario_seed_helpers.dart' show kQaSettlementOpenPlanId;

/// File name under the app documents directory, written by [tool/seed_qa_scenario.sh].
const kQaAndroidSeedMarkerFileName = 'compartarenta_qa_seed';

/// Written after a successful [maybeApplyQaAndroidSeed] for shell polling (avoids stale logcat).
const kQaAndroidSeedAppliedFileName = 'compartarenta_qa_seed_applied.txt';

/// Scenario ids supported by [applyQaScenario].
const kQaScenarioIds = <String>{
  'period_end_day',
  'settlement_open',
  'settlement_last_day',
  'settlement_closed',
  'renewal_fork_visible',
  'voluntary_withdrawal_ack_j5',
  'voluntary_withdrawal_effective',
  'proposal_response_expired',
  'proposal_wizard_expenses',
  'vehicle_add',
  'vehicle_fuel_purchase',
  'vehicle_use_session',
  'vehicle_session_start_gap',
  'vehicle_standalone_meter_gap',
  'vehicle_consumption',
  'vehicle_sale_export_import_seller',
  'vehicle_sale_export_import_buyer',
  'contact_handshake_inviter',
  'contact_handshake_invitee',
  'vehicle_sharing_offer_owner',
  'vehicle_sharing_offer_borrower',
  'vehicle_sharing_active_owner',
  'vehicle_sharing_active_borrower',
  'vehicle_sharing_usage_history_2nd_fill_owner',
  'vehicle_sharing_usage_history_2nd_fill_borrower',
  'vehicle_sharing_usage_history_3rd_fill_owner',
  'vehicle_sharing_usage_history_3rd_fill_borrower',
  'fcm_wake_push_proposer',
  'fcm_wake_push_recipient',
  'housing_payment_reminder_simulate_before_due',
};

/// Reads the adb-pushed marker on Android debug builds, seeds Drift + prefs, then
/// deletes the marker. Returns the scenario id when seeding ran.
Future<String?> maybeApplyQaAndroidSeed(AppDatabase db) async {
  if (!kDebugMode || kIsWeb || !Platform.isAndroid) return null;

  final marker = await _qaSeedMarkerFile();
  if (marker == null || !await marker.exists()) return null;

  final scenarioId = (await marker.readAsString()).trim();
  try {
    await marker.delete();
  } catch (e) {
    debugPrint('qa seed: could not delete marker file: $e');
  }
  if (scenarioId.isEmpty || !kQaScenarioIds.contains(scenarioId)) {
    debugPrint('qa seed: unknown scenario id "$scenarioId"');
    return null;
  }

  await clearDevOperationalTables(db);
  await applyQaScenario(db, scenarioId);
  await applyQaSharedPreferences(scenarioId);
  await syncQaE2eFlagsFromPrefs();
  await db.syncWebStorageToDisk();
  await _writeQaSeedAppliedMarker(scenarioId);
  debugPrint('qa seed: applied scenario $scenarioId');
  return scenarioId;
}

Future<void> _writeQaSeedAppliedMarker(String scenarioId) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    await File('${dir.path}/$kQaAndroidSeedAppliedFileName').writeAsString(
      scenarioId,
    );
  } catch (e) {
    debugPrint('qa seed: could not write applied marker: $e');
  }
}

Future<File?> _qaSeedMarkerFile() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$kQaAndroidSeedMarkerFileName');
  } catch (e) {
    debugPrint('qa seed: could not resolve documents directory: $e');
    return null;
  }
}

Future<void> applyQaSharedPreferences(String scenarioId) async {
  final persona = _qaPersonaForScenario(scenarioId);
  final prefs = await AppPreferences.load();
  await prefs.setDisplayName(persona.displayName);
  await prefs.setAvatarId(persona.avatarId);
  await prefs.setCurrency('CAD');
  await prefs.setDateFormat('yyyy-MM-dd');
  await prefs.setDistanceUnit(DistanceUnit.km);
  await prefs.setPlanTypes({PlanType.housing});
  await prefs.setNotificationsEnabled(
    _qaNotificationsEnabledForScenario(scenarioId),
  );
  await _applyQaPaymentReminderPrefs(prefs, scenarioId);
  await prefs.setHousingDefaultPlanSummaryReached(
    scenarioId != 'proposal_wizard_expenses',
  );
  await prefs.setLanguageCode('fr');
  await prefs.completeOnboarding();
  await _persistQaE2eForScenario(scenarioId);
}

bool _qaNotificationsEnabledForScenario(String scenarioId) {
  return scenarioId == 'fcm_wake_push_recipient' ||
      scenarioId == 'housing_payment_reminder_simulate_before_due' ||
      scenarioId == 'vehicle_sharing_offer_owner' ||
      scenarioId == 'vehicle_sharing_offer_borrower' ||
      scenarioId == 'vehicle_sharing_active_owner' ||
      scenarioId == 'vehicle_sharing_active_borrower' ||
      scenarioId == 'vehicle_sharing_usage_history_2nd_fill_owner' ||
      scenarioId == 'vehicle_sharing_usage_history_2nd_fill_borrower' ||
      scenarioId == 'vehicle_sharing_usage_history_3rd_fill_owner' ||
      scenarioId == 'vehicle_sharing_usage_history_3rd_fill_borrower';
}

Future<void> _applyQaPaymentReminderPrefs(
  AppPreferences prefs,
  String scenarioId,
) async {
  if (!scenarioId.startsWith('housing_payment_reminder_')) return;
  await prefs.setTimeZonePolicy(kTimeZonePolicyExplicit);
  await prefs.setTimeZoneId('America/Toronto');
  await prefs.setNotificationHousingPaymentReminders(true);
}

Future<void> _persistQaE2eForScenario(String scenarioId) async {
  final meterPhotoOptional = _qaMeterPhotoOptionalForScenario(scenarioId);
  switch (scenarioId) {
    case 'housing_payment_reminder_simulate_before_due':
      await persistQaE2eEnvironment(
        scenarioId: scenarioId,
        meterPhotoOptional: meterPhotoOptional,
        paymentReminderPlanId: kQaPaymentReminderPlanId,
      );
    default:
      await persistQaE2eEnvironment(
        scenarioId: scenarioId,
        meterPhotoOptional: meterPhotoOptional,
      );
  }
}

/// Maestro vehicle flows that enter meter values without driving the camera.
///
/// Multi-device / hub seeds used for manual QA keep photo required (false).
bool _qaMeterPhotoOptionalForScenario(String scenarioId) {
  return switch (scenarioId) {
    'vehicle_fuel_purchase' ||
    'vehicle_use_session' ||
    'vehicle_session_start_gap' ||
    'vehicle_standalone_meter_gap' ||
    'vehicle_add' ||
    'vehicle_consumption' =>
      true,
    _ => false,
  };
}

({String displayName, String avatarId}) _qaPersonaForScenario(
  String scenarioId,
) {
  return switch (scenarioId) {
    'contact_handshake_invitee' => (
      displayName: 'Louys QA',
      avatarId: 'a02',
    ),
    'vehicle_sharing_offer_owner' => (
      displayName: 'Louys QA',
      avatarId: 'a02',
    ),
    'vehicle_sharing_active_owner' => (
      displayName: 'Louys QA',
      avatarId: 'a02',
    ),
    'vehicle_sale_export_import_buyer' => (
      displayName: 'Louys QA',
      avatarId: 'a02',
    ),
    'fcm_wake_push_recipient' => (
      displayName: 'Louys QA',
      avatarId: 'a02',
    ),
    'fcm_wake_push_proposer' => (
      displayName: 'Monica QA',
      avatarId: 'a01',
    ),
    'vehicle_sharing_offer_borrower' => (
      displayName: 'Monica QA',
      avatarId: 'a01',
    ),
    'vehicle_sharing_active_borrower' => (
      displayName: 'Monica QA',
      avatarId: 'a01',
    ),
    'vehicle_sharing_usage_history_2nd_fill_owner' => (
      displayName: 'Louys QA',
      avatarId: 'a02',
    ),
    'vehicle_sharing_usage_history_2nd_fill_borrower' => (
      displayName: 'Monica QA',
      avatarId: 'a01',
    ),
    'vehicle_sharing_usage_history_3rd_fill_owner' => (
      displayName: 'Louys QA',
      avatarId: 'a02',
    ),
    'vehicle_sharing_usage_history_3rd_fill_borrower' => (
      displayName: 'Monica QA',
      avatarId: 'a01',
    ),
    _ => (displayName: 'Monica QA', avatarId: 'a01'),
  };
}

Future<void> applyQaScenario(
  AppDatabase db,
  String scenarioId, {
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  switch (scenarioId) {
    case 'period_end_day':
      await _seedPeriodEndDay(db, clock);
    case 'settlement_open':
      await _seedSettlementOpen(db, clock);
    case 'settlement_last_day':
      await _seedSettlementLastDay(db, clock);
    case 'settlement_closed':
      await _seedSettlementClosed(db, clock);
    case 'renewal_fork_visible':
      await _seedRenewalForkVisible(db, clock);
    case 'voluntary_withdrawal_ack_j5':
      await _seedVoluntaryWithdrawalAckJ5(db, clock);
    case 'voluntary_withdrawal_effective':
      await _seedVoluntaryWithdrawalEffective(db, clock);
    case 'proposal_response_expired':
      await _seedProposalResponseExpired(db, clock);
    case 'proposal_wizard_expenses':
      await _seedProposalWizardExpenses(db, clock);
    case 'vehicle_add':
      break;
    case 'vehicle_fuel_purchase':
    case 'vehicle_use_session':
    case 'vehicle_session_start_gap':
    case 'vehicle_standalone_meter_gap':
      await qaSeedE2eVehicle(db);
    case 'vehicle_consumption':
      await qaSeedVehicleConsumptionScenario(db);
    case 'vehicle_sale_export_import_seller':
      await qaSeedVehicleSalePortabilitySeller(db);
    case 'vehicle_sale_export_import_buyer':
      break;
    case 'contact_handshake_inviter':
    case 'contact_handshake_invitee':
      break;
    case 'vehicle_sharing_offer_owner':
      await seedQaVehicleSharingOfferOwner(db);
    case 'vehicle_sharing_offer_borrower':
      await seedQaVehicleSharingOfferBorrower(db);
    case 'vehicle_sharing_active_owner':
      await seedQaVehicleSharingActiveOwner(db);
    case 'vehicle_sharing_active_borrower':
      await seedQaVehicleSharingActiveBorrower(db);
    case 'vehicle_sharing_usage_history_2nd_fill_owner':
      await seedQaVehicleSharingUsageHistory2ndFillOwner(db);
    case 'vehicle_sharing_usage_history_2nd_fill_borrower':
      await seedQaVehicleSharingUsageHistory2ndFillBorrower(db);
    case 'vehicle_sharing_usage_history_3rd_fill_owner':
      await seedQaVehicleSharingUsageHistory3rdFillOwner(db);
    case 'vehicle_sharing_usage_history_3rd_fill_borrower':
      await seedQaVehicleSharingUsageHistory3rdFillBorrower(db);
    case 'fcm_wake_push_proposer':
      await seedQaFcmWakePushProposer(db);
    case 'fcm_wake_push_recipient':
      await seedQaFcmWakePushRecipient(db);
    case 'housing_payment_reminder_simulate_before_due':
      await seedQaPaymentReminderActivePlan(db);
    case _:
      throw ArgumentError('Unknown QA scenario: $scenarioId');
  }
}

Future<void> _seedEndedHousingPlan({
  required AppDatabase db,
  required String planId,
  required String title,
  required DateTime periodEnd,
  bool withPublishedExpense = false,
}) async {
  await seedQaInForceHousingPlan(
    db: db,
    planId: planId,
    title: title,
    periodStart: qaPeriodStartBeforeEnd(periodEnd),
    periodEnd: periodEnd,
    withPublishedExpense: withPublishedExpense,
  );
}

Future<void> _seedPeriodEndDay(AppDatabase db, DateTime now) async {
  await _seedEndedHousingPlan(
    db: db,
    planId: qaPlanIdForScenario('period_end_day'),
    title: 'Entente QA fin de période',
    periodEnd: qaPeriodEndYesterdayNoonUtc(now),
  );
}

Future<void> _seedSettlementOpen(AppDatabase db, DateTime now) async {
  await _seedEndedHousingPlan(
    db: db,
    planId: kQaSettlementOpenPlanId,
    title: 'Entente QA règlement',
    periodEnd: qaPeriodEndYesterdayNoonUtc(now),
    withPublishedExpense: true,
  );
}

Future<void> _seedSettlementLastDay(AppDatabase db, DateTime now) async {
  await _seedEndedHousingPlan(
    db: db,
    planId: qaPlanIdForScenario('settlement_last_day'),
    title: 'Entente QA dernier jour règlement',
    periodEnd: qaPeriodEndForSettlementLastDayNoonUtc(now),
    withPublishedExpense: true,
  );
}

Future<void> _seedSettlementClosed(AppDatabase db, DateTime now) async {
  await _seedEndedHousingPlan(
    db: db,
    planId: qaPlanIdForScenario('settlement_closed'),
    title: 'Entente QA règlement fermé',
    periodEnd: qaPeriodEndForSettlementClosedNoonUtc(now),
    withPublishedExpense: true,
  );
}

Future<void> _seedRenewalForkVisible(AppDatabase db, DateTime now) async {
  await _seedEndedHousingPlan(
    db: db,
    planId: qaPlanIdForScenario('renewal_fork_visible'),
    title: 'Entente QA renouvellement',
    periodEnd: qaPeriodEndYesterdayNoonUtc(now),
  );
}

Future<void> _seedVoluntaryWithdrawalAckJ5(AppDatabase db, DateTime now) async {
  const scenarioId = 'voluntary_withdrawal_ack_j5';
  final planId = qaPlanIdForScenario(scenarioId);
  final today = qaLocalDateOnly(now);
  await _seedEndedHousingPlan(
    db: db,
    planId: planId,
    title: 'Entente QA retrait ack',
    periodEnd: qaPeriodEndYesterdayNoonUtc(now),
  );
  await seedQaVoluntaryWithdrawal(
    db: db,
    planId: planId,
    changeId: 'pc:qa-withdraw-ack',
    noticeAt: qaNoonUtcOnLocalCalendarDate(
      today.subtract(const Duration(days: 5)),
    ),
    departureDate: qaNoonUtcOnLocalCalendarDate(
      today.add(const Duration(days: 14)),
    ),
    monicaAcknowledged: false,
  );
}

Future<void> _seedVoluntaryWithdrawalEffective(AppDatabase db, DateTime now) async {
  const scenarioId = 'voluntary_withdrawal_effective';
  final planId = qaPlanIdForScenario(scenarioId);
  final today = qaLocalDateOnly(now);
  await _seedEndedHousingPlan(
    db: db,
    planId: planId,
    title: 'Entente QA retrait effectif',
    periodEnd: qaPeriodEndYesterdayNoonUtc(now),
  );
  await seedQaVoluntaryWithdrawal(
    db: db,
    planId: planId,
    changeId: 'pc:qa-withdraw-effective',
    noticeAt: qaNoonUtcOnLocalCalendarDate(
      today.subtract(const Duration(days: 10)),
    ),
    departureDate: qaNoonUtcOnLocalCalendarDate(today),
    monicaAcknowledged: true,
  );
}

Future<void> _seedProposalWizardExpenses(AppDatabase db, DateTime now) async {
  await seedQaProposalWizardDraft(
    db: db,
    planId: qaPlanIdForScenario('proposal_wizard_expenses'),
    now: now,
  );
}

Future<void> _seedProposalResponseExpired(AppDatabase db, DateTime now) async {
  final yesterday = qaLocalDateOnly(now).subtract(const Duration(days: 1));
  final weekAgo = qaLocalDateOnly(now).subtract(const Duration(days: 7));
  await seedQaExpiredPendingProposal(
    db: db,
    planId: qaPlanIdForScenario('proposal_response_expired'),
    title: 'Proposition QA expirée',
    responseExpiresAt: qaNoonUtcOnLocalCalendarDate(yesterday),
    createdAt: qaNoonUtcOnLocalCalendarDate(weekAgo),
    periodStart: qaNoonUtcOnLocalCalendarDate(
      qaLocalDateOnly(now).add(const Duration(days: 30)),
    ),
    periodEnd: qaNoonUtcOnLocalCalendarDate(
      qaAddCalendarMonths(qaLocalDateOnly(now), 8),
    ),
  );
}

/// Validates that [scenarioId] produces the expected hub state for [now].
Future<void> assertQaScenarioPostconditions({
  required AppDatabase db,
  required String scenarioId,
  required DateTime now,
}) async {
  await _assertPastHubTitleWhenPeriodClosed(db, scenarioId, now);
  switch (scenarioId) {
    case 'period_end_day':
      await _assertPeriodEndDay(db, now);
    case 'settlement_open':
      await _assertSettlementOpen(db, now);
    case 'settlement_last_day':
      await _assertSettlementLastDay(db, now);
    case 'settlement_closed':
      await _assertSettlementClosed(db, now);
    case 'renewal_fork_visible':
      await _assertRenewalForkVisible(db, now);
    case 'voluntary_withdrawal_ack_j5':
      await _assertVoluntaryWithdrawalAckJ5(db, now);
    case 'voluntary_withdrawal_effective':
      await _assertVoluntaryWithdrawalEffective(db, now);
    case 'proposal_response_expired':
      await _assertProposalResponseExpired(db, now);
    case 'proposal_wizard_expenses':
      await _assertProposalWizardExpenses(db, now);
    case 'vehicle_add':
      await _assertVehicleAdd(db);
    case 'vehicle_fuel_purchase':
      await _assertVehicleFuelPurchaseSeed(db);
    case 'vehicle_use_session':
      await _assertVehicleUseSessionSeed(db);
    case 'vehicle_session_start_gap':
    case 'vehicle_standalone_meter_gap':
      await _assertVehicleGapAttributionSeed(db);
    case 'vehicle_consumption':
      await _assertVehicleConsumptionSeed(db);
    case 'vehicle_sale_export_import_seller':
      await _assertVehicleSalePortabilitySellerSeed(db);
    case 'vehicle_sale_export_import_buyer':
      await _assertVehicleAdd(db);
    case _:
      throw ArgumentError('Unknown QA scenario: $scenarioId');
  }
}

/// Resolves hub expense mode using [now] (for QA postconditions; mirrors [resolveHubExpenseEntry]).
HousingHubExpenseEntryMode qaExpectedHubExpenseMode({
  required AppDatabase db,
  required Agreement agreement,
  required bool hasNonZeroOptimizedBalances,
  required DateTime now,
  bool participationEnterEnabled = true,
}) {
  if (!participationEnterEnabled) {
    return HousingHubExpenseEntryMode.disabled;
  }
  if (HousingActiveAgreementService(db).isAgreementPeriodOpen(
    agreement,
    now: now,
  )) {
    return HousingHubExpenseEntryMode.enterExpense;
  }
  if (isSettlementOpen(
    agreement: agreement,
    hasNonZeroOptimizedBalances: hasNonZeroOptimizedBalances,
    now: now,
  )) {
    return HousingHubExpenseEntryMode.settlementDue;
  }
  return HousingHubExpenseEntryMode.disabled;
}

/// Whether renewal fork should show at [now] (mirrors [hubRenewalForkAvailable]).
Future<bool> qaRenewalForkAvailableAt(
  AppDatabase db,
  String planId,
  DateTime now,
) async {
  final agreement = await db.getAgreementForPlan(planId);
  if (agreement == null) return false;
  if (HousingActiveAgreementService(db).isAgreementPeriodOpen(
    agreement,
    now: now,
  )) {
    return false;
  }
  final pkg = await (db.select(db.proposalPackages)
        ..where((t) => t.planId.equals(planId)))
      .getSingleOrNull();
  return pkg?.activeRevisionId != null;
}

Future<void> _assertPastHubTitleWhenPeriodClosed(
  AppDatabase db,
  String scenarioId,
  DateTime now,
) async {
  if (scenarioId == 'proposal_response_expired' ||
      scenarioId == 'proposal_wizard_expenses' ||
      scenarioId == 'vehicle_add' ||
      scenarioId == 'vehicle_fuel_purchase' ||
      scenarioId == 'vehicle_use_session' ||
      scenarioId == 'vehicle_session_start_gap' ||
      scenarioId == 'vehicle_standalone_meter_gap' ||
      scenarioId == 'vehicle_consumption' ||
      scenarioId == 'vehicle_sale_export_import_seller' ||
      scenarioId == 'vehicle_sale_export_import_buyer') {
    return;
  }
  final planId = qaPlanIdForScenario(scenarioId);
  final agreement = await db.getAgreementForPlan(planId);
  if (agreement == null) return;
  if (HousingActiveAgreementService(db).isAgreementPeriodOpen(
    agreement,
    now: now,
  )) {
    return;
  }
  const activeTitle = 'ACTIVE';
  const pastTitle = 'PAST';
  final parts = await HousingParticipationMembershipService(db).hubTitleParts(
    planId: planId,
    selfParticipantId: '$planId:self',
    activeHubTitleL10n: activeTitle,
    pastHubTitleL10n: pastTitle,
    formatDate: (d) => d.toIso8601String().substring(0, 10),
    now: now,
  );
  if (parts.titlePrefix != pastTitle) {
    throw StateError(
      '$scenarioId: expected past hub title when period closed, got ${parts.titlePrefix}',
    );
  }
}

Future<void> _assertPeriodEndDay(AppDatabase db, DateTime now) async {
  final planId = qaPlanIdForScenario('period_end_day');
  final agreement = await db.getAgreementForPlan(planId);
  if (agreement == null) {
    throw StateError('missing agreement for $planId');
  }
  final hasNonZero = await qaPlanHasNonZeroBalances(db, planId);
  if (hasNonZero) {
    throw StateError('period_end_day: expected zero balances');
  }
  if (isSettlementOpen(
    agreement: agreement,
    hasNonZeroOptimizedBalances: hasNonZero,
    now: now,
  )) {
    throw StateError('period_end_day: settlement must not be open at $now');
  }
  final mode = qaExpectedHubExpenseMode(
    db: db,
    agreement: agreement,
    hasNonZeroOptimizedBalances: hasNonZero,
    now: now,
  );
  if (mode != HousingHubExpenseEntryMode.disabled) {
    throw StateError(
      'period_end_day: expected disabled expense tile, got $mode',
    );
  }
}

Future<void> _assertSettlementOpen(AppDatabase db, DateTime now) async {
  final agreement = await db.getAgreementForPlan(kQaSettlementOpenPlanId);
  if (agreement == null) {
    throw StateError('missing agreement for $kQaSettlementOpenPlanId');
  }
  final hasNonZero = await qaPlanHasNonZeroBalances(db, kQaSettlementOpenPlanId);
  if (!isSettlementOpen(
    agreement: agreement,
    hasNonZeroOptimizedBalances: hasNonZero,
    now: now,
  )) {
    throw StateError('settlement_open: expected settlement open at $now');
  }
}

Future<void> _assertSettlementLastDay(AppDatabase db, DateTime now) async {
  final planId = qaPlanIdForScenario('settlement_last_day');
  final agreement = await db.getAgreementForPlan(planId);
  if (agreement == null) {
    throw StateError('missing agreement for $planId');
  }
  final hasNonZero = await qaPlanHasNonZeroBalances(db, planId);
  if (!isSettlementOpen(
    agreement: agreement,
    hasNonZeroOptimizedBalances: hasNonZero,
    now: now,
  )) {
    throw StateError('settlement_last_day: expected settlement open at $now');
  }
  final lastDay = settlementWindowLastDayInclusive(agreement.periodEnd);
  if (now.toLocal().day != lastDay.day ||
      now.toLocal().month != lastDay.month) {
    throw StateError(
      'settlement_last_day: expected last window day $lastDay at $now',
    );
  }
}

Future<void> _assertSettlementClosed(AppDatabase db, DateTime now) async {
  final planId = qaPlanIdForScenario('settlement_closed');
  final agreement = await db.getAgreementForPlan(planId);
  if (agreement == null) {
    throw StateError('missing agreement for $planId');
  }
  final hasNonZero = await qaPlanHasNonZeroBalances(db, planId);
  if (isSettlementOpen(
    agreement: agreement,
    hasNonZeroOptimizedBalances: hasNonZero,
    now: now,
  )) {
    throw StateError('settlement_closed: settlement must be closed at $now');
  }
  final mode = qaExpectedHubExpenseMode(
    db: db,
    agreement: agreement,
    hasNonZeroOptimizedBalances: hasNonZero,
    now: now,
  );
  if (mode != HousingHubExpenseEntryMode.disabled) {
    throw StateError(
      'settlement_closed: expected disabled expense tile, got $mode',
    );
  }
}

Future<void> _assertRenewalForkVisible(AppDatabase db, DateTime now) async {
  final planId = qaPlanIdForScenario('renewal_fork_visible');
  if (!await qaRenewalForkAvailableAt(db, planId, now)) {
    throw StateError('renewal_fork_visible: fork tile must be available at $now');
  }
}

Future<void> _assertVoluntaryWithdrawalAckJ5(AppDatabase db, DateTime now) async {
  final planId = qaPlanIdForScenario('voluntary_withdrawal_ack_j5');
  final change = await HousingParticipationChangeService(db).pendingForPlan(
    planId,
  );
  if (change == null) {
    throw StateError('voluntary_withdrawal_ack_j5: expected pending change');
  }
  final notice = voluntaryWithdrawalNoticeDateLocal(change.createdAt);
  final lastAckDay = voluntaryWithdrawalAckLastDayInclusive(notice);
  final today = DateTime(now.year, now.month, now.day);
  if (today != lastAckDay) {
    throw StateError(
      'voluntary_withdrawal_ack_j5: expected last ack day $lastAckDay at $now',
    );
  }
  final gates = await HousingParticipationHubGates.compute(
    db: db,
    planId: planId,
    selfParticipantId: '$planId:self',
    bannerTextBuilder:
        ({
          required String initiatorName,
          required String? targetName,
          required DateTime? departureDate,
        }) => 'banner',
    ejectionCandidateSubtitle: '',
  );
  if (!gates.gates.showParticipationBanner) {
    throw StateError('voluntary_withdrawal_ack_j5: expected participation banner');
  }
}

Future<void> _assertVoluntaryWithdrawalEffective(
  AppDatabase db,
  DateTime now,
) async {
  final planId = qaPlanIdForScenario('voluntary_withdrawal_effective');
  final changeSvc = HousingParticipationChangeService(db);
  final change = await changeSvc.getById('pc:qa-withdraw-effective');
  if (change == null) {
    throw StateError('voluntary_withdrawal_effective: missing change row');
  }
  if (change.planId != planId) {
    throw StateError(
      'voluntary_withdrawal_effective: change planId mismatch ($planId)',
    );
  }
  if (change.status != HousingParticipationChangeStatus.pending.wireValue) {
    throw StateError('voluntary_withdrawal_effective: expected pending before apply');
  }
  if (!await changeSvc.allDecidersHaveAccepted(change.id)) {
    throw StateError('voluntary_withdrawal_effective: all deciders must have accepted');
  }
  final departure = change.departureDate;
  if (departure == null) {
    throw StateError('voluntary_withdrawal_effective: missing departure date');
  }
  final today = DateTime(now.year, now.month, now.day);
  final depDay = DateTime(
    departure.toLocal().year,
    departure.toLocal().month,
    departure.toLocal().day,
  );
  if (today.isBefore(depDay)) {
    throw StateError(
      'voluntary_withdrawal_effective: departure $depDay must be reached at $now',
    );
  }
}

Future<void> _assertProposalResponseExpired(AppDatabase db, DateTime now) async {
  final planId = qaPlanIdForScenario('proposal_response_expired');
  final transport = HousingProposalTransportService(db);
  if (await transport.hasActiveRevision(planId)) {
    throw StateError('proposal_response_expired: must not have active revision');
  }
  final pkg = await (db.select(db.proposalPackages)
        ..where((t) => t.planId.equals(planId)))
      .getSingleOrNull();
  final pendingId = pkg?.pendingRevisionId;
  if (pendingId == null) {
    throw StateError('proposal_response_expired: expected pending revision');
  }
  final rev = await (db.select(db.proposalRevisions)
        ..where((t) => t.id.equals(pendingId)))
      .getSingleOrNull();
  if (rev == null) {
    throw StateError('proposal_response_expired: missing revision row');
  }
  final state = HousingProposalRevisionState.fromJson(rev.payloadJson);
  final expires = state.responseExpiresAtUtc;
  if (expires == null || !now.toUtc().isAfter(expires)) {
    throw StateError(
      'proposal_response_expired: responseExpiresAt $expires must be before $now',
    );
  }
}

Future<void> _assertProposalWizardExpenses(
  AppDatabase db,
  DateTime now,
) async {
  final planId = qaPlanIdForScenario('proposal_wizard_expenses');
  final transport = HousingProposalTransportService(db);
  if (await transport.hasActiveRevision(planId)) {
    throw StateError('proposal_wizard_expenses: must not have active revision');
  }
  final agreement = await db.getAgreementForPlan(planId);
  if (agreement == null) {
    throw StateError('proposal_wizard_expenses: missing agreement');
  }
  final today = qaLocalDateOnly(now);
  final day20 = DateTime(today.year, today.month, 20);
  final endLocal = qaLocalDateOnly(agreement.periodEnd);
  if (endLocal.isBefore(day20)) {
    throw StateError(
      'proposal_wizard_expenses: periodEnd $endLocal must include '
      'the 20th of the current month ($day20) for the recurrence picker',
    );
  }
  final lines = await db.listPlanLines(planId);
  if (lines.isNotEmpty) {
    throw StateError('proposal_wizard_expenses: seed must start with no expenses');
  }
  final co = await (db.select(db.participants)
        ..where((t) => t.id.equals('$planId:p0')))
      .getSingleOrNull();
  if (co?.contactId == null || co!.contactId!.isEmpty) {
    throw StateError('proposal_wizard_expenses: co-participant needs contactId');
  }
}

Future<void> _assertVehicleAdd(AppDatabase db) async {
  final vehicles = await VehiclesRepository(db).listOwnedVehicles();
  if (vehicles.isNotEmpty) {
    throw StateError('vehicle_add: seed must start with no vehicles');
  }
}

Future<void> _assertVehicleFuelPurchaseSeed(AppDatabase db) async {
  await _assertVehicleE2eSeedVehicle(db);
}

Future<void> _assertVehicleUseSessionSeed(AppDatabase db) async {
  await _assertVehicleGapAttributionSeed(db);
  final open = await VehiclesRepository(db).findAnyOpenUse();
  if (open != null) {
    throw StateError('vehicle_use_session: seed must not have an open use');
  }
}

Future<void> _assertVehicleConsumptionSeed(AppDatabase db) async {
  await _assertVehicleE2eSeedVehicle(db);
  final open = await VehiclesRepository(db).findAnyOpenUse();
  if (open != null) {
    throw StateError('vehicle_consumption: seed must not have an open use');
  }
  final uses = await (db.select(db.vehicleUses)).get();
  if (uses.length != 13) {
    throw StateError(
      'vehicle_consumption: expected 13 closed sessions, got ${uses.length}',
    );
  }
  final purchases = await (db.select(db.fuelPurchases)).get();
  if (purchases.length != 4) {
    throw StateError(
      'vehicle_consumption: expected 4 full-tank purchases, got ${purchases.length}',
    );
  }
  final meter =
      await VehiclesRepository(db).latestMeterValue(uses.first.vehicleId);
  if (meter != kQaVehicleConsumptionFinalMeterTenths) {
    throw StateError(
      'vehicle_consumption: expected final meter '
      '$kQaVehicleConsumptionFinalMeterTenths, got $meter',
    );
  }
  final vehicle = (await VehiclesRepository(db).listOwnedVehicles()).single;
  final mode = VehicleConsumptionEstimationMode.fromWire(
    vehicle.consumptionEstimationMode,
  );
  if (mode != VehicleConsumptionEstimationMode.detailed) {
    throw StateError('vehicle_consumption: expected detailed consumption mode');
  }
}

Future<void> _assertVehicleSalePortabilitySellerSeed(AppDatabase db) async {
  await _assertVehicleE2eSeedVehicle(db);
  final open = await VehiclesRepository(db).findAnyOpenUse();
  if (open != null) {
    throw StateError(
      'vehicle_sale_export_import_seller: seed must not have an open use',
    );
  }
  final uses = await (db.select(db.vehicleUses)).get();
  if (uses.length != kQaVehicleSalePortabilitySessionCount) {
    throw StateError(
      'vehicle_sale_export_import_seller: expected '
      '$kQaVehicleSalePortabilitySessionCount closed sessions, '
      'got ${uses.length}',
    );
  }
  final purchases = await (db.select(db.fuelPurchases)).get();
  if (purchases.length != kQaVehicleSalePortabilityFuelPurchaseCount) {
    throw StateError(
      'vehicle_sale_export_import_seller: expected '
      '$kQaVehicleSalePortabilityFuelPurchaseCount fuel purchases, '
      'got ${purchases.length}',
    );
  }
  final oil = await (db.select(db.maintenanceEvents)
        ..where(
          (t) => t.category.equals(VehicleMaintenanceCategoryWire.oil.wire),
        ))
      .get();
  if (oil.length != kQaVehicleSalePortabilityOilChangeCount) {
    throw StateError(
      'vehicle_sale_export_import_seller: expected '
      '$kQaVehicleSalePortabilityOilChangeCount oil change, got ${oil.length}',
    );
  }
  if (oil.single.costMinor != kQaVehicleSalePortabilityOilChangeCostMinor) {
    throw StateError(
      'vehicle_sale_export_import_seller: expected oil cost '
      '$kQaVehicleSalePortabilityOilChangeCostMinor, got ${oil.single.costMinor}',
    );
  }
}

Future<void> _assertVehicleGapAttributionSeed(AppDatabase db) async {
  await _assertVehicleE2eSeedVehicle(db);
  final open = await VehiclesRepository(db).findAnyOpenUse();
  if (open != null) {
    throw StateError('vehicle gap seed: must not have an open use');
  }
  final gaps = await db.select(db.vehicleOdometerGaps).get();
  if (gaps.isNotEmpty) {
    throw StateError('vehicle gap seed: must not have odometer gaps yet');
  }
}

Future<void> _assertVehicleE2eSeedVehicle(AppDatabase db) async {
  final vehicles = await VehiclesRepository(db).listOwnedVehicles();
  if (vehicles.length != 1) {
    throw StateError(
      'vehicle E2E seed: expected exactly one vehicle, got ${vehicles.length}',
    );
  }
  if (vehicles.single.displayLabel != kQaVehicleE2eDisplayLabel) {
    throw StateError(
      'vehicle E2E seed: unexpected display label ${vehicles.single.displayLabel}',
    );
  }
}
