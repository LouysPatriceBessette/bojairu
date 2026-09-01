import 'store_product_catalog.dart';

const String kStoreLaunchPromotionProductId =
    StoreProductCatalog.allModulesProductId;

Uri storeLaunchPromotionDetailsUri(String languageCode) =>
    Uri.https('bojairu.app', '/${languageCode.toLowerCase()}/promotions');
