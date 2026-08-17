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

  @override
  bool operator ==(Object other) =>
      other is HousingLifecycleSnapshot &&
      trialStartedAt == other.trialStartedAt &&
      trialEndsAt == other.trialEndsAt &&
      graceEndsAt == other.graceEndsAt &&
      linkedNotActive == other.linkedNotActive;

  @override
  int get hashCode => Object.hash(
        trialStartedAt,
        trialEndsAt,
        graceEndsAt,
        linkedNotActive,
      );
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

    // Payment-default grace lives on store receipts, not after trial.
    if (graceEnd != null && !now.isAfter(graceEnd)) {
      return EntitlementSourceCandidate(
        state: ModuleEntitlementState.delinquentGrace,
        kind: EntitlementSourceKind.localLifecycle,
        expiresAt: graceEnd,
      );
    }

    // Trial fully elapsed without a paid license: read-only (no grace).
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

  /// Trial timestamps only. Payment-default grace is on store receipts.
  static HousingLifecycleSnapshot afterTrialExpired({
    required DateTime trialStartedAt,
    required DateTime trialEndsAt,
  }) {
    return HousingLifecycleSnapshot(
      trialStartedAt: trialStartedAt,
      trialEndsAt: trialEndsAt,
    );
  }

  /// Clock for first realized-expense sync: 14-day trial, or immediate
  /// read-only when this installation (or a roster peer) already consumed
  /// housing trial.
  static HousingLifecycleSnapshot forActiveUse({
    required DateTime startedAt,
    required bool trialEligible,
  }) {
    final started = startedAt.toUtc();
    if (trialEligible) {
      return afterTrialExpired(
        trialStartedAt: started,
        trialEndsAt: started.add(kHousingTrialDuration),
      );
    }
    final trialEnds = started.subtract(const Duration(microseconds: 1));
    return afterTrialExpired(
      trialStartedAt: started.subtract(kHousingTrialDuration),
      trialEndsAt: trialEnds,
    );
  }
}
