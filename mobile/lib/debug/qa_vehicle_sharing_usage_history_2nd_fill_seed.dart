import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';
import '../db/repositories/vehicles_repository.dart';
import '../vehicle/vehicle_consumption_estimation_mode.dart';
import '../vehicle/vehicle_meter_photo_path.dart';
import '../vehicle/vehicle_owner_contact.dart';
import 'qa_fcm_wake_push_seed.dart';
import 'qa_vehicle_seed_helpers.dart';
import 'qa_vehicle_sharing_active_seed.dart';

/// 2nd full-tank snapshot — captured from Louys-QA / Monica-QA dumps (`qa/db_seeds/usage-balance-diag-*`,
/// 2026-08-04) after `vehicle_sharing_active_seed` + manual sessions/fuels.
/// Photos use the known-unchanged sentinel (device content:// URIs are not portable).

/// Stable fuel purchase ids shared across owner/borrower AVD seeds (catch-up cursor).
const kQaUsageHistoryFuelPurchase1Id = 'fuel:qa-usage-history-fill-1';
const kQaUsageHistoryFuelPurchase2Id = 'fuel:qa-usage-history-fill-2';

/// Standalone baseline reading time in the dump (before the first session).
const kQaUsageHistory2ndFillBaselineMeterUnixSeconds = 1785853111;

/// Last session-end meter (tenths) after the captured journal.
const kQaUsageHistory2ndFillFinalMeterTenths = 511824;

DateTime _qaUsageHistory2ndFillAt(int unixSeconds) =>
    DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true);

Future<void> seedQaVehicleSharingUsageHistory2ndFillOwner(AppDatabase db) async {
  await seedQaVehicleSharingActiveOwner(db);
  await seedQaVehicleSharingUsageHistory2ndFillOwnerEvents(db);
}

Future<void> seedQaVehicleSharingUsageHistory2ndFillBorrower(AppDatabase db) async {
  await seedQaVehicleSharingActiveBorrower(db);
  await seedQaVehicleSharingUsageHistory2ndFillBorrowerEvents(db);
}

/// Active-seed baseline uses wall-clock `recordedAt`; history rows use dump
/// times earlier that day — without this, the hub card shows 50 000 km.
Future<void> _backdateOwnerBaselineMeter2ndFill(AppDatabase db) async {
  await (db.update(db.vehicleMeterReadings)
        ..where(
          (t) =>
              t.vehicleId.equals(kQaVehicleSharingActiveVehicleId) &
              t.readingRole.equals(MeterReadingRole.standalone.wire) &
              t.value.equals(kQaVehicleE2eInitialMeterTenths),
        ))
      .write(
        VehicleMeterReadingsCompanion(
          recordedAt: drift.Value(
            _qaUsageHistory2ndFillAt(kQaUsageHistory2ndFillBaselineMeterUnixSeconds),
          ),
        ),
      );
}

/// Owner-side journal: 7 closed uses + 2 full-tank purchases (Monica-recorded).
Future<void> seedQaVehicleSharingUsageHistory2ndFillOwnerEvents(AppDatabase db) async {
  await _backdateOwnerBaselineMeter2ndFill(db);
  final repo = VehiclesRepository(db);
  const vehicleId = kQaVehicleSharingActiveVehicleId;
  const unit = 'odometer_km';
  final photo = kVehicleMeterPhotoKnownUnchangedSentinel;

  Future<void> session({
    required String attributedContactId,
    required int startTs,
    required int endTs,
    required int startMeter,
    required int endMeter,
    required bool startFullTank,
    int? startTankPercent,
    required int endTankPercent,
    VehicleConsumptionEstimationMode? sessionMode,
  }) async {
    final startReading = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: startMeter,
      unit: unit,
      photoPath: photo,
      recordedByContactId: attributedContactId,
      role: MeterReadingRole.sessionStart,
      isFullTank: startFullTank ? true : null,
      tankFillFraction: startFullTank ? null : startTankPercent,
      recordedAt: _qaUsageHistory2ndFillAt(startTs),
    );
    final use = await repo.openUseSession(
      vehicleId: vehicleId,
      attributedContactId: attributedContactId,
      startReadingId: startReading.id,
    );
    final endReading = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: endMeter,
      unit: unit,
      photoPath: photo,
      recordedByContactId: attributedContactId,
      role: MeterReadingRole.sessionEnd,
      vehicleUseId: use.id,
      isFullTank: endTankPercent >= 100,
      tankFillFraction: endTankPercent >= 100 ? null : endTankPercent,
      recordedAt: _qaUsageHistory2ndFillAt(endTs),
    );
    await repo.closeUseSession(
      useId: use.id,
      endReadingId: endReading.id,
      sessionConsumptionMode: sessionMode,
    );
  }

  // Chronology from Louys dump (unix seconds).
  await session(
    attributedContactId: kQaFcmWakeMonicaContactId,
    startTs: 1785856434,
    endTs: 1785856651,
    startMeter: 500000,
    endMeter: 501475,
    startFullTank: true,
    endTankPercent: 75,
  );
  await session(
    attributedContactId: kVehicleOwnerSelfContactId,
    startTs: 1785856673,
    endTs: 1785856906,
    startMeter: 501475,
    endMeter: 502243,
    startFullTank: false,
    startTankPercent: 75,
    endTankPercent: 75,
    sessionMode: VehicleConsumptionEstimationMode.simple,
  );
  await session(
    attributedContactId: kQaFcmWakeMonicaContactId,
    startTs: 1785857148,
    endTs: 1785857365,
    startMeter: 502243,
    endMeter: 503107,
    startFullTank: false,
    startTankPercent: 75,
    endTankPercent: 50,
  );
  await session(
    attributedContactId: kVehicleOwnerSelfContactId,
    startTs: 1785858187,
    endTs: 1785858237,
    startMeter: 503107,
    endMeter: 504628,
    startFullTank: false,
    startTankPercent: 50,
    endTankPercent: 25,
    sessionMode: VehicleConsumptionEstimationMode.simple,
  );
  await session(
    attributedContactId: kQaFcmWakeMonicaContactId,
    startTs: 1785858342,
    endTs: 1785858752,
    startMeter: 504628,
    endMeter: 507186,
    startFullTank: false,
    startTankPercent: 25,
    endTankPercent: 62,
  );
  await repo.saveFuelPurchase(
    id: kQaUsageHistoryFuelPurchase1Id,
    vehicleId: vehicleId,
    purchasedAt: _qaUsageHistory2ndFillAt(1785858532),
    costMinor: 7400,
    currency: 'CAD',
    isFullTank: true,
    recordedByContactId: kQaFcmWakeMonicaContactId,
    volumeLiters: 37,
    meterReadingValue: 504651,
    meterPhotoPath: photo,
  );
  await session(
    attributedContactId: kVehicleOwnerSelfContactId,
    startTs: 1785858768,
    endTs: 1785858903,
    startMeter: 507186,
    endMeter: 509909,
    startFullTank: false,
    startTankPercent: 62,
    endTankPercent: 25,
    sessionMode: VehicleConsumptionEstimationMode.simple,
  );
  await session(
    attributedContactId: kQaFcmWakeMonicaContactId,
    startTs: 1785859020,
    endTs: 1785859366,
    startMeter: 509909,
    endMeter: 511824,
    startFullTank: false,
    startTankPercent: 25,
    endTankPercent: 87,
  );
  await repo.saveFuelPurchase(
    id: kQaUsageHistoryFuelPurchase2Id,
    vehicleId: vehicleId,
    purchasedAt: _qaUsageHistory2ndFillAt(1785859147),
    costMinor: 9000,
    currency: 'CAD',
    isFullTank: true,
    recordedByContactId: kQaFcmWakeMonicaContactId,
    volumeLiters: 45,
    meterReadingValue: 510303,
    meterPhotoPath: photo,
  );
}

