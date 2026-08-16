> **Status:** Client-side implementation complete for Sections 1–5 (including
> peer-appearance matrix **4.1**, already manually tested). Appearance notices
> reuse encrypted `profile_update` (`how_i_label_you`); documented in
> `docs/contacts-module-relay-payload.md` § 5.3 (tasks **6.1–6.2**, **7.1–7.3**).

## 1. Data model

## 1. Data model

- [x] 1.1 Add persisted fields (or a sibling table) for **local display label** per Contact, distinct from canonical name fields updated from the relay.
- [x] 1.2 Persist last-known **canonical** peer name and avatar separately from local label; migrate existing rows conservatively.
- [x] 1.3 Add a durable flag or derivation rule for **Disconnected** presentation (ex-`connected` without routing vs never-connected stub).

## 2. Settings — self identity

- [x] 2.1 Settings UI: edit display name with the same validation as onboarding.
- [x] 2.2 Settings UI: edit avatar from the supported palette.
- [x] 2.3 Wire saves to existing profile-update broadcast for connected peers.
- [x] 2.4 Block self **display-name** save and name-bearing `profile_update` broadcast while the local user is on roster for an open housing vote (`housing-plan-proposal-offer-flow` / task **1.24**); avatar-only edits remain allowed.

## 3. Contacts UI

- [x] 3.1 List + detail: show **Disconnected** where applicable; remove misleading “local only” copy for demoted peers.
- [x] 3.2 Detail: **Request reconnection** routes to invitation flow; contextual copy for reconnect.
- [x] 3.3 Detail / overflow: edit **local display label** only; clarify copy that this is “how you see them”.
- [x] 3.4 Remove or repurpose any legacy path that edits a peer’s name as if it were canonical identity.

## 4. Profile — peer view matrix

- [x] 4.1 Profile screen: **How others label you** compact table (columns: contact, their label for me). *(Product copy: EN `settingsProfileAppearancesTitle` / FR « Comment les autres vous nomment » — not “how I appear to others”.) **Won't do further (2026-07-13):** already implemented and manually tested.*
- [x] 4.2 Ingest appearance notices (or equivalent) to populate the matrix; handle offline / TTL drops gracefully. *(Inbound `how_i_label_you` on `profile_update` → `Contacts.theirLabelForMe`; omitted key does not clear a prior notice.)*

## 5. Notifications — canonical name changes

- [x] 5.1 On inbound profile-update changing peer canonical name, compare to local display label; implement silent match vs prompt with **Align** / **Keep my label**.
- [x] 5.2 Localization for all new strings (EN baseline per repo rules; FR/ES follow `ui-localization-fr-en-es`).

## 6. Relay / crypto

- [x] 6.1 Define or extend encrypted envelope type for **appearance notices** (informational only), with schema versioning and rejection of malformed payloads. *(Extended `profile_update` / kind `0x03`, framing `0x01`; optional `how_i_label_you`; non-string rejected as `EnvelopeDecryptionError`.)*
- [x] 6.2 Document payload in `docs/contacts-module-relay-payload.md` (or successor) once shape is fixed. *(§ 5.3, 2026-08-16.)*

_Client-side handling of existing `profile-update` envelopes (canonical rename vs local label, dialog) is implemented in the app; appearance-notice traffic is the optional `how_i_label_you` field on that same kind — not a new relay envelope kind._

## 7. Tests

- [x] 7.1 Unit tests: effective name resolution (override, clear, missing canonical). *(`contact_display_test.dart`, `contacts_repository_test.dart`.)*
- [x] 7.2 Unit tests: scenario F branching (equal vs unequal override). *(`contact_appearance_notice_test.dart`.)*
- [x] 7.3 Widget or integration tests: Settings save triggers profile-update fan-out (mock relay). *(`broadcastProfileUpdate` on `HandshakeOrchestrator` with `FakeRelayClient` — same path Settings → prefs listener uses.)*
