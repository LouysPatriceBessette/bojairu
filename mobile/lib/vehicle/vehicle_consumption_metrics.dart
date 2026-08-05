import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/repositories/vehicles_repository.dart';
import 'vehicle_consumption_estimation_mode.dart';
import 'vehicle_consumption_mode_policy.dart';
import 'vehicle_consumption_reliability.dart';
import 'vehicle_driving_condition_consumption.dart';
import 'vehicle_kind.dart';

/// One plein→plein interval used in consumption calculations.
class FullTankConsumptionInterval {
  const FullTankConsumptionInterval({
    required this.startAt,
    required this.endAt,
    required this.distanceTenths,
    required this.fuelLiters,
    required this.routeKm,
    required this.cityKm,
    required this.trafficKm,
    required this.homogeneousMode,
  });

  final DateTime startAt;
  final DateTime endAt;
  final int distanceTenths;
  final double fuelLiters;
  final double routeKm;
  final double cityKm;
  final double trafficKm;
  final VehicleConsumptionEstimationMode? homogeneousMode;

  bool get hasDrivingMix => routeKm + cityKm + trafficKm > 0;

  bool get matchesDetailedMode =>
      homogeneousMode == VehicleConsumptionEstimationMode.detailed;

  bool get matchesSimpleMode =>
      homogeneousMode == VehicleConsumptionEstimationMode.simple;

  DrivingConditionConsumptionInput? get modeInput {
    if (!hasDrivingMix) return null;
    return DrivingConditionConsumptionInput(
      routeKm: routeKm,
      cityKm: cityKm,
      trafficKm: trafficKm,
      fuelLiters: fuelLiters,
    );
  }
}

/// Derived consumption metrics from stored fuel facts (not authoritative).
class VehicleConsumptionSnapshot {
  const VehicleConsumptionSnapshot({
    required this.hasSufficientData,
    this.reliability = VehicleConsumptionReliability.none,
    this.periodsInWindow = 0,
    this.litersPer100Km,
    this.litersPerHour,
    this.litersPer100KmRoute,
    this.litersPer100KmCity,
    this.litersPer100KmTraffic,
    this.hasModeBreakdown = false,
    this.anchorStartAt,
    this.anchorEndAt,
    this.distanceInWindow,
    this.volumeInWindow,
    this.showInsufficientDetailedDataMessage = false,
    this.isCarriedFromOtherMode = false,
  });

  final bool hasSufficientData;
  final VehicleConsumptionReliability reliability;
  final int periodsInWindow;
  final double? litersPer100Km;
  final double? litersPerHour;
  final double? litersPer100KmRoute;
  final double? litersPer100KmCity;
  final double? litersPer100KmTraffic;
  final bool hasModeBreakdown;
  final DateTime? anchorStartAt;
  final DateTime? anchorEndAt;
  final int? distanceInWindow;
  final double? volumeInWindow;
  final bool showInsufficientDetailedDataMessage;
  final bool isCarriedFromOtherMode;
}

class VehicleConsumptionMetrics {
  VehicleConsumptionMetrics(this._db);

  final AppDatabase _db;

  Future<VehicleConsumptionSnapshot> forVehicle(String vehicleId) async {
    final vehicle = await (_db.select(_db.vehicles)
          ..where((t) => t.id.equals(vehicleId)))
        .getSingleOrNull();
    if (vehicle == null) {
      return const VehicleConsumptionSnapshot(hasSufficientData: false);
    }
    final kind = VehicleKind.fromWire(vehicle.vehicleKind);
    if (kind?.usesHorometer ?? false) {
      return _forHorometerVehicle(vehicleId);
    }
    final snapshot = await _forRoadVehicle(vehicle);
    await _maybeRecordReliableHistory(vehicleId: vehicleId, snapshot: snapshot);
    return snapshot;
  }

  Future<List<VehicleConsumptionEstimateHistoryData>>
      listReliableEstimateHistory(
    String vehicleId,
  ) {
    return (_db.select(_db.vehicleConsumptionEstimateHistory)
          ..where((t) => t.vehicleId.equals(vehicleId))
          ..orderBy([(t) => OrderingTerm.desc(t.anchorEndAt)]))
        .get();
  }

