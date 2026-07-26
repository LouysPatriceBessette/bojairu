import '../db/app_database.dart';
import 'expense_form/expense_recurrence_spec.dart';

/// Why the housing wizard expenses step cannot advance.
enum HousingExpensesStepIssue {
  none,
  noLines,
  noParticipants,
  invalidAmount,
  invalidRecurrence,
  incompleteSplit,
}

/// Pure validation for wizard step 3 (expenses + per-line ratios).
HousingExpensesStepIssue validateHousingExpensesStep({
  required List<PlanLine> lines,
  required List<String> participantIds,
  required List<PlanRatio> ratios,
}) {
  if (lines.isEmpty) return HousingExpensesStepIssue.noLines;
  if (participantIds.isEmpty) return HousingExpensesStepIssue.noParticipants;
  for (final line in lines) {
    if (line.amountMinor == null || line.amountMinor! <= 0) {
      return HousingExpensesStepIssue.invalidAmount;
    }
    if (line.isRecurring) {
      final spec = ExpenseRecurrenceSpec.parseStored(line.recurrenceSpecJson);
      if (spec == null) {
        final day = line.recurrenceDayOfMonth;
        if (day == null || day < 1 || day > 31) {
          return HousingExpensesStepIssue.invalidRecurrence;
        }
      }
    }
    var sum = 0;
    for (final pid in participantIds) {
      sum += housingExpenseRatioWeightBps(ratios, line.id, pid);
    }
    if (sum != 10000) {
      return HousingExpensesStepIssue.incompleteSplit;
    }
  }
  return HousingExpensesStepIssue.none;
}

/// Weight in basis points for [participantId] on [lineId] (0 if missing).
int housingExpenseRatioWeightBps(
  List<PlanRatio> ratios,
  String lineId,
  String participantId,
) {
  for (final r in ratios) {
    if (r.lineId != lineId) continue;
    if (r.participantId == participantId) return r.weight;
    final tail = participantId.split(':').last;
    if (r.participantId.endsWith(':$tail')) return r.weight;
  }
  return 0;
}
