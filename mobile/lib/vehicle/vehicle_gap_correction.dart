import '../db/app_database.dart';
import '../db/repositories/vehicles_repository.dart';

/// Context for a gap-related correction journal entry.
enum GapCorrectionContext {
  sessionStart,
  sessionEnd,
  standalone,
  applied;

  String get wire => name;

  static GapCorrectionContext? fromWire(String? raw) {
    if (raw == null) return null;
    for (final c in GapCorrectionContext.values) {
      if (c.name == raw) return c;
    }
    return null;
  }
}

enum GapResolutionKind {
  correctPrevious,
  correctTrigger,
  addSessions;

  String get wire => name;

  static GapResolutionKind? fromWire(String? raw) {
    if (raw == null) return null;
    for (final k in GapResolutionKind.values) {
      if (k.name == raw) return k;
    }
    return null;
  }
}

String encodeGapCorrectionNote({
  required int gapTenths,
  required GapCorrectionContext context,
}) =>
    '$gapTenths|${context.wire}';

({int gapTenths, GapCorrectionContext context})? decodeGapCorrectionNote(
  String note,
) {
  final parts = note.split('|');
  if (parts.length != 2) return null;
  final gapTenths = int.tryParse(parts[0]);
  final context = GapCorrectionContext.fromWire(parts[1]);
  if (gapTenths == null || context == null) return null;
  return (gapTenths: gapTenths, context: context);
}

String encodeAppliedGapCorrectionNote({
  required int kmAppliedTenths,
  required String attributedContactId,
  required String previousReadingId,
  required String triggerReadingId,
  required GapResolutionKind kind,
}) =>
    'applied|$kmAppliedTenths|$attributedContactId|$previousReadingId|$triggerReadingId|${kind.wire}';

({
  int kmAppliedTenths,
  String attributedContactId,
  String previousReadingId,
  String triggerReadingId,
  GapResolutionKind kind,
})? decodeAppliedGapCorrectionNote(String note) {
  final parts = note.split('|');
  if (parts.length != 6 || parts[0] != 'applied') return null;
  final kmAppliedTenths = int.tryParse(parts[1]);
  final kind = GapResolutionKind.fromWire(parts[5]);
  if (kmAppliedTenths == null || kind == null) return null;
  return (
    kmAppliedTenths: kmAppliedTenths,
    attributedContactId: parts[2],
    previousReadingId: parts[3],
    triggerReadingId: parts[4],
    kind: kind,
  );
}

bool isGapCorrectionReading(VehicleMeterReading reading) =>
    reading.isCorrection ||
    MeterReadingRole.fromWire(reading.readingRole) ==
        MeterReadingRole.correction;

/// Owner verification row: « Correction d'odomètre à vérifier ».
bool isGapVerificationCorrectionReading(VehicleMeterReading reading) {
  if (!isGapCorrectionReading(reading)) return false;
  if (reading.resolvedAt != null) return false;
  final decoded = decodeGapCorrectionNote(reading.correctionNote);
  if (decoded == null) return false;
  return decoded.context == GapCorrectionContext.sessionStart ||
      decoded.context == GapCorrectionContext.sessionEnd ||
      decoded.context == GapCorrectionContext.standalone;
}

/// Owner resolution row: « Correction appliquée ».
bool isGapAppliedCorrectionReading(VehicleMeterReading reading) {
  if (!isGapCorrectionReading(reading)) return false;
  return decodeAppliedGapCorrectionNote(reading.correctionNote) != null;
}

/// Owner gap resolution: replacement row for a superseded meter reading.
bool isMeterReadingReplacement(VehicleMeterReading reading) =>
    reading.supersedesReadingId != null &&
    reading.supersedesReadingId!.isNotEmpty;

/// User-facing meter / fuel journals omit replacement rows: the verification
/// line, session start/end, and « Correction appliquée » already tell the story.
bool isMeterReadingShownInJournal(VehicleMeterReading reading) =>
    !isMeterReadingReplacement(reading);

String encodeMeterReadingReplacementNote({required GapResolutionKind kind}) =>
    'replace|${kind.wire}';

GapResolutionKind? decodeMeterReadingReplacementKind(String note) {
  final parts = note.split('|');
  if (parts.length != 2 || parts[0] != 'replace') return null;
  return GapResolutionKind.fromWire(parts[1]);
}
