# Implementation tasks

## Delivery (2 PRs)

| PR | Passes | Goal |
|----|--------|------|
| **#1** | 1 + 2 | Data model, projection, proposal payload fields, full `ExpensePlanLineForm` (wizard may still use old steps until PR2 merges) |
| **#2** | 3 + 4 | Wizard cutover (4 steps), remove categories/split UI, cleanup, checklist |

---

## Pass 1 — Data model and transport (PR #1)

- [x] 1.1 Add `PlanRatioTemplates` table (`id`, `planId`, `displayTitle`, `weightsJson`, `createdAt`) and DAO helpers
- [x] 1.2 Extend `PlanLines`: `amountIsBudgetCap`, `paymentResponsibleParticipantId`, `recurrenceSpecJson`, `ratioTemplateId`; keep deprecated columns only for **local DB** backfill
- [x] 1.3 Drift migration v15+: backfill on device (`amountUsesRange` → `amountIsBudgetCap`; `recurrenceDayOfMonth` → `recurrenceSpecJson` where possible)
- [x] 1.4 Update `PlanProjection.unitMinor` for budget cap (high estimate for presentation chart; not min/max midpoint)
- [x] 1.5 Extend `PlanAgreementProposalService` payload JSON with new line fields when building proposals (**no legacy payload import** — plan export not implemented)
- [x] 1.6 Unit tests: template dedup by weight vector; budget cap projection; recurrence JSON round-trip

---

## Pass 2 — Extract super-component (PR #1)

- [x] 2.1 Create `mobile/lib/housing/expense_form/` module structure
- [x] 2.2 Implement `ExpenseSplitGrid` (correction row, row-local math, equal parts reset, save disabled on mismatch)
- [x] 2.3 Implement `ExpenseRatioTemplateRepository` (list, register on save, lookup by weights)
- [x] 2.4 Implement `LikeRatioSelector` (two-line items, blank row, clear on grid edit)
- [x] 2.5 Implement `RecurrenceRangePicker` + confirmation dialog (agreement-bounded range; hidden when not recurring)
- [x] 2.6 Implement `ExpensePlanLineForm` composing fields 1–12 per spec; wire save to DB (line + ratios + template; no `groupId` on save)
- [x] 2.7 Unit tests: split grid logic + recurrence spec (`housing_expense_*_test.dart`); widget tests optional follow-up
- [x] 2.8 Add l10n keys (EN/FR/ES): Name, Budgeted max, Payment responsible, All (default), Equal parts, Like, Split section, correction row

---

## Pass 3 — Wizard integration (PR #2)

- [x] 3.1 Reduce `_housingPlanStepCount` to 4; reindex agreement rules step
- [x] 3.2 Replace step 2 body with expense list (from old step 3); `+` navigates to `ExpensePlanLineForm` route
- [x] 3.3 Remove `_stepExpenseCategories`, category FAB, `_CategoryEditorDialog`
- [x] 3.4 Remove `_stepRatios` and related state (`_ratioParticipantIndex`, sliders, tick fractions, `_shareAmountControllers`, etc.)
- [x] 3.5 Update `_inferResumeStepIndex`, `_isHousingPlanWizardFullyDoneInDb`, footer Next validation (per-line ratios complete)
- [x] 3.6 Delete `_LineEditorDialog` / `_LineDraft` after form route works
- [x] 3.7 Update housing summary / presentation chart: one item per `PlanLine` (no group/template aggregation), budget cap semantics, drop category-step assumptions

---

## Pass 4 — Cleanup and conformance (PR #2)

- [x] 4.1 Stop writing `amountUsesRange`, `minAmountMinor`, `maxAmountMinor` on new saves
- [x] 4.2 Local DB: migrate or strip orphan **group-level** `PlanRatio` rows (draft plans on device only)
- [x] 4.3 Update `housing-plan-entry-spec-conformance-checklist.md` rows E1, E3, E7, E8
- [x] 4.4 Manual QA: add 3 expenses (equal, custom, Like), recurring confirm dialog, proposal payload fields on send — Maestro scenario `proposal_wizard_expenses` (`qa/flows/proposal_wizard_expenses.yaml`; seed `proposal_wizard_expenses`).
- [x] 4.5 Note notification + budget-threshold follow-up in `repo-maintenance-backlog` (active in-force flow)

---

## Deferred — active plan in-force flow (not PR #1 or #2)

Specified in `openspec/changes/housing-active-agreement-operations/`. Implementation tracked there and in `repo-maintenance-backlog`.

- [x] D.1 Wire `ExpensePlanLineForm` with `ExpensePlanLineFormScope` for accepted / in-force plans
- [x] D.2 Budgeted (max): confirmation dialog when a submitted expense exceeds the monthly cap
- [x] D.3 Notifications: designated payer vs default **All** (all participants: before-date + overdue reminders). *(Implemented in `housing-scheduled-payment-reminders`: `HousingPaymentReminderService`, relay cron, overdue journal card.)*
- [x] D.4 Define which fields are editable on an in-force plan vs proposal draft

---

## Verification checklist (acceptance)

- [x] Wizard shows 4 steps; no standalone categories or split steps
- [x] Expense form is full screen; dialog not used for add/edit
- [x] Approximate/min/max UI absent; Determined / Budgeted (max) works
- [x] Grid hidden without amount; correction row blocks save
- [x] Like selector appears after first non-equal expense; copying then editing clears Like
- [x] Recurrence range cannot exceed agreement period; confirm dialog required; calendar only when recurring
- [x] Proposal payload includes new fields when a proposal is built (no legacy import path added)

---

## Known bugs (backlog)

