import 'package:compartarenta/entitlement/local_store_receipt_store.dart';
import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('upsert into empty store does not throw on const-empty decode', () async {
    final store = LocalStoreReceiptStore();
    final now = DateTime.utc(2026, 8, 9);
    final rows = await store.upsert(
      StoreReceiptRecord(
        productId: 'bojairu.bundle.all_modules',
        platform: 'google_play',
        purchaseTokenOrReceipt: 'tok',
        purchasedAt: now,
      ),
    );
    expect(rows, hasLength(1));
    expect(rows.single.productId, 'bojairu.bundle.all_modules');

    final loaded = await store.loadAll();
    expect(loaded, hasLength(1));
  });
}
