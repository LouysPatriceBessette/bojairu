import 'package:compartarenta/entitlement/receipt_play_reconcile.dart';
import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 9, 21);

  StoreReceiptRecord play(String productId, {String token = 't'}) {
    return StoreReceiptRecord(
      productId: productId,
      platform: 'google_play',
      purchaseTokenOrReceipt: token,
      purchasedAt: now,
      autoRenewing: true,
    );
  }

  test('keeps live Play products and drops ghosts', () {
    final local = [
      play('bojairu.bundle.all_modules'),
      play('bojairu.housing'),
    ];
    final next = reconcileGooglePlayReceipts(
      local: local,
      liveProductIds: {'bojairu.housing'},
    );
    expect(next.map((r) => r.productId), ['bojairu.housing']);
  });

  test('empty live set drops all Google Play rows', () {
    final next = reconcileGooglePlayReceipts(
      local: [play('bojairu.vehicle')],
      liveProductIds: {},
    );
    expect(next, isEmpty);
  });

  test('keeps non-Play rows even when not in live set', () {
    final apple = StoreReceiptRecord(
      productId: 'bojairu.housing',
      platform: 'app_store',
      purchaseTokenOrReceipt: 'ios',
      purchasedAt: now,
    );
    final next = reconcileGooglePlayReceipts(
      local: [apple, play('bojairu.vehicle')],
      liveProductIds: {},
    );
    expect(next, [apple]);
  });
}
