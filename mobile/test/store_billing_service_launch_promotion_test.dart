import 'package:compartarenta/entitlement/module_entitlement_controller.dart';
import 'package:compartarenta/entitlement/store_billing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _FakeInAppPurchase implements InAppPurchase {
  PurchaseParam? lastPurchaseParam;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    lastPurchaseParam = purchaseParam;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductDetails _allModulesProduct() => ProductDetails(
  id: 'bojairu.bundle.all_modules',
  title: 'All modules',
  description: 'All modules',
  price: r'$0.00',
  rawPrice: 0,
  currencyCode: 'CAD',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Android launch promotion opens purchase for supplied subscription',
    () async {
      final iap = _FakeInAppPurchase();
      final service = StoreBillingService(
        entitlement: ModuleEntitlementController(),
        iap: iap,
      );

      final opened = await service.openLaunchPromotion(_allModulesProduct());

      expect(opened, isTrue);
      expect(
        iap.lastPurchaseParam?.productDetails.id,
        'bojairu.bundle.all_modules',
      );
    },
  );

  test(
    'Android launch promotion refuses to open without the subscription',
    () async {
      final iap = _FakeInAppPurchase();
      final service = StoreBillingService(
        entitlement: ModuleEntitlementController(),
        iap: iap,
      );

      final opened = await service.openLaunchPromotion(null);

      expect(opened, isFalse);
      expect(iap.lastPurchaseParam, isNull);
      expect(service.lastError, 'launch_promotion_product_unavailable');
    },
  );
}
