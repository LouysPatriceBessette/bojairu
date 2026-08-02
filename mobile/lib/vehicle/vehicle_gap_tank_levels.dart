import 'vehicle_tank_fill_levels.dart';

/// Tank fill choices between two declared levels (inclusive), per product rules.
List<VehicleTankFillLevel> tankFillLevelsBetween({
  required int? previousPercent,
  required int? triggerPercent,
}) {
  final low = _effectivePercent(previousPercent);
  final high = _effectivePercent(triggerPercent);
  final minP = low < high ? low : high;
  final maxP = low < high ? high : low;
  final levels = VehicleTankFillLevel.choices
      .where((level) => level.percent >= minP && level.percent <= maxP)
      .toList();
  if (maxP >= 100) {
    levels.insert(0, VehicleTankFillLevel.full);
  }
  return levels;
}

int _effectivePercent(int? percent) {
  if (percent == null) return 100;
  return percent;
}
