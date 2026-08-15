import 'package:shared_preferences/shared_preferences.dart';

import 'store_receipt_record.dart';

/// Persists store receipt metadata on-device.
///
/// Google Play purchase tokens are uploaded separately (entitlement HTTP).
class LocalStoreReceiptStore {
  LocalStoreReceiptStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const prefsKey = 'entitlement.store_receipts.v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<StoreReceiptRecord>> loadAll() async {
    final prefs = await _ensurePrefs();
    return StoreReceiptRecord.decodeList(prefs.getString(prefsKey));
  }

  Future<void> saveAll(List<StoreReceiptRecord> rows) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(prefsKey, StoreReceiptRecord.encodeList(rows));
  }

  /// Upsert by productId + purchaseTokenOrReceipt.
  Future<List<StoreReceiptRecord>> upsert(StoreReceiptRecord record) async {
    // [decodeList] may return a const empty list — copy before mutating.
    final rows = List<StoreReceiptRecord>.from(await loadAll());
    final idx = rows.indexWhere(
      (r) =>
          r.productId == record.productId &&
          r.purchaseTokenOrReceipt == record.purchaseTokenOrReceipt,
    );
    // Same SKU may have an older row (cancel then replace / resubscribe). Play
    // keeps the period end; keep the earlier purchasedAt / known expiresAt so
    // license-tester estimates do not jump forward on a new purchaseTime.
    var purchasedAt = record.purchasedAt;
    var expiresAt = record.expiresAt;
    for (final r in rows) {
      if (r.productId != record.productId) continue;
      if (r.purchasedAt.isBefore(purchasedAt)) {
        purchasedAt = r.purchasedAt;
      }
      expiresAt ??= r.expiresAt;
    }

    if (idx >= 0) {
      final prev = rows[idx];
      rows[idx] = StoreReceiptRecord(
        productId: record.productId,
        platform: record.platform,
        purchaseTokenOrReceipt: record.purchaseTokenOrReceipt,
        purchasedAt: purchasedAt,
        orderId: record.orderId ?? prev.orderId,
        expiresAt: expiresAt,
        autoRenewing: record.autoRenewing,
        acknowledged: record.acknowledged || prev.acknowledged,
        rawJson: record.rawJson ?? prev.rawJson,
      );
    } else {
      rows.add(
        StoreReceiptRecord(
          productId: record.productId,
          platform: record.platform,
          purchaseTokenOrReceipt: record.purchaseTokenOrReceipt,
          purchasedAt: purchasedAt,
          orderId: record.orderId,
          expiresAt: expiresAt,
          autoRenewing: record.autoRenewing,
          acknowledged: record.acknowledged,
          rawJson: record.rawJson,
        ),
      );
    }
    await saveAll(rows);
    return rows;
  }
}
