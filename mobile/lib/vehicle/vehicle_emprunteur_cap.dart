/// Product cap: at most this many **distinct** Emprunteurs per Propriétaire
/// across the owned fleet (active + pending offer + reactivate-pending).
const int kMaxDistinctEmprunteurs = 5;

/// Thrown when creating / proposing a share would exceed
/// [kMaxDistinctEmprunteurs] with a new distinct Contact.
class EmprunteurCapExceededException implements Exception {
  const EmprunteurCapExceededException();

  @override
  String toString() =>
      'EmprunteurCapExceededException: at most $kMaxDistinctEmprunteurs '
      'distinct Emprunteurs (active or pending)';
}

/// Thrown when an offer would make the local user Emprunteur of their own vehicle.
class SelfBorrowForbiddenException implements Exception {
  const SelfBorrowForbiddenException();

  @override
  String toString() =>
      'SelfBorrowForbiddenException: local user cannot be Emprunteur '
      'on a self-owned vehicle';
}

/// Pure helpers for the distinct-Emprunteur cap (fleet-wide).
class EmprunteurCapLogic {
  const EmprunteurCapLogic._();

  /// Whether [borrowerContactId] is already counted toward the cap.
  static bool contactAlreadyCounts({
    required Set<String> countingContactIds,
    required String borrowerContactId,
  }) =>
      countingContactIds.contains(borrowerContactId);

  /// True when inviting / reactivating [borrowerContactId] would make them the
  /// 5th distinct Emprunteur (last slot) without exceeding the cap.
  static bool wouldOccupyLastSlot({
    required Set<String> countingContactIds,
    required String borrowerContactId,
  }) {
    if (contactAlreadyCounts(
      countingContactIds: countingContactIds,
      borrowerContactId: borrowerContactId,
    )) {
      return false;
    }
    return countingContactIds.length == kMaxDistinctEmprunteurs - 1;
  }

  /// True when inviting / reactivating [borrowerContactId] would exceed the cap.
  static bool wouldExceedCap({
    required Set<String> countingContactIds,
    required String borrowerContactId,
  }) {
    if (contactAlreadyCounts(
      countingContactIds: countingContactIds,
      borrowerContactId: borrowerContactId,
    )) {
      return false;
    }
    return countingContactIds.length >= kMaxDistinctEmprunteurs;
  }
}
