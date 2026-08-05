import '../vehicle_consumption_metrics.dart';
import '../vehicle_consumption_reliability.dart';
import '../../db/repositories/vehicles_repository.dart';

/// Max fuel purchases used for the volume-weighted average price **P**.
const int kUsageBalanceFuelPricePurchaseLimit = 10;

/// Why a numeric usage balance cannot be shown.
enum VehicleUsageBalanceUnavailableReason {
  /// Consumption missing or not [VehicleConsumptionReliability.reliable] / better.
  consumptionNotReliable,

  /// No purchases with positive liters and cost to form **P**.
  noAverageFuelPrice,
}

/// One closed use or gap row contributing distance (stored tenths).
class UsageBalanceDistanceFact {
  const UsageBalanceDistanceFact({
    required this.attributedContactId,
    required this.distanceTenths,
    required this.at,
  });

  final String attributedContactId;
  final int distanceTenths;
  final DateTime at;
}

/// Fuel or maintenance cost row attributed by recorder.
class UsageBalanceCostFact {
  const UsageBalanceCostFact({
    required this.recordedByContactId,
    required this.costMinor,
    required this.at,
  });

  final String recordedByContactId;
  final int costMinor;
  final DateTime at;
}

/// Fuel purchase row used only for average price **P** (vehicle-wide).
class UsageBalanceFuelPriceFact {
  const UsageBalanceFuelPriceFact({
    required this.costMinor,
    required this.volumeLiters,
    required this.purchasedAt,
  });

  final int costMinor;
  final double volumeLiters;
  final DateTime purchasedAt;
}

/// Successful informative balance breakdown (minor currency units).
class VehicleUsageBalanceBreakdown {
  const VehicleUsageBalanceBreakdown({
    required this.litersPer100Km,
    required this.distanceKm,
    required this.pricePerLiterMinor,
    required this.fuelPurchasesInAverage,
    required this.borrowerFuelCostMinor,
    required this.borrowerMaintenanceCostMinor,
    required this.ratePerKmMinor,
    required this.estimatedFuelCostMinor,
    required this.compensationMinor,
    required this.balanceMinor,
    required this.windowStart,
    required this.windowEnd,
    required this.distanceLineItems,
    required this.borrowerFuelLineItems,
    required this.borrowerMaintenanceLineItems,
  });

  /// **C** — L/100 km.
  final double litersPer100Km;

  /// **D** — km (tenths preserved as a double, e.g. 12.3).
  final double distanceKm;

  /// **P** — minor units per litre (volume-weighted).
  final double pricePerLiterMinor;

  final int fuelPurchasesInAverage;

  /// **A**
  final int borrowerFuelCostMinor;

  /// **E**
  final int borrowerMaintenanceCostMinor;

  /// **T** — minor units per km (≥ 0).
  final int ratePerKmMinor;

  /// `(C/100)×D×P` rounded to nearest minor unit.
  final int estimatedFuelCostMinor;

  /// `(D×T)` rounded to nearest minor unit.
  final int compensationMinor;

  /// `estimatedFuelCost − A − E + compensation` (positive ⇒ owed to owner).
  final int balanceMinor;

  final DateTime windowStart;
  final DateTime windowEnd;

  /// Borrower distance rows (uses + attributed gaps) in the window, oldest first.
  final List<UsageBalanceDistanceFact> distanceLineItems;

  /// Borrower fuel purchases in the window, oldest first.
  final List<UsageBalanceCostFact> borrowerFuelLineItems;

  /// Borrower maintenance events in the window, oldest first.
  final List<UsageBalanceCostFact> borrowerMaintenanceLineItems;
}

/// Result of [computeVehicleUsageBalance].
class VehicleUsageBalanceResult {
  const VehicleUsageBalanceResult._({
    this.breakdown,
    this.unavailableReason,
  });

  const VehicleUsageBalanceResult.ok(VehicleUsageBalanceBreakdown breakdown)
      : this._(breakdown: breakdown);

  const VehicleUsageBalanceResult.unavailable(
    VehicleUsageBalanceUnavailableReason reason,
  ) : this._(unavailableReason: reason);

  final VehicleUsageBalanceBreakdown? breakdown;
  final VehicleUsageBalanceUnavailableReason? unavailableReason;

  bool get isAvailable => breakdown != null;
}

/// Running window start: future confirmed payment, else acceptance, else created.
DateTime usageBalanceWindowStart({
  required DateTime linkCreatedAt,
  DateTime? linkAcceptedAt,
  DateTime? lastConfirmedUsagePaymentAt,
}) {
  return lastConfirmedUsagePaymentAt ??
      linkAcceptedAt ??
      linkCreatedAt;
}

/// Volume-weighted average price (minor per litre) from up to
/// [kUsageBalanceFuelPricePurchaseLimit] most recent usable purchases.
({double pricePerLiterMinor, int purchaseCount})? averageFuelPricePerLiterMinor(
  Iterable<UsageBalanceFuelPriceFact> purchases,
) {
  final usable = purchases
      .where((p) => p.volumeLiters > 0)
      .toList()
    ..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
  if (usable.isEmpty) return null;
  final sample = usable.take(kUsageBalanceFuelPricePurchaseLimit).toList();
  var costSum = 0;
  var litersSum = 0.0;
  for (final p in sample) {
    costSum += p.costMinor;
    litersSum += p.volumeLiters;
  }
  if (litersSum <= 0) return null;
  return (pricePerLiterMinor: costSum / litersSum, purchaseCount: sample.length);
}

