import 'package:compartarenta/vehicle/sharing/vehicle_usage_balance.dart';
import 'package:compartarenta/vehicle/vehicle_consumption_metrics.dart';
import 'package:compartarenta/vehicle/vehicle_consumption_reliability.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleConsumptionSnapshot _consumption({
  required VehicleConsumptionReliability reliability,
  double litersPer100Km = 8.0,
  bool hasSufficientData = true,
}) {
  return VehicleConsumptionSnapshot(
    hasSufficientData: hasSufficientData,
    reliability: reliability,
    litersPer100Km: hasSufficientData ? litersPer100Km : null,
  );
}

void main() {
  final windowStart = DateTime.utc(2026, 1, 1);
  final windowEnd = DateTime.utc(2026, 6, 1);
  const borrower = 'contact:borrower-1';

  UsageBalanceFuelPriceFact fuelPrice({
    required int costMinor,
    required double liters,
    required DateTime at,
  }) =>
      UsageBalanceFuelPriceFact(
        costMinor: costMinor,
        volumeLiters: liters,
        purchasedAt: at,
      );

  test('unavailable when consumption not reliable', () {
    final result = computeVehicleUsageBalance(
      consumption: _consumption(
        reliability: VehicleConsumptionReliability.preliminary,
      ),
      fuelPurchasesForPrice: [
        fuelPrice(
          costMinor: 10000,
          liters: 50,
          at: DateTime.utc(2026, 5, 1),
        ),
      ],
      useDistances: const [],
      gapDistances: const [],
      fuelCostsByBorrower: const [],
      maintenanceCostsByBorrower: const [],
      borrowerContactId: borrower,
      ratePerKmMinor: 25,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    expect(result.isAvailable, isFalse);
    expect(
      result.unavailableReason,
      VehicleUsageBalanceUnavailableReason.consumptionNotReliable,
    );
  });

  test('unavailable when no usable fuel purchases for P', () {
    final result = computeVehicleUsageBalance(
      consumption: _consumption(
        reliability: VehicleConsumptionReliability.reliable,
      ),
      fuelPurchasesForPrice: [
        fuelPrice(
          costMinor: 10000,
          liters: 0,
          at: DateTime.utc(2026, 5, 1),
        ),
      ],
      useDistances: const [],
      gapDistances: const [],
      fuelCostsByBorrower: const [],
      maintenanceCostsByBorrower: const [],
      borrowerContactId: borrower,
      ratePerKmMinor: 25,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    expect(result.isAvailable, isFalse);
    expect(
      result.unavailableReason,
      VehicleUsageBalanceUnavailableReason.noAverageFuelPrice,
    );
  });

  test('T=0 yields zero compensation; positive balance from fuel estimate', () {
    // C=10 L/100, D=100 km → 10 L; P=200 minor/L → estimated 2000 minor
    final result = computeVehicleUsageBalance(
      consumption: _consumption(
        reliability: VehicleConsumptionReliability.reliable,
        litersPer100Km: 10,
      ),
      fuelPurchasesForPrice: [
        fuelPrice(
          costMinor: 10000,
          liters: 50,
          at: DateTime.utc(2026, 5, 1),
        ),
      ],
      useDistances: [
        UsageBalanceDistanceFact(
          attributedContactId: borrower,
          distanceTenths: 1000, // 100.0 km
          at: DateTime.utc(2026, 3, 1),
        ),
      ],
      gapDistances: const [],
      fuelCostsByBorrower: const [],
      maintenanceCostsByBorrower: const [],
      borrowerContactId: borrower,
      ratePerKmMinor: 0,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    expect(result.isAvailable, isTrue);
    final b = result.breakdown!;
    expect(b.compensationMinor, 0);
    expect(b.estimatedFuelCostMinor, 2000);
    expect(b.balanceMinor, 2000);
    expect(b.pricePerLiterMinor, 200.0);
  });

  test('subtracts A and E; adds D×T; preserves tenths on D', () {
    // D = 12.3 km (123 tenths); C=10; P=200 minor/L
    // liters = 1.23; fuel est = round(246) = 246
    // T = 25 minor/km → compensation = round(307.5) = 308
    // A=100, E=50 → balance = 246 - 100 - 50 + 308 = 404
    final result = computeVehicleUsageBalance(
      consumption: _consumption(
        reliability: VehicleConsumptionReliability.veryReliable,
        litersPer100Km: 10,
      ),
      fuelPurchasesForPrice: [
        fuelPrice(
          costMinor: 10000,
          liters: 50,
          at: DateTime.utc(2026, 5, 1),
        ),
      ],
      useDistances: [
        UsageBalanceDistanceFact(
          attributedContactId: borrower,
          distanceTenths: 123,
          at: DateTime.utc(2026, 3, 1),
        ),
      ],
      gapDistances: const [],
      fuelCostsByBorrower: [
        UsageBalanceCostFact(
          recordedByContactId: borrower,
          costMinor: 100,
          at: DateTime.utc(2026, 3, 2),
        ),
      ],
      maintenanceCostsByBorrower: [
        UsageBalanceCostFact(
          recordedByContactId: borrower,
          costMinor: 50,
          at: DateTime.utc(2026, 3, 3),
        ),
      ],
      borrowerContactId: borrower,
      ratePerKmMinor: 25,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    final b = result.breakdown!;
    expect(b.distanceKm, 12.3);
    expect(b.estimatedFuelCostMinor, 246);
    expect(b.compensationMinor, 308);
    expect(b.borrowerFuelCostMinor, 100);
    expect(b.borrowerMaintenanceCostMinor, 50);
    expect(b.balanceMinor, 404);
    expect(b.distanceLineItems, hasLength(1));
    expect(b.distanceLineItems.single.distanceTenths, 123);
    expect(b.borrowerFuelLineItems, hasLength(1));
    expect(b.borrowerFuelLineItems.single.costMinor, 100);
    expect(b.borrowerMaintenanceLineItems, hasLength(1));
    expect(b.borrowerMaintenanceLineItems.single.costMinor, 50);
  });

  test('excludes unknown and split gaps; ignores other borrowers', () {
    final result = computeVehicleUsageBalance(
      consumption: _consumption(
        reliability: VehicleConsumptionReliability.reliable,
        litersPer100Km: 10,
      ),
      fuelPurchasesForPrice: [
        fuelPrice(
          costMinor: 10000,
          liters: 50,
          at: DateTime.utc(2026, 5, 1),
        ),
      ],
      useDistances: [
        UsageBalanceDistanceFact(
          attributedContactId: 'other',
          distanceTenths: 5000,
          at: DateTime.utc(2026, 3, 1),
        ),
      ],
      gapDistances: [
        UsageBalanceDistanceFact(
          attributedContactId: kVehicleGapAttributionUnknown,
          distanceTenths: 200,
          at: DateTime.utc(2026, 3, 1),
        ),
        UsageBalanceDistanceFact(
          attributedContactId: 'split',
          distanceTenths: 300,
          at: DateTime.utc(2026, 3, 1),
        ),
        UsageBalanceDistanceFact(
          attributedContactId: borrower,
          distanceTenths: 100, // 10 km
          at: DateTime.utc(2026, 3, 1),
        ),
      ],
      fuelCostsByBorrower: const [],
      maintenanceCostsByBorrower: const [],
      borrowerContactId: borrower,
      ratePerKmMinor: 0,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    expect(result.breakdown!.distanceKm, 10.0);
  });

  test('negative balance when borrower payments exceed estimate', () {
    final result = computeVehicleUsageBalance(
      consumption: _consumption(
        reliability: VehicleConsumptionReliability.reliable,
        litersPer100Km: 10,
      ),
      fuelPurchasesForPrice: [
        fuelPrice(
          costMinor: 10000,
          liters: 50,
          at: DateTime.utc(2026, 5, 1),
        ),
      ],
      useDistances: [
        UsageBalanceDistanceFact(
          attributedContactId: borrower,
          distanceTenths: 100, // 10 km → 1 L → 200 minor
          at: DateTime.utc(2026, 3, 1),
        ),
      ],
      gapDistances: const [],
      fuelCostsByBorrower: [
        UsageBalanceCostFact(
          recordedByContactId: borrower,
          costMinor: 5000,
          at: DateTime.utc(2026, 3, 2),
        ),
      ],
      maintenanceCostsByBorrower: const [],
      borrowerContactId: borrower,
      ratePerKmMinor: 0,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    expect(result.breakdown!.balanceMinor, lessThan(0));
    expect(result.breakdown!.balanceMinor, 200 - 5000);
  });

  test('P uses at most 10 most recent usable purchases (volume-weighted)', () {
    final purchases = <UsageBalanceFuelPriceFact>[];
    for (var i = 0; i < 12; i++) {
      purchases.add(
        fuelPrice(
          costMinor: 1000 + i,
          liters: 10,
          at: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
        ),
      );
    }
    // Most recent 10: days 2..11 → cost sum = 1002+...+1011 = 10065; liters=100
    final avg = averageFuelPricePerLiterMinor(purchases)!;
    expect(avg.purchaseCount, 10);
    expect(avg.pricePerLiterMinor, closeTo(100.65, 0.0001));
  });

  test('windowStart prefers payment then acceptedAt then createdAt', () {
    final created = DateTime.utc(2026, 1, 1);
    final accepted = DateTime.utc(2026, 2, 1);
    final paid = DateTime.utc(2026, 3, 1);
    expect(
      usageBalanceWindowStart(
        linkCreatedAt: created,
        linkAcceptedAt: accepted,
        lastConfirmedUsagePaymentAt: paid,
      ),
      paid,
    );
    expect(
      usageBalanceWindowStart(
        linkCreatedAt: created,
        linkAcceptedAt: accepted,
      ),
      accepted,
    );
    expect(
      usageBalanceWindowStart(linkCreatedAt: created),
      created,
    );
  });

  test('facts outside window are excluded', () {
    final result = computeVehicleUsageBalance(
      consumption: _consumption(
        reliability: VehicleConsumptionReliability.reliable,
        litersPer100Km: 10,
      ),
      fuelPurchasesForPrice: [
        fuelPrice(
          costMinor: 10000,
          liters: 50,
          at: DateTime.utc(2026, 5, 1),
        ),
      ],
      useDistances: [
        UsageBalanceDistanceFact(
          attributedContactId: borrower,
          distanceTenths: 1000,
          at: DateTime.utc(2025, 12, 1), // before window
        ),
      ],
      gapDistances: const [],
      fuelCostsByBorrower: [
        UsageBalanceCostFact(
          recordedByContactId: borrower,
          costMinor: 999,
          at: DateTime.utc(2025, 12, 2),
        ),
      ],
      maintenanceCostsByBorrower: const [],
      borrowerContactId: borrower,
      ratePerKmMinor: 25,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    expect(result.breakdown!.distanceKm, 0);
    expect(result.breakdown!.borrowerFuelCostMinor, 0);
    expect(result.breakdown!.balanceMinor, 0);
  });
}
