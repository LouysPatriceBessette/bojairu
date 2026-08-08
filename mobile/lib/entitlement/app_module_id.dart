/// Canonical module identifiers (OpenSpec `per-module-licensing-and-bundles`).
enum AppModuleId {
  housing('housing'),
  vehicle('vehicle'),
  vehicleSharing('vehicle-sharing');

  const AppModuleId(this.wire);

  /// Kebab-case id used in specs, store-mapping, and evaluation.
  final String wire;

  static AppModuleId? tryParse(String raw) {
    for (final m in AppModuleId.values) {
      if (m.wire == raw) return m;
    }
    return null;
  }
}

/// Bundle policy ids from [docs/store-mapping.md].
enum AppBundleId {
  housingVehicleSharing('housing_vehicle_sharing'),
  vehicleVehicleSharing('vehicle_vehicle_sharing'),
  housingVehicle('housing_vehicle'),
  allModules('all_modules');

  const AppBundleId(this.wire);
  final String wire;

  static AppBundleId? tryParse(String raw) {
    for (final b in AppBundleId.values) {
      if (b.wire == raw) return b;
    }
    return null;
  }
}
