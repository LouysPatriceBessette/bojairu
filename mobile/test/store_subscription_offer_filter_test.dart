import 'package:compartarenta/entitlement/app_module_id.dart';
import 'package:compartarenta/entitlement/store_product_catalog.dart';
import 'package:compartarenta/entitlement/store_product_display_names.dart';
import 'package:compartarenta/entitlement/store_subscription_offer_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreProductDisplayNames', () {
    test('canonical FR labels cover every catalog productId', () {
      expect(
        StoreProductDisplayNames.canonicalFr.keys.toSet(),
        StoreProductCatalog.allProductIds,
      );
    });

    test('canonical FR labels match étape-0 wording', () {
      expect(StoreProductDisplayNames.canonicalFr['bojairu.housing'], 'Logement');
      expect(StoreProductDisplayNames.canonicalFr['bojairu.vehicle'], 'Véhicule');
      expect(
        StoreProductDisplayNames.canonicalFr['bojairu.vehicle_sharing'],
        'Partage',
      );
      expect(
        StoreProductDisplayNames.canonicalFr[
            'bojairu.bundle.housing_vehicle_sharing'],
        'Bundle Logement + Partage',
      );
      expect(
        StoreProductDisplayNames.canonicalFr[
            'bojairu.bundle.vehicle_vehicle_sharing'],
        'Bundle Véhicule + Partage',
      );
      expect(
        StoreProductDisplayNames.canonicalFr['bojairu.bundle.housing_vehicle'],
        'Bundle Logement + Véhicule',
      );
      expect(
        StoreProductDisplayNames.canonicalFr['bojairu.bundle.all_modules'],
        'Bundle les trois',
      );
    });
  });

  group('filterSubscriptionOffers', () {
    test('housing covered + vehicle in cart → vehicle and housing_vehicle', () {
      final offers = filterSubscriptionOffers(
        cart: <AppModuleId>{AppModuleId.housing, AppModuleId.vehicle},
        paidProductIds: <String>{'bojairu.housing'},
      );
      expect(
        offers.map((e) => e.productId).toSet(),
        <String>{
          'bojairu.vehicle',
          'bojairu.bundle.housing_vehicle',
        },
      );
    });

    test('vehicle only in cart → vehicle only', () {
      final offers = filterSubscriptionOffers(
        cart: <AppModuleId>{AppModuleId.vehicle},
        paidProductIds: <String>{'bojairu.housing'},
      );
      expect(
        offers.map((e) => e.productId).toList(),
        <String>['bojairu.vehicle'],
      );
    });

    test('empty cart → no offers', () {
      expect(
        filterSubscriptionOffers(
          cart: <AppModuleId>{},
          paidProductIds: <String>{},
        ),
        isEmpty,
      );
    });

    test('all three selected unpaid → all seven products', () {
      final offers = filterSubscriptionOffers(
        cart: AppModuleId.values.toSet(),
        paidProductIds: <String>{},
      );
      expect(offers, hasLength(7));
    });
  });

  group('shouldPromptSelectModuleToAdd', () {
    test('empty cart prompts', () {
      expect(
        shouldPromptSelectModuleToAdd(
          cart: <AppModuleId>{},
          coveredByPlay: <AppModuleId>{},
        ),
        isTrue,
      );
    });

    test('only covered modules in cart prompts', () {
      expect(
        shouldPromptSelectModuleToAdd(
          cart: <AppModuleId>{AppModuleId.housing},
          coveredByPlay: <AppModuleId>{AppModuleId.housing},
        ),
        isTrue,
      );
    });

    test('uncovered module in cart does not prompt', () {
      expect(
        shouldPromptSelectModuleToAdd(
          cart: <AppModuleId>{AppModuleId.housing, AppModuleId.vehicle},
          coveredByPlay: <AppModuleId>{AppModuleId.housing},
        ),
        isFalse,
      );
    });
  });
}
