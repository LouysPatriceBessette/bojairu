import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../housing/realized_expense/realized_expense_participants.dart';
import '../notifications/housing_license_reminder_service.dart';
import '../prefs/app_preferences.dart';
import 'entitlement_coordinator.dart';
import 'housing_license_reminder_schedule.dart';
import 'housing_plan_license_access.dart';
import 'housing_trial_consumption_store.dart';
import 'housing_trial_eligibility.dart';
import 'module_entitlement_controller.dart';
import 'app_module_id.dart';

/// Applies local housing trial / grace clocks, reminders, and module state.
abstract final class HousingLicenseLifecycleSync {
  /// Test seam: when set, [apply] does not talk to the notification plugin.
  static Future<void> Function({
    required String planId,
    required List<HousingLicenseReminderSlot> slots,
    required DateTime now,
    required bool showDueImmediately,
    required bool paid,
  })?
  reminderSinkForTesting;

  static Future<void> apply({
    AppPreferences? prefs,
    AppDatabase? db,
    String? showDueImmediatelyForPlanId,
    DateTime? now,
  }) async {
    final p = prefs ?? await AppPreferences.load();
    final utc = (now ?? DateTime.now()).toUtc();
    final trialStore = await HousingTrialConsumptionStore.load();
    final entitlement = ModuleEntitlementController.maybeInstance;
    final paid = entitlement?.isActivePaid(AppModuleId.housing) ?? false;

    final worst = worstHousingLifecycleSnapshot(
      prefs: p,
      trialStore: trialStore,
      now: utc,
    );
    entitlement?.setHousingLifecycle(worst);

    for (final planId in p.housingPlanIdsWithActiveUseStarted()) {
      var eligible = trialStore.planTrialEligible(planId);
      if (eligible == null && db != null) {
        try {
          final roster = await participantsForPlan(db, planId);
          eligible = await housingRosterMayReceiveTrial(
            planId: planId,
            participantIds: roster.map((e) => e.id).toList(),
            trialStore: trialStore,
          );
          await trialStore.setPlanTrialEligible(planId, eligible);
        } on Object catch (e, st) {
          debugPrint('housing: trial eligibility refresh skipped: $e\n$st');
          eligible = true;
        }
      }
      eligible ??= true;
      final started = p.housingPlanActiveUseStartedAt(planId)?.toUtc();
      if (started == null) continue;
      final slots = housingLicenseReminderSlots(
        activeUseStartedAt: started,
        trialEligible: eligible,
      );
      final sink = reminderSinkForTesting;
      if (sink != null) {
        await sink(
          planId: planId,
          slots: slots,
          now: utc,
          showDueImmediately: planId == showDueImmediatelyForPlanId,
          paid: paid,
        );
      } else {
        await HousingLicenseReminderService.syncPlan(
          planId: planId,
          slots: slots,
          now: utc,
          showDueImmediately: planId == showDueImmediatelyForPlanId,
          paid: paid,
        );
      }
    }
  }

  static Future<HousingPlanLicenseView> viewForPlan({
    required String planId,
    AppPreferences? prefs,
    DateTime? now,
  }) async {
    final p = prefs ?? await AppPreferences.load();
    final trialStore = await HousingTrialConsumptionStore.load();
    return housingPlanLicenseView(
      prefs: p,
      trialStore: trialStore,
      planId: planId,
      now: (now ?? DateTime.now()).toUtc(),
      entitlement: ModuleEntitlementController.maybeInstance,
    );
  }

  static Future<void> consumeTrialIfEligible({
    required AppDatabase db,
    required String planId,
    required String selfParticipantId,
  }) async {
    final trialStore = await HousingTrialConsumptionStore.load();
    var eligible = trialStore.planTrialEligible(planId);
    if (eligible == null) {
      final roster = await participantsForPlan(db, planId);
      eligible = await housingRosterMayReceiveTrial(
        planId: planId,
        participantIds: roster.map((e) => e.id).toList(),
        trialStore: trialStore,
      );
      await trialStore.setPlanTrialEligible(planId, eligible);
    }
    if (!eligible) return;
    final coordinator = EntitlementCoordinator.maybeInstance;
    if (coordinator == null) return;
    final selfInstallation = await coordinator.installationIdForSnapshot(
      planId: planId,
      participantId: selfParticipantId,
    );
    if (selfInstallation.isNotEmpty) {
      await trialStore.markConsumed(selfInstallation);
    }
  }
}
