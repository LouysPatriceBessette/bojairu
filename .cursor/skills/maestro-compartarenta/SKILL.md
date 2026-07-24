---
name: maestro-compartarenta
description: >-
  Write and maintain Bojairũ Android Maestro YAML flows, multi-device
  coordinators, and qa-* semantics. Use when editing qa/flows, qa/multi_scenarios,
  tool/coordinators, housing_proposal or contact_handshake scenarios, Maestro
  probes, or docs/qa-android-e2e.md. Do NOT use Patrol for this repo's QA
  toolchain. Pair with maestro-e2e for generic Maestro syntax and Maestro MCP
  for live emulator inspection.
---

# Maestro QA — Bojairũ

This repository uses **Maestro YAML + shell coordinators**, not Patrol (`patrol_test/`).

## Before any edit (mandatory)

1. Read **`.cursor/skills/maestro-scenario-avoid-carpet-tripping/SKILL.md`**
   — mandatory for **any** new or extended scenario (code-first workflow,
   anti-blind-YAML, no vandalizing shared flows).
2. Read **`docs/qa-android-e2e.md`** (Maestro section + semantics table).
3. Read the **reference coordinator** and manifest for the scenario you extend
   (e.g. `tool/coordinators/housing_proposal.sh` + `qa/multi_scenarios/*.yaml`).
4. **Grep** existing flows for the same surface — reuse `_*.yaml` helpers; do not
   invent parallel patterns.
5. State in one sentence: **symptom**, **role/device**, **repro vs fixed** (see
   `.cursor/rules/qa-scenario-reference-and-objective-discipline.mdc`).

## Maestro MCP (when emulators are running)

Project MCP: `.cursor/mcp.json` → `tool/maestro_mcp.sh` → `maestro mcp`.

**Use MCP before committing new selectors or navigation:**

1. `list_devices` — confirm `emulator-5554` / `emulator-5556` (Louys-QA / Monica-QA).
2. Inspect hierarchy on the **same screen** the flow will assert.
3. Run the draft flow with `--udid <serial>` before editing coordinators.

MCP validates **single-device** flows. Multi-device timing stays in bash coordinators.

## Bojairũ conventions (high error rate — do not skip)

### Semantics (`qa-*`)

- Maestro uses **`Semantics.identifier`**, not Flutter `Key`.
- Every new `id:` in YAML must exist in Dart (`mobile/lib/**`) or the edit is invalid.
- Run before delivery: `python3 tool/verify_qa_semantics.py` (must exit 0).
- Prefer **`id:`** over `text:` for list rows, FABs, wizard steps, dialogs.

### Text vs input

- **`inputText`**: ASCII only — no accented characters in typed values.
- **`tapOn` / `assertVisible` text**: French UI labels OK (seeds use `fr`).
- Text selectors are **full-string regex** — use `.*substring.*` for partial match.

### Contacts / handshake navigation

After inviter **generate**, handshake complete pops to **Codes d'invitation**, not Contacts.

Pattern for **invitee** flows that need Contacts:

```yaml
- runFlow:
    file: _return_to_contacts_list.yaml
- extendedWaitUntil:
    visible:
      id: "qa-contacts-redeem-open"   # contacts list only
    timeout: 45000
```

`_return_to_contacts_list.yaml`: one `back` when `qa-contacts-invite-fab` is not visible; wait `qa-contacts-invite-fab`.

**Inviter duplicate dialogs** (merge / anchor reject): **wait dialog → Ok first** (dialog may overlay
the invite screen), then `_navigate_inviter_to_contacts_list.yaml`, then assert peer row. Do **not**
navigate before Ok — `_navigate_inviter_to_contacts_list` will fail on `qa-contacts-invite-fab` while
the modal is open.

Duplicate handshake dialogs render only on **`ContactsListScreen`** — never assert
dialog ids while still on invitation screens.

### Notifications in QA flows

Use **`_accept_notification_prompt.yaml`** — taps only when visible (`when:`), with exact
**fr** strings from `app_fr.arb`:

