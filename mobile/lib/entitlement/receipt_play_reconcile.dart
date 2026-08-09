import 'store_receipt_record.dart';

/// Drops local Google Play receipts whose [productId] is absent from Play's
/// current purchase query (cancelled+expired / revoked / never restored).
///
/// Non-Play rows are kept. Call only after a **successful** Play query — an
/// empty [liveProductIds] from a failed query must not be passed here.
List<StoreReceiptRecord> reconcileGooglePlayReceipts({
  required Iterable<StoreReceiptRecord> local,
  required Set<String> liveProductIds,
}) {
  return [
    for (final r in local)
      if (r.platform != 'google_play' || liveProductIds.contains(r.productId)) r,
  ];
}
