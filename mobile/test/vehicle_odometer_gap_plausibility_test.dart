import 'package:flutter_test/flutter_test.dart';

import 'package:compartarenta/vehicle/vehicle_consumption_metrics.dart';
import 'package:compartarenta/vehicle/vehicle_odometer_gap_plausibility.dart';

void main() {
  group('guardConsumptionLitersPer100Km', () {
    test('uses default when no mode breakdown', () {
      expect(
        guardConsumptionLitersPer100Km(
          const VehicleConsumptionSnapshot(hasSufficientData: false),
        ),
        kDefaultOdometerGapGuardLitersPer100Km,
      );
    });

    test('uses highest of city route traffic', () {
      expect(
        guardConsumptionLitersPer100Km(
          const VehicleConsumptionSnapshot(
            hasSufficientData: true,
            litersPer100KmRoute: 6.5,
            litersPer100KmCity: 9.2,
            litersPer100KmTraffic: 8.0,
          ),
        ),
        9.2,
      );
    });
  });

  group('maxPlausibleDistanceTenthsFromFuel', () {
    test('60 L tank at 7.5 L/100 km → 800 km', () {
      expect(
        maxPlausibleDistanceTenthsFromFuel(
          tankCapacityLiters: 60,
          additionalFuelLitersAfterLastFullTank: 0,
          guardLitersPer100Km: 7.5,
        ),
        8000,
      );
    });

    test('60 L capacity + 20 L after last plein → 80 L → ~1066.7 km', () {
      expect(
        maxPlausibleDistanceTenthsFromFuel(
          tankCapacityLiters: 60,
          additionalFuelLitersAfterLastFullTank: 20,
          guardLitersPer100Km: 7.5,
        ),
        10667,
      );
    });

    test('returns null without tank capacity', () {
      expect(
        maxPlausibleDistanceTenthsFromFuel(
          tankCapacityLiters: null,
          additionalFuelLitersAfterLastFullTank: 20,
          guardLitersPer100Km: 7.5,
        ),
        isNull,
      );
    });
  });

  group('maxPlausibleSessionDistanceTenths', () {
    test('adds fuel volumes after last full tank (not capped at capacity)', () {
      expect(
        maxPlausibleSessionDistanceTenths(
          tankCapacityLiters: 60,
          fuelPurchasedLitersDuringSession: 20,
          guardLitersPer100Km: 7.5,
        ),
        10667,
      );
    });
  });

  group('maxPlausiblePositiveGapTenths', () {
    test('delegates with zero additional fuel', () {
      expect(
        maxPlausiblePositiveGapTenths(
          tankCapacityLiters: 60,
          guardLitersPer100Km: 7.5,
        ),
        8000,
      );
    });
  });

  group('isSuspiciousPositiveGap', () {
    test('false when under or equal to max', () {
      expect(
        isSuspiciousPositiveGap(gapTenths: 526, maxGapTenths: 8000),
        isFalse,
      );
      expect(
        isSuspiciousPositiveGap(gapTenths: 8000, maxGapTenths: 8000),
        isFalse,
      );
    });

    test('true when gap exceeds one-tank max', () {
      expect(
        isSuspiciousPositiveGap(gapTenths: 8304, maxGapTenths: 8000),
        isTrue,
      );
      expect(
        isSuspiciousPositiveGap(gapTenths: 9000, maxGapTenths: 8000),
        isTrue,
      );
    });

    test(
      '830.4 km since last plein is OK once 20 L top-up raises ceiling to ~1066.7 km',
      () {
        const lastFullMeter = 510303;
        const sessionEnd = 518607;
        const sinceFullGap = sessionEnd - lastFullMeter;
        final maxWithTopUp = maxPlausibleDistanceTenthsFromFuel(
          tankCapacityLiters: 60,
          additionalFuelLitersAfterLastFullTank: 20,
          guardLitersPer100Km: 7.5,
        );
        final maxCapacityOnly = maxPlausibleDistanceTenthsFromFuel(
          tankCapacityLiters: 60,
          additionalFuelLitersAfterLastFullTank: 0,
          guardLitersPer100Km: 7.5,
        );
        expect(sinceFullGap, 8304);
        expect(maxCapacityOnly, 8000);
        expect(maxWithTopUp, 10667);
        expect(
          isSuspiciousPositiveGap(
            gapTenths: sinceFullGap,
            maxGapTenths: maxCapacityOnly,
          ),
          isTrue,
        );
        expect(
          isSuspiciousPositiveGap(
            gapTenths: sinceFullGap,
            maxGapTenths: maxWithTopUp,
          ),
          isFalse,
        );
      },
    );
  });
}
