import 'package:compartarenta/scheduling/client_scheduled_fire_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClientScheduledFireTimes.actionDeadlineFires', () {
    test('24h validity schedules T-2h before_expiry and expired at T', () {
      final expires = DateTime.utc(2026, 7, 24, 18);
      final now = DateTime.utc(2026, 7, 24, 10);
      final pairs = ClientScheduledFireTimes.actionDeadlineFires(
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

    test('3h validity uses T-30m soon ping', () {
      final expires = DateTime.utc(2026, 7, 24, 17);
      final now = DateTime.utc(2026, 7, 24, 14);
      final pairs = ClientScheduledFireTimes.actionDeadlineFires(
        validFor: const Duration(hours: 3),
        expiresAtUtc: expires,
        nowUtc: now,
      );
      expect(pairs[0].fireAt, DateTime.utc(2026, 7, 24, 16, 30));
      expect(pairs[1].kind, ClientScheduledFireTimes.kindExpired);
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
}