/// Borrower-side journal: 4 closed uses (self) + 2 full-tank purchases.
Future<void> seedQaVehicleSharingUsageHistory2ndFillBorrowerEvents(
  AppDatabase db,
) async {
  final repo = VehiclesRepository(db);
  const vehicleId = kQaVehicleSharingActiveVehicleId;
  const unit = 'odometer_km';
  final photo = kVehicleMeterPhotoKnownUnchangedSentinel;
  const self = kVehicleBorrowerSelfContactId;

  Future<void> session({
    required int startTs,
    required int endTs,
    required int startMeter,
    required int endMeter,
    required bool startFullTank,
    int? startTankPercent,
    required int endTankPercent,
  }) async {
    final startReading = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: startMeter,
      unit: unit,
      photoPath: photo,
      recordedByContactId: self,
      role: MeterReadingRole.sessionStart,
      isFullTank: startFullTank ? true : null,
      tankFillFraction: startFullTank ? null : startTankPercent,
      recordedAt: _qaUsageHistory2ndFillAt(startTs),
    );
    final use = await repo.openUseSession(
      vehicleId: vehicleId,
      attributedContactId: self,
      startReadingId: startReading.id,
    );
    final endReading = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: endMeter,
      unit: unit,
      photoPath: photo,
      recordedByContactId: self,
      role: MeterReadingRole.sessionEnd,
      vehicleUseId: use.id,
      isFullTank: endTankPercent >= 100,
      tankFillFraction: endTankPercent >= 100 ? null : endTankPercent,
      recordedAt: _qaUsageHistory2ndFillAt(endTs),
    );
    await repo.closeUseSession(
      useId: use.id,
      endReadingId: endReading.id,
      sessionConsumptionMode: VehicleConsumptionEstimationMode.simple,
    );
  }

  await session(
    startTs: 1785856434,
    endTs: 1785856651,
    startMeter: 500000,
    endMeter: 501475,
    startFullTank: true,
    endTankPercent: 75,
  );
  await session(
    startTs: 1785857148,
    endTs: 1785857365,
    startMeter: 502243,
    endMeter: 503107,
    startFullTank: false,
    startTankPercent: 75,
    endTankPercent: 50,
  );
  await session(
    startTs: 1785858342,
    endTs: 1785858752,
    startMeter: 504628,
    endMeter: 507186,
    startFullTank: false,
    startTankPercent: 25,
    endTankPercent: 62,
  );
  await repo.saveFuelPurchase(
    id: kQaUsageHistoryFuelPurchase1Id,
    vehicleId: vehicleId,
    purchasedAt: _qaUsageHistory2ndFillAt(1785858532),
    costMinor: 7400,
    currency: 'CAD',
    isFullTank: true,
    recordedByContactId: self,
    volumeLiters: 37,
    meterReadingValue: 504651,
    meterPhotoPath: photo,
  );
  await session(
    startTs: 1785859020,
    endTs: 1785859366,
    startMeter: 509909,
    endMeter: 511824,
    startFullTank: false,
    startTankPercent: 25,
    endTankPercent: 87,
  );
  await repo.saveFuelPurchase(
    id: kQaUsageHistoryFuelPurchase2Id,
    vehicleId: vehicleId,
    purchasedAt: _qaUsageHistory2ndFillAt(1785859147),
    costMinor: 9000,
    currency: 'CAD',
    isFullTank: true,
    recordedByContactId: self,
    volumeLiters: 45,
    meterReadingValue: 510303,
    meterPhotoPath: photo,
  );
}
