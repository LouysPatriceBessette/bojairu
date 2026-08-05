import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';
import '../db/repositories/vehicles_repository.dart';
import '../vehicle/vehicle_consumption_estimation_mode.dart';
import '../vehicle/vehicle_meter_photo_path.dart';
import '../vehicle/vehicle_owner_contact.dart';
import 'qa_fcm_wake_push_seed.dart';
import 'qa_vehicle_sharing_active_seed.dart';
import 'qa_vehicle_sharing_usage_history_2nd_fill_seed.dart';

/// 3rd full-tank snapshot — from `qa/db_seeds/consumption-verify-*` (2026-08-04,
/// re-stolen after Monica's post-3rd-plein session + fuel catch-up).
/// Extends [seedQaVehicleSharingUsageHistory2ndFill*] through the owner's 3rd
/// plein (45 L at 51 870.4 km), owner session to 51 950.9 km, then Monica's
/// closed session to 52 000.0 km (borrower also has fill-3 via catch-up).
/// Photos use the known-unchanged sentinel.

DateTime _qaUsageHistory3rdFillAt(int unixSeconds) =>
    DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true);

/// Owner non-full top-up between 2nd and 3rd plein (stable cross-device id).
const kQaUsageHistoryPartial20FuelId = 'fuel:qa-usage-history-partial-20';

/// Third full-tank purchase (owner; catch-up'd onto Monica).
const kQaUsageHistoryFuelPurchase3Id = 'fuel:qa-usage-history-fill-3';

/// Latest meter after Monica's post-catch-up session (both devices).
const kQaUsageHistory3rdFillOwnerFinalMeterTenths = 520000;

/// Same final meter on Monica after her last closed session in this dump.
const kQaUsageHistory3rdFillBorrowerFinalMeterTenths = 520000;

Future<void> seedQaVehicleSharingUsageHistory3rdFillOwner(AppDatabase db) async {
  await seedQaVehicleSharingActiveOwner(db);
  await seedQaVehicleSharingUsageHistory2ndFillOwnerEvents(db);
  await seedQaVehicleSharingUsageHistory3rdFillOwnerExtraEvents(db);
}

Future<void> seedQaVehicleSharingUsageHistory3rdFillBorrower(
  AppDatabase db,
) async {
  await seedQaVehicleSharingActiveBorrower(db);
  await seedQaVehicleSharingUsageHistory2ndFillBorrowerEvents(db);
  await seedQaVehicleSharingUsageHistory3rdFillBorrowerExtraEvents(db);
}

/// Events after the 2nd-fill journal on the owner device (through 3rd plein).
Future<void> seedQaVehicleSharingUsageHistory3rdFillOwnerExtraEvents(
  AppDatabase db,
) async {
  final repo = VehiclesRepository(db);
  const vehicleId = kQaVehicleSharingActiveVehicleId;
  const unit = 'odometer_km';
  final photo = kVehicleMeterPhotoKnownUnchangedSentinel;

  Future<void> closedSession({
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
      recordedAt: _qaUsageHistory3rdFillAt(startTs),
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
      recordedAt: _qaUsageHistory3rdFillAt(endTs),
    );
    await repo.closeUseSession(
      useId: use.id,
      endReadingId: endReading.id,
      sessionConsumptionMode: sessionMode,
    );
  }

  await closedSession(
    attributedContactId: kVehicleOwnerSelfContactId,
    startTs: 1785881680,
    endTs: 1785881712,
    startMeter: 511824,
    endMeter: 515706,
    startFullTank: false,
    startTankPercent: 87,
    endTankPercent: 25,
    sessionMode: VehicleConsumptionEstimationMode.simple,
  );
  await closedSession(
    attributedContactId: kQaFcmWakeMonicaContactId,
    startTs: 1785881774,
    endTs: 1785881808,
    startMeter: 515706,
    endMeter: 516924,
    startFullTank: false,
    startTankPercent: 25,
    endTankPercent: 1,
  );
  await closedSession(
    attributedContactId: kVehicleOwnerSelfContactId,
    startTs: 1785881840,
    endTs: 1785881917,
    startMeter: 516924,
    endMeter: 518081,
    startFullTank: false,
    startTankPercent: 1,
    endTankPercent: 37,
    sessionMode: VehicleConsumptionEstimationMode.simple,
  );
  await repo.saveFuelPurchase(
    id: kQaUsageHistoryPartial20FuelId,
    vehicleId: vehicleId,
    purchasedAt: _qaUsageHistory3rdFillAt(1785881887),
    costMinor: 4000,
    currency: 'CAD',
    isFullTank: false,
    recordedByContactId: kVehicleOwnerSelfContactId,
    volumeLiters: 20,
    meterReadingValue: 517081,
    meterPhotoPath: photo,
    tankFillFraction: 50,
  );
  await closedSession(
    attributedContactId: kQaFcmWakeMonicaContactId,
    startTs: 1785881993,
    endTs: 1785882039,
    startMeter: 518081,
    endMeter: 518607,
    startFullTank: false,
    startTankPercent: 37,
    endTankPercent: 25,
  );
  await closedSession(
    attributedContactId: kVehicleOwnerSelfContactId,
    startTs: 1785882152,
    endTs: 1785882473,
    startMeter: 518607,
    endMeter: 519509,
    startFullTank: false,
    startTankPercent: 25,
    endTankPercent: 87,
    sessionMode: VehicleConsumptionEstimationMode.simple,
  );
  await repo.saveFuelPurchase(
    id: kQaUsageHistoryFuelPurchase3Id,
    vehicleId: vehicleId,
    purchasedAt: _qaUsageHistory3rdFillAt(1785882223),
    costMinor: 9000,
    currency: 'CAD',
    isFullTank: true,
    recordedByContactId: kVehicleOwnerSelfContactId,
    volumeLiters: 45,
    meterReadingValue: 518704,
    meterPhotoPath: photo,
  );
  await closedSession(
    attributedContactId: kQaFcmWakeMonicaContactId,
    startTs: 1785891668,
    endTs: 1785891801,
    startMeter: 519509,
    endMeter: kQaUsageHistory3rdFillOwnerFinalMeterTenths,
    startFullTank: false,
    startTankPercent: 87,
    endTankPercent: 87,
  );
}

