import 'package:compartarenta/entitlement/app_module_id.dart';
import 'package:compartarenta/entitlement/local_store_receipt_store.dart';
import 'package:compartarenta/entitlement/module_entitlement_controller.dart';
import 'package:compartarenta/entitlement/module_entitlement_state.dart';
import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModuleEntitlementController', () {
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

  test('upsertReceipt applies server expiry from play token uploader', () async {
    final now = DateTime.utc(2026, 8, 15, 12);
    final serverExpiry = DateTime.utc(2026, 9, 15, 10);
    var uploadedProductId = '';
    var uploadedToken = '';
    final controller = ModuleEntitlementController(
      receiptStore: LocalStoreReceiptStore(),
      clock: () => now,
      playTokenUploader: (record) async {
        uploadedProductId = record.productId;
        uploadedToken = record.purchaseTokenOrReceipt;
        return serverExpiry;
      },
    );

    await controller.upsertReceipt(
      StoreReceiptRecord(
        productId: 'bojairu.housing',
        platform: 'google_play',
        purchaseTokenOrReceipt: 'play-tok',
        purchasedAt: now,
      ),
    );

    expect(uploadedProductId, 'bojairu.housing');
    expect(uploadedToken, 'play-tok');
    expect(controller.receipts.single.expiresAt, serverExpiry);
    expect(
      controller.stateOf(AppModuleId.housing),
      ModuleEntitlementState.activePaid,
    );
  });

  test('upsertReceipt skips upload for non-Play receipts', () async {
    var called = false;
    final controller = ModuleEntitlementController(
      receiptStore: LocalStoreReceiptStore(),
      playTokenUploader: (_) async {
        called = true;
        return null;
      },
    );

    await controller.upsertReceipt(
      StoreReceiptRecord(
        productId: 'bojairu.housing',
        platform: 'app_store',
        purchaseTokenOrReceipt: 'ios-tok',
        purchasedAt: DateTime.utc(2026, 8, 15),
      ),
    );

    expect(called, isFalse);
  });

  test('server all-modules grant opens and revoke closes all modules', () async {
    final now = DateTime.utc(2026, 9, 1);
    final controller = ModuleEntitlementController(
      receiptStore: LocalStoreReceiptStore(),
      clock: () => now,
    );

    await controller.reconcileServerGrant(
      StoreReceiptRecord(
        productId: 'bojairu.bundle.all_modules',
        platform: 'server_grant',
        purchaseTokenOrReceipt: 'server-grant:installation-1',
        purchasedAt: now,
        expiresAt: now.add(const Duration(days: 365)),
        autoRenewing: false,
      ),
    );

    for (final module in AppModuleId.values) {
      expect(controller.stateOf(module), ModuleEntitlementState.activePaid);
    }

    await controller.reconcileServerGrant(null);

    for (final module in AppModuleId.values) {
      expect(controller.stateOf(module), ModuleEntitlementState.free);
    }
  });
  });
}
