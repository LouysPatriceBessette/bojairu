import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/debug/qa_fcm_wake_push_seed.dart';
import 'package:compartarenta/debug/qa_scenario_seed_helpers.dart';
import 'package:compartarenta/debug/qa_vehicle_sharing_active_seed.dart';
import 'package:compartarenta/debug/qa_vehicle_sharing_usage_history_2nd_fill_seed.dart';
import 'package:compartarenta/debug/qa_vehicle_sharing_usage_history_3rd_fill_seed.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_usage_balance.dart';
import 'package:compartarenta/vehicle/vehicle_consumption_metrics.dart';
import 'package:compartarenta/vehicle/vehicle_consumption_reliability.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('2nd-fill owner: 7 uses, 2 full tanks, preliminary consumption', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await qaSeedFcmWakeConnectedContact(
      db: db,
      contactId: kQaFcmWakeMonicaContactId,
      displayName: 'Monica QA',
      avatarId: 'a01',
      peerPublicMaterialB64: 'dGVzdA',
      now: kQaSeedCreatedAt,
    );
    await seedQaVehicleSharingActiveOwnerLocalData(db);
    await seedQaVehicleSharingUsageHistory2ndFillOwnerEvents(db);

    final uses = await db.select(db.vehicleUses).get();
    expect(uses, hasLength(7));
    expect(uses.every((u) => u.endedAt != null), isTrue);
    final fuels = await db.select(db.fuelPurchases).get();
    expect(fuels, hasLength(2));
    expect(fuels.every((f) => f.isFullTank), isTrue);

    final repo = VehiclesRepository(db);
    expect(
      await repo.latestMeterValue(kQaVehicleSharingActiveVehicleId),
      kQaUsageHistory2ndFillFinalMeterTenths,
    );

    final snapshot = await VehicleConsumptionMetrics(db)
        .forVehicle(kQaVehicleSharingActiveVehicleId);
    expect(snapshot.hasSufficientData, isTrue);
    expect(snapshot.reliability, VehicleConsumptionReliability.preliminary);
    expect(snapshot.periodsInWindow, 1);
  });

  test('2nd-fill borrower: 4 uses, 2 full tanks', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await qaSeedFcmWakeConnectedContact(
      db: db,
      contactId: kQaFcmWakeLouysContactId,
      displayName: 'Louys QA',
      avatarId: 'a02',
      peerPublicMaterialB64: 'dGVzdA',
      now: kQaSeedCreatedAt,
    );
    await seedQaVehicleSharingActiveBorrowerLocalData(db);
    await seedQaVehicleSharingUsageHistory2ndFillBorrowerEvents(db);

    final uses = await db.select(db.vehicleUses).get();
    expect(uses, hasLength(4));
    final fuels = await db.select(db.fuelPurchases).get();
    expect(fuels, hasLength(2));
    expect(
      fuels.map((f) => f.id),
      containsAll([
        kQaUsageHistoryFuelPurchase1Id,
        kQaUsageHistoryFuelPurchase2Id,
      ]),
    );
  });

  test('3rd-fill owner: 13 uses, 4 fuels, reliable consumption ~7.8', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await qaSeedFcmWakeConnectedContact(
      db: db,
      contactId: kQaFcmWakeMonicaContactId,
      displayName: 'Monica QA',
      avatarId: 'a01',
      peerPublicMaterialB64: 'dGVzdA',
      now: kQaSeedCreatedAt,
    );
    await seedQaVehicleSharingActiveOwnerLocalData(db);
    await seedQaVehicleSharingUsageHistory2ndFillOwnerEvents(db);
    await seedQaVehicleSharingUsageHistory3rdFillOwnerExtraEvents(db);

    final uses = await db.select(db.vehicleUses).get();
    expect(uses, hasLength(13));
    expect(uses.every((u) => u.endedAt != null), isTrue);
    final fuels = await db.select(db.fuelPurchases).get();
    expect(fuels, hasLength(4));
    expect(
      fuels.map((f) => f.id),
      containsAll([
        kQaUsageHistoryFuelPurchase1Id,
        kQaUsageHistoryFuelPurchase2Id,
        kQaUsageHistoryPartial20FuelId,
        kQaUsageHistoryFuelPurchase3Id,
      ]),
    );
    expect(fuels.where((f) => !f.isFullTank), hasLength(1));

    final repo = VehiclesRepository(db);
    expect(
      await repo.latestMeterValue(kQaVehicleSharingActiveVehicleId),
      kQaUsageHistory3rdFillOwnerFinalMeterTenths,
    );

    final snapshot = await VehicleConsumptionMetrics(db)
        .forVehicle(kQaVehicleSharingActiveVehicleId);
    expect(snapshot.hasSufficientData, isTrue);
    expect(snapshot.reliability, VehicleConsumptionReliability.reliable);
    expect(snapshot.periodsInWindow, 2);
    // 110 L / 1405.3 km ≈ 7.828 L/100 (opening 37 L excluded; window ends at 3rd plein).
    expect(snapshot.litersPer100Km, closeTo(7.828, 0.01));
  });

  test(
    '3rd-fill borrower: 7 uses, 4 fuels (catch-up fill-3 + session), reliable',
    () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await qaSeedFcmWakeConnectedContact(
      db: db,
      contactId: kQaFcmWakeLouysContactId,
      displayName: 'Louys QA',
      avatarId: 'a02',
      peerPublicMaterialB64: 'dGVzdA',
      now: kQaSeedCreatedAt,
    );
    await seedQaVehicleSharingActiveBorrowerLocalData(db);
    await seedQaVehicleSharingUsageHistory2ndFillBorrowerEvents(db);
    await seedQaVehicleSharingUsageHistory3rdFillBorrowerExtraEvents(db);

    final uses = await db.select(db.vehicleUses).get();
    expect(uses, hasLength(7));
    expect(uses.every((u) => u.endedAt != null), isTrue);
    expect(
      uses.where((u) => u.fuelCatchUpResponseReceived == true),
      hasLength(1),
    );
    final fuels = await db.select(db.fuelPurchases).get();
    expect(fuels, hasLength(4));
    expect(
      fuels.map((f) => f.id),
      containsAll([
        kQaUsageHistoryFuelPurchase1Id,
        kQaUsageHistoryFuelPurchase2Id,
        kQaUsageHistoryPartial20FuelId,
        kQaUsageHistoryFuelPurchase3Id,
      ]),
    );

    final repo = VehiclesRepository(db);
    expect(
      await repo.latestMeterValue(kQaVehicleSharingActiveVehicleId),
      kQaUsageHistory3rdFillBorrowerFinalMeterTenths,
    );

    final snapshot = await VehicleConsumptionMetrics(db)
        .forVehicle(kQaVehicleSharingActiveVehicleId);
    expect(snapshot.hasSufficientData, isTrue);
    expect(snapshot.reliability, VehicleConsumptionReliability.reliable);
    expect(snapshot.periodsInWindow, 2);
    expect(snapshot.litersPer100Km, closeTo(7.828, 0.01));

    final link = await repo.getSharingLink(kQaVehicleSharingActiveLinkId);
    expect(link, isNotNull);
    expect(link!.acceptedAt!.toUtc(), kQaVehicleSharingActiveLinkAt);
    expect(link.ratePerKmMinor, kQaVehicleSharingActiveRatePerKmMinor);
    final now = DateTime.utc(2026, 8, 5, 12);
    final consumption = await VehicleConsumptionMetrics(db)
        .forVehicle(kQaVehicleSharingActiveVehicleId);
    final purchases = await repo.listFuelPurchases(kQaVehicleSharingActiveVehicleId);
    final useRows = await repo.listUses(kQaVehicleSharingActiveVehicleId);
    final balance = computeVehicleUsageBalance(
      consumption: consumption,
      fuelPurchasesForPrice: purchases.map(
        (p) => UsageBalanceFuelPriceFact(
          costMinor: p.costMinor,
          volumeLiters: p.volumeLiters ?? 0,
          purchasedAt: p.purchasedAt.toUtc(),
        ),
      ),
      useDistances: [
        for (final u in useRows)
          if (u.usageAmount != null && u.usageAmount! > 0)
            UsageBalanceDistanceFact(
              attributedContactId: u.attributedContactId,
              distanceTenths: u.usageAmount!,
              at: (u.endedAt ?? u.startedAt).toUtc(),
            ),
      ],
      gapDistances: const [],
      fuelCostsByBorrower: purchases.map(
        (p) => UsageBalanceCostFact(
          recordedByContactId: p.recordedByContactId,
          costMinor: p.costMinor,
          at: p.purchasedAt.toUtc(),
        ),
      ),
      maintenanceCostsByBorrower: const [],
      borrowerContactId: kVehicleBorrowerSelfContactId,
      ratePerKmMinor: link.ratePerKmMinor,
      windowStart: usageBalanceWindowStart(
        linkCreatedAt: link.createdAt.toUtc(),
        linkAcceptedAt: link.acceptedAt?.toUtc(),
      ),
      windowEnd: now,
    );
    expect(balance.isAvailable, isTrue);
    expect(balance.breakdown!.distanceKm, greaterThan(0));
    expect(balance.breakdown!.borrowerFuelCostMinor, greaterThan(0));
  });
}
