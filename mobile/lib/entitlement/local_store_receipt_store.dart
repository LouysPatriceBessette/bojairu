import 'package:shared_preferences/shared_preferences.dart';

import 'store_receipt_record.dart';

/// Persists store receipt metadata on-device only (no entitlement HTTP upload).
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
    if (idx >= 0) {
      rows[idx] = record;
    } else {
      rows.add(record);
    }
    await saveAll(rows);
    return rows;
  }
}