- [ ] **5.1 Bug (high / high recurrence): expense split weights ≠ 10000 bps can be saved; wizard catches late**  
  **Importance:** high. **Recurrence:** high (3-way / non-terminating percents + manual edits keep producing off-by-one bps vectors).  
  **Confirmed (2026-07-26):** Simulation housing wizard — five expenses listed; **Suivant** blocked with *La répartition de chaque dépense doit totaliser 100 %.* User could finish the per-expense form without a hard gate on `sum(weight) == 10000`.  
  **Repro artifact DB:** local snapshot `qa/db_seeds/plan-half-done` (gitignored; steal via `qa:db-snapshot-steal`).  
  **Failing line in that snapshot:** **Épicerie** (`line:1785079545095-52133596`) — exact `plan_ratios.weight` rows:  
  `…:self` = **0**, `…:p0` (Monica) = **6667**, `…:p1` (Ròberr) = **3334**, **sum = 10001** (not 10000). Other lines in the same snapshot sum to 10000.  
  **Detection commit (message clarity only — does not fix save gate):** [`7cc095155e3d14efec2a2df3699a8fd8351fb31c`](https://github.com/LouysPatriceBessette/bojairu/commit/7cc095155e3d14efec2a2df3699a8fd8351fb31c) — *Répartition de dépense NON 100% qui leak - bug identifié* (`housing_expenses_step_validation.dart` + distinct wizard snackbars).  
  **Manual repro recalled (expense form, three participants — matches Épicerie outcome):**  
  1. Auto split starts at ~**33.3…%** each (equal parts among three).  
  2. Set one participant to **0%**; set another toward **66.6%** (third keeps the remainder).  
  3. UI refuses save / continue (correction / mismatch). Try **66.7%** instead of 66.6%.  
  4. UI still refuses.  
  5. Adjust the **amount** (remove **4 cents** that were unbalancing the amount↔% grid math) → **UI accepts and saves**.  
  **Outcome:** form treated amount/percent grid as consistent enough to save, yet persisted bps were **0 / 6667 / 3334 = 10001**. Wizard **Suivant** is the first hard `sum == 10000` check; snackbar does not name which expense.  
  **Expected:** form save MUST refuse (or correct under an explicit product rule) any split whose basis-point weights do not total exactly 10000; amount tweaks MUST NOT bypass that invariant; wizard Next must not be the first place the user learns a prior expense is invalid; UI SHOULD identify **which** expense is wrong.  
  **Spec conflict:** `housing-expense-split-grid` — *Persist weights on save* (sum MUST equal 10000); tasks **2.2** / checklist *correction row blocks save* claimed mismatch blocked — incomplete when grid “looks” balanced but bps sum ≠ 10000.  
  **Likely area:** `expense_split_grid_logic.dart` (percent↔amount / Hamilton), `ExpenseLinePersistence.save`, form `_canContinue` / correction row; optional wizard list badge once save is fixed.  
  **Do not confuse with:** wizard snackbar wording alone (already improved in `7cc0951`); that only surfaces the late check.

- [x] **5.2 Bug (high / navigation trap): “Voir les dépenses en détail” had no in-app Retour**  
  **Confirmed (2026-07-26):** From plan summary / invite before submit, detail carousel opened correctly but AppBar had **no leading back** (only Android system back).  
  **Root cause:** `navigateToRoute` = `Navigator.pushReplacement` removed the parent from the stack → `ModalRoute.canPop == false` → default AppBar omits leading. Not a missing `IconButton`.  
  **Fix:** open `HousingProposalExpensesDetailScreen` with `navigateToChildRoute` (`push`) from `housing_plan_screen.dart` and `housing_invite_proposal_screen.dart` (active plan read-only already used child route). Docs on `app_navigation.dart` + skill `.cursor/skills/flutter-in-app-back-navigation/SKILL.md`.  
  **Forbidden workaround:** fake `leading: BackButton()` without fixing entry navigation.

- [ ] **5.3 Audit (minor / non-blocking): other `navigateToRoute` (`pushReplacement`) call sites — verify in-app back**  
  **Importance:** minor. **Blocking for closed-test / release:** no.  
  **Context (2026-07-26):** Inventory after bug **5.2**. Same API removes the parent from the stack; AppBar leading back only appears when `canPop` is true. Skill: `.cursor/skills/flutter-in-app-back-navigation/SKILL.md`.  
  **How to verify each row:** open via product UI → confirm content → leave with **in-app** chrome (AppBar back or explicit exit) → land on the expected parent. System back alone does **not** pass. If return is required and missing → switch entry to `navigateToChildRoute` (do not fake `leading` only).  
  **Priority A — detail / review openings (return likely expected):**

  | From | To |
  | --- | --- |
  | Monthly expenses list | Realized-expense review |
  | Rejected-expenses browse | Realized-expense review |
  | Realized-expense review list | Realized-expense review |
  | Realized-expense review | Form / another review / fullscreen image viewer |
  | Amendment line-edit preview | Line-edit detail |
  | Amendment journal | Amendment detail / participation-change detail |
  | Amendment submit preview | Detail route (replaces preview) |

  **Priority B — module / workbench transitions (replace often intentional; still confirm a visible exit):** workbench → plan / invite / active plan / archive; module entry → missing contacts / participation detail; archive / plan / amendment detail → invite or missing contacts; past-agreement entry → active plan; housing navigation intent (root); plan → invite after send.  
  **Also note (different layer):** `navigateTo` / `context.go` replace GoRouter location (home, contacts, housing, onboarding, sandbox exit). Settings children already use `navigateToChild`. Not the same API as `navigateToRoute`; still no automatic AppBar back onto the previous GoRouter location unless that stack allows it.  
  **Out of scope for this checkbox:** re-opening expenses-in-detail after **5.2** (already fixed).
