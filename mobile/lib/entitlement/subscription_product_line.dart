import 'store_receipt_record.dart';

/// UI line state for one store product on the Licenses screen.
enum SubscriptionProductLineKind {
  /// No valid local receipt for this productId.
  none,

  /// Valid receipt with auto-renew still on.
  autoRenewing,

  /// Valid receipt; user cancelled renewal but period not expired.
  canceledStillValid,
}

/// Resolves the licenses-row status from local receipts for [productId].
SubscriptionProductLineKind subscriptionProductLineKind({
  required String productId,
  required Iterable<StoreReceiptRecord> receipts,
  required DateTime now,
}) {
  final receipt = validReceiptForProductId(
    productId: productId,
    receipts: receipts,
    now: now,
  );
  if (receipt == null) return SubscriptionProductLineKind.none;
  if (receipt.autoRenewing) return SubscriptionProductLineKind.autoRenewing;
  return SubscriptionProductLineKind.canceledStillValid;
}

/// Best still-valid receipt for [productId], or null.
///
/// When several tokens exist for the same SKU (cancel then resubscribe), prefer
/// an auto-renewing receipt over a canceled-but-still-valid one, then the later
/// [StoreReceiptRecord.purchasedAt], then the later [StoreReceiptRecord.expiresAt].
StoreReceiptRecord? validReceiptForProductId({
  required String productId,
  required Iterable<StoreReceiptRecord> receipts,
  required DateTime now,
}) {
  StoreReceiptRecord? best;
  for (final r in receipts) {
    if (r.productId != productId) continue;
    if (!r.isValidAt(now)) continue;
    if (best == null || _isPreferredReceipt(r, best)) {
      best = r;
    }
  }
  return best;
}

bool _isPreferredReceipt(
  StoreReceiptRecord candidate,
  StoreReceiptRecord incumbent,
) {
  if (candidate.autoRenewing != incumbent.autoRenewing) {
    return candidate.autoRenewing;
  }
  if (candidate.purchasedAt != incumbent.purchasedAt) {
    return candidate.purchasedAt.isAfter(incumbent.purchasedAt);
  }
  final a = candidate.expiresAt;
  final b = incumbent.expiresAt;
  if (a != null && (b == null || a.isAfter(b))) return true;
  return false;
}

/// True when [after] shows auto-renew turned off after [before] had it on,
/// and access remains until [after.expiresAt] (when known).
bool didCancelAutoRenew({
  required StoreReceiptRecord? before,
  required StoreReceiptRecord? after,
  required DateTime now,
}) {
  if (before == null || after == null) return false;
  if (before.productId != after.productId) return false;
  if (!before.autoRenewing) return false;
  if (after.autoRenewing) return false;
  return after.isValidAt(now);
}

/// Play subscriptions deep-link for a SKU (Android).
Uri playSubscriptionManagementUri({
  required String productId,
  required String packageName,
}) {
  return Uri.https(
    'play.google.com',
    '/store/account/subscriptions',
    <String, String>{
      'sku': productId,
      'package': packageName,
    },
  );
}
