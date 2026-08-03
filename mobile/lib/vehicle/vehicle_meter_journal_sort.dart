import '../db/app_database.dart';
import '../db/repositories/vehicles_repository.dart';
import 'vehicle_gap_correction.dart';

/// Newest-first journal ordering. When [recordedAt] ties, gap corrections sort
/// older than the session start / standalone reading they precede chronologically.
int compareMeterReadingsNewestFirst(
  VehicleMeterReading a,
  VehicleMeterReading b,
) {
  final byTime = b.recordedAt.compareTo(a.recordedAt);
  if (byTime != 0) return byTime;
  return _meterReadingJournalRank(b).compareTo(_meterReadingJournalRank(a));
}

int meterReadingJournalRank(VehicleMeterReading reading) {
  return _meterReadingJournalRank(reading);
}

int _meterReadingJournalRank(VehicleMeterReading reading) {
  if (isGapCorrectionReading(reading)) return 2;
  return switch (MeterReadingRole.fromWire(reading.readingRole)) {
    MeterReadingRole.sessionStart => 3,
    MeterReadingRole.standalone => 3,
    MeterReadingRole.sessionEnd => 2,
    MeterReadingRole.fuelPurchase => 1,
    MeterReadingRole.maintenance => 1,
    MeterReadingRole.correction => 4,
    null => 1,
  };
}
