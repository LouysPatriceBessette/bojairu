## Context

Bojairũ production clients use `HttpRelayClient` + `HandshakeOrchestrator` for Contacts handshakes and Housing steady-state envelopes. Unit tests already exercise multi-identity flows with `FakeRelayClient` (`mobile/lib/relay/testing/fake_relay_client.dart`). Product simulation mode must reuse that seam so UI, crypto, inbox import, and review queues behave like real multi-device use — without production relay traffic or a second human.

Users need a labeled free sandbox (Play closed-test retention + unpaid preview). Real and sandbox data MUST NOT coexist in one Drift DB. Entry is gated by absence of a real housing plan (draft or active). Exit restores a fixed internal checkpoint when one was created on enter.

Constraints: no `Timer.periodic` for bot expenses; wipe must never appear as a production “Reset database” feature; Android + iOS parity (iOS QA deferred); web is dev-only and out of product sandbox scope unless explicitly revisited.

## Goals / Non-Goals

**Goals:**

- Persist `sandboxMode` + `sandboxEnteredAt` across wipe; bootstrap FakeRelay + PeerSimulator when sandbox.
- One-click enter from Housing wizard step 1; safe checkpoint → wipe; cold-start seed of sandbox transport; bot invite/auto-accept; housing proposal + minor amendments + B1 bot expense into review queue; clear Simulation chrome and 8h nudge; hard gates for Vehicle, major change, portability, push/reminders.

**Non-Goals:**

- Simulating Vehicle / vehicle sharing / major participation-change flows.
- Simulated payment reminders, relay expiry, FCM/wake.
- Export/import **from** sandbox as a user feature.
- Coexistence of real + sim DBs; re-entering sim after a real plan (MVP).
- Replacing Google Play’s 12 human × 14-day closed-test rule.
- Fixing SVG balance overflow for >8 participants (mitigated by max 5 bots).
- Relay Go service changes.

## Decisions

### D1 — PeerSimulator behind FakeRelay (not Drift shortcuts)

**Choice:** Runtime uses `FakeRelayClient` (or thin production wrapper over the same in-memory inbox) plus a `PeerSimulator` that holds bot installation keypairs and posts encrypted replies through the same orchestrator path as real peers.

**Why:** Preserves inbox import, notifications, and review queues. Avoids drift from production when handlers change.

**Alternatives considered:** Direct Drift writes for “accepted” — rejected (bypasses crypto/routing; diverges from product).

### D2 — Prefs survive wipe; DB does not

**Choice:** `sandboxMode` and `sandboxEnteredAt` live in SharedPreferences (or equivalent) that survive `DbReset`. Operational data lives only in Drift and is wiped on mode switches.

**Why:** Bootstrap must know to attach FakeRelay before seed even when DB is empty.

### D3 — Enter / checkpoint protocol

**Choice:** On **Simuler**:

1. If local operational data should be restored later (non-empty DB worth preserving): run existing export → decode/verify (same integrity as import stage) → copy to **fixed** private app path (e.g. application-support `sandbox_real_checkpoint.bundle` — exact name in implementation) → re-verify second copy → wipe only if both OK.
2. Write `sandboxMode=true`, `sandboxEnteredAt=now` **before** wipe when ordering requires flag-first (flag before wipe is mandatory so post-restart bootstrap enters sandbox).
3. Full process restart after wipe (`DbReset` existing behavior); prefer auto-relaunch if reliable on platform, else “reopen the app” message.

If DB is already empty / no preservable real data: set flags and restart into FakeRelay without checkpoint.

**Why:** Dual verified copies remove “lost export file” risk while keeping portability codepaths.

### D4 — Solo UI entry at plan wizard step 1

**Choice:** Only entry control: orange **Mode simulation** left of **Next** on `_stepIndex == 0` in `housing_plan_screen.dart`. Unavailable when any real housing plan exists (draft or active). Dialog copy + Annuler / Simuler as product-frozen FR (ARB + EN/ES).

**Why:** Product decision superseding earlier “post-onboarding / real contact blocks” UX gate.

### D5 — Exit via Simulation ribbon tap

**Choice:** Primary exit affordance is a **tap on the Simulation ribbon** (top-right). Tap opens a confirm dialog: body **« Sortir du mode simulation? »** (localized); actions **Annuler** / **Oui**. **Oui** runs the exit protocol. Secondary: 8-hour reopen nudge may offer the same exit. There is **no** dedicated Settings “Exit simulation” row. Entry dialog warns about 8h; does not itself exit.

