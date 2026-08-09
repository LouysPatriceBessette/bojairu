import 'package:compartarenta/entitlement/subscription_renewal_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final purchase = DateTime.utc(2026, 8, 9, 20, 0, 0); // 16:00 EDT

  group('nextLicenseTesterRenewalBoundary', () {
    test('before first period ends → signup + 5 min', () {
      final now = purchase.add(const Duration(minutes: 2));
      expect(
        nextLicenseTesterRenewalBoundary(
          purchaseTimeUtc: purchase,
          nowUtc: now,
        ),
        purchase.add(const Duration(minutes: 5)),
      );
    });

    test('mid second period → signup + 10 min', () {
      final now = purchase.add(const Duration(minutes: 7));
      expect(
        nextLicenseTesterRenewalBoundary(
          purchaseTimeUtc: purchase,
          nowUtc: now,
        ),
        purchase.add(const Duration(minutes: 10)),
      );
    });

    test('exact boundary → following period', () {
      final now = purchase.add(const Duration(minutes: 10));
      expect(
        nextLicenseTesterRenewalBoundary(
          purchaseTimeUtc: purchase,
          nowUtc: now,
        ),
        purchase.add(const Duration(minutes: 15)),
      );
    });

    test('now at signup → first boundary', () {
      expect(
        nextLicenseTesterRenewalBoundary(
          purchaseTimeUtc: purchase,
          nowUtc: purchase,
        ),
        purchase.add(const Duration(minutes: 5)),
      );
    });
  });

  group('accessBoundaryForDisplay', () {
    test('prefers expiresAt over estimate', () {
      final exp = purchase.add(const Duration(days: 30));
      expect(
        accessBoundaryForDisplay(
          purchasedAt: purchase,
          now: purchase.add(const Duration(minutes: 3)),
          expiresAt: exp,
        ),
        exp,
      );
    });

    test('estimates when expiresAt missing', () {
      expect(
        accessBoundaryForDisplay(
          purchasedAt: purchase,
          now: purchase.add(const Duration(minutes: 3)),
          expiresAt: null,
        ),
        purchase.add(const Duration(minutes: 5)),
      );
    });
  });
}
