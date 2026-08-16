## ADDED Requirements

### Requirement: Proposal deadline reminders use relay cron instead of local scheduling

The system SHALL **not** rely on on-device local notification scheduling for housing proposal **response deadline** reminders (`housing-plan-proposal-offer-and-responses` task 1.4b). Instead, the relay cron defined in `relay-scheduled-notification-jobs` SHALL fire deadline reminders.

When the author **dispatches** an open `revisionId`, the author's client SHALL register relay fire rows using **recipe A** (same lead times as contacts invitation expiry): `before_expiry` to participants who must respond, and `expired` at `expiresAt` to the author if still unanswered. When the revision is **invalidated**, **expired**, or the user responds, the registering client SHALL cancel pending fires for that `revisionId`.

#### Scenario: Dispatch registers deadline fires

- **WHEN** the author dispatches a housing proposal revision with `expiresAt` set
- **THEN** the author's client upserts relay scheduled fires for deadline reminders before `expiresAt`

#### Scenario: Response cancels pending deadline fires

- **WHEN** a recipient submits a response for `revisionId` R
- **THEN** pending deadline fires for R are cancelled on the relay

---

### Requirement: Contacts invitation expiry reminders use relay cron instead of local scheduling

The system SHALL **not** rely on on-device local notification scheduling for outgoing **invitation expiry** notifications (`contacts-module` task 3.7 and the Settings category for unconsumed invitation expiration). Instead, the relay cron defined in `relay-scheduled-notification-jobs` SHALL fire them under domain `contacts_invitation_expiry`.

The **inviter's** client SHALL register relay fire rows when a pending invitation is **created**, and cancel all pending fires for that invitation when it is **used**, **revoked**, or otherwise invalidated. If invitation validity is **extended**, the client SHALL cancel and re-register fires from the new `expiresAt`.

#### Scenario: Invitation creation registers expiry fires

- **WHEN** the inviter creates a pending invitation with `expiresAt`
- **THEN** the inviter's client upserts relay scheduled fires for that invitation under `contacts_invitation_expiry`

#### Scenario: Revocation cancels expiry fires

- **WHEN** the inviter revokes a pending invitation
- **THEN** all pending expiry fires for that invitation are cancelled on the relay

#### Scenario: Successful redemption cancels expiry fires

- **WHEN** the invitation code is consumed (handshake hello validated / invitation marked used)
- **THEN** all pending expiry fires for that invitation are cancelled on the relay

---

### Requirement: Invitation expiry fire kinds and lead times

For domain `contacts_invitation_expiry`, the inviter's client SHALL compute concrete `fire_at` instants as **wall-clock offsets from `expiresAt`** (UTC), supply them to the relay as `fires[]`, and SHALL **not** use housing payment 14:00-local tiered rules.

Validity presets are the app's standard invitation durations: **3h**, **8h**, **24h**, and **48h**.

| Validity | `before_expiry` (soon) | `expired` (unconsumed at T) |
|----------|------------------------|-----------------------------|
| 3h | `expiresAt − 30 minutes` | exactly `expiresAt` |
| 8h | `expiresAt − 1 hour` | exactly `expiresAt` |
| 24h | `expiresAt − 2 hours` | exactly `expiresAt` |
| 48h | `expiresAt − 4 hours` | exactly `expiresAt` |

At registration, any fire whose `fire_at` is already in the past SHALL be **omitted**. Recipient is the **inviter** only.

#### Scenario: 24h invitation schedules soon and at expiry

- **WHEN** the inviter creates a pending invitation with validity 24h and `expiresAt` = T
- **THEN** the client registers a `before_expiry` fire at T−2h and an `expired` fire at T (unless either instant is already past)

#### Scenario: Past lead time is skipped

- **WHEN** registration runs after T−2h for a 24h invitation that still expires at T
- **THEN** the client omits the `before_expiry` fire and still registers `expired` at T if T is still in the future

---

### Requirement: Invitation expiry notification prefs, copy, and deep link

Both `before_expiry` and `expired` notifications SHALL honor the app-level master notification switch and the Contacts Settings category **unconsumed invitation expiration** (`notificationContactInvitationExpiration`). They SHALL **not** reuse incoming-handshake-request wording.

Localized push copy SHALL be:

| Kind | Language | Title | Body |
|------|----------|-------|------|
| `before_expiry` | FR | Invitation bientôt expirée | Une invitation en attente expirera bientôt. |
| `before_expiry` | EN | Invitation expiring soon | A pending invitation will expire soon. |
| `expired` | FR | Invitation expirée | Une invitation n’a pas été utilisée et a expiré. |
| `expired` | EN | Invitation expired | An invitation was not used and has expired. |

Spanish SHALL use the same meaning with locale-appropriate wording (chosen at implementation).

Tapping either notification SHALL open the inviter's **outstanding outgoing invitations** list.

#### Scenario: Soon reminder uses future-tense body

- **WHEN** a `before_expiry` fire is delivered while the invitation is still pending and the Contacts invitation-expiration preference is on
- **THEN** the notification body communicates that a pending invitation **will** expire soon (FR: *expirera*)

#### Scenario: Expired unconsumed notification at expiry

- **WHEN** an `expired` fire is delivered for an invitation that remains unused at `expiresAt` and the preference is on
- **THEN** the notification states that an invitation was not used and has expired

#### Scenario: Preference off suppresses display

- **WHEN** a due invitation-expiry fire is delivered but `notificationContactInvitationExpiration` is off (or master notifications are off)
- **THEN** the client does not show the local notification
