import 'package:compartarenta/entitlement/receipt_play_reconcile.dart';
import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 9, 21);

  StoreReceiptRecord play(
    String productId, {
    String token = 't',
    bool autoRenewing = true,
  }) {
    return StoreReceiptRecord(
      productId: productId,
      platform: 'google_play',
      purchaseTokenOrReceipt: token,
      purchasedAt: now,
      autoRenewing: autoRenewing,
    );
  }

  test('keeps live tokens and drops replaced / ghost tokens', () {
    final local = [
      play('bojairu.housing', token: 'old', autoRenewing: false),
      play('bojairu.housing', token: 'new', autoRenewing: true),
      play('bojairu.bundle.all_modules', token: 'gone'),
    ];
    final next = reconcileGooglePlayReceipts(
      local: local,
      livePurchaseTokens: {'new'},
    );
    expect(next.map((r) => r.purchaseTokenOrReceipt), ['new']);
  });

  test('empty live set drops all Google Play rows', () {
    final next = reconcileGooglePlayReceipts(
      local: [play('bojairu.vehicle')],
      livePurchaseTokens: {},
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
      livePurchaseTokens: {},
    );
    expect(next, [apple]);
  });
}
