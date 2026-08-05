/// Reliability of a tank-to-tank fuel consumption estimate from the number of
/// full-tank intervals in the rolling calculation window.
enum VehicleConsumptionReliability {
  /// No plein→plein interval yet — no estimate.
  none,

  /// Exactly one interval in the window (second full tank).
  preliminary,

  /// Two to four intervals in the window.
  reliable,

  /// Five intervals in the window (maximum window size).
  veryReliable;

  String get wire => name;

  static VehicleConsumptionReliability? fromWire(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final r in VehicleConsumptionReliability.values) {
      if (r.name == raw) return r;
    }
    return null;
  }
}

/// Maximum number of plein→plein intervals used for a single estimate.
const int kMaxFullTankIntervalsInConsumptionWindow = 5;

/// Maps the count of intervals in the active window to a reliability level.
VehicleConsumptionReliability consumptionReliabilityFromPeriodCount(int count) {
  if (count < 1) return VehicleConsumptionReliability.none;
  if (count == 1) return VehicleConsumptionReliability.preliminary;
  if (count <= 4) return VehicleConsumptionReliability.reliable;
  return VehicleConsumptionReliability.veryReliable;
}

bool consumptionReliabilityIsReliableOrBetter(
  VehicleConsumptionReliability reliability,
) {
  return reliability == VehicleConsumptionReliability.reliable ||
      reliability == VehicleConsumptionReliability.veryReliable;
}
