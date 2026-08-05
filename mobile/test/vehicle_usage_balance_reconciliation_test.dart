import 'package:flutter_test/flutter_test.dart';

import 'package:compartarenta/vehicle/sharing/vehicle_usage_balance.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_usage_balance_reconciliation.dart';

void main() {
  test('UsageBalanceBreakdownCodec round-trips snapshot fields', () {
    final original = VehicleUsageBalanceBreakdown(
      litersPer100Km: 8.5,
      distanceKm: 120.3,
      pricePerLiterMinor: 145.2,
      fuelPurchasesInAverage: 3,
      borrowerFuelCostMinor: 4000,
      borrowerMaintenanceCostMinor: 1500,
      ratePerKmMinor: 10,
      estimatedFuelCostMinor: 14850,
      compensationMinor: 1203,
      balanceMinor: 10553,
      windowStart: DateTime.utc(2026, 1, 1),
      windowEnd: DateTime.utc(2026, 2, 1),
      distanceLineItems: [
        UsageBalanceDistanceFact(
          attributedContactId: 'vehicle:borrower:self',
          distanceTenths: 1203,
          at: DateTime.utc(2026, 1, 15),
        ),
      ],
      borrowerFuelLineItems: [
        UsageBalanceCostFact(
          recordedByContactId: 'vehicle:borrower:self',
          costMinor: 4000,
          at: DateTime.utc(2026, 1, 10),
        ),
      ],
      borrowerMaintenanceLineItems: const [],
    );

    final decoded = UsageBalanceBreakdownCodec.decode(
      UsageBalanceBreakdownCodec.encode(original),
    );
    expect(decoded.balanceMinor, original.balanceMinor);
    expect(decoded.litersPer100Km, original.litersPer100Km);
    expect(decoded.distanceLineItems, hasLength(1));
    expect(decoded.borrowerFuelLineItems.first.costMinor, 4000);
    expect(decoded.windowStart, original.windowStart);
  });

  test('usageBalanceCarriedForwardMinor sums freezes and signed transfers', () {
    expect(
      usageBalanceCarriedForwardMinor(
        confirmedFreezeBalanceMinors: [10000, 2500],
        confirmedTransferLedgerDeltas: [-3000, -500],
      ),
      9000,
    );
    expect(
      usageBalanceTransferLedgerDeltaMinor(
        amountMinor: 3000,
        paidToOwner: true,
      ),
      -3000,
    );
    expect(
      usageBalanceTransferLedgerDeltaMinor(
        amountMinor: 2000,
        paidToOwner: false,
      ),
      2000,
    );
    expect(
      usageBalanceCarriedForwardMinor(
        confirmedFreezeBalanceMinors: [-5000],
        confirmedTransferLedgerDeltas: [2000],
      ),
      -3000,
    );
  });

  test('usageBalanceWindowStart prefers last confirmed freeze', () {
    final created = DateTime.utc(2026, 1, 1);
    final accepted = DateTime.utc(2026, 1, 2);
    final freeze = DateTime.utc(2026, 3, 1);
    expect(
      usageBalanceWindowStart(
        linkCreatedAt: created,
        linkAcceptedAt: accepted,
        lastConfirmedUsagePaymentAt: freeze,
      ),
      freeze,
    );
  });
}
