import 'package:compartarenta/debug/qa_date_range_picker_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('qaRecurrenceDaySemanticsId', () {
    test('uses stable 15/20 ids for the first month only', () {
      final first = DateTime(2026, 8, 1);
      expect(
        qaRecurrenceDaySemanticsId(
          DateTime(2026, 8, 15),
          rangeFirstDate: first,
        ),
        kQaRecurrenceDay15,
      );
      expect(
        qaRecurrenceDaySemanticsId(
          DateTime(2026, 8, 20),
          rangeFirstDate: first,
        ),
        kQaRecurrenceDay20,
      );
      expect(
        qaRecurrenceDaySemanticsId(
          DateTime(2026, 8, 17),
          rangeFirstDate: first,
        ),
        'qa-housing-expense-recurrence-day-2026-08-17',
      );
    });

    test('later months keep ISO ids so day 15 is not duplicated', () {
      final first = DateTime(2026, 8, 1);
      expect(
        qaRecurrenceDaySemanticsId(
          DateTime(2026, 9, 15),
          rangeFirstDate: first,
        ),
        'qa-housing-expense-recurrence-day-2026-09-15',
      );
      expect(
        qaRecurrenceDaySemanticsId(
          DateTime(2027, 6, 15),
          rangeFirstDate: first,
        ),
        'qa-housing-expense-recurrence-day-2027-06-15',
      );
    });

    test('stable 15/20 follow the first month in 2028 and 2029', () {
      expect(
        qaRecurrenceDaySemanticsId(
          DateTime(2028, 3, 15),
          rangeFirstDate: DateTime(2028, 3, 1),
        ),
        kQaRecurrenceDay15,
      );
      expect(
        qaRecurrenceDaySemanticsId(
          DateTime(2029, 12, 20),
          rangeFirstDate: DateTime(2029, 12, 1),
        ),
        kQaRecurrenceDay20,
      );
    });
  });
}
