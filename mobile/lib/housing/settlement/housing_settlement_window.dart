import 'package:flutter/material.dart' show DateUtils;

import '../../db/app_database.dart';

/// Lifecycle of an agreement after [Agreement.periodEnd].
enum AgreementOperationalState {
  /// Calendar period still open through [Agreement.periodEnd] inclusive.
  inForce,

  /// Period ended, non-zero optimized balances, within settlement window.
  settlementOpen,

  /// Period ended and either balances are zero or settlement window elapsed.
  closed,
}

/// Last inclusive calendar day of the post-end settlement window.
///
/// Same day-of-month one calendar month after [periodEnd] (e.g. Jul 10 → Aug 10).
/// When the target month is shorter, the last day of that month is used.
DateTime settlementWindowLastDayInclusive(DateTime periodEnd) {
  final end = DateUtils.dateOnly(periodEnd.toLocal());
  var year = end.year;
  var month = end.month + 1;
  if (month > 12) {
    month = 1;
    year++;
  }
  final daysInMonth = DateUtils.getDaysInMonth(year, month);
  final day = end.day <= daysInMonth ? end.day : daysInMonth;
  return DateTime(year, month, day);
}

/// Whether [now] is the last inclusive calendar day of the settlement window.
bool isSettlementWindowLastDay({
  required DateTime settlementWindowEnd,
  DateTime? now,
}) {
  final today = DateUtils.dateOnly((now ?? DateTime.now()).toLocal());
  final lastDay = DateUtils.dateOnly(settlementWindowEnd.toLocal());
  return today == lastDay;
}

/// Whether an ended agreement is still in its settlement window.
bool isSettlementOpen({
  required Agreement agreement,
  required bool hasNonZeroOptimizedBalances,
  DateTime? now,
}) {
  if (!hasNonZeroOptimizedBalances) return false;
  final today = DateUtils.dateOnly((now ?? DateTime.now()).toLocal());
  final periodEnd = DateUtils.dateOnly(agreement.periodEnd.toLocal());
  if (!today.isAfter(periodEnd)) return false;
  final lastDay = settlementWindowLastDayInclusive(periodEnd);
  return !today.isAfter(lastDay);
}

/// Resolves [AgreementOperationalState] from agreement dates and balances.
AgreementOperationalState resolveAgreementOperationalState({
  required Agreement agreement,
  required bool hasNonZeroOptimizedBalances,
  DateTime? now,
}) {
  final today = DateUtils.dateOnly((now ?? DateTime.now()).toLocal());
  final periodEnd = DateUtils.dateOnly(agreement.periodEnd.toLocal());
  if (!today.isAfter(periodEnd)) {
    return AgreementOperationalState.inForce;
  }
  if (isSettlementOpen(
    agreement: agreement,
    hasNonZeroOptimizedBalances: hasNonZeroOptimizedBalances,
    now: now,
  )) {
    return AgreementOperationalState.settlementOpen;
  }
  return AgreementOperationalState.closed;
}
