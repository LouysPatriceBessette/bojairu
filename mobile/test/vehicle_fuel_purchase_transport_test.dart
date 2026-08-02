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
}
