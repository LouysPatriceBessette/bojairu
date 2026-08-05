import 'package:intl/intl.dart';

import '../prefs/app_preferences.dart';

/// Statute mile in kilometres (international).
const double kmPerMile = 1.609344;

/// User-facing liquid volume abbreviations (fixed labels per product spec).
String liquidVolumeUnitAbbrev(LiquidVolumeUnit unit) => switch (unit) {
      LiquidVolumeUnit.liter => 'L',
      LiquidVolumeUnit.usGallon => 'Gal US',
      LiquidVolumeUnit.imperialGallon => 'Gal Imp',
    };

/// User-facing distance abbreviations (fixed labels per product spec).
String distanceUnitAbbrev(DistanceUnit unit) => switch (unit) {
      DistanceUnit.km => 'Km',
      DistanceUnit.miles => 'Miles',
    };

/// Short distance unit for rate / consumption copy (`km` / `mile`).
String distanceUnitShort(DistanceUnit unit) => switch (unit) {
      DistanceUnit.km => 'km',
      DistanceUnit.miles => 'mile',
    };

LiquidVolumeUnit resolveLiquidVolumeUnit(AppPreferences prefs) =>
    prefs.liquidVolumeUnit ?? LiquidVolumeUnit.liter;

DistanceUnit resolveDistanceUnit(AppPreferences prefs) =>
    prefs.distanceUnit ?? DistanceUnit.km;

const double _litersPerUsGallon = 3.785411784;
const double _litersPerImperialGallon = 4.54609;

double _litersPerDisplayVolumeUnit(LiquidVolumeUnit unit) => switch (unit) {
      LiquidVolumeUnit.liter => 1.0,
      LiquidVolumeUnit.usGallon => _litersPerUsGallon,
      LiquidVolumeUnit.imperialGallon => _litersPerImperialGallon,
    };

/// Converts liters (canonical storage) to the user's liquid volume unit.
double litersToDisplayVolume(double liters, LiquidVolumeUnit unit) =>
    switch (unit) {
      LiquidVolumeUnit.liter => liters,
      LiquidVolumeUnit.usGallon => liters / _litersPerUsGallon,
      LiquidVolumeUnit.imperialGallon => liters / _litersPerImperialGallon,
    };

/// Converts a user-entered volume to liters for persistence.
double displayVolumeToLiters(double display, LiquidVolumeUnit unit) =>
    switch (unit) {
      LiquidVolumeUnit.liter => display,
      LiquidVolumeUnit.usGallon => display * _litersPerUsGallon,
      LiquidVolumeUnit.imperialGallon => display * _litersPerImperialGallon,
    };

/// Canonical km → user distance unit.
double kmToDisplayDistance(double km, DistanceUnit unit) => switch (unit) {
      DistanceUnit.km => km,
      DistanceUnit.miles => km / kmPerMile,
    };

/// User distance unit → canonical km.
double displayDistanceToKm(double display, DistanceUnit unit) => switch (unit) {
      DistanceUnit.km => display,
      DistanceUnit.miles => display * kmPerMile,
    };

/// L/100 km → volume per 100 display-distance units.
double litersPer100KmToDisplay(
  double litersPer100Km, {
  required LiquidVolumeUnit volumeUnit,
  required DistanceUnit distanceUnit,
}) {
  final litersPer100DisplayDistance = distanceUnit == DistanceUnit.miles
      ? litersPer100Km * kmPerMile
      : litersPer100Km;
  return litersToDisplayVolume(litersPer100DisplayDistance, volumeUnit);
}

/// L/h → display volume per hour.
double litersPerHourToDisplay(
  double litersPerHour, {
  required LiquidVolumeUnit volumeUnit,
}) =>
    litersToDisplayVolume(litersPerHour, volumeUnit);

/// Minor units per litre → minor units per display volume unit.
double pricePerLiterMinorToDisplayMinor(
  double pricePerLiterMinor, {
  required LiquidVolumeUnit volumeUnit,
}) =>
    pricePerLiterMinor * _litersPerDisplayVolumeUnit(volumeUnit);

/// Sous (cents) per km ↔ sous per display distance unit.
double ratePerKmMinorToDisplay(
  double ratePerKmMinor, {
  required DistanceUnit distanceUnit,
}) =>
    distanceUnit == DistanceUnit.miles
        ? ratePerKmMinor * kmPerMile
        : ratePerKmMinor;

double displayRateToPerKmMinor(
  double displayRateMinor, {
  required DistanceUnit distanceUnit,
}) =>
    distanceUnit == DistanceUnit.miles
        ? displayRateMinor / kmPerMile
        : displayRateMinor;

String formatLiquidVolumeForDisplay(
  double liters, {
  required LiquidVolumeUnit unit,
  required String locale,
}) {
  final display = litersToDisplayVolume(liters, unit);
  final formatted = NumberFormat('#,##0.0', locale).format(display);
  return '$formatted ${liquidVolumeUnitAbbrev(unit)}';
}
