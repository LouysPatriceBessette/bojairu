## 1. Settlement window state

- [x] 1.1 Add a helper that computes whether an ended agreement is `settlement-open` from `periodEnd`, current local date, and current participant balances. *(See `mobile/lib/housing/settlement/housing_settlement_window.dart`; unit tests in `mobile/test/housing_settlement_window_test.dart`.)*
- [x] 1.2 Keep ended agreements read-only for amendments while allowing settlement-only expense operations during the settlement window. *(Amendment / major-change hub gates require `periodOpen` in `housing_participation_hub_gates.dart`; settlement entry via `HousingHubExpenseEntryMode.settlementDue` only.)*
- [x] 1.3 Ensure a successor agreement can coexist with a prior settlement-open agreement without merging their operational state. *(Workbench splits in-force vs settlement-open rows in `housing_workbench_screen.dart`; renewal fork availability in `housing_renewal_fork_availability.dart`.)*

## 2. Expense entry gating

- [x] 2.1 Update housing expense-entry gating so ended agreements allow entry only while the settlement window is open. *(See `housing_hub_expense_entry.dart`, hub tiles in `housing_active_plan_screen.dart`.)*
- [x] 2.2 Extend the realized-expense date picker to allow dates through the settlement-window end, while keeping entries scoped to the ended agreement. *(See `housing_settlement_due_form_screen.dart` — `lastDate` capped at `settlementWindowLastDayInclusive`.)*
- [x] 2.3 Add targeted tests for blocked vs allowed post-end entry dates. *(Unit: `housing_settlement_window_test.dart`, seed postconditions in `qa_scenario_seed_test.dart`; Android E2E: `period_end_day`, `settlement_open`, `settlement_last_day`, `settlement_closed` — see `docs/qa-android-e2e.md`.)*

## 3. Ledger and navigation

- [x] 3.1 Centralize the accessible month-window calculation for the monthly summary screen. *(See `housing_agreement_month_window.dart`.)*
- [x] 3.2 Support the documented near-end-of-month extension and settlement-month visibility in monthly navigation. *(See `HousingAgreementMonthWindow.fromAgreement`; unit tests in `housing_agreement_month_window_test.dart`.)*
- [x] 3.3 Add targeted tests for the month-window examples and settlement-month behavior. *(See `housing_agreement_month_window_test.dart`.)*

## 4. Parallel agreement UX

- [x] 4.1 Expose enough UI state to distinguish an in-force agreement from a settlement-open ended agreement. *(Workbench settlement section + hub `qa-housing-hub-settlement-due` / `qa-housing-hub-expense-disabled` semantics; E2E screenshots in settlement scenarios.)*
- [x] 4.2 Verify hub / selector routing can open the prior agreement for settlement while also opening the successor agreement for current operations. *(Workbench active vs settlement rows; renewal fork tile — E2E scenario `renewal_fork_visible`.)*

## 5. Android E2E QA (Maestro, debug Android)

Manual multi-device QA is **not** replaced; these scenarios automate **single-device hub gating** after programmatic seed + clock push (`docs/qa-android-e2e.md`).

- [x] 5.1 Scenario manifests + Maestro flows for settlement arc (`period_end_day`, `settlement_open`, `settlement_last_day`, `settlement_closed`).
- [x] 5.2 Seed postconditions + unit tests aligned with Maestro assertions (`qa_scenario_seed.dart`, `qa_scenario_seed_test.dart`).
- [x] 5.3 Orchestrator: `run_scenario.sh`, `run_all_scenarios.sh`, aggregated `index.html` report, manifest/semantics verification (`qa:verify`, `qa:run-all-scenarios`).

**Out of scope for E2E (still manual or future scenarios):** settlement **form submit**, multi-device sync, entitlement/trial clock on VPS.
