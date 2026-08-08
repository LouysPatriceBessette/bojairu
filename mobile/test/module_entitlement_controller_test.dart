import 'package:compartarenta/entitlement/app_module_id.dart';
import 'package:compartarenta/entitlement/local_store_receipt_store.dart';
import 'package:compartarenta/entitlement/module_entitlement_controller.dart';
import 'package:compartarenta/entitlement/module_entitlement_state.dart';
import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ModuleEntitlementController.uninstall();
  });

  test('delinquency on housing does not change vehicle', () async {
    final now = DateTime.utc(2026, 8, 8);
    final controller = ModuleEntitlementController(
      receiptStore: LocalStoreReceiptStore(),
      clock: () => now,
    );
    await controller.replaceReceipts([
      StoreReceiptRecord(
        productId: 'bojairu.housing',
        platform: 'google_play',
        purchaseTokenOrReceipt: 'h',
        purchasedAt: now.subtract(const Duration(days: 40)),
        expiresAt: now.subtract(const Duration(days: 10)),
      ),
      StoreReceiptRecord(
        productId: 'bojairu.vehicle',
        platform: 'google_play',
        purchaseTokenOrReceipt: 'v',
        purchasedAt: now.subtract(const Duration(days: 1)),
        expiresAt: now.add(const Duration(days: 20)),
      ),
    ]);

    expect(
      controller.stateOf(AppModuleId.housing),
      ModuleEntitlementState.delinquentReadonly,
    );
    expect(
      controller.stateOf(AppModuleId.vehicle),
      ModuleEntitlementState.activePaid,
    );
  });
}
