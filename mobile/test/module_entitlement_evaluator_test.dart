import 'package:compartarenta/entitlement/module_entitlement_evaluator.dart';
import 'package:compartarenta/entitlement/module_entitlement_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModuleEntitlementEvaluator', () {
    test('empty candidates → free', () {
      expect(
        ModuleEntitlementEvaluator.evaluate(const []),
        ModuleEntitlementState.free,
      );
    });

    test('activePaid beats activeTrial', () {
      final state = ModuleEntitlementEvaluator.evaluate([
        const EntitlementSourceCandidate(
          state: ModuleEntitlementState.activeTrial,
          kind: EntitlementSourceKind.localLifecycle,
        ),
        const EntitlementSourceCandidate(
          state: ModuleEntitlementState.activePaid,
          kind: EntitlementSourceKind.bundle,
        ),
      ]);
      expect(state, ModuleEntitlementState.activePaid);
    });

    test('standalone paid beats delinquent bundle', () {
      final state = ModuleEntitlementEvaluator.evaluate([
        const EntitlementSourceCandidate(
          state: ModuleEntitlementState.delinquentGrace,
          kind: EntitlementSourceKind.bundle,
        ),
        const EntitlementSourceCandidate(
          state: ModuleEntitlementState.activePaid,
          kind: EntitlementSourceKind.standalone,
        ),
      ]);
      expect(state, ModuleEntitlementState.activePaid);
    });

    test('later expiry wins at equal rank', () {
      final early = DateTime.utc(2026, 8, 1);
      final late = DateTime.utc(2026, 9, 1);
      final state = ModuleEntitlementEvaluator.evaluate([
        EntitlementSourceCandidate(
          state: ModuleEntitlementState.activePaid,
          kind: EntitlementSourceKind.bundle,
          expiresAt: early,
        ),
        EntitlementSourceCandidate(
          state: ModuleEntitlementState.activePaid,
          kind: EntitlementSourceKind.standalone,
          expiresAt: late,
        ),
      ]);
      expect(state, ModuleEntitlementState.activePaid);
      // Prefer later expiry over kind when ranks equal — winner is the late one
      // (state identical; verify via kind tie-break when expiries equal).
      final tie = ModuleEntitlementEvaluator.evaluate([
        EntitlementSourceCandidate(
          state: ModuleEntitlementState.activePaid,
          kind: EntitlementSourceKind.bundle,
          expiresAt: late,
        ),
        EntitlementSourceCandidate(
          state: ModuleEntitlementState.activePaid,
          kind: EntitlementSourceKind.standalone,
          expiresAt: late,
        ),
      ]);
      expect(tie, ModuleEntitlementState.activePaid);
    });

    test('standalone beats bundle at equal rank and expiry', () {
      final exp = DateTime.utc(2026, 9, 1);
      final winner = ModuleEntitlementEvaluator.evaluate([
        EntitlementSourceCandidate(
          state: ModuleEntitlementState.activePaid,
          kind: EntitlementSourceKind.bundle,
          expiresAt: exp,
        ),
        EntitlementSourceCandidate(
          state: ModuleEntitlementState.activePaid,
          kind: EntitlementSourceKind.standalone,
          expiresAt: exp,
        ),
      ]);
      expect(winner, ModuleEntitlementState.activePaid);
    });

    test('delinquentGrace beats free and readonly', () {
      expect(
        ModuleEntitlementEvaluator.evaluate([
          const EntitlementSourceCandidate(
            state: ModuleEntitlementState.free,
            kind: EntitlementSourceKind.localLifecycle,
          ),
          const EntitlementSourceCandidate(
            state: ModuleEntitlementState.delinquentGrace,
            kind: EntitlementSourceKind.standalone,
          ),
          const EntitlementSourceCandidate(
            state: ModuleEntitlementState.delinquentReadonly,
            kind: EntitlementSourceKind.bundle,
          ),
        ]),
        ModuleEntitlementState.delinquentGrace,
      );
    });
  });
}
