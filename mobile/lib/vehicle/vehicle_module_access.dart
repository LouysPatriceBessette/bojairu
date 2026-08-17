import 'package:flutter/foundation.dart';

import '../entitlement/app_module_id.dart';
import '../entitlement/license_checkpoint.dart';
import '../entitlement/module_entitlement_controller.dart';
import '../entitlement/module_entitlement_state.dart';

/// Module identifiers per OpenSpec (`vehicle`, `vehicle-sharing`).
enum VehicleModuleId {
  vehicle('vehicle'),
  vehicleSharing('vehicle-sharing');

  const VehicleModuleId(this.wire);
  final String wire;
}

/// Local entitlement gate for vehicle modules.
///
/// Debug builds keep sharing offer/borrower actions usable without a store
/// purchase (Maestro / `run:dev`). Vehicle trial still runs from local clocks.
class VehicleModuleAccess {
  const VehicleModuleAccess();

  ModuleEntitlementState get _vehicleState {
    final c = ModuleEntitlementController.maybeInstance;
    return c?.stateOf(AppModuleId.vehicle) ?? ModuleEntitlementState.free;
  }

  ModuleEntitlementState get _sharingState {
    final c = ModuleEntitlementController.maybeInstance;
    return c?.stateOf(AppModuleId.vehicleSharing) ??
        ModuleEntitlementState.free;
  }

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

  /// Accueil tiles are always shown when the module is enabled.
  bool get vehicleModuleEnabled => true;

  bool get vehicleSharingModuleEnabled => true;

  bool get showVehicleHomeTile => vehicleModuleEnabled;

  bool get showVehicleSharingHomeTile => vehicleSharingModuleEnabled;

  /// Owner writes (fuel, sessions, new vehicles) except after trial / unpaid
  /// read-only. [free] (trial not started) remains writable.
  bool get vehicleWritesAllowed {
    return _vehicleState != ModuleEntitlementState.delinquentReadonly;
  }

  /// Invite / revoke / reactivate: both modules paid, not trial, not grace.
  bool get canOfferSharing {
    if (kDebugMode) return true;
    final c = ModuleEntitlementController.maybeInstance;
    if (c == null) return false;
    return c.isActivePaid(AppModuleId.vehicle) &&
        c.isActivePaid(AppModuleId.vehicleSharing);
  }

  /// Borrower actions: paid sharing license only (no trial, no grace).
  bool get canLogAsBorrower {
    if (kDebugMode) return true;
    return ModuleEntitlementController.maybeInstance?.isActivePaid(
          AppModuleId.vehicleSharing,
        ) ??
        false;
  }

  /// Owner must not apply borrower envelopes (hold locally instead).
  bool get ownerInboundIsHeld {
    if (_vehicleState == ModuleEntitlementState.delinquentReadonly) {
      return true;
    }
    return _sharingState != ModuleEntitlementState.activePaid;
  }

  bool get shouldHoldOwnerInbound {
    if (kDebugMode) return false;
    return ownerInboundIsHeld;
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

  /// Live Play check before offer / invite flows (needs both modules paid).
  Future<bool> refreshAndCanOfferSharing() async {
    if (kDebugMode) return true;
    final playOk = await refreshPlayForLicenseCheckpoint();
    if (!playOk) return false;
    return canOfferSharing;
  }

  Future<bool> refreshAndCanLogAsBorrower() async {
    if (kDebugMode) return true;
    final playOk = await refreshPlayForLicenseCheckpoint();
    if (!playOk) return false;
    return canLogAsBorrower;
  }
}
