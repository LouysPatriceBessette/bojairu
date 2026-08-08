import 'module_entitlement_state.dart';

/// Deterministic "most favorable source wins" evaluation.
///
/// Rank (higher wins):
/// `activePaid` > `activeTrial` > `delinquentGrace` > `linkedNotActive` >
/// `free` > `delinquentReadonly`.
///
/// At equal rank: later [EntitlementSourceCandidate.expiresAt] wins; if both
/// null or equal, kind order is standalone > bundle > localLifecycle.
abstract final class ModuleEntitlementEvaluator {
  static const Map<ModuleEntitlementState, int> _rank =
      <ModuleEntitlementState, int>{
    ModuleEntitlementState.activePaid: 60,
    ModuleEntitlementState.activeTrial: 50,
    ModuleEntitlementState.delinquentGrace: 40,
    ModuleEntitlementState.linkedNotActive: 30,
    ModuleEntitlementState.free: 20,
    ModuleEntitlementState.delinquentReadonly: 10,
  };

  static const Map<EntitlementSourceKind, int> _kindRank =
      <EntitlementSourceKind, int>{
    EntitlementSourceKind.standalone: 3,
    EntitlementSourceKind.bundle: 2,
    EntitlementSourceKind.localLifecycle: 1,
  };

  /// Returns the winning state, or [ModuleEntitlementState.free] if empty.
  static ModuleEntitlementState evaluate(
    Iterable<EntitlementSourceCandidate> candidates,
  ) {
    final list = candidates.toList(growable: false);
    if (list.isEmpty) return ModuleEntitlementState.free;

    EntitlementSourceCandidate? best;
    for (final c in list) {
      if (best == null || _isBetter(c, best)) {
        best = c;
      }
    }
    return best!.state;
  }

  static bool _isBetter(
    EntitlementSourceCandidate a,
    EntitlementSourceCandidate b,
  ) {
    final rankA = _rank[a.state]!;
    final rankB = _rank[b.state]!;
    if (rankA != rankB) return rankA > rankB;

    final expA = a.expiresAt;
    final expB = b.expiresAt;
    if (expA != null && expB != null && expA != expB) {
      return expA.isAfter(expB);
    }
    if (expA != null && expB == null) return true;
    if (expA == null && expB != null) return false;

    return _kindRank[a.kind]! > _kindRank[b.kind]!;
  }
}
