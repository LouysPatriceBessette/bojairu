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

  test('upsert keeps earlier purchasedAt and previous expiresAt if omitted', () async {
    final store = LocalStoreReceiptStore();
    final signup = DateTime.utc(2026, 8, 9, 20);
    final expiry = signup.add(const Duration(minutes: 5));
    await store.upsert(
      StoreReceiptRecord(
        productId: 'bojairu.housing',
        platform: 'google_play',
        purchaseTokenOrReceipt: 'tok',
        purchasedAt: signup,
        expiresAt: expiry,
        autoRenewing: true,
      ),
    );
    final rows = await store.upsert(
      StoreReceiptRecord(
        productId: 'bojairu.housing',
        platform: 'google_play',
        purchaseTokenOrReceipt: 'tok',
        purchasedAt: signup.add(const Duration(minutes: 1)),
        autoRenewing: false,
      ),
    );
    expect(rows.single.purchasedAt, signup);
    expect(rows.single.expiresAt, expiry);
    expect(rows.single.autoRenewing, isFalse);
  });

  test('new token for same SKU keeps earlier purchasedAt from peer row', () async {
    final store = LocalStoreReceiptStore();
    final signup = DateTime.utc(2026, 8, 9, 23, 4);
    await store.upsert(
      StoreReceiptRecord(
        productId: 'bojairu.housing',
        platform: 'google_play',
        purchaseTokenOrReceipt: 'old',
        purchasedAt: signup,
        autoRenewing: false,
      ),
    );
    final rows = await store.upsert(
      StoreReceiptRecord(
        productId: 'bojairu.housing',
        platform: 'google_play',
        purchaseTokenOrReceipt: 'new',
        purchasedAt: signup.add(const Duration(minutes: 4)),
        autoRenewing: true,
      ),
    );
    final neu = rows.firstWhere((r) => r.purchaseTokenOrReceipt == 'new');
    expect(neu.purchasedAt, signup);
    expect(neu.autoRenewing, isTrue);
  });
}
