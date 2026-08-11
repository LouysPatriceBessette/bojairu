import '../l10n/app_localizations.dart';
import 'store_product_catalog.dart';

/// App-facing labels for Play product ids (étape-0 mapping; ids stay stable).
abstract final class StoreProductDisplayNames {
  /// French labels from billing étape 0 (lines 21–27). Used as the source of
  /// truth for which strings exist; UI resolves via [forProductId] / ARB.
  static const Map<String, String> canonicalFr = <String, String>{
    'bojairu.housing': 'Logement',
    'bojairu.vehicle': 'Véhicule',
    'bojairu.vehicle_sharing': 'Partage',
    'bojairu.bundle.housing_vehicle_sharing': 'Bundle Logement + Partage',
    'bojairu.bundle.vehicle_vehicle_sharing': 'Bundle Véhicule + Partage',
    'bojairu.bundle.housing_vehicle': 'Bundle Logement + Véhicule',
    'bojairu.bundle.all_modules': 'Bundle les trois',
  };

  static String forProductId(String productId, AppLocalizations l10n) {
    switch (productId) {
      case 'bojairu.housing':
        return l10n.licensesProductHousing;
      case 'bojairu.vehicle':
        return l10n.licensesProductVehicle;
      case 'bojairu.vehicle_sharing':
        return l10n.licensesProductSharing;
      case 'bojairu.bundle.housing_vehicle_sharing':
        return l10n.licensesProductBundleHousingSharing;
      case 'bojairu.bundle.vehicle_vehicle_sharing':
        return l10n.licensesProductBundleVehicleSharing;
      case 'bojairu.bundle.housing_vehicle':
        return l10n.licensesProductBundleHousingVehicle;
      case 'bojairu.bundle.all_modules':
        return l10n.licensesProductBundleAllModules;
      default:
        return productId;
    }
  }

  static Iterable<String> get knownProductIds => StoreProductCatalog.allProductIds;
}
