import 'package:flutter/foundation.dart';

import '../entitlement/app_module_id.dart';
import '../entitlement/module_entitlement_controller.dart';

/// Module identifiers per OpenSpec (`vehicle`, `vehicle-sharing`).
enum VehicleModuleId {
  vehicle('vehicle'),
  vehicleSharing('vehicle-sharing');

  const VehicleModuleId(this.wire);
  final String wire;
}

/// Local entitlement gate for vehicle modules.
///
/// Debug builds keep modules usable without a store purchase (local QA).
/// Release builds use [ModuleEntitlementController] effective state.
class VehicleModuleAccess {
  const VehicleModuleAccess();

  bool get hasVehicleEntitlement {
    if (kDebugMode) return true;
    final c = ModuleEntitlementController.maybeInstance;
    return c?.hasUsableAccess(AppModuleId.vehicle) ?? false;
  }

  bool get hasVehicleSharingEntitlement {
    if (kDebugMode) return true;
    final c = ModuleEntitlementController.maybeInstance;
    return c?.hasUsableAccess(AppModuleId.vehicleSharing) ?? false;
  }

  bool get vehicleModuleEnabled => true;

  bool get vehicleSharingModuleEnabled => true;

  bool get showVehicleHomeTile =>
      hasVehicleEntitlement && vehicleModuleEnabled;

  bool get showVehicleSharingHomeTile =>
      hasVehicleSharingEntitlement && vehicleSharingModuleEnabled;

  bool get canOfferSharing =>
      hasVehicleEntitlement && hasVehicleSharingEntitlement;

  bool get canLogAsBorrower => hasVehicleSharingEntitlement;
}
