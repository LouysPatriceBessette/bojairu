import '../notifications/vehicle_license_reminder_service.dart';
import '../notifications/vehicle_sharing_license_notification.dart';
import '../prefs/app_preferences.dart';
import '../relay/handshake_orchestrator.dart';
import '../vehicle/vehicle_module_access.dart';
import '../vehicle/vehicle_owner_contact.dart';
import 'app_module_id.dart';
import 'housing_license_reminder_schedule.dart';
import 'housing_lifecycle_source.dart';
import 'module_entitlement_controller.dart';
import 'module_entitlement_state.dart';
import 'receipt_to_candidates.dart';
import 'store_product_catalog.dart';
import 'store_receipt_record.dart';

const String kVehicleLicenseReminderPlanId = 'vehicle:module';

/// Applies local vehicle trial clocks, reminders, and sharing hold replay.
abstract final class VehicleLicenseLifecycleSync {
  static Future<void> Function({
    required List<HousingLicenseReminderSlot> slots,
    required DateTime now,
    required bool showDueImmediately,
    required bool paid,
  })?
  reminderSinkForTesting;

  static Future<void> apply({
    AppPreferences? prefs,
    DateTime? now,
    bool showDueImmediately = false,
  }) async {
    final p = prefs ?? await AppPreferences.load();
    final utc = (now ?? DateTime.now()).toUtc();
    final entitlement = ModuleEntitlementController.maybeInstance;
    final paid = entitlement?.isActivePaid(AppModuleId.vehicle) ?? false;
    final started = p.vehicleTrialStartedAt()?.toUtc();
    final snap = started == null
        ? null
        : HousingLifecycleSource.forActiveUse(
            startedAt: started,
            trialEligible: true,
          );
    entitlement?.setVehicleLifecycle(snap);

    if (started != null) {
      final slots = <HousingLicenseReminderSlot>[
        ...housingLicenseReminderSlots(
          activeUseStartedAt: started,
          trialEligible: true,
        ),
        if (!paid)
          ..._receiptGraceSlots(
            receipts: entitlement?.receipts ?? const [],
            now: utc,
          ),
      ];
      final sink = reminderSinkForTesting;
      if (sink != null) {
        await sink(
          slots: slots,
          now: utc,
          showDueImmediately: showDueImmediately,
          paid: paid,
        );
      } else {
        await VehicleLicenseReminderService.sync(
          slots: slots,
          extraCancelSlots: housingLicenseLegacyGraceCancelSlots(
            activeUseStartedAt: started,
          ),
          now: utc,
          showDueImmediately: showDueImmediately,
          paid: paid,
        );
      }
    }

    await _syncSharingDisabledNotification(prefs: p);
    await _replayHeldIfAllowed();
  }

  /// First owner-side session end or fuel purchase starts the 14-day trial.
  static Future<void> maybeStartTrialFromOwnerFact({
    required String actingContactId,
  }) async {
    if (!vehicleContactIsOwnerSelf(actingContactId)) return;
    final entitlement = ModuleEntitlementController.maybeInstance;
    if (entitlement == null) return;
    if (entitlement.isActivePaid(AppModuleId.vehicle)) {
      return;
    }
    if (entitlement.stateOf(AppModuleId.vehicle) ==
        ModuleEntitlementState.delinquentReadonly) {
      return;
    }
    final prefs = await AppPreferences.load();
    final started = await prefs.markVehicleTrialStarted();
    if (!started) return;
    await apply(prefs: prefs, showDueImmediately: true);
  }

  static Future<void> _syncSharingDisabledNotification({
    required AppPreferences prefs,
  }) async {
    final hold = const VehicleModuleAccess().shouldHoldOwnerInbound;
    if (!hold) {
      if (prefs.vehicleSharingDisabledEntryNotified()) {
        await prefs.setVehicleSharingDisabledEntryNotified(false);
      }
      if (prefs.vehicleSharingHoldInboundNotified()) {
        await prefs.setVehicleSharingHoldInboundNotified(false);
      }
      return;
    }
    if (prefs.vehicleSharingDisabledEntryNotified()) return;
    await prefs.setVehicleSharingDisabledEntryNotified(true);
    await showVehicleSharingDisabledNotification();
  }

  static Future<void> _replayHeldIfAllowed() async {
    if (const VehicleModuleAccess().shouldHoldOwnerInbound) return;
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return;
    await orch.replayHeldBorrowerVehicleEnvelopes();
  }
}

List<HousingLicenseReminderSlot> _receiptGraceSlots({
  required List<StoreReceiptRecord> receipts,
  required DateTime now,
}) {
  DateTime? earliestExpiry;
  for (final receipt in receipts) {
    final entry = StoreProductCatalog.entryForProductId(receipt.productId);
    if (entry == null ||
        !entry.grantsModules.contains(AppModuleId.vehicle)) {
      continue;
    }
    final exp = receipt.expiresAt;
    if (exp == null || !exp.isBefore(now)) continue;
    final graceEnd = exp.add(kStoreReceiptGraceDuration);
    if (now.isAfter(graceEnd)) continue;
    if (earliestExpiry == null || exp.isBefore(earliestExpiry)) {
      earliestExpiry = exp;
    }
  }
  if (earliestExpiry == null) return const [];
  return housingLicenseReceiptGraceSlots(receiptExpiredAt: earliestExpiry);
}
