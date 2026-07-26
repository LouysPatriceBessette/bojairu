## 1. Sandbox prefs and bootstrap

- [x] 1.1 Add `sandboxMode` and `sandboxEnteredAt` preference accessors that survive DB wipe
- [x] 1.2 Branch `bootstrap.dart` to attach FakeRelay + start PeerSimulator when `sandboxMode` is true; keep HttpRelay otherwise
- [x] 1.3 Stub/disable entitlement active-use reporting and push/wake registration while sandbox is active
- [x] 1.4 Add release-visible, tappable Simulation ribbon overlay (do not rely on `debugShowCheckedModeBanner`)
- [x] 1.5 When ribbon is visible, reserve 40 px trailing AppBar clearance after the settings gear (home and any other top-right settings control that would collide)

## 2. PeerSimulator and FakeRelay runtime

- [x] 2.1 Promote/reuse `FakeRelayClient` for runtime sandbox (shared with tests or thin wrapper)
- [x] 2.2 Implement PeerSimulator with bot keypair store and auto-ack/auto-accept handlers for in-scope envelope kinds
- [x] 2.3 Ensure simulator posts via orchestrator/FakeRelay paths (no Drift-only accept shortcuts)

## 3. Enter / exit lifecycle and checkpoint

- [x] 3.1 Implement dual-verify checkpoint service (export → verify → fixed private copy → verify → wipe only if both OK)
- [x] 3.2 Implement enter-simulation orchestration (set prefs before wipe, then full restart / reopen instruction)
- [x] 3.3 Implement exit-simulation orchestration (wipe sim → import checkpoint if present → clear prefs → restart)
- [x] 3.4 Wire Simulation ribbon tap → exit dialog (« Sortir du mode simulation? », Annuler / Oui) → exit protocol on Oui
- [x] 3.5 Add ≥8h reopen nudge (dialog/notification; snackbar/dialog fallback if notifications denied) that can invoke exit
- [x] 3.6 Do not add a Settings-only “Exit simulation” row (ribbon + 8h nudge are the product exits)

## 4. Housing wizard entry UI

- [x] 4.1 Add ARB strings (FR/EN/ES) for Mode simulation, dialog body, Annuler/Simuler, Simulation ribbon, exit dialog (« Sortir du mode simulation? » / Oui), 8h nudge, bot expense tile, exhausted-catalog dialog
- [x] 4.2 Add orange Mode simulation button on `housing_plan_screen` step 1 same row as Next; gate on no real draft/active plan
- [x] 4.3 Wire dialog → enter-simulation orchestration

## 5. Sandbox Contacts invite

- [x] 5.1 Define ordered 7-bot catalog (Louys → Youkie) with random avatars from product pool
- [x] 5.2 Replace invite-code UI in sandbox with “add next bot” connected via PeerSimulator
- [x] 5.3 Show Ok-only exhausted-catalog dialog when all seven bots are present
- [x] 5.4 Gate external code generate/redeem paths with sandbox hard checks

## 6. Sandbox Housing hub and modules

- [x] 6.1 Disable (visible) major-change hub tile and block deep links into major-change flows in sandbox
- [x] 6.2 Keep minor “Modify the plan” enabled; rely on PeerSimulator auto-accept
- [x] 6.3 Add orange bot-expense tile above Submit expense (after section divider); one-shot B1 into review queue + local notification; amount = share × {1.0, 0.5, 1.5}; no photo
- [x] 6.4 Disable Vehicle and Vehicle sharing module-home tiles while sandbox (visible)
- [x] 6.5 Block Settings device export/import UI in sandbox (lifecycle checkpoint remains internal-only)

## 7. Tests and verification

