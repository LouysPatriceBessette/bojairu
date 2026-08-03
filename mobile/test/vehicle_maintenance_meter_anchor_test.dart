import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saveMaintenanceEvent with meter advances latestMeterValue and reading',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = VehiclesRepository(db);
      const vehicleId = 'vehicle:maint-meter';
      final t0 = DateTime.utc(2026, 6, 30, 10);
      final t1 = DateTime.utc(2026, 6, 30, 12);

      await db.into(db.vehicles).insert(
            VehiclesCompanion.insert(
              id: vehicleId,
              ownerContactId: kVehicleOwnerSelfContactId,
              vehicleKind: VehicleKind.car.wire,
              displayLabel: 'Test',
              createdAt: t0,
              updatedAt: t0,
            ),
          );

      await db.into(db.vehicleMeterReadings).insert(
            VehicleMeterReadingsCompanion.insert(
              id: 'meter:init',
              vehicleId: vehicleId,
              value: 5000000,
              unit: 'odometer_km',
              photoPath: 'init.jpg',
              recordedAt: t0,
              recordedByContactId: kVehicleOwnerSelfContactId,
              readingRole: MeterReadingRole.standalone.wire,
            ),
          );

      await repo.saveMaintenanceEvent(
        vehicleId: vehicleId,
        servicedAt: t1,
        category: 'oil',
        costMinor: 3500,
        currency: 'CAD',
        recordedByContactId: kVehicleOwnerSelfContactId,
        meterAtService: 5015000,
        attachmentPath: 'oil.jpg',
      );

      expect(await repo.latestMeterValue(vehicleId), 5015000);
      final latestReading = await repo.latestNonCorrectionMeterReading(vehicleId);
      expect(latestReading, isNotNull);
      expect(latestReading!.value, 5015000);
      expect(latestReading.readingRole, MeterReadingRole.maintenance.wire);
      expect(latestReading.photoPath, 'oil.jpg');
    },
  );
}
