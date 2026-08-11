import 'app_module_id.dart';
import 'store_product_catalog.dart';
import 'store_receipt_record.dart';
import 'subscription_product_line.dart';

/// True when [module] is granted by at least one catalog product with a valid
/// Play receipt (trial / local lifecycle alone does not count).
bool moduleCoveredByPlayReceipt({
  required AppModuleId module,
  required Iterable<StoreReceiptRecord> receipts,
  required DateTime now,
}) {
  for (final entry in StoreProductCatalog.entries) {
    if (!entry.grantsModules.contains(module)) continue;
    if (validReceiptForProductId(
          productId: entry.productId,
          receipts: receipts,
          now: now,
        ) !=
        null) {
      return true;
    }
  }
  return false;
}

/// Product ids that currently have a valid Play receipt.
Set<String> paidProductIdsFromReceipts({
  required Iterable<StoreReceiptRecord> receipts,
  required DateTime now,
}) {
  final out = <String>{};
  for (final entry in StoreProductCatalog.entries) {
    if (validReceiptForProductId(
          productId: entry.productId,
          receipts: receipts,
          now: now,
        ) !=
        null) {
      out.add(entry.productId);
    }
  }
  return out;
}

/// Catalog entries whose modules are a non-empty subset of [cart], excluding
/// products already covered by a valid Play receipt.
///
/// [cart] = modules toggled to the « Déselectionner » (in-cart) state.
List<StoreCatalogEntry> filterSubscriptionOffers({
  required Set<AppModuleId> cart,
  required Set<String> paidProductIds,
}) {
  if (cart.isEmpty) return const <StoreCatalogEntry>[];
  return StoreProductCatalog.entries.where((entry) {
    final grants = entry.grantsModules.toSet();
    if (grants.isEmpty) return false;
    if (!grants.every(cart.contains)) return false;
    if (paidProductIds.contains(entry.productId)) return false;
    return true;
  }).toList(growable: false);
}

/// When true, the UI shows « Sélectionnez un module à ajouter » instead of radios.
bool shouldPromptSelectModuleToAdd({
  required Set<AppModuleId> cart,
  required Set<AppModuleId> coveredByPlay,
}) {
  if (cart.isEmpty) return true;
  return cart.every(coveredByPlay.contains);
}
