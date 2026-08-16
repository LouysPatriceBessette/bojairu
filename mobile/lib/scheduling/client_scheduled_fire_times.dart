import 'dart:convert';
import 'dart:typed_data';

/// Wall-clock fire helpers for client-supplied relay scheduled notifications.
abstract final class ClientScheduledFireTimes {
  static const domainContactsInvitationExpiry = 'contacts_invitation_expiry';
  static const domainHousingProposalDeadline = 'housing_proposal_deadline';
  static const domainVehicleSharingDeadline = 'vehicle_sharing_deadline';

  static const kindBeforeExpiry = 'before_expiry';
  static const kindExpired = 'expired';
  static const kindBeforeDeadline = 'before_deadline';

  /// Decision-deadline validity → before_expiry offset (recipe A).
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

  /// Recipe A: soon ping + ping at T. Omits instants already past [nowUtc].
  static List<({String kind, DateTime fireAt})> actionDeadlineFires({
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

  /// Invitation expiry uses the same recipe A table as other decision deadlines.
  static List<({String kind, DateTime fireAt})> invitationExpiryFires({
    required Duration validFor,
    required DateTime expiresAtUtc,
    required DateTime nowUtc,
  }) => actionDeadlineFires(
    validFor: validFor,
    expiresAtUtc: expiresAtUtc,
    nowUtc: nowUtc,
  );

  static Uint8List scopeKeyFromUtf8(String id) =>
      Uint8List.fromList(utf8.encode(id));
}
