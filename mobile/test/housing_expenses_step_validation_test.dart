import 'package:flutter_test/flutter_test.dart';

import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/housing/housing_expenses_step_validation.dart';

void main() {
  PlanLine line({
    required String id,
    int? amountMinor = 100,
    bool isRecurring = false,
    String recurrenceSpecJson = '',
    int? recurrenceDayOfMonth,
  }) {
    return PlanLine(
      id: id,
      planId: 'housing:test',
      isRecurring: isRecurring,
      title: 'Loyer',
      currency: 'CAD',
      amountUsesRange: false,
      amountMinor: amountMinor,
      minAmountMinor: null,
      maxAmountMinor: null,
      description: '',
      cadence: 'monthly',
      recurrenceDayOfMonth: recurrenceDayOfMonth,
      sortOrder: 0,
      groupId: null,
      amountIsBudgetCap: false,
      paymentResponsibleParticipantId: null,
      recurrenceSpecJson: recurrenceSpecJson,
      ratioTemplateId: null,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  PlanRatio ratio({
    required String lineId,
    required String participantId,
    required int weight,
  }) {
    return PlanRatio(
      id: 'r:$lineId:$participantId',
      planId: 'housing:test',
      participantId: participantId,
      lineId: lineId,
      groupId: null,
      weight: weight,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  const pids = ['housing:test:self', 'housing:test:p0'];

  test('no lines', () {
    expect(
      validateHousingExpensesStep(
        lines: const [],
        participantIds: pids,
        ratios: const [],
      ),
      HousingExpensesStepIssue.noLines,
    );
  });

  test('incomplete split reports incompleteSplit not noLines', () {
    final lines = [line(id: 'line:1')];
    final ratios = [
      ratio(lineId: 'line:1', participantId: pids[0], weight: 5000),
    ];
    expect(
      validateHousingExpensesStep(
        lines: lines,
        participantIds: pids,
        ratios: ratios,
      ),
      HousingExpensesStepIssue.incompleteSplit,
    );
  });

  test('complete equal split passes', () {
    final lines = [line(id: 'line:1')];
    final ratios = [
      ratio(lineId: 'line:1', participantId: pids[0], weight: 5000),
      ratio(lineId: 'line:1', participantId: pids[1], weight: 5000),
    ];
    expect(
      validateHousingExpensesStep(
        lines: lines,
        participantIds: pids,
        ratios: ratios,
      ),
      HousingExpensesStepIssue.none,
    );
  });

  test('recurring without recurrence fails', () {
    final lines = [line(id: 'line:1', isRecurring: true)];
    final ratios = [
      ratio(lineId: 'line:1', participantId: pids[0], weight: 5000),
      ratio(lineId: 'line:1', participantId: pids[1], weight: 5000),
    ];
    expect(
      validateHousingExpensesStep(
        lines: lines,
        participantIds: pids,
        ratios: ratios,
      ),
      HousingExpensesStepIssue.invalidRecurrence,
    );
  });
}
