import '../prefs/app_preferences.dart';
import '../util/display_units.dart';

/// Parses oil-change interval form input into stored tenths (km or engine hours).
///
/// Land: multiplier ×1000 on the user's distance unit (km or miles), then km tenths.
/// Boat: direct hours in [50, 500], stored as hour tenths.
int? parseOilChangeIntervalToStoredTenths({
  required String text,
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  if (parsed == null) return null;

  if (usesHorometer) {
    if (parsed < 50 || parsed > 500) return null;
    return (parsed * 10).round();
  }

  if (parsed < 1 || parsed > 20) return null;
  final displayDistance = parsed * 1000;
  final km = switch (distanceUnit) {
    DistanceUnit.km => displayDistance,
    DistanceUnit.miles => displayDistance * kmPerMile,
  };
  return (km * 10).round();
}

String oilChangeIntervalUnitSuffix({
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) {
  if (usesHorometer) return 'h';
  return 'x 1000 ${distanceUnitAbbrev(distanceUnit)}';
}

enum OilChangeIntervalValidationIssue {
  empty,
  invalid,
  landBelowMin,
  landAboveMax,
  boatBelowMin,
  boatAboveMax,
}

OilChangeIntervalValidationIssue? oilChangeIntervalValidationIssue({
  required String text,
  required bool usesHorometer,
}) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return OilChangeIntervalValidationIssue.empty;
  final parsed = double.tryParse(normalized);
  if (parsed == null) return OilChangeIntervalValidationIssue.invalid;

  if (usesHorometer) {
    if (parsed < 50) return OilChangeIntervalValidationIssue.boatBelowMin;
    if (parsed > 500) return OilChangeIntervalValidationIssue.boatAboveMax;
    return null;
  }

  if (parsed < 1) return OilChangeIntervalValidationIssue.landBelowMin;
  if (parsed > 20) return OilChangeIntervalValidationIssue.landAboveMax;
  return null;
}

/// Form display value from stored interval tenths (inverse of [parseOilChangeIntervalToStoredTenths]).
String formatOilChangeIntervalForDisplay({
  required int storedTenths,
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) {
  if (usesHorometer) {
    return _formatOilChangeMultiplier(storedTenths / 10.0);
  }
  final km = storedTenths / 10.0;
  final displayDistance = switch (distanceUnit) {
    DistanceUnit.km => km,
    DistanceUnit.miles => km / kmPerMile,
  };
  return _formatOilChangeMultiplier(displayDistance / 1000.0);
}

String _formatOilChangeMultiplier(double value) {
  if ((value - value.roundToDouble()).abs() < 0.0001) {
    return value.round().toString();
  }
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
