import 'dart:math';

import 'vehicle_consumption_metrics.dart';

/// Default guard when no city/route/traffic consumption is known: 7.5 L/100 km.
const double kDefaultOdometerGapGuardLitersPer100Km = 7.5;

/// Highest known city/route/traffic consumption, or [kDefaultOdometerGapGuardLitersPer100Km].
double guardConsumptionLitersPer100Km(VehicleConsumptionSnapshot snapshot) {
  final candidates = <double>[
    if (snapshot.litersPer100KmRoute != null && snapshot.litersPer100KmRoute! > 0)
      snapshot.litersPer100KmRoute!,
    if (snapshot.litersPer100KmCity != null && snapshot.litersPer100KmCity! > 0)
      snapshot.litersPer100KmCity!,
    if (snapshot.litersPer100KmTraffic != null &&
        snapshot.litersPer100KmTraffic! > 0)
      snapshot.litersPer100KmTraffic!,
  ];
  if (candidates.isEmpty) {
    return kDefaultOdometerGapGuardLitersPer100Km;
  }
  return candidates.reduce(max);
}

/// Max plausible one-tank distance in stored km tenths, or null when unknown.
int? maxPlausiblePositiveGapTenths({
  required double? tankCapacityLiters,
  required double guardLitersPer100Km,
}) {
  return maxPlausibleDistanceTenthsFromFuel(
    tankCapacityLiters: tankCapacityLiters,
    additionalFuelLitersAfterLastFullTank: 0,
    guardLitersPer100Km: guardLitersPer100Km,
  );
}

/// Max plausible distance from fuel available since the last full tank.
///
/// After a full tank, the vehicle is treated as having [tankCapacityLiters].
/// Later non-full (and any other) purchases add their [volumeLiters] on top —
/// e.g. 60 L capacity + 20 L top-up → 80 L for the ceiling.
int? maxPlausibleDistanceTenthsFromFuel({
  required double? tankCapacityLiters,
  required double additionalFuelLitersAfterLastFullTank,
  required double guardLitersPer100Km,
}) {
  if (tankCapacityLiters == null ||
      tankCapacityLiters <= 0 ||
      guardLitersPer100Km <= 0) {
    return null;
  }
  final added = additionalFuelLitersAfterLastFullTank > 0
      ? additionalFuelLitersAfterLastFullTank
      : 0.0;
  final effectiveFuelLiters = tankCapacityLiters + added;
  final maxKm = effectiveFuelLiters * 100 / guardLitersPer100Km;
  return (maxKm * 10).round();
}

/// Alias kept for call sites that still name the session-end helper.
int? maxPlausibleSessionDistanceTenths({
  required double? tankCapacityLiters,
  required double fuelPurchasedLitersDuringSession,
  required double guardLitersPer100Km,
}) {
  return maxPlausibleDistanceTenthsFromFuel(
    tankCapacityLiters: tankCapacityLiters,
    additionalFuelLitersAfterLastFullTank: fuelPurchasedLitersDuringSession,
    guardLitersPer100Km: guardLitersPer100Km,
  );
}

bool isSuspiciousPositiveGap({
  required int gapTenths,
  required int? maxGapTenths,
}) {
  if (maxGapTenths == null || gapTenths <= 0) {
    return false;
  }
  return gapTenths > maxGapTenths;
}
