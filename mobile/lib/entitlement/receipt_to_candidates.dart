import 'app_module_id.dart';
import 'module_entitlement_state.dart';
import 'store_product_catalog.dart';
import 'store_receipt_record.dart';

/// Grace window after a store receipt expires before read-only (local only).
const Duration kStoreReceiptGraceDuration = Duration(days: 7);

/// Projects local store receipts into per-module entitlement candidates.
abstract final class ReceiptToCandidates {
  static Map<AppModuleId, List<EntitlementSourceCandidate>> fromReceipts(
    Iterable<StoreReceiptRecord> receipts, {
    required DateTime now,
    Duration graceDuration = kStoreReceiptGraceDuration,
  }) {
    final out = <AppModuleId, List<EntitlementSourceCandidate>>{
      for (final m in AppModuleId.values)
        m: <EntitlementSourceCandidate>[],
    };

    for (final receipt in receipts) {
      final entry = StoreProductCatalog.entryForProductId(receipt.productId);
      if (entry == null) continue;

      final kind = entry.isBundle
          ? EntitlementSourceKind.bundle
          : EntitlementSourceKind.standalone;
      final candidate = _candidateForReceipt(
        receipt,
        now: now,
        kind: kind,
        graceDuration: graceDuration,
      );
      if (candidate == null) continue;

      for (final module in entry.grantsModules) {
        out[module]!.add(candidate);
      }
    }
    return out;
  }

  static EntitlementSourceCandidate? _candidateForReceipt(
    StoreReceiptRecord receipt, {
    required DateTime now,
    required EntitlementSourceKind kind,
    required Duration graceDuration,
  }) {
    final exp = receipt.expiresAt;
    if (exp == null || !exp.isBefore(now)) {
      return EntitlementSourceCandidate(
        state: ModuleEntitlementState.activePaid,
        kind: kind,
        expiresAt: exp,
      );
    }
    final graceEnd = exp.add(graceDuration);
    if (!now.isAfter(graceEnd)) {
      return EntitlementSourceCandidate(
        state: ModuleEntitlementState.delinquentGrace,
        kind: kind,
        expiresAt: graceEnd,
      );
    }
    return EntitlementSourceCandidate(
      state: ModuleEntitlementState.delinquentReadonly,
      kind: kind,
      expiresAt: graceEnd,
    );
  }
}
