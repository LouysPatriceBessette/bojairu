import 'package:compartarenta/entitlement/app_module_id.dart';
import 'package:compartarenta/entitlement/module_entitlement_evaluator.dart';
import 'package:compartarenta/entitlement/module_entitlement_state.dart';
import 'package:compartarenta/entitlement/receipt_to_candidates.dart';
import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8, 12);

  test('bundle projects activePaid onto included modules', () {
    final map = ReceiptToCandidates.fromReceipts(
      [
        StoreReceiptRecord(
          productId: 'bojairu.bundle.housing_vehicle',
          platform: 'google_play',
          purchaseTokenOrReceipt: 'tok',
          purchasedAt: now.subtract(const Duration(days: 1)),
          expiresAt: now.add(const Duration(days: 20)),
        ),
      ],
      now: now,
    );
    expect(
      ModuleEntitlementEvaluator.evaluate(map[AppModuleId.housing]!),
      ModuleEntitlementState.activePaid,
    );
    expect(
      ModuleEntitlementEvaluator.evaluate(map[AppModuleId.vehicle]!),
      ModuleEntitlementState.activePaid,
    );
    expect(
      ModuleEntitlementEvaluator.evaluate(map[AppModuleId.vehicleSharing]!),
      ModuleEntitlementState.free,
    );
  });

  test('expired receipt enters grace then readonly', () {
    final expired = now.subtract(const Duration(days: 2));
    final inGrace = ReceiptToCandidates.fromReceipts(
      [
        StoreReceiptRecord(
          productId: 'bojairu.housing',
          platform: 'google_play',
          purchaseTokenOrReceipt: 'tok',
          purchasedAt: expired.subtract(const Duration(days: 30)),
          expiresAt: expired,
        ),
      ],
      now: now,
      graceDuration: const Duration(days: 7),
    );
    expect(
      ModuleEntitlementEvaluator.evaluate(inGrace[AppModuleId.housing]!),
      ModuleEntitlementState.delinquentGrace,
    );

    final afterGrace = ReceiptToCandidates.fromReceipts(
      [
        StoreReceiptRecord(
          productId: 'bojairu.housing',
          platform: 'google_play',
          purchaseTokenOrReceipt: 'tok',
          purchasedAt: expired.subtract(const Duration(days: 30)),
          expiresAt: expired,
        ),
      ],
      now: expired.add(const Duration(days: 8)),
      graceDuration: const Duration(days: 7),
    );
    expect(
      ModuleEntitlementEvaluator.evaluate(afterGrace[AppModuleId.housing]!),
      ModuleEntitlementState.delinquentReadonly,
    );
  });
}
