import 'package:compartarenta/entitlement/housing_lifecycle_source.dart';
import 'package:compartarenta/entitlement/module_entitlement_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final trialStart = DateTime.utc(2026, 8, 1);
  final trialEnd = trialStart.add(kHousingTrialDuration);

  test('during trial → activeTrial', () {
    final c = HousingLifecycleSource.candidateFor(
      HousingLifecycleSnapshot(
        trialStartedAt: trialStart,
        trialEndsAt: trialEnd,
      ),
      now: trialStart.add(const Duration(days: 3)),
    );
    expect(c?.state, ModuleEntitlementState.activeTrial);
  });

  test('after trial without purchase → delinquentReadonly (no grace)', () {
    final snap = HousingLifecycleSource.afterTrialExpired(
      trialStartedAt: trialStart,
      trialEndsAt: trialEnd,
    );
    final c = HousingLifecycleSource.candidateFor(
      snap,
      now: trialEnd.add(const Duration(days: 2)),
    );
    expect(c?.state, ModuleEntitlementState.delinquentReadonly);
  });

  test('well after trial → delinquentReadonly', () {
    final snap = HousingLifecycleSource.afterTrialExpired(
      trialStartedAt: trialStart,
      trialEndsAt: trialEnd,
    );
    final c = HousingLifecycleSource.candidateFor(
      snap,
      now: trialEnd.add(const Duration(days: 10)),
    );
    expect(c?.state, ModuleEntitlementState.delinquentReadonly);
  });

  test('snapshot taken at trial start still yields readonly after trial', () {
    final snap = HousingLifecycleSource.afterTrialExpired(
      trialStartedAt: trialStart,
      trialEndsAt: trialEnd,
    );
    expect(
      HousingLifecycleSource.candidateFor(
        snap,
        now: trialStart.add(const Duration(days: 1)),
      )?.state,
      ModuleEntitlementState.activeTrial,
    );
    expect(
      HousingLifecycleSource.candidateFor(
        snap,
        now: trialEnd.add(const Duration(days: 1)),
      )?.state,
      ModuleEntitlementState.delinquentReadonly,
    );
  });

  test('consumed trial starts read-only', () {
    final started = DateTime.utc(2026, 8, 15);
    final snap = HousingLifecycleSource.forActiveUse(
      startedAt: started,
      trialEligible: false,
    );
    expect(
      HousingLifecycleSource.candidateFor(snap, now: started)?.state,
      ModuleEntitlementState.delinquentReadonly,
    );
  });
}
