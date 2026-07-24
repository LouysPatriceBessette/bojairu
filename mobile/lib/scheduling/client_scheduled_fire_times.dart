import 'dart:convert';
import 'dart:typed_data';

/// Wall-clock fire helpers for client-supplied relay scheduled notifications.
abstract final class ClientScheduledFireTimes {
  static const domainContactsInvitationExpiry = 'contacts_invitation_expiry';
  static const domainHousingProposalDeadline = 'housing_proposal_deadline';

  static const kindBeforeExpiry = 'before_expiry';
  static const kindExpired = 'expired';
  static const kindBeforeDeadline = 'before_deadline';

  /// Invitation validity → before_expiry offset (spec table).
  static Duration beforeExpiryLead(Duration validFor) {
    if (validFor <= const Duration(hours: 3)) {
      return const Duration(minutes: 30);
    }
    if (validFor <= const Duration(hours: 8)) {
      return const Duration(hours: 1);
    }
    if (validFor <= const Duration(hours: 24)) {
      return const Duration(hours: 2);
    }
    return const Duration(hours: 4);
  }

  /// Returns (kind, fireAt) pairs; omits instants already past [now].
  static List<({String kind, DateTime fireAt})> invitationExpiryFires({
    required Duration validFor,
    required DateTime expiresAtUtc,
    required DateTime nowUtc,
  }) {
    final expires = expiresAtUtc.toUtc();
    final now = nowUtc.toUtc();
    final out = <({String kind, DateTime fireAt})>[];
    final soon = expires.subtract(beforeExpiryLead(validFor));
    if (soon.isAfter(now)) {
      out.add((kind: kindBeforeExpiry, fireAt: soon));
    }
    if (expires.isAfter(now)) {
      out.add((kind: kindExpired, fireAt: expires));
    }
    return out;
  }

  /// Proposal deadline lead times (product table for this cut):
  /// window ≥ 7d → T−48h + T−24h; else ≥ 48h → T−24h + T−6h; else T−6h + T−2h.
  static List<DateTime> proposalDeadlineFireAts({
    required DateTime expiresAtUtc,
    required DateTime nowUtc,
    Duration? windowHint,
  }) {
    final expires = expiresAtUtc.toUtc();
    final now = nowUtc.toUtc();
    final window = windowHint ?? expires.difference(now);
    final List<Duration> leads;
    if (window >= const Duration(days: 7)) {
      leads = const [Duration(hours: 48), Duration(hours: 24)];
    } else if (window >= const Duration(hours: 48)) {
      leads = const [Duration(hours: 24), Duration(hours: 6)];
    } else {
      leads = const [Duration(hours: 6), Duration(hours: 2)];
    }
    final out = <DateTime>[];
    for (final lead in leads) {
      final at = expires.subtract(lead);
      if (at.isAfter(now)) out.add(at);
    }
    return out;
  }

  static Uint8List scopeKeyFromUtf8(String id) =>
      Uint8List.fromList(utf8.encode(id));
}
