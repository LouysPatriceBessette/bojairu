import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/debug/qa_scenario_seed.dart';
import 'package:compartarenta/debug/qa_scenario_seed_helpers.dart';
import 'package:compartarenta/housing/realized_expense/realized_expense_ledger_service.dart';
import 'package:compartarenta/housing/settlement/housing_settlement_window.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const housingHubScenarios = <String>[
    'period_end_day',
    'settlement_open',
    'settlement_last_day',
    'settlement_closed',
    'renewal_fork_visible',
    'voluntary_withdrawal_ack_j5',
    'voluntary_withdrawal_effective',
    'proposal_response_expired',
  ];

  const otherScenarios = <String>[
    'proposal_wizard_expenses',
    'vehicle_add',
    'vehicle_fuel_purchase',
    'vehicle_use_session',
    'vehicle_session_start_gap',
    'vehicle_standalone_meter_gap',
    'vehicle_consumption',
    'vehicle_sale_export_import_seller',
    'vehicle_sale_export_import_buyer',
  ];

  test('housing hub seeds satisfy postconditions at DateTime.now', () async {
    final now = DateTime.now();
    for (final id in housingHubScenarios) {
      if (id == 'settlement_last_day' && !qaSettlementLastDayRoundTrips(now)) {
        continue;
      }
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await applyQaScenario(db, id, now: now);
      await assertQaScenarioPostconditions(
        db: db,
        scenarioId: id,
        now: now,
      );
    }
  });

  test('settlement_last_day round-trips on 2026-08-17', () async {
    final now = DateTime(2026, 8, 17, 12);
    expect(qaSettlementLastDayRoundTrips(now), isTrue);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await applyQaScenario(db, 'settlement_last_day', now: now);
    await assertQaScenarioPostconditions(
      db: db,
      scenarioId: 'settlement_last_day',
      now: now,
    );
  });

  for (final id in otherScenarios) {
    test('$id seed satisfies postconditions', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.now();
      await applyQaScenario(db, id, now: now);
      await assertQaScenarioPostconditions(
        db: db,
        scenarioId: id,
        now: now,
      );
    });
  }

  test('proposal_wizard_expenses period includes day 20 in 2028 and 2029',
      () async {
    for (final now in [
      DateTime(2028, 3, 17, 12),
      DateTime(2029, 12, 5, 12),
    ]) {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await applyQaScenario(db, 'proposal_wizard_expenses', now: now);
      await assertQaScenarioPostconditions(
        db: db,
        scenarioId: 'proposal_wizard_expenses',
        now: now,
      );
    }
  });

  test('settlement_open has non-zero balances and window open at now', () async {
    final now = DateTime.now();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await applyQaScenario(db, 'settlement_open', now: now);

    final agreement = await db.getAgreementForPlan(kQaSettlementOpenPlanId);
    expect(agreement, isNotNull);
    final ledger = RealizedExpenseLedgerService(db);
    expect(
      await ledger.hasNonZeroOptimizedBalances(kQaSettlementOpenPlanId),
      isTrue,
    );
    expect(
      isSettlementOpen(
        agreement: agreement!,
        hasNonZeroOptimizedBalances: true,
        now: now,
      ),
      isTrue,
    );
  });

  test('all scenario ids have manifests in kQaScenarioIds', () {
    expect(
      kQaScenarioIds,
      containsAll([...housingHubScenarios, ...otherScenarios]),
    );
  });
}
