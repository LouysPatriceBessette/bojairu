import 'package:compartarenta/entitlement/entitlement_client.dart';
import 'package:compartarenta/entitlement/server_grant_receipt.dart';
import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 1, 12);

  test('valid all-module server grant becomes a local receipt', () {
    final receipt = storeReceiptFromServerGrant(
      ServerLicenseReceipt(
        productId: kAllModulesProductId,
        platform: kServerGrantPlatform,
        purchaseToken: 'server-grant:installation-1',
        validationState: 'valid',
        grantedModules: const ['housing', 'vehicle', 'vehicle-sharing'],
        autoRenewing: false,
        purchasedAt: now,
        expiresAt: now.add(const Duration(days: 365)),
      ),
      now: now,
    );

    expect(receipt, isNotNull);
    expect(receipt!.productId, kAllModulesProductId);
    expect(receipt.platform, kServerGrantPlatform);
    expect(receipt.autoRenewing, isFalse);
  });

  test('reconcile removes only server grant on revoke', () {
    final play = StoreReceiptRecord(
      productId: 'bojairu.housing',
      platform: 'google_play',
      purchaseTokenOrReceipt: 'play-token',
      purchasedAt: now,
    );
    final server = StoreReceiptRecord(
      productId: kAllModulesProductId,
      platform: kServerGrantPlatform,
      purchaseTokenOrReceipt: 'server-grant:installation-1',
      purchasedAt: now,
      expiresAt: now.add(const Duration(days: 365)),
    );

    final reconciled = reconcileServerGrantReceipts(local: [play, server]);

    expect(reconciled, [play]);
  });

  test('grant push must target this installation', () {
    final receipt = storeReceiptFromLicensePush(
      {
        'kind': kLicenseReceiptChangedKind,
        'action': 'grant',
        'installation_id': 'another-installation',
        'product_id': kAllModulesProductId,
        'platform': kServerGrantPlatform,
        'purchase_token': 'server-grant:another-installation',
        'purchased_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(days: 365)).toIso8601String(),
      },
      installationId: 'this-installation',
      now: now,
    );

    expect(receipt, isNull);
  });
}
