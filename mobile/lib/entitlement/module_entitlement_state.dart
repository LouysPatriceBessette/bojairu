/// Per-module effective entitlement (housing lifecycle template).
enum ModuleEntitlementState {
  free,
  linkedNotActive,
  activeTrial,
  activePaid,
  delinquentGrace,
  delinquentReadonly,
}

/// Source kind for most-favorable evaluation (tie-break order).
enum EntitlementSourceKind {
  /// Standalone module store product.
  standalone,

  /// Bundle store product that includes the module.
  bundle,

  /// Local lifecycle (trial / grace / etc.) without a store receipt.
  localLifecycle,
}

/// One candidate contributing to a module's effective state.
class EntitlementSourceCandidate {
  const EntitlementSourceCandidate({
    required this.state,
    required this.kind,
    this.expiresAt,
  });

  final ModuleEntitlementState state;
  final EntitlementSourceKind kind;
  final DateTime? expiresAt;
}
