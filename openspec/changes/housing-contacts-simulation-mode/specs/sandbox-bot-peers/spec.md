## ADDED Requirements

### Requirement: PeerSimulator drives bot crypto identities on FakeRelay

When sandbox mode is active, the application SHALL run a PeerSimulator that owns cryptographic material for catalog bots and exchanges envelopes through the in-process FakeRelay so that `HandshakeOrchestrator` encrypt/post/inbox/import paths remain the authority for contact connection and housing peer messages. The simulator MUST NOT write housing or contact acceptances by bypassing those paths with ad-hoc Drift mutations.

#### Scenario: Bot appears as connected contact through transport
- **WHEN** the user invites the next catalog bot in sandbox
- **THEN** a contact row reaches `connected` with valid peer public material
- **THEN** the connection was completed via FakeRelay-mediated handshake (or equivalent orchestrator-complete path), not a silent Drift-only stub without crypto

### Requirement: Fixed ordered bot catalog of five

The sandbox bot catalog SHALL contain exactly these display names in order: Louys, Monica, Ròberr, Liuva, Leo. Avatars SHALL be chosen from the product avatar pool (stable unique ids per catalog index in implementation). The application SHALL NOT create more than five bots for a sandbox session. Germaine and Youkie SHALL NOT be in the catalog (ANR risk with 7–8 in-process peer stacks).

#### Scenario: First invite yields Louys
- **WHEN** no bots have been invited yet and the user invites someone in sandbox
- **THEN** the added bot is named Louys

#### Scenario: Cap at five bots
- **WHEN** five bots are already present and the user attempts another invite
- **THEN** no sixth bot is created

### Requirement: Invite someone adds the next bot without invitation codes

In sandbox mode, the Contacts “Invite someone” entry point SHALL NOT display or mint an external invitation code or QR for human redeem. It SHALL add the next unused catalog bot as a connected contact. Bots SHALL auto-accept subsequent in-scope connection and housing peer decisions (plan proposals, minor amendments, and peer-side expense decisions where a bot is the actor).

#### Scenario: Invite skips code UI
- **WHEN** the user taps Invite someone in sandbox with catalog capacity remaining
- **THEN** no invitation code or QR screen is shown for that invite
- **THEN** the next catalog bot appears as a connected contact

#### Scenario: Bots auto-accept housing proposal
- **WHEN** the human sends a housing plan proposal to connected bots
- **THEN** each bot peer responds with acceptance through the FakeRelay path without human action on a second device

### Requirement: Exhausted catalog shows Ok-only dialog

When all five catalog bots have already been invited and the user attempts Invite someone again, the application SHALL show a dialog with a single Ok action. The FR message SHALL be “Vous avez invité tout les bots.” (localized equivalents in EN/ES). No additional bot SHALL be added.

#### Scenario: Exhausted catalog dialog
- **WHEN** five bots are invited and the user taps Invite someone
- **THEN** the Ok-only dialog appears with the exhausted-catalog message
- **THEN** the contact list still contains exactly five bots
