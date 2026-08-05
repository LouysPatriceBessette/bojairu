import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/vehicle/vehicle_consumption_metrics.dart';
import 'package:compartarenta/vehicle/vehicle_consumption_reliability.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses only the last five plein-to-plein intervals', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.bindProcessScope(db);
    addTearDown(() {
      AppDatabase.clearProcessScopeIfReferencing(db);
      db.close();
    });

    const vehicleId = 'vehicle:window';
    final t0 = DateTime.utc(2026, 1, 1);

    await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'Window',
            createdAt: t0,
            updatedAt: t0,
          ),
        );

    var meter = 1000000;
    for (var i = 0; i <= 6; i++) {
      final at = t0.add(Duration(days: i * 10));
      meter += 1000;
      await db.into(db.fuelPurchases).insert(
            FuelPurchasesCompanion.insert(
              id: 'fuel:$i',
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

    final metrics = VehicleConsumptionMetrics(db);
    final snapshot = await metrics.forVehicle(vehicleId);

    expect(snapshot.reliability, VehicleConsumptionReliability.veryReliable);
    expect(snapshot.periodsInWindow, 5);
    expect(snapshot.hasSufficientData, isTrue);
    expect(snapshot.distanceInWindow, 5000);
    expect(snapshot.volumeInWindow, closeTo(200, 0.001));
    expect(snapshot.litersPer100Km, closeTo(40, 0.1));
  });

  test('includes partial top-ups between full-tank anchors in fuel volume',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.bindProcessScope(db);
    addTearDown(() {
      AppDatabase.clearProcessScopeIfReferencing(db);
      db.close();
    });

    const vehicleId = 'vehicle:partial';
    final t0 = DateTime.utc(2026, 8, 1);
    final t1 = DateTime.utc(2026, 8, 10);
    final tPartial = DateTime.utc(2026, 8, 15);
    final t2 = DateTime.utc(2026, 8, 20);

    await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'Partial',
            createdAt: t0,
            updatedAt: t0,
          ),
        );

    Future<void> insertPurchase({
      required String id,
      required DateTime at,
      required int meter,
      required double liters,
      required bool full,
    }) {
      return db.into(db.fuelPurchases).insert(
            FuelPurchasesCompanion.insert(
              id: id,
              vehicleId: vehicleId,
              purchasedAt: at,
              costMinor: 4000,
              currency: 'CAD',
              volumeLiters: Value(liters),
              meterReadingValue: Value(meter),
              isFullTank: full,
              recordedByContactId: kVehicleOwnerSelfContactId,
              tankFillFraction: full ? const Value.absent() : const Value(40),
            ),
          );
    }

    // Mirrors Louys verify: 37 → 45 → 20 partial → 45.
    await insertPurchase(
      id: 'fuel:a',
      at: t0,
      meter: 504651,
      liters: 37,
      full: true,
    );
    await insertPurchase(
      id: 'fuel:b',
      at: t1,
      meter: 510303,
      liters: 45,
      full: true,
    );
    await insertPurchase(
      id: 'fuel:p',
      at: tPartial,
      meter: 517081,
      liters: 20,
      full: false,
    );
    await insertPurchase(
      id: 'fuel:c',
      at: t2,
      meter: 518704,
      liters: 45,
      full: true,
    );

    final snapshot = await VehicleConsumptionMetrics(db).forVehicle(vehicleId);
    expect(snapshot.hasSufficientData, isTrue);
    expect(snapshot.periodsInWindow, 2);
    // 45 + (20+45) = 110 L over 1405.3 km → ~7.83 L/100 km.
    expect(snapshot.volumeInWindow, closeTo(110, 0.001));
    expect(snapshot.distanceInWindow, 14053);
    expect(snapshot.litersPer100Km, closeTo(7.83, 0.05));
  });

  test('records reliable estimate history once per anchor end', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.bindProcessScope(db);
    addTearDown(() {
      AppDatabase.clearProcessScopeIfReferencing(db);
      db.close();
    });

    const vehicleId = 'vehicle:hist';
    final t0 = DateTime.utc(2026, 2, 1);
    final t1 = DateTime.utc(2026, 2, 11);
    final t2 = DateTime.utc(2026, 2, 21);
    final t3 = DateTime.utc(2026, 3, 3);
    final t4 = DateTime.utc(2026, 3, 13);

    await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'Hist',
            createdAt: t0,
            updatedAt: t0,
          ),
        );

    Future<void> insertFull({
      required String id,
      required DateTime at,
      required int meter,
      required double liters,
    }) {
      return db.into(db.fuelPurchases).insert(
            FuelPurchasesCompanion.insert(
              id: id,
              vehicleId: vehicleId,
              purchasedAt: at,
              costMinor: 5000,
              currency: 'CAD',
              volumeLiters: Value(liters),
              meterReadingValue: Value(meter),
              isFullTank: true,
              recordedByContactId: kVehicleOwnerSelfContactId,
            ),
          );
    }

    await insertFull(id: 'fuel:0', at: t0, meter: 1000000, liters: 40);
    await insertFull(id: 'fuel:1', at: t1, meter: 1001000, liters: 40);
    await insertFull(id: 'fuel:2', at: t2, meter: 1002000, liters: 40);
    await insertFull(id: 'fuel:3', at: t3, meter: 1003000, liters: 40);

    final metrics = VehicleConsumptionMetrics(db);
    await metrics.forVehicle(vehicleId);
    await metrics.forVehicle(vehicleId);
    var history = await metrics.listReliableEstimateHistory(vehicleId);
    expect(history, hasLength(1));

    await insertFull(id: 'fuel:4', at: t4, meter: 1004000, liters: 40);
    await metrics.forVehicle(vehicleId);
    history = await metrics.listReliableEstimateHistory(vehicleId);
    expect(history, hasLength(2));
  });
}
