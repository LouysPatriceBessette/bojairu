import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/housing/settlement/housing_settlement_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Agreement agreement({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) =>
      Agreement(
        id: 'a1',
        planId: 'plan',
        periodStart: periodStart,
        periodEnd: periodEnd,
        minNoticeDays: 0,
        penaltyMinor: 0,
        clauses: '',
        withdrawalSameForAll: 'true',
        withdrawalPerParticipantJson: '{}',
        agreementRulesJson: '{}',
        version: 1,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  group('settlementWindowLastDayInclusive', () {
    test('maps Jul 10 to Aug 10', () {
      final end = settlementWindowLastDayInclusive(DateTime(2026, 7, 10));
      expect(end, DateTime(2026, 8, 10));
    });

    test('maps Oct 28 to Nov 28', () {
      final end = settlementWindowLastDayInclusive(DateTime(2026, 10, 28));
      expect(end, DateTime(2026, 11, 28));
    });

    test('clamps Jan 31 to last day of February', () {
      final end = settlementWindowLastDayInclusive(DateTime(2026, 1, 31));
      expect(end, DateTime(2026, 2, 28));
    });
  });

  group('isSettlementWindowLastDay', () {
    test('is true on the inclusive last day', () {
      expect(
        isSettlementWindowLastDay(
          settlementWindowEnd: DateTime(2026, 8, 17),
          now: DateTime(2026, 8, 17, 19, 44),
        ),
        isTrue,
      );
    });

    test('is false the day before and the day after', () {
      expect(
        isSettlementWindowLastDay(
          settlementWindowEnd: DateTime(2026, 8, 17),
          now: DateTime(2026, 8, 16),
        ),
        isFalse,
      );
      expect(
        isSettlementWindowLastDay(
          settlementWindowEnd: DateTime(2026, 8, 17),
          now: DateTime(2026, 8, 18),
        ),
        isFalse,
      );
    });
  });

  group('isSettlementOpen', () {
    test('is false while period still open', () {
      expect(
        isSettlementOpen(
          agreement: agreement(
            periodStart: DateTime(2026, 1, 1),
            periodEnd: DateTime(2026, 10, 28),
          ),
          hasNonZeroOptimizedBalances: true,
          now: DateTime(2026, 10, 28),
        ),
        isFalse,
      );
    });

    test('is true after periodEnd within window with balances', () {
      expect(
        isSettlementOpen(
          agreement: agreement(
            periodStart: DateTime(2026, 1, 1),
            periodEnd: DateTime(2026, 10, 28),
          ),
          hasNonZeroOptimizedBalances: true,
          now: DateTime(2026, 11, 10),
        ),
        isTrue,
      );
    });

    test('is false when balances are zero', () {
      expect(
        isSettlementOpen(
          agreement: agreement(
            periodStart: DateTime(2026, 1, 1),
            periodEnd: DateTime(2026, 10, 28),
          ),
          hasNonZeroOptimizedBalances: false,
          now: DateTime(2026, 11, 10),
        ),
        isFalse,
      );
    });

    test('is false after settlement window ends', () {
      expect(
        isSettlementOpen(
          agreement: agreement(
            periodStart: DateTime(2026, 1, 1),
            periodEnd: DateTime(2026, 10, 28),
          ),
          hasNonZeroOptimizedBalances: true,
          now: DateTime(2026, 11, 29),
        ),
        isFalse,
      );
    });
  });

  group('resolveAgreementOperationalState', () {
    final endedAgreement = agreement(
      periodStart: DateTime(2026, 5, 25),
      periodEnd: DateTime(2026, 10, 15),
    );

    test('inForce through periodEnd', () {
      expect(
        resolveAgreementOperationalState(
          agreement: endedAgreement,
          hasNonZeroOptimizedBalances: true,
          now: DateTime(2026, 10, 15),
        ),
        AgreementOperationalState.inForce,
      );
    });

    test('settlementOpen after periodEnd with balances', () {
      expect(
        resolveAgreementOperationalState(
          agreement: endedAgreement,
          hasNonZeroOptimizedBalances: true,
          now: DateTime(2026, 11, 1),
        ),
        AgreementOperationalState.settlementOpen,
      );
    });

    test('closed after window', () {
      expect(
        resolveAgreementOperationalState(
          agreement: endedAgreement,
          hasNonZeroOptimizedBalances: true,
          now: DateTime(2026, 11, 16),
        ),
        AgreementOperationalState.closed,
      );
    });
  });
}
