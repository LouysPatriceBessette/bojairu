import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../vehicle_consumption_metrics.dart';
import 'vehicle_usage_balance.dart';

/// Loads vehicle facts and computes [computeVehicleUsageBalance].
class VehicleUsageBalanceService {
  VehicleUsageBalanceService(this._repo);

  final VehiclesRepository _repo;

  Future<VehicleUsageBalanceResult> computeForLink({
    required VehicleSharingLink link,
    DateTime? lastConfirmedUsagePaymentAt,
    DateTime? now,
  }) async {
    final windowEnd = now ?? DateTime.now().toUtc();
    final freezeAt = lastConfirmedUsagePaymentAt?.toUtc() ??
        await _repo.latestConfirmedFreezeAt(link.id);
    final windowStart = usageBalanceWindowStart(
      linkCreatedAt: link.createdAt.toUtc(),
      linkAcceptedAt: link.acceptedAt?.toUtc(),
      lastConfirmedUsagePaymentAt: freezeAt,
    );

    final consumption = await VehicleConsumptionMetrics(AppDatabase.processScope)
        .forVehicle(link.vehicleId);
    final purchases = await _repo.listFuelPurchases(link.vehicleId);
    final maintenance = await _repo.listMaintenanceEvents(link.vehicleId);
    final uses = await _repo.listUses(link.vehicleId);
    final gaps = await _repo.listOdometerGaps(link.vehicleId);

    final priceFacts = purchases.map(
      (p) => UsageBalanceFuelPriceFact(
        costMinor: p.costMinor,
        volumeLiters: p.volumeLiters ?? 0,
        purchasedAt: p.purchasedAt.toUtc(),
      ),
    );

    final useDistances = <UsageBalanceDistanceFact>[];
    for (final use in uses) {
      final amount = use.usageAmount;
      if (amount == null || amount <= 0) continue;
      final at = (use.endedAt ?? use.startedAt).toUtc();
      useDistances.add(
        UsageBalanceDistanceFact(
          attributedContactId: use.attributedContactId,
          distanceTenths: amount,
          at: at,
        ),
      );
    }

    final gapDistances = gaps.map(
      (g) => UsageBalanceDistanceFact(
        attributedContactId: g.attributedContactId,
        distanceTenths: g.gapAmount,
        at: g.recordedAt.toUtc(),
      ),
    );

    final fuelCosts = purchases.map(
      (p) => UsageBalanceCostFact(
        recordedByContactId: p.recordedByContactId,
        costMinor: p.costMinor,
        at: p.purchasedAt.toUtc(),
      ),
    );

    final maintenanceCosts = maintenance.map(
      (m) => UsageBalanceCostFact(
        recordedByContactId: m.recordedByContactId,
        costMinor: m.costMinor,
        at: m.servicedAt.toUtc(),
      ),
    );

    return computeVehicleUsageBalance(
      consumption: consumption,
      fuelPurchasesForPrice: priceFacts,
      useDistances: useDistances,
      gapDistances: gapDistances,
      fuelCostsByBorrower: fuelCosts,
      maintenanceCostsByBorrower: maintenanceCosts,
      borrowerContactId: link.borrowerContactId,
      ratePerKmMinor: link.ratePerKmMinor,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }
}
