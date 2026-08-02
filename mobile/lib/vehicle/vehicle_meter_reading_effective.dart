import '../db/app_database.dart';
import 'vehicle_gap_correction.dart';

/// Reading ids replaced by a newer correction row (kept in DB for metrics;
/// replacement rows are hidden from user-facing journals).
Set<String> supersededMeterReadingIds(Iterable<VehicleMeterReading> readings) {
  return readings
      .map((r) => r.supersedesReadingId)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();
}

bool isSupersededMeterReading(
  VehicleMeterReading reading,
  Set<String> supersededIds,
) =>
    supersededIds.contains(reading.id);

/// Canonical readings for gap detection and consumption (excludes superseded
/// originals and gap journal rows).
List<VehicleMeterReading> effectiveMeterReadingsChronological(
  List<VehicleMeterReading> readings,
) {
  final superseded = supersededMeterReadingIds(readings);
  final filtered = readings
      .where((r) => !isSupersededMeterReading(r, superseded))
      .where((r) => !isGapVerificationCorrectionReading(r))
      .where((r) => !isGapAppliedCorrectionReading(r))
      .toList()
    ..sort((a, b) {
      final byTime = a.recordedAt.compareTo(b.recordedAt);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
  return filtered;
}

VehicleMeterReading? latestEffectiveMeterReading(
  List<VehicleMeterReading> readings,
) {
  final ordered = effectiveMeterReadingsChronological(readings);
  return ordered.isEmpty ? null : ordered.last;
}