- [x] 7.1 Unit/widget tests: prefs survive wipe mock; catalog order; exhausted dialog; entry gate with draft/active plan
- [x] 7.2 Harness tests: FakeRelay + PeerSimulator auto-accept proposal; bot expense appears in review queue
- [x] 7.3 Tests: checkpoint dual-verify refuses wipe on bad copy; exit restores checkpoint
- [x] 7.4 Run `cd mobile && ./tool/flutterw analyze --fatal-infos .` and `./tool/flutterw test` until green
- [x] 7.5 Manual QA PASSED (2026-07-16, Android): add sandbox bot contacts (catalog invite) through connected peers
- [x] 7.6 Manual QA PASSED (2026-07-16, Android): housing plan submit through unanimous acceptance (OS notifications: 3× #7 + 1× #9 in causal order; simulation exit without crash)

---

## Known bugs (backlog)

- [x] **S.1 Bug (high / sandbox): cold restore aborted all bots when one catalogue contact was not `connected`**  
  **Importance:** high (blocks simulation auto-accept after process restart). **Recurrence:** high whenever a catalogue bot was disconnected/deleted while `sandboxInvitedBotCount` still counted it.  
  **Confirmed (2026-07-26):** Simulation — plan submitted; invitee chips stayed **En attente**; no decision/activation OS notifications. Not a notification-permission issue.  
  **Evidence DB:** `qa/db_seeds/plan-half-done` — Louys catalogue bot soft-deleted / `local-only` + disconnected (`sandbox-bot-0`); Monica + Ròberr still `connected`; prefs `sandbox.invitedBotCount = 3`; plan roster only Monica/Ròberr.  
  **Root cause:** `PeerSimulator.restoreInvitedBotsIfNeeded` required a matching **connected** human contact for **every** catalogue index `0..count-1`. First miss (Louys) aborted and tore down prior restores → **0 bots** after cold start (`run:dev` / process death). FakeRelay could still receive proposals; nobody auto-accepted.  
  **Fix:** skip catalogue slots without a connected match; restore remaining bots; keep high-water `sandboxInvitedBotCount` for next invite (next name = next catalogue slot, e.g. Liuva); seed identity by catalogue index. Unit test: `restoreInvitedBotsIfNeeded skips disconnected catalogue bots and keeps connected`.  
  **Manual confirm (2026-07-26):** user retest after fix + restored stolen DB — bots accept again; steal/restore path OK.  
  **Implications when `_bots` stayed empty after cold start (same root):** all PeerSimulator-driven peer actions fail silently or stall — not only initial plan submit.

  | Surface | What breaks with 0 bots |
  | --- | --- |
  | Housing plan / amendment send | Envelopes may post to FakeRelay; invitee chips stay **En attente**; no #7 / #9 |
  | Realized-expense review (human payer opens detail) | `_scheduleSandboxBotReviewsOnOpenIfHumanPayer` returns early if `sim.bots.isEmpty` — reviewers stay « ? » with empty dates; no bot-accept local notifications |
  | After human accept/reject on a bot expense | `_scheduleSandboxBotExpenseReviews` same empty-bots early return |
  | Hub « Simuler une dépense d'un Bot » | `sandbox_bot_expense.dart` refuses / cannot pick a bot |
  | `reactOnce` / inbox reactions | No-op (`bots=0`) |
  | Contacts « Invite someone » | Still works (spawns new catalogue slot via high-water count) once fix is present |

  **Do not confuse with:** master notification switch off (would silence #7/#9 even when accepts land); that was ruled out by **En attente** / empty decision dates.

- [x] **S.2 Bug (high / sandbox): co-reviewer bot stays « ? » on bot-payer expense after human accept when payer bot row is gone**  
  **Importance:** high (blocks unanimous expense settlement in Simulation). **Recurrence:** high after cold restore (`run:dev` / process death) when a bot-proposed expense still sits on the human DB but bot sqlite was recreated empty.  
  **Confirmed (2026-07-26):** Révision de dépense — Monica payer (« Dépense simulée »); Louys accepted with timestamp; Ròberr stayed yellow « ? » with empty date.  
  **Root cause:** `_expenseProposeSource` only used a bot DB that still held the payer row, or the human DB when the **human** was payer. After restore, neither bot had the expense → backfill aborted (`no payer source`) → peer never accepted. Secondary gap: bot already accepted locally but human never got the decision was not re-sent.  
  **Fix:** backfill from the human copy of a bot-payer expense using the payer bot’s long-term key as synthetic sender; treat missing local acceptance as needs-accept; re-send when the human review table still awaits that bot. Unit test: `bot-payer expense missing on bots after wipe backfills from human copy`.  
  **Manual confirm:** pending (rebuild / retest after S.2).

- [x] **S.3 Bug (high / sandbox): human-payer expense bots stay pending after cold restore — no local active agreement**  
  **Importance:** high (blocks bot auto-accept of the human’s own expense after `run:dev` / process restart). **Recurrence:** every cold restore while an active housing plan remains on the human DB.  
  **Confirmed (2026-07-26, `mobile/terminal.log`):** `PeerSimulator restore end bots=2`; review sequence ran with `humanAwaits=true`; both Monica and Ròberr logged `import skip: no local active agreement for package=pkg:housing:…` then `skip: missing expense after backfill`.  
  **Root cause:** restore recreates empty bot sqlite; FakeRelay is in-memory and loses prior proposal envelopes. Bots have contacts only — no `received:<uuid>` agreement. Expense backfill from the human copy still called `importProposedFromPeer`, which requires a local active package. `_ensureBotHousingPlanActive` could only repair pending/peer mirrors, not clone from the human.  
  **Fix:** when peer mirror fails, export the human’s active agreement for that bot’s roster slot, `importReceivedProposal` onto the bot, force-activate, then continue expense backfill/accept. If a later bot sees a peer `activeRevisionId` but lacks the local revision row (ordering after the first bot’s human mirror), fall through to the same human clone instead of aborting — terminal evidence: Monica OK, Ròberr `cannot peer mirror … missing revision` then `no local active agreement`. Unit test: `human-payer expense after cold empty bot mirrors agreement then accepts` (two bots).  
  **Manual confirm:** pending (rebuild; reopen expense review — both bots).