/// Events after the 2nd-fill journal on the borrower device (no open session).
///
/// Includes owner 20 L + 3rd plein (catch-up) and Monica's post-catch-up
/// closed session (flag [VehicleUse.fuelCatchUpResponseReceived] = true).
Future<void> seedQaVehicleSharingUsageHistory3rdFillBorrowerExtraEvents(
  AppDatabase db,
) async {
  final repo = VehiclesRepository(db);
  const vehicleId = kQaVehicleSharingActiveVehicleId;
  const unit = 'odometer_km';
  final photo = kVehicleMeterPhotoKnownUnchangedSentinel;
  const self = kVehicleBorrowerSelfContactId;

  Future<String> closedSession({
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
      recordedAt: _qaUsageHistory3rdFillAt(startTs),
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
      recordedAt: _qaUsageHistory3rdFillAt(endTs),
    );
    await repo.closeUseSession(
      useId: use.id,
      endReadingId: endReading.id,
      sessionConsumptionMode: VehicleConsumptionEstimationMode.simple,
    );
    return use.id;
  }

  await closedSession(
    startTs: 1785881774,
    endTs: 1785881808,
    startMeter: 515706,
    endMeter: 516924,
    startFullTank: false,
    startTankPercent: 25,
    endTankPercent: 1,
  );
  await repo.saveFuelPurchase(
    id: kQaUsageHistoryPartial20FuelId,
    vehicleId: vehicleId,
    purchasedAt: _qaUsageHistory3rdFillAt(1785881887),
    costMinor: 4000,
    currency: 'CAD',
    isFullTank: false,
    recordedByContactId: kQaFcmWakeLouysContactId,
    volumeLiters: 20,
    meterReadingValue: 517081,
    meterPhotoPath: photo,
    tankFillFraction: 50,
  );
  await closedSession(
    startTs: 1785881993,
    endTs: 1785882039,
    startMeter: 518081,
    endMeter: 518607,
    startFullTank: false,
    startTankPercent: 37,
    endTankPercent: 25,
  );
  await repo.saveFuelPurchase(
    id: kQaUsageHistoryFuelPurchase3Id,
    vehicleId: vehicleId,
    purchasedAt: _qaUsageHistory3rdFillAt(1785882223),
    costMinor: 9000,
    currency: 'CAD',
    isFullTank: true,
    recordedByContactId: kQaFcmWakeLouysContactId,
    volumeLiters: 45,
    meterReadingValue: 518704,
    meterPhotoPath: photo,
  );
  final catchUpSessionId = await closedSession(
    startTs: 1785891668,
    endTs: 1785891801,
    startMeter: 519509,
    endMeter: kQaUsageHistory3rdFillBorrowerFinalMeterTenths,
    startFullTank: false,
    startTankPercent: 87,
    endTankPercent: 87,
  );
  await (db.update(db.vehicleUses)..where((t) => t.id.equals(catchUpSessionId)))
      .write(
    const VehicleUsesCompanion(
      fuelCatchUpResponseReceived: drift.Value(true),
    ),
  );
}