bool _inWindow(DateTime at, DateTime windowStart, DateTime windowEnd) {
  return !at.isBefore(windowStart) && !at.isAfter(windowEnd);
}

/// Pure usage-balance calculation (no I/O).
///
/// [borrowerContactId] must be the id used on **this device** for that
/// Emprunteur (`Contact.id` on the owner install, or
/// `vehicle:borrower:self` on the borrower install).
VehicleUsageBalanceResult computeVehicleUsageBalance({
  required VehicleConsumptionSnapshot consumption,
  required Iterable<UsageBalanceFuelPriceFact> fuelPurchasesForPrice,
  required Iterable<UsageBalanceDistanceFact> useDistances,
  required Iterable<UsageBalanceDistanceFact> gapDistances,
  required Iterable<UsageBalanceCostFact> fuelCostsByBorrower,
  required Iterable<UsageBalanceCostFact> maintenanceCostsByBorrower,
  required String borrowerContactId,
  required int ratePerKmMinor,
  required DateTime windowStart,
  required DateTime windowEnd,
}) {
  if (!consumption.hasSufficientData ||
      consumption.litersPer100Km == null ||
      !consumptionReliabilityIsReliableOrBetter(consumption.reliability)) {
    return const VehicleUsageBalanceResult.unavailable(
      VehicleUsageBalanceUnavailableReason.consumptionNotReliable,
    );
  }

  final price = averageFuelPricePerLiterMinor(fuelPurchasesForPrice);
  if (price == null) {
    return const VehicleUsageBalanceResult.unavailable(
      VehicleUsageBalanceUnavailableReason.noAverageFuelPrice,
    );
  }

  final rate = ratePerKmMinor < 0 ? 0 : ratePerKmMinor;
  var distanceTenths = 0;
  final distanceLineItems = <UsageBalanceDistanceFact>[];

  for (final use in useDistances) {
    if (use.attributedContactId != borrowerContactId) continue;
    if (!_inWindow(use.at, windowStart, windowEnd)) continue;
    if (use.distanceTenths > 0) {
      distanceTenths += use.distanceTenths;
      distanceLineItems.add(use);
    }
  }

  for (final gap in gapDistances) {
    if (gap.attributedContactId == kVehicleGapAttributionUnknown) continue;
    if (gap.attributedContactId == 'split') continue;
    if (gap.attributedContactId != borrowerContactId) continue;
    if (!_inWindow(gap.at, windowStart, windowEnd)) continue;
    if (gap.distanceTenths > 0) {
      distanceTenths += gap.distanceTenths;
      distanceLineItems.add(gap);
    }
  }
  distanceLineItems.sort((a, b) => a.at.compareTo(b.at));

  final distanceKm = distanceTenths / 10.0;

  var aMinor = 0;
  final fuelLineItems = <UsageBalanceCostFact>[];
  for (final row in fuelCostsByBorrower) {
    if (row.recordedByContactId != borrowerContactId) continue;
    if (!_inWindow(row.at, windowStart, windowEnd)) continue;
    aMinor += row.costMinor;
    fuelLineItems.add(row);
  }
  fuelLineItems.sort((a, b) => a.at.compareTo(b.at));

  var eMinor = 0;
  final maintenanceLineItems = <UsageBalanceCostFact>[];
  for (final row in maintenanceCostsByBorrower) {
    if (row.recordedByContactId != borrowerContactId) continue;
    if (!_inWindow(row.at, windowStart, windowEnd)) continue;
    eMinor += row.costMinor;
    maintenanceLineItems.add(row);
  }
  maintenanceLineItems.sort((a, b) => a.at.compareTo(b.at));

  final c = consumption.litersPer100Km!;
  final litersConsumed = (c / 100.0) * distanceKm;
  final estimatedFuelCostMinor =
      (litersConsumed * price.pricePerLiterMinor).round();
  final compensationMinor = (distanceKm * rate).round();
  final balanceMinor =
      estimatedFuelCostMinor - aMinor - eMinor + compensationMinor;

  return VehicleUsageBalanceResult.ok(
    VehicleUsageBalanceBreakdown(
      litersPer100Km: c,
      distanceKm: distanceKm,
      pricePerLiterMinor: price.pricePerLiterMinor,
      fuelPurchasesInAverage: price.purchaseCount,
      borrowerFuelCostMinor: aMinor,
      borrowerMaintenanceCostMinor: eMinor,
      ratePerKmMinor: rate,
      estimatedFuelCostMinor: estimatedFuelCostMinor,
      compensationMinor: compensationMinor,
      balanceMinor: balanceMinor,
      windowStart: windowStart,
      windowEnd: windowEnd,
      distanceLineItems: distanceLineItems,
      borrowerFuelLineItems: fuelLineItems,
      borrowerMaintenanceLineItems: maintenanceLineItems,
    ),
  );
}
