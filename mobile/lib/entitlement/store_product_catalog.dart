import 'app_module_id.dart';

/// One sellable Play / App Store subscription row (module or bundle).
class StoreCatalogEntry {
  const StoreCatalogEntry.module({
    required this.productId,
    required AppModuleId module,
  }) : bundleId = null,
       includedModules = null,
       _module = module;

  const StoreCatalogEntry.bundle({
    required this.productId,
    required this.bundleId,
    required this.includedModules,
  }) : _module = null;

  final String productId;
  final AppModuleId? _module;
  final AppBundleId? bundleId;
  final List<AppModuleId>? includedModules;

  bool get isBundle => bundleId != null;

  AppModuleId? get module => _module;

  /// Modules granted when this product's receipt is valid.
  List<AppModuleId> get grantsModules {
    if (_module != null) return <AppModuleId>[_module];
    return List<AppModuleId>.unmodifiable(includedModules!);
  }
}

/// Canonical catalog aligned with [docs/store-mapping.md] (Play product ids).
abstract final class StoreProductCatalog {
  static const String basePlanMonthly = 'monthly';
  static const String allModulesProductId = 'bojairu.bundle.all_modules';

  static const List<StoreCatalogEntry> entries = <StoreCatalogEntry>[
    StoreCatalogEntry.module(
      productId: 'bojairu.housing',
      module: AppModuleId.housing,
    ),
    StoreCatalogEntry.module(
      productId: 'bojairu.vehicle',
      module: AppModuleId.vehicle,
    ),
    StoreCatalogEntry.module(
      productId: 'bojairu.vehicle_sharing',
      module: AppModuleId.vehicleSharing,
    ),
    StoreCatalogEntry.bundle(
      productId: 'bojairu.bundle.housing_vehicle_sharing',
      bundleId: AppBundleId.housingVehicleSharing,
      includedModules: <AppModuleId>[
        AppModuleId.housing,
        AppModuleId.vehicleSharing,
      ],
    ),
    StoreCatalogEntry.bundle(
      productId: 'bojairu.bundle.vehicle_vehicle_sharing',
      bundleId: AppBundleId.vehicleVehicleSharing,
      includedModules: <AppModuleId>[
        AppModuleId.vehicle,
        AppModuleId.vehicleSharing,
      ],
    ),
    StoreCatalogEntry.bundle(
      productId: 'bojairu.bundle.housing_vehicle',
      bundleId: AppBundleId.housingVehicle,
      includedModules: <AppModuleId>[AppModuleId.housing, AppModuleId.vehicle],
    ),
    StoreCatalogEntry.bundle(
      productId: allModulesProductId,
      bundleId: AppBundleId.allModules,
      includedModules: <AppModuleId>[
        AppModuleId.housing,
        AppModuleId.vehicle,
        AppModuleId.vehicleSharing,
      ],
    ),
  ];

  static final Map<String, StoreCatalogEntry> byProductId =
      <String, StoreCatalogEntry>{for (final e in entries) e.productId: e};

  static Set<String> get allProductIds => byProductId.keys.toSet();

  static StoreCatalogEntry? entryForProductId(String productId) =>
      byProductId[productId];
}
