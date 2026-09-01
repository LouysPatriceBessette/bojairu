import 'package:compartarenta/entitlement/store_launch_promotion.dart';
import 'package:compartarenta/entitlement/store_product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('launch promotion targets the all-modules subscription', () {
    expect(
      kStoreLaunchPromotionProductId,
      StoreProductCatalog.allModulesProductId,
    );
    expect(
      StoreProductCatalog.allProductIds,
      contains(kStoreLaunchPromotionProductId),
    );
  });

  test('promotion details URL follows the user language', () {
    expect(
      storeLaunchPromotionDetailsUri('FR').toString(),
      'https://bojairu.app/fr/promotions',
    );
  });
}
