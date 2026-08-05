import 'dart:convert';

import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_fuel_purchase_transport_service.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
import 'package:compartarenta/vehicle/vehicle_meter_photo_path.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vehicleId = 'vehicle:civic';
  const borrowerContactId = 'contact:monica';
  const ownerPeerContactId = 'contact:louys';
  const linkId = 'vshare:link-1';

  Future<void> seedOwnedVehicle(AppDatabase db) async {
    await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'QA Civic',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  Future<void> seedSharedVehicle(AppDatabase db) async {
    await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: ownerPeerContactId,
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'QA Civic',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  test('import fuel purchase preserves remotePurchaseId', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleFuelPurchaseTransportService(db);
    final repo = VehiclesRepository(db);

    final purchaseJson = jsonEncode({
      'kind': VehicleFuelPurchaseTransportService.purchaseKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'remotePurchaseId': 'fuel:remote-stable-1',
      'purchasedAt': '2026-08-01T18:30:00.000Z',
      'costMinor': 8500,
      'currency': 'CAD',
      'isFullTank': false,
      'volumeLiters': 40.0,
      'meterTenths': 501000,
      'tankFillFraction': 60,
      'photoBase64': null,
      'photoIsSentinel': true,
    });

    final imported = await transport.importReceivedPurchase(
      purchaseJson: purchaseJson,
      borrowerContactId: borrowerContactId,
    );
    expect(imported.id, 'fuel:remote-stable-1');

    final again = await transport.importReceivedPurchase(
      purchaseJson: purchaseJson,
      borrowerContactId: borrowerContactId,
    );
    expect(again.id, imported.id);
    expect(await repo.listFuelPurchases(vehicleId), hasLength(1));
  });

  test('import fuel purchase updates owner meter anchor', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleFuelPurchaseTransportService(db);
    final repo = VehiclesRepository(db);

    final start = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: 500000,
      unit: 'odometer_km',
      photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      recordedByContactId: kVehicleOwnerSelfContactId,
      role: MeterReadingRole.sessionStart,
      recordedAt: DateTime.utc(2026, 8, 1, 9),
    );
    await repo.openUseSession(
      vehicleId: vehicleId,
      attributedContactId: borrowerContactId,
      startReadingId: start.id,
    );

    final purchaseJson = jsonEncode({
      'kind': VehicleFuelPurchaseTransportService.purchaseKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'remotePurchaseId': 'fuel:remote-1',
      'purchasedAt': '2026-08-01T18:30:00.000Z',
      'costMinor': 8500,
      'currency': 'CAD',
      'isFullTank': false,
      'volumeLiters': 40.0,
      'meterTenths': 501000,
      'tankFillFraction': 60,
      'photoBase64': null,
      'photoIsSentinel': true,
    });

    final imported = await transport.importReceivedPurchase(
      purchaseJson: purchaseJson,
      borrowerContactId: borrowerContactId,
    );

    expect(imported.meterReadingValue, 501000);
    expect(imported.volumeLiters, 40.0);
    expect(imported.recordedByContactId, borrowerContactId);
    expect(await repo.latestMeterValue(vehicleId), 501000);
  });

  test('export then import round-trips fuel purchase fields', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleFuelPurchaseTransportService(db);
    final repo = VehiclesRepository(db);

    final local = await repo.saveFuelPurchase(
      vehicleId: vehicleId,
      purchasedAt: DateTime.utc(2026, 8, 1, 18, 30),
      costMinor: 9000,
      currency: 'CAD',
      isFullTank: true,
      recordedByContactId: borrowerContactId,
      volumeLiters: 45.5,
      meterReadingValue: 502000,
      meterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
    );

    final exported = await transport.exportPurchaseJson(
      linkId: linkId,
      vehicleId: vehicleId,
      remotePurchaseId: local.id,
    );
    final root = jsonDecode(exported) as Map<String, dynamic>;
    expect(root['kind'], VehicleFuelPurchaseTransportService.purchaseKind);
    expect(root['meterTenths'], 502000);
    expect(root['volumeLiters'], 45.5);
    expect(root['isFullTank'], isTrue);
  });

  test('catch-up after cursor returns only later purchases', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final repo = VehiclesRepository(db);

    final fill1 = await repo.saveFuelPurchase(
      id: 'fuel:fill-1',
      vehicleId: vehicleId,
      purchasedAt: DateTime.utc(2026, 8, 1, 10),
      costMinor: 7000,
      currency: 'CAD',
      isFullTank: true,
      recordedByContactId: borrowerContactId,
      volumeLiters: 40,
      meterReadingValue: 500000,
      meterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
    );
    await repo.saveFuelPurchase(
      id: 'fuel:fill-2',
      vehicleId: vehicleId,
      purchasedAt: DateTime.utc(2026, 8, 2, 10),
      costMinor: 8000,
      currency: 'CAD',
      isFullTank: true,
      recordedByContactId: borrowerContactId,
      volumeLiters: 42,
      meterReadingValue: 505000,
      meterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
    );
    await repo.saveFuelPurchase(
      id: 'fuel:topup',
      vehicleId: vehicleId,
      purchasedAt: DateTime.utc(2026, 8, 3, 10),
      costMinor: 4000,
      currency: 'CAD',
      isFullTank: false,
      recordedByContactId: kVehicleOwnerSelfContactId,
      volumeLiters: 20,
      meterReadingValue: 508000,
      meterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      tankFillFraction: 40,
    );

    final afterFill1 = await repo.fuelPurchasesForSessionStartCatchUp(
      vehicleId,
      lastKnownPurchaseId: fill1.id,
    );
    expect(afterFill1.map((p) => p.id), ['fuel:fill-2', 'fuel:topup']);

    final afterFill2 = await repo.fuelPurchasesForSessionStartCatchUp(
      vehicleId,
      lastKnownPurchaseId: 'fuel:fill-2',
    );
    expect(afterFill2.map((p) => p.id), ['fuel:topup']);
  });

  test('catch-up without cursor returns last full tank inclusive', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final repo = VehiclesRepository(db);

    await repo.saveFuelPurchase(
      id: 'fuel:old-full',
      vehicleId: vehicleId,
      purchasedAt: DateTime.utc(2026, 7, 1, 10),
      costMinor: 6000,
      currency: 'CAD',
      isFullTank: true,
      recordedByContactId: kVehicleOwnerSelfContactId,
      volumeLiters: 50,
      meterReadingValue: 490000,
      meterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
    );
    await repo.saveFuelPurchase(
      id: 'fuel:last-full',
      vehicleId: vehicleId,
      purchasedAt: DateTime.utc(2026, 8, 2, 10),
      costMinor: 8000,
      currency: 'CAD',
      isFullTank: true,
      recordedByContactId: borrowerContactId,
      volumeLiters: 45,
      meterReadingValue: 505000,
      meterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
    );
    await repo.saveFuelPurchase(
      id: 'fuel:topup',
      vehicleId: vehicleId,
      purchasedAt: DateTime.utc(2026, 8, 3, 10),
      costMinor: 4000,
      currency: 'CAD',
      isFullTank: false,
      recordedByContactId: kVehicleOwnerSelfContactId,
      volumeLiters: 20,
      meterReadingValue: 508000,
      meterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      tankFillFraction: 40,
    );

    final batch = await repo.fuelPurchasesForSessionStartCatchUp(vehicleId);
    expect(batch.map((p) => p.id), ['fuel:last-full', 'fuel:topup']);
  });

  test('export catch-up always sends; empty ack marks response received',
      () async {
    final ownerDb = AppDatabase.forTesting(NativeDatabase.memory());
    final borrowerDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(ownerDb.close);
    addTearDown(borrowerDb.close);
    await seedOwnedVehicle(ownerDb);
    await seedSharedVehicle(borrowerDb);

    final ownerRepo = VehiclesRepository(ownerDb);
    await ownerRepo.saveFuelPurchase(
      id: 'fuel:last-full',
      vehicleId: vehicleId,
      purchasedAt: DateTime.utc(2026, 8, 2, 10),
      costMinor: 8000,
      currency: 'CAD',
      isFullTank: true,
      recordedByContactId: borrowerContactId,
      volumeLiters: 45,
      meterReadingValue: 505000,
      meterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
    );
    await ownerRepo.saveFuelPurchase(
      id: 'fuel:topup',
      vehicleId: vehicleId,
      purchasedAt: DateTime.utc(2026, 8, 3, 10),
      costMinor: 4000,
      currency: 'CAD',
      isFullTank: false,
      recordedByContactId: kVehicleOwnerSelfContactId,
      volumeLiters: 20,
      meterReadingValue: 508000,
      meterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      tankFillFraction: 40,
    );

    final ownerTransport = VehicleFuelPurchaseTransportService(ownerDb);
    final emptyCatchUp = await ownerTransport.exportCatchUpJson(
      linkId: linkId,
      vehicleId: vehicleId,
      lastKnownPurchaseId: 'fuel:topup',
    );
    final emptyRoot = jsonDecode(emptyCatchUp) as Map<String, dynamic>;
    expect(emptyRoot['kind'], VehicleFuelPurchaseTransportService.catchUpKind);
    expect(emptyRoot['purchases'], isEmpty);

    final catchUp = await ownerTransport.exportCatchUpJson(
      linkId: linkId,
      vehicleId: vehicleId,
      lastKnownPurchaseId: 'fuel:last-full',
    );
    final root = jsonDecode(catchUp) as Map<String, dynamic>;
    expect(root['kind'], VehicleFuelPurchaseTransportService.catchUpKind);
    expect((root['purchases'] as List), hasLength(1));

    final borrowerRepo = VehiclesRepository(borrowerDb);
    final start = await borrowerRepo.saveMeterReading(
      vehicleId: vehicleId,
      value: 510000,
      unit: 'odometer_km',
      photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      recordedByContactId: kVehicleBorrowerSelfContactId,
      role: MeterReadingRole.sessionStart,
      recordedAt: DateTime.utc(2026, 8, 4, 10),
    );
    final use = await borrowerRepo.openUseSession(
      vehicleId: vehicleId,
      attributedContactId: kVehicleBorrowerSelfContactId,
      startReadingId: start.id,
    );
    await borrowerRepo.markFuelCatchUpResponsePending(use.id);
    expect(
      (await borrowerRepo.getVehicleUse(use.id))!.fuelCatchUpResponseReceived,
      isFalse,
    );

    final borrowerTransport = VehicleFuelPurchaseTransportService(borrowerDb);
    final imported =
        await borrowerTransport.importCatchUpPurchases(catchUpJson: catchUp);
    expect(imported, hasLength(1));
    expect(imported.single.id, 'fuel:topup');
    expect(imported.single.recordedByContactId, ownerPeerContactId);
    expect(
      (await borrowerRepo.getVehicleUse(use.id))!.fuelCatchUpResponseReceived,
      isTrue,
    );

    await borrowerRepo.markFuelCatchUpResponsePending(use.id);
    final ackOnly = await borrowerTransport.importCatchUpPurchases(
      catchUpJson: emptyCatchUp,
    );
    expect(ackOnly, isEmpty);
    expect(
      (await borrowerRepo.getVehicleUse(use.id))!.fuelCatchUpResponseReceived,
      isTrue,
    );
  });
}
