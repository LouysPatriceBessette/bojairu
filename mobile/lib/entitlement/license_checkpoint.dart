import 'package:flutter/foundation.dart';

import 'app_module_id.dart';
import 'entitlement_coordinator.dart';
import 'module_entitlement_controller.dart';
import 'server_grant_receipt.dart';
import 'store_billing_service.dart';

/// Refreshes Play-owned receipts before a license access decision.
///
/// Returns `true` when the store query succeeded (or when skipped in debug
/// builds that do not require store purchases). Returns `false` when Play
/// could not be queried — callers that gate paid features should fail closed.
Future<bool> refreshPlayForLicenseCheckpoint() async {
  if (kDebugMode) return true;
  final entitlement = ModuleEntitlementController.maybeInstance;
  final coordinator = EntitlementCoordinator.maybeInstance;
  final serverSyncOk = await coordinator?.syncServerLicenses() ?? false;
  final hasServerGrant =
      entitlement != null &&
      hasActiveServerGrant(
        entitlement.receipts,
        module: AppModuleId.housing,
        now: DateTime.now().toUtc(),
      );
  if (hasServerGrant) return serverSyncOk;
  final billing = StoreBillingService.maybeInstance;
  if (billing == null) return false;
  return billing.refreshForLicenseCheckpoint();
}