  Future<VehicleConsumptionSnapshot> _forHorometerVehicle(
    String vehicleId,
  ) async {
    final anchors = await _fullTankAnchorsNewestFirst(vehicleId);
    if (anchors.length < 2) {
      return const VehicleConsumptionSnapshot(hasSufficientData: false);
    }
    final newest = anchors[0];
    final previous = anchors[1];
    final endMeter = newest.meterReadingValue;
    final startMeter = previous.meterReadingValue;
    if (endMeter == null || startMeter == null || endMeter <= startMeter) {
      return VehicleConsumptionSnapshot(
        hasSufficientData: false,
        anchorStartAt: previous.purchasedAt,
        anchorEndAt: newest.purchasedAt,
      );
    }
    final delta = endMeter - startMeter;
    final allPurchases = await (_db.select(_db.fuelPurchases)
          ..where((t) => t.vehicleId.equals(vehicleId)))
        .get();
    final vol = _fuelLitersBetweenFullTankAnchors(
      allPurchases,
      start: previous,
      end: newest,
    );
    if (vol <= 0 || delta <= 0) {
      return VehicleConsumptionSnapshot(
        hasSufficientData: false,
        anchorStartAt: previous.purchasedAt,
        anchorEndAt: newest.purchasedAt,
      );
    }
    final hours = delta / 10.0;
    if (hours <= 0) {
      return const VehicleConsumptionSnapshot(hasSufficientData: false);
    }
    return VehicleConsumptionSnapshot(
      hasSufficientData: true,
      litersPerHour: vol / hours,
      anchorStartAt: previous.purchasedAt,
      anchorEndAt: newest.purchasedAt,
      distanceInWindow: delta,
      volumeInWindow: vol,
    );
  }

  Future<VehicleConsumptionSnapshot> _forRoadVehicle(Vehicle vehicle) async {
    final vehicleId = vehicle.id;
    final estimationMode = VehicleConsumptionEstimationMode.fromWire(
      vehicle.consumptionEstimationMode,
    );
    final anchors = await _fullTankAnchorsNewestFirst(vehicleId);
    final allIntervals =
        await _buildFullTankIntervals(vehicleId, anchors, estimationMode);
    if (allIntervals.isEmpty) {
      return const VehicleConsumptionSnapshot(hasSufficientData: false);
    }

    final modeIntervals = allIntervals
        .where(
          (i) =>
              i.homogeneousMode != null && i.homogeneousMode == estimationMode,
        )
        .toList();

    if (estimationMode == VehicleConsumptionEstimationMode.simple) {
      return _simpleModeSnapshot(
        vehicleId: vehicleId,
        modeIntervals: modeIntervals,
      );
    }
    return _detailedModeSnapshot(
      vehicleId: vehicleId,
      modeIntervals: modeIntervals,
      allIntervals: allIntervals,
    );
  }

  Future<VehicleConsumptionSnapshot> _simpleModeSnapshot({
    required String vehicleId,
    required List<FullTankConsumptionInterval> modeIntervals,
  }) async {
    final window = _rollingConsumptionWindow(modeIntervals);
    final periodsInWindow = window.length;
    final reliability = consumptionReliabilityFromPeriodCount(periodsInWindow);

    if (reliability == VehicleConsumptionReliability.none) {
      final carryover = await _averageReliableHistoryBlended(vehicleId);
      if (carryover != null) {
        return VehicleConsumptionSnapshot(
          hasSufficientData: true,
          reliability: VehicleConsumptionReliability.preliminary,
          litersPer100Km: carryover,
          isCarriedFromOtherMode: true,
        );
      }
      return VehicleConsumptionSnapshot(
        hasSufficientData: false,
        reliability: reliability,
        periodsInWindow: periodsInWindow,
        anchorStartAt: window.firstOrNull?.startAt,
        anchorEndAt: window.lastOrNull?.endAt,
      );
    }

    final blended = _blendedLitersPer100Km(window);
    if (blended == null) {
      return VehicleConsumptionSnapshot(
        hasSufficientData: false,
        reliability: reliability,
        periodsInWindow: periodsInWindow,
        anchorStartAt: window.firstOrNull?.startAt,
        anchorEndAt: window.lastOrNull?.endAt,
      );
    }

    return VehicleConsumptionSnapshot(
      hasSufficientData: true,
      reliability: reliability,
      periodsInWindow: periodsInWindow,
      litersPer100Km: blended,
      anchorStartAt: window.first.startAt,
      anchorEndAt: window.last.endAt,
      distanceInWindow: _totalDistanceTenths(window),
      volumeInWindow: _totalFuel(window),
    );
  }

