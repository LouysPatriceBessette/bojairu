/// Play license-tester acceleration for a **monthly** base plan.
///
/// See https://developer.android.com/google/play/billing/test — a 1-month
/// subscription renews every 5 minutes for license testers. Étape 2 server
/// expiry replaces this estimate when available.
const Duration kPlayLicenseTesterMonthlyRenewalPeriod = Duration(minutes: 5);

/// Next period boundary after [purchaseTimeUtc] that is strictly after [nowUtc].
///
/// Play's client purchase JSON usually omits expiry; [purchaseTime] is the
/// subscription signup time and does not move on renewal. Boundaries are
/// therefore signup + N × [period] (license-tester monthly → 5 minutes).
DateTime nextLicenseTesterRenewalBoundary({
  required DateTime purchaseTimeUtc,
  required DateTime nowUtc,
  Duration period = kPlayLicenseTesterMonthlyRenewalPeriod,
}) {
  final start = purchaseTimeUtc.toUtc();
  final now = nowUtc.toUtc();
  if (period <= Duration.zero) {
    return now;
  }
  if (!now.isAfter(start)) {
    return start.add(period);
  }
  final elapsedMs = now.difference(start).inMilliseconds;
  final periodMs = period.inMilliseconds;
  final completed = elapsedMs ~/ periodMs;
  var next = start.add(Duration(milliseconds: periodMs * (completed + 1)));
  // Exact boundary: treat as already due → show the following period.
  if (!next.isAfter(now)) {
    next = next.add(period);
  }
  return next;
}

/// Renewal / period-end date for Licenses UI copy only.
///
/// Call only when a receipt is still present after a successful Play sync
/// (subscription exists). Prefer Play/server [expiresAt]; otherwise the
/// license-tester 5-minute estimate. This helper never decides whether the
/// subscription exists — presence is Play query + prune only.
DateTime? accessBoundaryForDisplay({
  required DateTime purchasedAt,
  required DateTime now,
  DateTime? expiresAt,
  Duration period = kPlayLicenseTesterMonthlyRenewalPeriod,
}) {
  final exp = expiresAt;
  if (exp != null) return exp.toUtc();
  return nextLicenseTesterRenewalBoundary(
    purchaseTimeUtc: purchasedAt,
    nowUtc: now,
    period: period,
  );
}
