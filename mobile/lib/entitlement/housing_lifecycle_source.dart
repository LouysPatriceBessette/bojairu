import 'module_entitlement_state.dart';

/// Durations matching entitlement server defaults (14d trial, 7d grace).
const Duration kHousingTrialDuration = Duration(days: 14);
const Duration kHousingGraceDuration = Duration(days: 7);

/// Inputs for the housing local lifecycle candidate (no store receipt).
class HousingLifecycleSnapshot {
  const HousingLifecycleSnapshot({
    this.trialStartedAt,
    this.trialEndsAt,
    this.graceEndsAt,
    this.linkedNotActive = false,
  });

  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final DateTime? graceEndsAt;
  final bool linkedNotActive;
}

/// Maps housing local lifecycle timestamps → entitlement candidate.
abstract final class HousingLifecycleSource {
  static EntitlementSourceCandidate? candidateFor(
    HousingLifecycleSnapshot snap, {
    required DateTime now,
  }) {
    final trialEnd = snap.trialEndsAt;
    final graceEnd = snap.graceEndsAt;

    if (trialEnd != null && !now.isAfter(trialEnd)) {
      return EntitlementSourceCandidate(
        state: ModuleEntitlementState.activeTrial,
        kind: EntitlementSourceKind.localLifecycle,
        expiresAt: trialEnd,
      );
    }

    if (graceEnd != null && !now.isAfter(graceEnd)) {
      return EntitlementSourceCandidate(
        state: ModuleEntitlementState.delinquentGrace,
        kind: EntitlementSourceKind.localLifecycle,
        expiresAt: graceEnd,
      );
    }

    // Trial fully elapsed (and grace if any): read-only.
    if (snap.trialStartedAt != null &&
        trialEnd != null &&
        now.isAfter(trialEnd)) {
      return const EntitlementSourceCandidate(
        state: ModuleEntitlementState.delinquentReadonly,
        kind: EntitlementSourceKind.localLifecycle,
      );
    }

    if (snap.linkedNotActive) {
      return const EntitlementSourceCandidate(
        state: ModuleEntitlementState.linkedNotActive,
        kind: EntitlementSourceKind.localLifecycle,
      );
    }

    return null;
  }

  /// After trial ends without paid coverage: grace then readonly.
  static HousingLifecycleSnapshot afterTrialExpired({
    required DateTime trialStartedAt,
    required DateTime trialEndsAt,
    required DateTime now,
    Duration graceDuration = kHousingGraceDuration,
  }) {
    if (!now.isAfter(trialEndsAt)) {
      return HousingLifecycleSnapshot(
        trialStartedAt: trialStartedAt,
        trialEndsAt: trialEndsAt,
      );
    }
    final graceEnds = trialEndsAt.add(graceDuration);
    if (!now.isAfter(graceEnds)) {
      return HousingLifecycleSnapshot(
        trialStartedAt: trialStartedAt,
        trialEndsAt: trialEndsAt,
        graceEndsAt: graceEnds,
      );
    }
    return HousingLifecycleSnapshot(
      trialStartedAt: trialStartedAt,
      trialEndsAt: trialEndsAt,
      graceEndsAt: graceEnds,
    );
  }
}