  Future<VehicleConsumptionSnapshot> _detailedModeSnapshot({
    required String vehicleId,
    required List<FullTankConsumptionInterval> modeIntervals,
    required List<FullTankConsumptionInterval> allIntervals,
  }) async {
    final window = _rollingConsumptionWindow(modeIntervals);
    final periodsInWindow = window.length;
    final reliability = consumptionReliabilityFromPeriodCount(periodsInWindow);

    final modeFitIntervals = window
        .map((i) => i.modeInput)
        .whereType<DrivingConditionConsumptionInput>()
        .toList();
    final modeFit = modeFitIntervals.length >=
            kMinFullTankIntervalsForDrivingConditionConsumption
        ? solveDrivingConditionConsumption(modeFitIntervals)
        : null;

    if (reliability != VehicleConsumptionReliability.none && modeFit != null) {
      var totalRoute = 0.0;
      var totalCity = 0.0;
      var totalTraffic = 0.0;
      for (final interval in modeFitIntervals) {
        totalRoute += interval.routeKm;
        totalCity += interval.cityKm;
        totalTraffic += interval.trafficKm;
      }

      return VehicleConsumptionSnapshot(
        hasSufficientData: true,
        reliability: reliability,
        periodsInWindow: periodsInWindow,
        litersPer100Km: modeFit.blendedLitersPer100Km(
          totalRouteKm: totalRoute,
          totalCityKm: totalCity,
          totalTrafficKm: totalTraffic,
        ),
        litersPer100KmRoute: modeFit.litersPer100KmRoute,
        litersPer100KmCity: modeFit.litersPer100KmCity,
        litersPer100KmTraffic: modeFit.litersPer100KmTraffic,
        hasModeBreakdown: true,
        anchorStartAt: window.first.startAt,
        anchorEndAt: window.last.endAt,
        distanceInWindow: _totalDistanceTenths(window),
        volumeInWindow: _totalFuel(window),
      );
    }

    if (reliability != VehicleConsumptionReliability.none) {
      final blended = _blendedLitersPer100Km(window);
      if (blended != null) {
        return VehicleConsumptionSnapshot(
          hasSufficientData: true,
          reliability: reliability,
          periodsInWindow: periodsInWindow,
          litersPer100Km: blended,
          showInsufficientDetailedDataMessage: true,
          anchorStartAt: window.first.startAt,
          anchorEndAt: window.last.endAt,
          distanceInWindow: _totalDistanceTenths(window),
          volumeInWindow: _totalFuel(window),
        );
      }
    }

    final simpleIntervals = allIntervals.where((i) => i.matchesSimpleMode).toList();
    final simpleWindow = _rollingConsumptionWindow(simpleIntervals);
    final simpleBlended = _blendedLitersPer100Km(simpleWindow);
    if (simpleBlended != null) {
      return VehicleConsumptionSnapshot(
        hasSufficientData: true,
        reliability: consumptionReliabilityFromPeriodCount(simpleWindow.length),
        periodsInWindow: periodsInWindow,
        litersPer100Km: simpleBlended,
        showInsufficientDetailedDataMessage: true,
        anchorStartAt: simpleWindow.firstOrNull?.startAt,
        anchorEndAt: simpleWindow.lastOrNull?.endAt,
        distanceInWindow: _totalDistanceTenths(simpleWindow),
        volumeInWindow: _totalFuel(simpleWindow),
      );
    }

    return VehicleConsumptionSnapshot(
      hasSufficientData: false,
      reliability: reliability,
      periodsInWindow: periodsInWindow,
      anchorStartAt: window.firstOrNull?.startAt,
      anchorEndAt: window.lastOrNull?.endAt,
    );
  }

  double? _blendedLitersPer100Km(List<FullTankConsumptionInterval> window) {
    if (window.isEmpty) return null;
    var totalDistanceTenths = 0;
    var totalFuel = 0.0;
    for (final interval in window) {
      totalDistanceTenths += interval.distanceTenths;
      totalFuel += interval.fuelLiters;
    }
    if (totalDistanceTenths <= 0 || totalFuel <= 0) return null;
    return (totalFuel / totalDistanceTenths) * 1000;
  }

