import 'package:compartarenta/scheduling/client_scheduled_fire_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClientScheduledFireTimes.invitationExpiryFires', () {
    test('24h validity schedules T-2h before_expiry and expired at T', () {
      final expires = DateTime.utc(2026, 7, 24, 18);
      final now = DateTime.utc(2026, 7, 24, 10);
      final pairs = ClientScheduledFireTimes.invitationExpiryFires(
        validFor: const Duration(hours: 24),
        expiresAtUtc: expires,
        nowUtc: now,
      );
      expect(pairs, hasLength(2));
      expect(pairs[0].kind, ClientScheduledFireTimes.kindBeforeExpiry);
      expect(pairs[0].fireAt, DateTime.utc(2026, 7, 24, 16));
      expect(pairs[1].kind, ClientScheduledFireTimes.kindExpired);
      expect(pairs[1].fireAt, expires);
    });

    test('omits past before_expiry lead', () {
      final expires = DateTime.utc(2026, 7, 24, 18);
      final now = DateTime.utc(2026, 7, 24, 17);
      final pairs = ClientScheduledFireTimes.invitationExpiryFires(
        validFor: const Duration(hours: 24),
        expiresAtUtc: expires,
        nowUtc: now,
      );
      expect(pairs, hasLength(1));
      expect(pairs.single.kind, ClientScheduledFireTimes.kindExpired);
    });
  });

  group('ClientScheduledFireTimes.proposalDeadlineFireAts', () {
    test('7d+ window uses T-48h and T-24h', () {
      final expires = DateTime.utc(2026, 8, 1, 12);
      final now = DateTime.utc(2026, 7, 20, 12);
      final ats = ClientScheduledFireTimes.proposalDeadlineFireAts(
        expiresAtUtc: expires,
        nowUtc: now,
        windowHint: const Duration(days: 7),
      );
      expect(ats, [
        DateTime.utc(2026, 7, 30, 12),
        DateTime.utc(2026, 7, 31, 12),
      ]);
    });

    test('48h window uses T-24h and T-6h', () {
      final expires = DateTime.utc(2026, 7, 26, 12);
      final now = DateTime.utc(2026, 7, 24, 12);
      final ats = ClientScheduledFireTimes.proposalDeadlineFireAts(
        expiresAtUtc: expires,
        nowUtc: now,
        windowHint: const Duration(hours: 48),
      );
      expect(ats, [
        DateTime.utc(2026, 7, 25, 12),
        DateTime.utc(2026, 7, 26, 6),
      ]);
    });
  });
}
