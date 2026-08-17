import 'package:compartarenta/entitlement/app_module_id.dart';
import 'package:compartarenta/entitlement/housing_license_lifecycle_sync.dart';
import 'package:compartarenta/entitlement/housing_license_reminder_schedule.dart';
import 'package:compartarenta/entitlement/housing_plan_license_access.dart';
import 'package:compartarenta/entitlement/housing_trial_consumption_store.dart';
import 'package:compartarenta/entitlement/local_store_receipt_store.dart';
import 'package:compartarenta/entitlement/module_entitlement_controller.dart';
import 'package:compartarenta/entitlement/module_entitlement_state.dart';
import 'package:compartarenta/entitlement/store_receipt_record.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const planId = 'housing:license-clock';
  final started = DateTime.utc(2026, 8, 1, 12);

  late List<({String planId, bool paid, bool showDue, int slotCount})> sinkLog;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'licensing.housing.planActiveUseStarted.$planId':
          started.toIso8601String(),
    });
    ModuleEntitlementController.uninstall();
    sinkLog = [];
    HousingLicenseLifecycleSync.reminderSinkForTesting =
        ({
          required String planId,
          required List<HousingLicenseReminderSlot> slots,
          required DateTime now,
          required bool showDueImmediately,
          required bool paid,
        }) async {
          sinkLog.add((
            planId: planId,
            paid: paid,
            showDue: showDueImmediately,
            slotCount: slots.length,
          ));
        };
  });

  tearDown(() {
    HousingLicenseLifecycleSync.reminderSinkForTesting = null;
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

  test('trial → readonly keeps no usable access after day 14', () async {
    final trialStore = await HousingTrialConsumptionStore.load();
    await trialStore.setPlanTrialEligible(planId, true);
    final prefs = await AppPreferences.load();

    Future<void> applyAt(DateTime now) async {
      await installController(clock: () => now);
      await HousingLicenseLifecycleSync.apply(prefs: prefs, now: now);
    }

    await applyAt(started.add(const Duration(days: 1)));
    var c = ModuleEntitlementController.maybeInstance!;
    expect(c.stateOf(AppModuleId.housing), ModuleEntitlementState.activeTrial);
    expect(c.hasUsableAccess(AppModuleId.housing), isTrue);

    await applyAt(started.add(const Duration(days: 15)));
    c = ModuleEntitlementController.maybeInstance!;
    expect(
      c.stateOf(AppModuleId.housing),
      ModuleEntitlementState.delinquentReadonly,
    );
    expect(c.hasUsableAccess(AppModuleId.housing), isFalse);

    final view = housingPlanLicenseView(
      prefs: prefs,
      trialStore: trialStore,
      planId: planId,
      now: started.add(const Duration(days: 15)),
      entitlement: c,
    );
    expect(view.allowsNewRealizedExpense, isFalse);
    expect(view.showReadonlyBanner, isTrue);
  });

  test('consumed trial skips 14-day trial and is read-only', () async {
    final trialStore = await HousingTrialConsumptionStore.load();
    await trialStore.setPlanTrialEligible(planId, false);
    final prefs = await AppPreferences.load();
    await installController(clock: () => started);
    await HousingLicenseLifecycleSync.apply(prefs: prefs, now: started);

    expect(
      ModuleEntitlementController.maybeInstance!.stateOf(AppModuleId.housing),
      ModuleEntitlementState.delinquentReadonly,
    );
    expect(sinkLog.single.slotCount, 0);
  });

  test('paid Play housing cancels reminders and allows new expenses', () async {
    final trialStore = await HousingTrialConsumptionStore.load();
    await trialStore.setPlanTrialEligible(planId, true);
    final prefs = await AppPreferences.load();
    final now = started.add(const Duration(days: 22));
    final controller = await installController(clock: () => now);
    await controller.upsertReceipt(
      StoreReceiptRecord(
        productId: 'bojairu.housing',
        platform: 'google_play',
        purchaseTokenOrReceipt: 'tok',
        purchasedAt: now,
        expiresAt: now.add(const Duration(days: 30)),
      ),
    );
    await HousingLicenseLifecycleSync.apply(prefs: prefs, now: now);

    expect(controller.stateOf(AppModuleId.housing), ModuleEntitlementState.activePaid);
    expect(controller.hasUsableAccess(AppModuleId.housing), isTrue);
    expect(sinkLog.last.paid, isTrue);
    final view = housingPlanLicenseView(
      prefs: prefs,
      trialStore: trialStore,
      planId: planId,
      now: now,
      entitlement: controller,
    );
    expect(view.allowsNewRealizedExpense, isTrue);
    expect(view.showReadonlyBanner, isFalse);
  });
}