  int _totalDistanceTenths(List<FullTankConsumptionInterval> window) {
    var total = 0;
    for (final interval in window) {
      total += interval.distanceTenths;
    }
    return total;
  }

  double _totalFuel(List<FullTankConsumptionInterval> window) {
    var total = 0.0;
    for (final interval in window) {
      total += interval.fuelLiters;
    }
    return total;
  }

  Future<double?> _averageReliableHistoryBlended(String vehicleId) async {
    final history = await listReliableEstimateHistory(vehicleId);
    final values = <double>[];
    for (final row in history) {
      final reliability =
          VehicleConsumptionReliability.fromWire(row.reliability);
      if (reliability == null ||
          !consumptionReliabilityIsReliableOrBetter(reliability)) {
        continue;
      }
      values.add(row.litersPer100Km);
    }
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<FullTankConsumptionInterval> _rollingConsumptionWindow(
    List<FullTankConsumptionInterval> chronological,
  ) {
    if (chronological.length <= kMaxFullTankIntervalsInConsumptionWindow) {
      return chronological;
    }
    return chronological.sublist(
      chronological.length - kMaxFullTankIntervalsInConsumptionWindow,
    );
  }

  Future<void> _maybeRecordReliableHistory({
    required String vehicleId,
    required VehicleConsumptionSnapshot snapshot,
  }) async {
    if (snapshot.isCarriedFromOtherMode) return;
    if (!consumptionReliabilityIsReliableOrBetter(snapshot.reliability)) {
      return;
    }
    final anchorEnd = snapshot.anchorEndAt;
    final blended = snapshot.litersPer100Km;
    if (anchorEnd == null || blended == null) return;

    final existing = await (_db.select(_db.vehicleConsumptionEstimateHistory)
          ..where(
            (t) =>
                t.vehicleId.equals(vehicleId) &
                t.anchorEndAt.equals(anchorEnd),
          ))
        .getSingleOrNull();
    if (existing != null) return;

    await _db.into(_db.vehicleConsumptionEstimateHistory).insert(
          VehicleConsumptionEstimateHistoryCompanion.insert(
            id: _newConsumptionHistoryId(),
            vehicleId: vehicleId,
            anchorEndAt: anchorEnd,
            recordedAt: DateTime.now().toUtc(),
            reliability: snapshot.reliability.wire,
            litersPer100Km: blended,
            litersPer100KmRoute: Value(snapshot.litersPer100KmRoute),
            litersPer100KmCity: Value(snapshot.litersPer100KmCity),
            litersPer100KmTraffic: Value(snapshot.litersPer100KmTraffic),
            periodsInWindow: snapshot.periodsInWindow,
          ),
        );
  }

  Future<List<FuelPurchase>> _fullTankAnchorsNewestFirst(
    String vehicleId,
  ) {
    return (_db.select(_db.fuelPurchases)
          ..where(
            (t) => t.vehicleId.equals(vehicleId) & t.isFullTank.equals(true),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.purchasedAt)]))
        .get();
  }

  VehicleConsumptionEstimationMode? _homogeneousModeForUses(
    List<VehicleUse> uses,
    VehicleConsumptionEstimationMode vehicleMode,
  ) {
    if (uses.isEmpty) {
      return vehicleMode;
    }
    final modes = uses.map(effectiveSessionConsumptionMode).toSet();
    if (modes.length != 1) return null;
    return modes.first;
  }

  Future<List<FullTankConsumptionInterval>> _buildFullTankIntervals(
    String vehicleId,
    List<FuelPurchase> anchorsNewestFirst,
    VehicleConsumptionEstimationMode vehicleMode,
  ) async {
    if (anchorsNewestFirst.length < 2) return const [];

    final chronological = anchorsNewestFirst.reversed.toList();
    final uses = await (_db.select(_db.vehicleUses)
          ..where(
            (t) => t.vehicleId.equals(vehicleId) & t.endedAt.isNotNull(),
          ))
        .get();
    final allPurchases = await (_db.select(_db.fuelPurchases)
          ..where((t) => t.vehicleId.equals(vehicleId)))
        .get();

    final intervals = <FullTankConsumptionInterval>[];
    for (var i = 1; i < chronological.length; i++) {
      final start = chronological[i - 1];
      final end = chronological[i];
      final endMeter = end.meterReadingValue;
      final startMeter = start.meterReadingValue;
      if (endMeter == null ||
          startMeter == null ||
          endMeter <= startMeter) {
        continue;
      }

      // Liters put in after the opening plein through (and including) the
      // closing plein — partial top-ups between anchors count.
      final vol = _fuelLitersBetweenFullTankAnchors(
        allPurchases,
        start: start,
        end: end,
      );
      if (vol <= 0) {
        continue;
      }

      final windowUses = uses.where((u) {
        final ended = u.endedAt;
        if (ended == null) return false;
        return !ended.isBefore(start.purchasedAt) &&
            !ended.isAfter(end.purchasedAt);
      }).toList();

      var routeKm = 0.0;
      var cityKm = 0.0;
      var trafficKm = 0.0;
      for (final use in windowUses) {
        final amount = use.usageAmount;
        final routePct = use.drivingRoutePercent;
        final cityPct = use.drivingCityPercent;
        final trafficPct = use.drivingTrafficPercent;
        if (amount == null ||
            routePct == null ||
            cityPct == null ||
            trafficPct == null) {
          continue;
        }
        if (!drivingMixPercentsValid(routePct, cityPct, trafficPct)) {
          continue;
        }
        routeKm += modeKmFromSession(
          usageAmountTenths: amount,
          percent: routePct,
        );
        cityKm += modeKmFromSession(
          usageAmountTenths: amount,
          percent: cityPct,
        );
        trafficKm += modeKmFromSession(
          usageAmountTenths: amount,
          percent: trafficPct,
        );
      }

      intervals.add(
        FullTankConsumptionInterval(
          startAt: start.purchasedAt,
          endAt: end.purchasedAt,
          distanceTenths: endMeter - startMeter,
          fuelLiters: vol,
          routeKm: routeKm,
          cityKm: cityKm,
          trafficKm: trafficKm,
          homogeneousMode: _homogeneousModeForUses(windowUses, vehicleMode),
        ),
      );
    }
    return intervals;
  }

  /// Sum of purchase volumes strictly after [start] through [end] inclusive.
  ///
  /// Prefers meter order when both purchases have meters; otherwise
  /// [purchasedAt]. The opening plein volume is excluded; closing plein and
  /// any partial top-ups in between are included.
  double _fuelLitersBetweenFullTankAnchors(
    List<FuelPurchase> purchases, {
    required FuelPurchase start,
    required FuelPurchase end,
  }) {
    var total = 0.0;
    final startMeter = start.meterReadingValue;
    final endMeter = end.meterReadingValue;
    final useMeters = startMeter != null && endMeter != null;

    for (final purchase in purchases) {
      final volume = purchase.volumeLiters;
      if (volume == null || volume <= 0) continue;

      if (useMeters) {
        final meter = purchase.meterReadingValue;
        if (meter == null) continue;
        if (meter <= startMeter || meter > endMeter) continue;
      } else {
        if (!purchase.purchasedAt.isAfter(start.purchasedAt) ||
            purchase.purchasedAt.isAfter(end.purchasedAt)) {
          continue;
        }
      }
      total += volume;
    }
    return total;
  }

  Future<int> totalLifetimeUsage(String vehicleId) async {
    final repo = VehiclesRepository(_db);
    final latest = await repo.latestMeterAnchor(vehicleId);
    final earliest = await repo.earliestMeterAnchor(vehicleId);
    if (latest != null && earliest != null) {
      final delta = latest.value - earliest.value;
      if (delta > 0) return delta;
    }

    final uses = await (_db.select(_db.vehicleUses)
          ..where((t) => t.vehicleId.equals(vehicleId)))
        .get();
    var total = 0;
    for (final u in uses) {
      total += u.usageAmount ?? 0;
    }
    return total;
  }
}

String _newConsumptionHistoryId() {
  final bytes = List<int>.generate(12, (_) => Random.secure().nextInt(256));
  return 'consumption_hist:${base64Url.encode(bytes).replaceAll('=', '')}';
}