**Why:** Product decision filling the former open hole; ribbon is always visible in sandbox and co-located with awareness chrome.

### D6 — Bot catalog and invite

**Choice:** Ordered catalog (max **5**): Louys, Monica, Ròberr, Liuva, Leo (`SandboxBotCatalog.maxBots = 5`). Stable unique avatars per catalog index. Invite = instantiate next unused bot identity → connected contact via FakeRelay hello/ack (or equivalent orchestrator-complete path). No invite-code UI. Exhausted catalog → Ok-only dialog (“Vous avez invité tout les bots.” / localized). Germaine and Youkie are **out** of the catalog.

**Why:** Simplifies Contacts for sandbox; caps in-process peer stacks. Product cut from seven → five after ANR at 7–8 concurrent bot stacks; code and tests assert five names and exclude Germaine/Youkie.

### D7 — Auto-accept policy

**Choice:** Bots accept all in-scope peer decisions: connection, plan proposals, minor amendments, expense review responses when they are the peer actor. Human still reviews inbound bot expenses (B1).

### D8 — Bot expense one-shot (B1)

**Choice:** Hub tile above “Submit expense”, after existing section divider. Orange housing color. Two-line label. No form. Select random connected bot + random plan line; amount = bot line share × {1.0, 0.5, 1.5}; no proof photo; post envelope through FakeRelay → existing review queue + local notification.

**Why:** Explicit user trigger; no scheduler; exercises balances/charts.

### D9 — Hard gates beyond hidden UI

**Choice:** `sandboxMode` checks on out-of-scope actions (major change navigation, Vehicle entry, Settings export/import, external invite code mint, entitlement active-use report, push registration) — fail closed with feedback, not only disabled widgets.

### D10 — Simulation ribbon (chrome + hit target + AppBar clearance)

**Choice:** Custom overlay/banner mimicking Debug ribbon position (top-right), text **Simulation**, shown whenever sandbox is active — including release/Play builds. Do not rely solely on `debugShowCheckedModeBanner`. The ribbon is **tappable** (see D5). Because it overlaps the same corner as the home AppBar settings (gear) action, when the ribbon is visible the settings action area SHALL reserve **40 logical pixels** of trailing clearance to the right of the gear (starting value; adjust if QA finds occlusion). That clearance applies on surfaces that show both the ribbon and a top-right settings (or equivalent trailing) control.

### D11 — Entitlement / licensing in sandbox

**Choice:** Do not call production entitlement for active-use / trial start from sandbox expense sync. Do not treat sandbox activity as paid real-mode usage. Free simulation is product intent independent of store subscription.

### D12 — Localization

**Choice:** FR copy from product notes is canonical intent; apply minor spelling fixes (`totalement`, `aperçu`, `vraie`, `rester`, `réel`, `tous`) in ARB FR if product accepts at implement time; ship EN/ES translations in same change.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| User stays in sandbox and misses real peer invites | Entry warning + 8h reopen nudge + Simulation ribbon |
| Checkpoint missing on exit | Refuse wipe-enter unless dual verify OK; exit without checkpoint → wipe sim + clear flags only |
| FakeRelay diverges from HttpRelayClient API | Keep implementing against `RelayClient`; share test FakeRelay |
| Accidental wipe exposed in Settings | No production Reset DB; wipe only inside enter/exit services; exit via ribbon dialog + 8h nudge only |
| Ribbon occludes settings gear | 40 px trailing AppBar clearance when ribbon visible (D10) |
| Bot expense without active plan / lines | Hub unreachable then — no extra hub gate |
| Restart after wipe flaky auto-relaunch | Prefer simple “reopen app” if relaunch unreliable |
| Release builds hide Simulation chrome | Custom ribbon required (D10) |

## Migration Plan

1. Ship behind feature complete for Android closed test; iOS compiles with parity (QA deferred).
2. No DB schema migration required for flag (prefs). Checkpoint file is new private storage artifact.
3. Rollback: remove sandbox entry button / ignore `sandboxMode` and force real bootstrap (or document one-time prefs clear). No relay deploy.

## Open Questions

None blocking. Non-blocking: exact EN/ES ARB strings (implementer proposes); exact checkpoint filename constant; auto-relaunch vs manual reopen per platform reliability during implementation; whether 40 px trailing clearance needs tuning after device QA.