- In-app: `Oui, les activer et continuer` (`notificationFlowPermissionEnableAction`)
- Android system (FR emulator): `Autoriser`

Do **not** use blind `optional: true` taps on `Autoriser` / `AUTORISER` / `Allow` — they add
WARNED steps when permission is already granted.

### Duplicate contact probes (bug 1.22)

- One `assertVisible` without **`index`** passes if **any** row matches — wrong for duplicates.
- Repro: `qa-contacts-row-monica-qa` at **`index: 1`** and/or banner
  `qa-contacts-duplicate-connected-monica-qa`.
- Clean: `assertNotVisible` on `index: 1` + banner absent.
- Probe flow **expects** symptom visible (maestro fails → coordinator: symptom absent).

### Orchestrator final status (single- and multi-device)

On a **successful** end-to-end run, the shell entry point **must** echo a final
line that contains **`PASSED`** and the scenario id (e.g.
`Scenario PASSED | <id>` or `Test PASSED | <id>`). Do not use only `complete` /
`Done` without `PASSED`. See
`maestro-scenario-avoid-carpet-tripping/SKILL.md` (orchestrator success line).

### Multi-device coordinators

- **Sequential handshake only**: inviter `generate` → export code → invitee `redeem`.
  No parallel `inviter-standby` + `invitee-redeem` unless user-approved exception.
- **Roles**: Monica-QA = proposer (web/Android per manifest), Louys-QA = recipient —
  read `session-test-topology-bootstrap.mdc` before operational steps.
- Coordinator functions (`_run_proposal_happy_path_once`, `_connect_handshake_sequential`)
  are the source of truth — align new modes by **grep diff**, not copy-paste fragments.

### appId and device

Every flow:

```yaml
appId: app.incoherences.bojairu.dev
```

Maestro runs with `--udid <serial>` from coordinators — never assume a single device.

## Workflow (write or extend a scenario)

| Step | Action |
|------|--------|
| 1 | Read manifest + reference coordinator mode branch |
| 2 | List shared subflows already used (`qa/flows/_*.yaml`) |
| 3 | Add or extend YAML; reuse helpers |
| 4 | Add Dart `qa-*` only when necessary (debug semantics) |
| 5 | `python3 tool/verify_qa_semantics.py` |
| 6 | Run targeted scenario: `./tool/melosw run qa:run-multi-scenario -- <id>` |

Do **not** edit product logic to “fix” a scenario unless the bug is proven in app
code — see `no-probability-coding.mdc`.

## Key paths

| Path | Role |
|------|------|
| `qa/flows/*.yaml` | Maestro steps |
| `qa/flows/_*.yaml` | Shared subflows |
| `qa/scenarios/*.yaml` | Single-device manifests |
| `qa/multi_scenarios/*.yaml` | Multi-device manifests |
| `tool/coordinators/*.sh` | Orchestration, drift, probes |
| `mobile/lib/debug/qa_*_semantics.dart` | Identifier constants |
| `tool/verify_qa_semantics.py` | YAML ↔ Dart gate |

## Generic Maestro syntax

Load **`.cursor/skills/maestro-e2e/`** for commands, `runFlow`, `when:`, waits,
permissions, Flutter `Semantics.identifier` patterns.

## Patrol

**Out of scope** for Bojairũ QA unless the user explicitly migrates to Patrol.
Do not generate `patrol_test/` or `patrolTest` when the task is Maestro/coordinator work.

## Delivery checklist

- [ ] Referenced coordinator + manifest read this session
- [ ] Reused existing `_*.yaml` helpers where applicable
- [ ] No duplicate-row assert without `index: 1` when testing duplicates
- [ ] Inviter post-handshake navigation uses `_return_to_contacts_list` when needed
- [ ] `verify_qa_semantics.py` passes
- [ ] Success path prints an explicit **`PASSED | <scenario-id>`** (or equivalent containing `PASSED`) log line
- [ ] No Patrol artifacts introduced

See [reference.md](reference.md) for helper catalog and common flows.
