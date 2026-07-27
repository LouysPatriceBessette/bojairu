# Housing + Contacts simulation mode

## Why

Closed-test and free-preview users often have **no second human partner**. Without a solo path, they cannot exercise Contacts and Housing UI (proposal, activation, expenses, balances/charts). A labeled **simulation mode** with local bot peers and an in-process fake relay lets one device run that surface area without production relay traffic, while remaining free and clearly distinct from paid real-mode usage.

## What Changes

- Persist a **`sandboxMode`** flag (survives DB wipe) and bootstrap **FakeRelayClient** + **PeerSimulator** when active (no HTTP to production relay; entitlement active-use reporting off/stubbed; no push/wake registration).
- **Enter simulation** only from Housing plan wizard **step 1** (participants): orange **Mode simulation** button → confirm dialog → **Simuler** (gate: unavailable when a real housing plan draft or active plan exists).
- On enter: if real data must be preserved for return, **export → integrity verify → fixed internal second copy → verify → wipe** (wipe never shown as a user “Reset DB” product action).
- Cold start with sandbox + empty DB: auto-seed bot catalog machinery; seed bots as the user invites them (**no** user “seed” / Maestro-only step).
- **Contacts in sandbox**: no external invite codes/QR; **Invite someone** adds the next catalog bot as a `connected` contact (crypto-valid path through orchestrator/FakeRelay). Max **5** bots (fixed ordered names: Louys → Leo). Catalog exhausted → Ok-only dialog. Bots **auto-accept** handshake/proposal/minor amendment/expense responses as applicable.
- **Housing in sandbox**: proposal → activation; minor plan amendments enabled (bots auto-accept); **major participation change** hub tile **disabled** (visible); Settings device export/import **blocked**. Orange hub tile **Simuler une dépense d'un Bot** one-shot → fake inbound expense into **review queue** + local notification (B1). Amount = bot’s share of a random plan line × random **100% / 50% / 150%**; **no photo**.
- Home module tiles **Vehicle** and **Vehicle sharing**: visible, **disabled**.
- Global **Simulation** ribbon (release-visible, Debug-banner position/style; not reliant on `debugShowCheckedModeBanner`). Ribbon is **tappable**: dialog « Sortir du mode simulation? » with **Annuler** / **Oui**; **Oui** exits. When visible, reserve **40 px** trailing clearance right of the settings gear so the ribbon does not block it.
- After **≥ 8 hours** since `sandboxEnteredAt`, on reopen: nudge to return to real mode (missed real invitations risk). Copy also in entry dialog.
- **Exit simulation**: wipe sim DB + import fixed checkpoint if present; clear sandbox flag (triggered from ribbon dialog and from the 8h nudge).
- **Out of scope**: Vehicle / vehicle sharing simulation; major change subtree; payment reminders / relay expiry (even simulated); device wake / push; portability **from** sandbox; coexistence of real+sim in one DB; re-entry to sim after a real plan (MVP); Google Play 12×14 compliance itself (bots ≠ human testers).

## Capabilities

### New Capabilities

- `sandbox-mode-lifecycle`: Flag, enter/exit protocols, invisible wipe, fixed checkpoint, cold-start bootstrap, Simulation banner, 8-hour return nudge, hard gates for out-of-scope actions.
- `sandbox-bot-peers`: FakeRelay + PeerSimulator, fixed 5-bot catalog, invite-without-code, auto-accept policy, catalog-exhausted dialog.
- `sandbox-housing-operations`: Housing wizard entry affordance, active-hub bot-expense tile (B1), hub/module tile enablement matrix in sandbox, minor amendments on / major change off.

### Modified Capabilities

- `contact-invitation-and-codes`: When sandbox is active, the invite entry point MUST NOT mint/show external invitation codes; it adds a catalog bot instead (or shows the exhausted-catalog dialog).
- `device-data-import-restore`: When sandbox is active, user-initiated device export/import MUST be blocked (checkpoint copy remains an internal lifecycle step only).

## Impact

| Area | Impact |
|------|--------|
| `mobile/lib/bootstrap.dart` | Wire FakeRelay when `sandboxMode` |
| `mobile/lib/relay/testing/fake_relay_client.dart` | Promote/reuse for runtime sandbox (not tests-only) |
| New PeerSimulator / sandbox services | Bot keypairs, auto-responses, expense one-shot |
| `housing_plan_screen.dart` | Step-1 Mode simulation button + dialog + gate |
| `housing_active_plan_screen.dart` | Bot expense tile; major-change disabled |
| Contacts invite UI / flows | Bot add; no code UI in sandbox |
| Settings / portability | Disable export/import in sandbox; AppBar trailing clearance when Simulation ribbon visible |
| Simulation ribbon | Overlay + exit-confirm dialog on tap |
| Prefs | `sandboxMode`, `sandboxEnteredAt`, checkpoint path convention |
| `db_reset.dart` | Internal wipe for mode switches only |
| Entitlement / FCM | Off or stubbed in sandbox |
| Relay / VPS | **No** relay source change required |
| Platforms | Android + iOS code parity; iOS QA deferred; web dev out of product scope |
