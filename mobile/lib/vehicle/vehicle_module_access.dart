import 'package:flutter/foundation.dart';

import '../entitlement/app_module_id.dart';
import '../entitlement/license_checkpoint.dart';
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
/// Release builds use [ModuleEntitlementController] after a Play refresh at
/// each license checkpoint (hub entry / gated action).
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

  /// Live Play check before vehicle hub / gated vehicle UI.
  Future<bool> refreshAndHasVehicleEntitlement() async {
    if (kDebugMode) return true;
    final playOk = await refreshPlayForLicenseCheckpoint();
    if (!playOk) return false;
    return hasVehicleEntitlement;
  }

  /// Live Play check before vehicle-sharing hub / gated sharing UI.
  Future<bool> refreshAndHasVehicleSharingEntitlement() async {
    if (kDebugMode) return true;
    final playOk = await refreshPlayForLicenseCheckpoint();
    if (!playOk) return false;
    return hasVehicleSharingEntitlement;
  }

  /// Live Play check before offer / invite flows (needs both modules).
  Future<bool> refreshAndCanOfferSharing() async {
    if (kDebugMode) return true;
    final playOk = await refreshPlayForLicenseCheckpoint();
    if (!playOk) return false;
    return canOfferSharing;
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
