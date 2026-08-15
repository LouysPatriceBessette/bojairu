import 'app_module_id.dart';
import 'housing_lifecycle_source.dart';
import 'housing_trial_consumption_store.dart';
import 'module_entitlement_controller.dart';
import 'module_entitlement_state.dart';
import '../prefs/app_preferences.dart';

/// Per-plan housing trial / grace / read-only view (Play paid covers all plans).
class HousingPlanLicenseView {
  const HousingPlanLicenseView({
    required this.planState,
    required this.allowsNewRealizedExpense,
    required this.housingPaid,
    this.trialEndsAt,
    this.graceEndsAt,
    this.snapshot,
  });

  final ModuleEntitlementState planState;
  final bool allowsNewRealizedExpense;
  final bool housingPaid;
  final DateTime? trialEndsAt;
  final DateTime? graceEndsAt;
  final HousingLifecycleSnapshot? snapshot;

  bool get showGraceBanner =>
      !housingPaid && planState == ModuleEntitlementState.delinquentGrace;

  bool get showReadonlyBanner =>
      !housingPaid && planState == ModuleEntitlementState.delinquentReadonly;
}

/// Builds the local lifecycle snapshot for one plan's active-use clock.
HousingLifecycleSnapshot? housingLifecycleSnapshotForPlan({
  required AppPreferences prefs,
  required HousingTrialConsumptionStore trialStore,
  required String planId,
}) {
  final started = prefs.housingPlanActiveUseStartedAt(planId)?.toUtc();
  if (started == null) return null;
  final eligible = trialStore.planTrialEligible(planId) ?? true;
  return HousingLifecycleSource.forActiveUse(
    startedAt: started,
    trialEligible: eligible,
  );
}

HousingPlanLicenseView housingPlanLicenseView({
  required AppPreferences prefs,
  required HousingTrialConsumptionStore trialStore,
  required String planId,
  required DateTime now,
  ModuleEntitlementController? entitlement,
}) {
  final utc = now.toUtc();
  final paid =
      entitlement?.isActivePaid(AppModuleId.housing) ?? false;
  final snap = housingLifecycleSnapshotForPlan(
    prefs: prefs,
    trialStore: trialStore,
    planId: planId,
  );
  final life = snap == null
      ? null
      : HousingLifecycleSource.candidateFor(snap, now: utc);
  final planState = paid
      ? ModuleEntitlementState.activePaid
      : (life?.state ?? ModuleEntitlementState.free);
  final allows = paid ||
      snap == null ||
      planState == ModuleEntitlementState.activeTrial ||
      planState == ModuleEntitlementState.delinquentGrace ||
      planState == ModuleEntitlementState.activePaid;
  return HousingPlanLicenseView(
    planState: planState,
    allowsNewRealizedExpense: allows,
    housingPaid: paid,
    trialEndsAt: snap?.trialEndsAt,
    graceEndsAt: snap?.graceEndsAt,
    snapshot: snap,
  );
}

/// Least favorable unpaid local lifecycle among plans that started active use.
HousingLifecycleSnapshot? worstHousingLifecycleSnapshot({
  required AppPreferences prefs,
  required HousingTrialConsumptionStore trialStore,
  required DateTime now,
}) {
  HousingLifecycleSnapshot? worst;
  var worstScore = -1;
  for (final planId in prefs.housingPlanIdsWithActiveUseStarted()) {
    final snap = housingLifecycleSnapshotForPlan(
      prefs: prefs,
      trialStore: trialStore,
      planId: planId,
    );
    if (snap == null) continue;
    final state = HousingLifecycleSource.candidateFor(
      snap,
      now: now.toUtc(),
    )?.state;
    final score = _unpaidSeverity(state);
    if (score > worstScore) {
      worstScore = score;
      worst = snap;
    }
  }
  return worst;
}

int _unpaidSeverity(ModuleEntitlementState? state) {
  return switch (state) {
    ModuleEntitlementState.delinquentReadonly => 3,
    ModuleEntitlementState.delinquentGrace => 2,
    ModuleEntitlementState.activeTrial => 1,
    _ => 0,
  };
}
