import 'package:flutter/foundation.dart';

import 'store_billing_service.dart';

/// Refreshes Play-owned receipts before a license access decision.
///
/// Returns `true` when the store query succeeded (or when skipped in debug
/// builds that do not require store purchases). Returns `false` when Play
/// could not be queried — callers that gate paid features should fail closed.
Future<bool> refreshPlayForLicenseCheckpoint() async {
  if (kDebugMode) return true;
  final billing = StoreBillingService.maybeInstance;
  if (billing == null) return false;
  return billing.refreshForLicenseCheckpoint();
}
