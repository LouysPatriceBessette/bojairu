import 'package:compartarenta/entitlement/app_module_id.dart';
import 'package:compartarenta/entitlement/housing_license_reminder_schedule.dart';
import 'package:compartarenta/entitlement/local_store_receipt_store.dart';
import 'package:compartarenta/entitlement/module_entitlement_controller.dart';
import 'package:compartarenta/entitlement/module_entitlement_state.dart';
import 'package:compartarenta/entitlement/vehicle_license_lifecycle_sync.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/vehicle/vehicle_module_access.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final started = DateTime.utc(2026, 8, 1, 12);

  late List<int> slotCounts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ModuleEntitlementController.uninstall();
    slotCounts = [];
    VehicleLicenseLifecycleSync.reminderSinkForTesting =
        ({
          required List<HousingLicenseReminderSlot> slots,
          required DateTime now,
          required bool showDueImmediately,
          required bool paid,
        }) async {
          slotCounts.add(slots.length);
        };
  });

  tearDown(() {
    VehicleLicenseLifecycleSync.reminderSinkForTesting = null;
    ModuleEntitlementController.uninstall();
  });

  Future<ModuleEntitlementController> installController({
    DateTime Function()? clock,
  }) async {
    final controller = ModuleEntitlementController(
      receiptStore: LocalStoreReceiptStore(),
      clock: clock,
    );
    ModuleEntitlementController.install(controller);
    await controller.load();
    return controller;
  }

  test('owner fact starts 14-day vehicle trial', () async {
    await installController();
    await VehicleLicenseLifecycleSync.maybeStartTrialFromOwnerFact(
      actingContactId: kVehicleOwnerSelfContactId,
    );
    final c = ModuleEntitlementController.maybeInstance!;
    expect(c.stateOf(AppModuleId.vehicle), ModuleEntitlementState.activeTrial);
    expect(c.hasUsableAccess(AppModuleId.vehicle), isTrue);
    expect(slotCounts, isNotEmpty);
  });

  test('borrower fact does not start vehicle trial', () async {
    await installController(clock: () => started);
    await VehicleLicenseLifecycleSync.maybeStartTrialFromOwnerFact(
      actingContactId: 'contact:someone',
    );
    expect(
      ModuleEntitlementController.maybeInstance!.stateOf(AppModuleId.vehicle),
      ModuleEntitlementState.free,
    );
  });

  test('vehicle trial ends in read-only without grace', () async {
    SharedPreferences.setMockInitialValues({
      'licensing.vehicle.trialStartedAt': started.toIso8601String(),
    });
    await installController(
      clock: () => started.add(const Duration(days: 15)),
    );
    final prefs = await AppPreferences.load();
    await VehicleLicenseLifecycleSync.apply(prefs: prefs, now: started.add(const Duration(days: 15)));
    final c = ModuleEntitlementController.maybeInstance!;
    expect(
      c.stateOf(AppModuleId.vehicle),
      ModuleEntitlementState.delinquentReadonly,
    );
    expect(c.hasUsableAccess(AppModuleId.vehicle), isFalse);
    expect(const VehicleModuleAccess().vehicleWritesAllowed, isFalse);
    expect(const VehicleModuleAccess().ownerInboundIsHeld, isTrue);
  });
}
