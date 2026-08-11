import 'package:compartarenta/entitlement/store_subscription_price_label.dart';
import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

ProductDetails _product({required String price}) {
  return ProductDetails(
    id: 'test.sku',
    title: 'Test',
    description: 'Test',
    price: price,
    rawPrice: 0,
    currencyCode: 'CAD',
  );
}

void main() {
  group('storeBillingPeriodUnitFromIso8601', () {
    test('parses Play monthly / yearly / weekly / daily', () {
      expect(
        storeBillingPeriodUnitFromIso8601('P1M'),
        StoreBillingPeriodUnit.month,
      );
      expect(
        storeBillingPeriodUnitFromIso8601('p1y'),
        StoreBillingPeriodUnit.year,
      );
      expect(
        storeBillingPeriodUnitFromIso8601('P1W'),
        StoreBillingPeriodUnit.week,
      );
      expect(
        storeBillingPeriodUnitFromIso8601('P7D'),
        StoreBillingPeriodUnit.week,
      );
      expect(
        storeBillingPeriodUnitFromIso8601('P1D'),
        StoreBillingPeriodUnit.day,
      );
    });

    test('rejects empty and unsupported multiples', () {
      expect(storeBillingPeriodUnitFromIso8601(null), isNull);
      expect(storeBillingPeriodUnitFromIso8601(''), isNull);
      expect(storeBillingPeriodUnitFromIso8601('P3M'), isNull);
      expect(storeBillingPeriodUnitFromIso8601('PT1H'), isNull);
    });
  });

  group('isStoreFreePriceLabel', () {
    test('matches Free / FREE case-insensitively', () {
      expect(isStoreFreePriceLabel('Free'), isTrue);
      expect(isStoreFreePriceLabel('FREE'), isTrue);
      expect(isStoreFreePriceLabel(' free '), isTrue);
      expect(isStoreFreePriceLabel('3,99 \$'), isFalse);
      expect(isStoreFreePriceLabel('0,00 \$'), isFalse);
    });
  });

  group('formatSubscriptionPriceWithPeriod', () {
    test('localizes FREE with no period suffix', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));

      expect(
        formatSubscriptionPriceWithPeriod(
          product: _product(price: 'FREE'),
          l10n: fr,
        ),
        'Gratuit',
      );
      expect(
        formatSubscriptionPriceWithPeriod(
          product: _product(price: 'Free'),
          l10n: en,
        ),
        'Free',
      );
      expect(
        formatSubscriptionPriceWithPeriod(
          product: _product(price: 'free'),
          l10n: es,
        ),
        'Gratis',
      );
    });

    test('paid price without Play period falls back to monthly suffix', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      expect(
        formatSubscriptionPriceWithPeriod(
          product: _product(price: '3,99 \$'),
          l10n: fr,
        ),
        '3,99 \$/mois',
      );
    });
  });
}
