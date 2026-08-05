import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/vehicle/vehicle_consumption_estimation_mode.dart';
import 'package:compartarenta/vehicle/vehicle_consumption_metrics.dart';
import 'package:compartarenta/vehicle/vehicle_consumption_reliability.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simple mode ignores detailed-only intervals', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.bindProcessScope(db);
    addTearDown(() {
      AppDatabase.clearProcessScopeIfReferencing(db);
      db.close();
    });

    const vehicleId = 'vehicle:simple_mode';
    final t0 = DateTime.utc(2026, 3, 1);

    await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'Simple',
            consumptionEstimationMode: Value(
              VehicleConsumptionEstimationMode.simple.wire,
            ),
            createdAt: t0,
            updatedAt: t0,
          ),
        );

    Future<void> insertFull({
      required String id,
      required DateTime at,
      required int meter,
    }) {
      return db.into(db.fuelPurchases).insert(
            FuelPurchasesCompanion.insert(
              id: id,
              vehicleId: vehicleId,
              purchasedAt: at,
              costMinor: 5000,
              currency: 'CAD',
              volumeLiters: const Value(40),
              meterReadingValue: Value(meter),
              isFullTank: true,
              recordedByContactId: kVehicleOwnerSelfContactId,
            ),
          );
    }

    await insertFull(id: 'fuel:0', at: t0, meter: 1000000);
    await insertFull(
      id: 'fuel:1',
      at: t0.add(const Duration(days: 10)),
      meter: 1001000,
    );
    await insertFull(
      id: 'fuel:2',
      at: t0.add(const Duration(days: 20)),
      meter: 1002000,
    );

    final startReading = await db.into(db.vehicleMeterReadings).insertReturning(
          VehicleMeterReadingsCompanion.insert(
            id: 'meter:start',
            vehicleId: vehicleId,
            value: 1000500,
            unit: 'odometer_km',
            photoPath: 'a.jpg',
            recordedAt: t0.add(const Duration(days: 5)),
            recordedByContactId: kVehicleOwnerSelfContactId,
            readingRole: MeterReadingRole.sessionStart.wire,
          ),
        );
    final endReading = await db.into(db.vehicleMeterReadings).insertReturning(
          VehicleMeterReadingsCompanion.insert(
            id: 'meter:end',
            vehicleId: vehicleId,
            value: 1000900,
            unit: 'odometer_km',
            photoPath: 'b.jpg',
            recordedAt: t0.add(const Duration(days: 8)),
            recordedByContactId: kVehicleOwnerSelfContactId,
            readingRole: MeterReadingRole.sessionEnd.wire,
          ),
        );
    await db.into(db.vehicleUses).insert(
          VehicleUsesCompanion.insert(
            id: 'use:detailed',
            vehicleId: vehicleId,
            attributedContactId: kVehicleOwnerSelfContactId,
            startedAt: t0.add(const Duration(days: 5)),
            endedAt: Value(t0.add(const Duration(days: 8))),
            startReadingId: startReading.id,
            endReadingId: Value(endReading.id),
            usageAmount: const Value(400),
            drivingRoutePercent: const Value(50),
            drivingCityPercent: const Value(30),
            drivingTrafficPercent: const Value(20),
            sessionConsumptionMode: Value(
              VehicleConsumptionEstimationMode.detailed.wire,
            ),
          ),
        );

    final snapshot =
        await VehicleConsumptionMetrics(db).forVehicle(vehicleId);

    // Interval fuel:0→fuel:1 is ignored (detailed session); fuel:1→fuel:2 remains.
    // One simple interval is enough for a preliminary estimate.
    expect(snapshot.hasSufficientData, isTrue);
    expect(snapshot.reliability, VehicleConsumptionReliability.preliminary);
    expect(snapshot.periodsInWindow, 1);
  });
}
