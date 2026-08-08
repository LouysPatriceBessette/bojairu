import 'package:flutter/foundation.dart';

import '../entitlement/app_module_id.dart';
import '../entitlement/module_entitlement_controller.dart';

/// Whether the user may import a device backup (active paid housing subscription).
abstract class StoreImportGate {
  Future<bool> hasActiveHousingSubscription();
}

/// Debug / pre-billing: import enabled when [kDebugMode] unless overridden.
class DevFakeStoreImportGate implements StoreImportGate {
  DevFakeStoreImportGate({this.forceEnabled = true});

  final bool forceEnabled;

  static const enabledDefine = bool.fromEnvironment(
    'DEVICE_IMPORT_GATE_FAKE',
    defaultValue: true,
  );

  @override
  Future<bool> hasActiveHousingSubscription() async {
    if (!kDebugMode) return false;
    return enabledDefine && forceEnabled;
  }
}

/// Release: housing must be [active-paid] from local store receipts / evaluation.
class ModuleEntitlementImportGate implements StoreImportGate {
  @override
  Future<bool> hasActiveHousingSubscription() async {
    final c = ModuleEntitlementController.maybeInstance;
    if (c == null) return false;
    return c.isActivePaid(AppModuleId.housing);
  }
}

/// Alias kept for existing call sites / tests.
class ReleaseStoreImportGate extends ModuleEntitlementImportGate {}

StoreImportGate defaultStoreImportGate() {
  if (kDebugMode) return DevFakeStoreImportGate();
  return ModuleEntitlementImportGate();
}
