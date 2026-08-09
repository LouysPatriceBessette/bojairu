import 'store_receipt_record.dart';

/// Drops local Google Play receipts whose purchase token is absent from Play's
/// current purchase query (replaced token after resubscribe, expired, revoked).
///
/// Non-Play rows are kept. Call only after a **successful** Play query — an
/// empty [livePurchaseTokens] from a failed query must not be passed here.
List<StoreReceiptRecord> reconcileGooglePlayReceipts({
  required Iterable<StoreReceiptRecord> local,
  required Set<String> livePurchaseTokens,
}) {
  return [
    for (final r in local)
      if (r.platform != 'google_play' ||
          livePurchaseTokens.contains(r.purchaseTokenOrReceipt))
        r,
  ];
}
