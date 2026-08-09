import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:compartarenta/entitlement/subscription_product_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 9, 16);
  final expires = now.add(const Duration(days: 20));

  StoreReceiptRecord receipt({
    required bool autoRenewing,
    DateTime? expiresAt,
    DateTime? purchasedAt,
    String productId = 'bojairu.bundle.all_modules',
    String token = 'tok',
  }) {
    return StoreReceiptRecord(
      productId: productId,
      platform: 'google_play',
      purchaseTokenOrReceipt: token,
      purchasedAt: purchasedAt ?? now.subtract(const Duration(days: 1)),
      expiresAt: expiresAt ?? expires,
      autoRenewing: autoRenewing,
    );
  }

  group('subscriptionProductLineKind', () {
    test('none when no valid receipt', () {
      expect(
        subscriptionProductLineKind(
          productId: 'bojairu.housing',
          receipts: const [],
          now: now,
        ),
        SubscriptionProductLineKind.none,
      );
      expect(
        subscriptionProductLineKind(
          productId: 'bojairu.housing',
          receipts: [
            receipt(
              autoRenewing: true,
              productId: 'bojairu.housing',
              expiresAt: now.subtract(const Duration(hours: 1)),
            ),
          ],
          now: now,
        ),
        SubscriptionProductLineKind.none,
      );
    });

    test('autoRenewing when valid and renewing', () {
      expect(
        subscriptionProductLineKind(
          productId: 'bojairu.housing',
          receipts: [
            receipt(autoRenewing: true, productId: 'bojairu.housing'),
          ],
          now: now,
        ),
        SubscriptionProductLineKind.autoRenewing,
      );
    });

    test('canceledStillValid when valid and not renewing', () {
      expect(
        subscriptionProductLineKind(
          productId: 'bojairu.housing',
          receipts: [
            receipt(autoRenewing: false, productId: 'bojairu.housing'),
          ],
          now: now,
        ),
        SubscriptionProductLineKind.canceledStillValid,
      );
    });

    test('prefers autoRenewing over older canceled token for same SKU', () {
      expect(
        subscriptionProductLineKind(
          productId: 'bojairu.housing',
          receipts: [
            receipt(
              autoRenewing: false,
              productId: 'bojairu.housing',
              token: 'old',
              purchasedAt: now.subtract(const Duration(hours: 2)),
              expiresAt: now.add(const Duration(minutes: 3)),
            ),
            receipt(
              autoRenewing: true,
              productId: 'bojairu.housing',
              token: 'new',
              purchasedAt: now.subtract(const Duration(minutes: 1)),
              expiresAt: null,
            ),
          ],
          now: now,
        ),
        SubscriptionProductLineKind.autoRenewing,
      );
    });
  });

  group('didCancelAutoRenew', () {
    test('true on true→false while still valid', () {
      expect(
        didCancelAutoRenew(
          before: receipt(autoRenewing: true),
          after: receipt(autoRenewing: false),
          now: now,
        ),
        isTrue,
      );
    });

    test('false when still renewing', () {
      expect(
        didCancelAutoRenew(
          before: receipt(autoRenewing: true),
          after: receipt(autoRenewing: true),
          now: now,
        ),
        isFalse,
      );
    });

    test('false when already canceled before', () {
      expect(
        didCancelAutoRenew(
          before: receipt(autoRenewing: false),
          after: receipt(autoRenewing: false),
          now: now,
        ),
        isFalse,
      );
    });

    test('false when after expired', () {
      expect(
        didCancelAutoRenew(
          before: receipt(autoRenewing: true),
          after: receipt(
            autoRenewing: false,
            expiresAt: now.subtract(const Duration(minutes: 1)),
          ),
          now: now,
        ),
        isFalse,
      );
    });
  });

  test('playSubscriptionManagementUri includes sku and package', () {
    final uri = playSubscriptionManagementUri(
      productId: 'bojairu.housing',
      packageName: 'app.incoherences.bojairu',
    );
    expect(uri.host, 'play.google.com');
    expect(uri.path, '/store/account/subscriptions');
    expect(uri.queryParameters['sku'], 'bojairu.housing');
    expect(uri.queryParameters['package'], 'app.incoherences.bojairu');
  });
}
