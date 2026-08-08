import 'package:compartarenta/entitlement/store_product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog lists seven Play product ids from store-mapping', () {
    expect(StoreProductCatalog.entries, hasLength(7));
    expect(
      StoreProductCatalog.allProductIds,
      containsAll(<String>[
        'bojairu.housing',
        'bojairu.vehicle',
        'bojairu.vehicle_sharing',
        'bojairu.bundle.housing_vehicle_sharing',
        'bojairu.bundle.vehicle_vehicle_sharing',
        'bojairu.bundle.housing_vehicle',
        'bojairu.bundle.all_modules',
      ]),
    );
  });
}
