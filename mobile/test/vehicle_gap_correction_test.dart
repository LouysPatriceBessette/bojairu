import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/vehicle/vehicle_gap_correction.dart';
import 'package:compartarenta/vehicle/vehicle_meter_journal_sort.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encodeGapCorrectionNote / decodeGapCorrectionNote', () {
    test('round-trip session start', () {
      final note = encodeGapCorrectionNote(
        gapTenths: 1000,
        context: GapCorrectionContext.sessionStart,
      );
      expect(note, '1000|sessionStart');
      expect(decodeGapCorrectionNote(note)?.gapTenths, 1000);
      expect(
        decodeGapCorrectionNote(note)?.context,
        GapCorrectionContext.sessionStart,
      );
    });

    test('round-trip standalone', () {
      final note = encodeGapCorrectionNote(
        gapTenths: 500,
        context: GapCorrectionContext.standalone,
      );
      expect(decodeGapCorrectionNote(note)?.context,
          GapCorrectionContext.standalone);
    });

    test('round-trip negative gap', () {
      final note = encodeGapCorrectionNote(
        gapTenths: -1000,
        context: GapCorrectionContext.sessionStart,
      );
      expect(note, '-1000|sessionStart');
      expect(decodeGapCorrectionNote(note)?.gapTenths, -1000);
    });

    test('invalid note returns null', () {
      expect(decodeGapCorrectionNote(''), isNull);
      expect(decodeGapCorrectionNote('abc|sessionStart'), isNull);
      expect(decodeGapCorrectionNote('1000|unknown'), isNull);
    });
  });

  group('isGapCorrectionReading', () {
    test('true when role is correction', () {
      final reading = VehicleMeterReading(
        id: 'm1',
        vehicleId: 'v1',
        value: 50100,
        unit: 'km',
        photoPath: 'p',
        recordedAt: DateTime.utc(2027, 1, 1),
        recordedByContactId: 'c1',
        vehicleUseId: null,
        readingRole: 'correction',
        isCorrection: true,
        correctionNote: '1000|sessionStart',
        negativeGapAcknowledged: false,
        isFullTank: null,
        tankFillFraction: null,
        resolvedAt: null,
        supersedesReadingId: null,
      );
      expect(isGapCorrectionReading(reading), isTrue);
    });
  });

  group('isMeterReadingShownInJournal', () {
    test('hides replacement rows that supersede another reading', () {
      final replacement = VehicleMeterReading(
        id: 'm2',
        vehicleId: 'v1',
        value: 500500,
        unit: 'km',
        photoPath: 'p',
        recordedAt: DateTime.utc(2027, 1, 1),
        recordedByContactId: 'c1',
        vehicleUseId: null,
        readingRole: 'standalone',
        isCorrection: true,
        correctionNote: 'replace|correctPrevious',
        negativeGapAcknowledged: false,
        isFullTank: null,
        tankFillFraction: null,
        resolvedAt: null,
        supersedesReadingId: 'm1',
      );
      expect(isMeterReadingReplacement(replacement), isTrue);
      expect(isMeterReadingShownInJournal(replacement), isFalse);
    });

    test('keeps verification and applied correction rows', () {
      final verification = VehicleMeterReading(
        id: 'c1',
        vehicleId: 'v1',
        value: 500500,
        unit: 'km',
        photoPath: 'p',
        recordedAt: DateTime.utc(2027, 1, 1),
        recordedByContactId: 'c1',
        vehicleUseId: null,
        readingRole: 'correction',
        isCorrection: true,
        correctionNote: '1000|sessionStart',
        negativeGapAcknowledged: false,
        isFullTank: null,
        tankFillFraction: null,
        resolvedAt: null,
        supersedesReadingId: null,
      );
      expect(isMeterReadingShownInJournal(verification), isTrue);
    });
  });

  group('compareMeterReadingsNewestFirst', () {
    test('correction below session start when recordedAt is one second earlier',
        () {
      final followUpAt = DateTime.utc(2027, 1, 1, 12);
      final correction = VehicleMeterReading(
        id: 'c1',
        vehicleId: 'v1',
        value: 50100,
        unit: 'km',
        photoPath: 'p',
        recordedAt: followUpAt.subtract(const Duration(seconds: 1)),
        recordedByContactId: 'c1',
        vehicleUseId: null,
        readingRole: 'correction',
        isCorrection: true,
        correctionNote: '1000|sessionStart',
        negativeGapAcknowledged: false,
        isFullTank: null,
        tankFillFraction: null,
        resolvedAt: null,
        supersedesReadingId: null,
      );
      final sessionStart = correction.copyWith(
        id: 's1',
        recordedAt: followUpAt,
        readingRole: 'sessionStart',
        isCorrection: false,
        correctionNote: '',
      );
      final ordered = [correction, sessionStart]
        ..sort(compareMeterReadingsNewestFirst);
      expect(ordered.first.readingRole, 'sessionStart');
      expect(ordered.last.readingRole, 'correction');
    });

    test('correction below session start when recordedAt ties (legacy rows)',
        () {
      final at = DateTime.utc(2027, 1, 1, 12);
      final correction = VehicleMeterReading(
        id: 'c1',
        vehicleId: 'v1',
        value: 50100,
        unit: 'km',
        photoPath: 'p',
        recordedAt: at,
        recordedByContactId: 'c1',
        vehicleUseId: null,
        readingRole: 'correction',
        isCorrection: true,
        correctionNote: '1000|sessionStart',
        negativeGapAcknowledged: false,
        isFullTank: null,
        tankFillFraction: null,
        resolvedAt: null,
        supersedesReadingId: null,
      );
      final sessionStart = correction.copyWith(
        id: 's1',
        readingRole: 'sessionStart',
        isCorrection: false,
        correctionNote: '',
      );
      final ordered = [correction, sessionStart]
        ..sort(compareMeterReadingsNewestFirst);
      expect(ordered.first.readingRole, 'sessionStart');
      expect(ordered.last.readingRole, 'correction');
    });
  });
}
