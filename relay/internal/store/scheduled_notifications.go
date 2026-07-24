package store

import (
	"context"
	"crypto/rand"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/compartarenta/relay/internal/scheduling"
)

// HousingPaymentTargetInput is one reminder target row from reconciliation.
type HousingPaymentTargetInput struct {
	ScopeKey             []byte
	RecipientRoutingID   []byte
	ReminderKind         string
	PeriodKey            []byte
	RecurrencePeriodDays int
	DueAt                time.Time
	BoundAt              *time.Time
}

// PendingReminderDelivery is a fired reminder awaiting client pull.
type PendingReminderDelivery struct {
	FireID               []byte
	TargetID             []byte
	RecipientRoutingID   []byte
	Domain               string
	ScopeKey           []byte
	ReminderKind       string
	PeriodKey          []byte
	PeriodDueAt        *time.Time
	RecurrencePeriodDays *int
	FiredAt            time.Time
}

// UpsertRecipientTimezone stores the IANA zone for a routing identity.
func (s *Store) UpsertRecipientTimezone(ctx context.Context, recipient []byte, iana string, now time.Time) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO recipient_notification_timezone (recipient_routing_id, iana_timezone, updated_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (recipient_routing_id) DO UPDATE SET
			iana_timezone = EXCLUDED.iana_timezone,
			updated_at = EXCLUDED.updated_at
	`, recipient, iana, now)
	return err
}

// GetRecipientTimezone returns the stored IANA id or empty if absent.
func (s *Store) GetRecipientTimezone(ctx context.Context, recipient []byte) (string, error) {
	var tz string
	err := s.pool.QueryRow(ctx, `
		SELECT iana_timezone FROM recipient_notification_timezone
		WHERE recipient_routing_id = $1
	`, recipient).Scan(&tz)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil
		}
		return "", err
	}
	return tz, nil
}

// ReconcileHousingPaymentPlan replaces all active housing_payment targets for
// planID at generation and materializes pending fires.
func (s *Store) ReconcileHousingPaymentPlan(
	ctx context.Context,
	planID []byte,
	generation int64,
	targets []HousingPaymentTargetInput,
	now time.Time,
) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	_, err = tx.Exec(ctx, `
		INSERT INTO housing_reminder_plan_generation (plan_id, generation, updated_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (plan_id) DO UPDATE SET
			generation = EXCLUDED.generation,
			updated_at = EXCLUDED.updated_at
		WHERE housing_reminder_plan_generation.generation <= EXCLUDED.generation
	`, planID, generation, now)
	if err != nil {
		return err
	}

	// Cancel targets for this plan superseded by generation.
	planLen := len(planID)
	_, err = tx.Exec(ctx, `
		UPDATE scheduled_notification_targets t
		SET cancelled_at = $3, updated_at = $3
		WHERE t.domain = 'housing_payment'
		  AND length(t.scope_key) > $4
		  AND substring(t.scope_key from 1 for $4) = $1
		  AND get_byte(t.scope_key, $4) = 31
		  AND t.cancelled_at IS NULL
		  AND (t.plan_generation IS NULL OR t.plan_generation < $2)
	`, planID, generation, now, planLen)
	if err != nil {
		return err
	}

	// Cancel pending fires on cancelled targets.
	_, err = tx.Exec(ctx, `
		UPDATE scheduled_notification_fires f
		SET status = 'cancelled'
		FROM scheduled_notification_targets t
		WHERE f.target_id = t.target_id
		  AND f.status = 'pending'
		  AND t.cancelled_at IS NOT NULL
	`)
	if err != nil {
		return err
	}

	for _, t := range targets {
		if err := upsertHousingTargetAndFires(ctx, tx, generation, t, now); err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

func upsertHousingTargetAndFires(
	ctx context.Context,
	tx pgx.Tx,
	generation int64,
	in HousingPaymentTargetInput,
	now time.Time,
) error {
	targetID, err := randomID()
	if err != nil {
		return err
	}

	var boundAt *time.Time
	if in.BoundAt != nil {
		boundAt = in.BoundAt
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO scheduled_notification_targets (
			target_id, domain, scope_key, recipient_routing_id,
			reminder_kind, period_key, recurrence_period_days,
			due_at, bound_at, generation, plan_generation, updated_at
		) VALUES (
			$1, 'housing_payment', $2, $3,
			$4, $5, $6,
			$7, $8, $9, $10, $11
		)
		ON CONFLICT (domain, scope_key, recipient_routing_id, reminder_kind, period_key)
		DO UPDATE SET
			recurrence_period_days = EXCLUDED.recurrence_period_days,
			due_at = EXCLUDED.due_at,
			bound_at = EXCLUDED.bound_at,
			generation = EXCLUDED.generation,
			plan_generation = EXCLUDED.plan_generation,
			cancelled_at = NULL,
			updated_at = EXCLUDED.updated_at
	`, targetID, in.ScopeKey, in.RecipientRoutingID,
		in.ReminderKind, in.PeriodKey, in.RecurrencePeriodDays,
		in.DueAt, boundAt, generation, generation, now)
	if err != nil {
		return err
	}

	// Resolve canonical target_id after upsert.
	err = tx.QueryRow(ctx, `
		SELECT target_id FROM scheduled_notification_targets
		WHERE domain = 'housing_payment'
		  AND scope_key = $1
		  AND recipient_routing_id = $2
		  AND reminder_kind = $3
		  AND period_key IS NOT DISTINCT FROM $4
	`, in.ScopeKey, in.RecipientRoutingID, in.ReminderKind, in.PeriodKey).Scan(&targetID)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `
		UPDATE scheduled_notification_fires
		SET status = 'cancelled'
		WHERE target_id = $1 AND status = 'pending'
	`, targetID)
	if err != nil {
		return err
	}

	tz, err := getRecipientTimezoneTx(ctx, tx, in.RecipientRoutingID)
	if err != nil {
		return err
	}
	if tz == "" {
		return nil
	}
	loc, err := time.LoadLocation(tz)
	if err != nil {
		return nil
	}

	var fireAts []time.Time
	switch in.ReminderKind {
	case "before_due":
		fireAts = scheduling.HousingBeforeDateFiresUTC(
			in.DueAt, in.RecurrencePeriodDays, loc, now)
	case "overdue":
		if t, ok := scheduling.HousingOverdueFireUTC(in.DueAt, loc, now); ok {
			if in.BoundAt == nil || t.Before(*in.BoundAt) || t.Equal(*in.BoundAt) {
				fireAts = []time.Time{t}
			}
		}
	default:
		return nil
	}

	for _, fireAt := range fireAts {
		fireID, err := randomID()
		if err != nil {
			return err
		}
		_, err = tx.Exec(ctx, `
			INSERT INTO scheduled_notification_fires (
				fire_id, target_id, recipient_routing_id, fire_at, status
			) VALUES ($1, $2, $3, $4, 'pending')
			ON CONFLICT (target_id, fire_at) DO NOTHING
		`, fireID, targetID, in.RecipientRoutingID, fireAt)
		if err != nil {
			return err
		}
	}
	return nil
}

func getRecipientTimezoneTx(ctx context.Context, tx pgx.Tx, recipient []byte) (string, error) {
	var tz string
	err := tx.QueryRow(ctx, `
		SELECT iana_timezone FROM recipient_notification_timezone
		WHERE recipient_routing_id = $1
	`, recipient).Scan(&tz)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil
		}
		return "", err
	}
	return tz, nil
}

// CancelHousingPaymentTargets cancels targets matching scope keys (coverage complete).
func (s *Store) CancelHousingPaymentTargets(
	ctx context.Context,
	scopeKeys [][]byte,
	reminderKind string,
	periodKey []byte,
	now time.Time,
) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	for _, sk := range scopeKeys {
		_, err = tx.Exec(ctx, `
			UPDATE scheduled_notification_targets
			SET cancelled_at = $4, updated_at = $4
			WHERE domain = 'housing_payment'
			  AND scope_key = $1
			  AND reminder_kind = $2
			  AND period_key IS NOT DISTINCT FROM $3
			  AND cancelled_at IS NULL
		`, sk, reminderKind, periodKey, now)
		if err != nil {
			return err
		}
	}
	_, err = tx.Exec(ctx, `
		UPDATE scheduled_notification_fires f
		SET status = 'cancelled'
		FROM scheduled_notification_targets t
		WHERE f.target_id = t.target_id
		  AND f.status = 'pending'
		  AND t.cancelled_at IS NOT NULL
	`)
	if err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// RecomputePendingHousingFiresForRecipient recomputes fire_at for pending rows
// after a timezone change.
func (s *Store) RecomputePendingHousingFiresForRecipient(
	ctx context.Context,
	recipient []byte,
	now time.Time,
) error {
	tz, err := s.GetRecipientTimezone(ctx, recipient)
	if err != nil || tz == "" {
		return err
	}
	loc, err := time.LoadLocation(tz)
	if err != nil {
		return nil
	}

	rows, err := s.pool.Query(ctx, `
		SELECT t.target_id, t.reminder_kind, t.recurrence_period_days, t.due_at, t.bound_at
		FROM scheduled_notification_targets t
		WHERE t.domain = 'housing_payment'
		  AND t.recipient_routing_id = $1
		  AND t.cancelled_at IS NULL
	`, recipient)
	if err != nil {
		return err
	}
	defer rows.Close()

	type row struct {
		targetID             []byte
		kind                 string
		recurrencePeriodDays int
		dueAt                time.Time
		boundAt              *time.Time
	}
	var targets []row
	for rows.Next() {
		var r row
		if err := rows.Scan(&r.targetID, &r.kind, &r.recurrencePeriodDays, &r.dueAt, &r.boundAt); err != nil {
			return err
		}
		targets = append(targets, r)
	}
	if err := rows.Err(); err != nil {
		return err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	for _, t := range targets {
		_, err = tx.Exec(ctx, `
			UPDATE scheduled_notification_fires
			SET status = 'cancelled'
			WHERE target_id = $1 AND status = 'pending'
		`, t.targetID)
		if err != nil {
			return err
		}
		var fireAts []time.Time
		switch t.kind {
		case "before_due":
			fireAts = scheduling.HousingBeforeDateFiresUTC(
				t.dueAt, t.recurrencePeriodDays, loc, now)
		case "overdue":
			if ft, ok := scheduling.HousingOverdueFireUTC(t.dueAt, loc, now); ok {
				if t.boundAt == nil || ft.Before(*t.boundAt) || ft.Equal(*t.boundAt) {
					fireAts = []time.Time{ft}
				}
			}
		}
		for _, fireAt := range fireAts {
			fireID, err := randomID()
			if err != nil {
				return err
			}
			_, err = tx.Exec(ctx, `
				INSERT INTO scheduled_notification_fires (
					fire_id, target_id, recipient_routing_id, fire_at, status
				) VALUES ($1, $2, $3, $4, 'pending')
				ON CONFLICT (target_id, fire_at) DO NOTHING
			`, fireID, t.targetID, recipient, fireAt)
			if err != nil {
				return err
			}
		}
	}
	return tx.Commit(ctx)
}

// ClaimDueReminderFires marks due pending fires as fired and returns them.
func (s *Store) ClaimDueReminderFires(ctx context.Context, now time.Time, limit int) ([]PendingReminderDelivery, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	rows, err := tx.Query(ctx, `
		SELECT f.fire_id, f.target_id, f.recipient_routing_id,
		       t.domain, t.scope_key, t.reminder_kind, t.period_key,
		       t.due_at, t.recurrence_period_days
		FROM scheduled_notification_fires f
		JOIN scheduled_notification_targets t ON t.target_id = f.target_id
		WHERE f.status = 'pending'
		  AND f.fire_at <= $1
		  AND t.cancelled_at IS NULL
		ORDER BY f.fire_at
		LIMIT $2
		FOR UPDATE OF f SKIP LOCKED
	`, now, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var claimed []PendingReminderDelivery
	for rows.Next() {
		var d PendingReminderDelivery
		var dueAt *time.Time
		var w *int
		if err := rows.Scan(
			&d.FireID, &d.TargetID, &d.RecipientRoutingID,
			&d.Domain, &d.ScopeKey, &d.ReminderKind, &d.PeriodKey,
			&dueAt, &w,
		); err != nil {
			return nil, err
		}
		d.PeriodDueAt = dueAt
		d.RecurrencePeriodDays = w
		d.FiredAt = now
		claimed = append(claimed, d)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	for _, d := range claimed {
		_, err = tx.Exec(ctx, `
			UPDATE scheduled_notification_fires
			SET status = 'fired', fired_at = $2
			WHERE fire_id = $1
		`, d.FireID, now)
		if err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return claimed, nil
}

// ListUndeliveredReminderFires returns fired rows not yet acked by the client.
func (s *Store) ListUndeliveredReminderFires(
	ctx context.Context,
	recipient []byte,
	limit int,
) ([]PendingReminderDelivery, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT f.fire_id, f.target_id, f.recipient_routing_id,
		       t.domain, t.scope_key, t.reminder_kind, t.period_key,
		       t.due_at, t.recurrence_period_days, f.fired_at
		FROM scheduled_notification_fires f
		JOIN scheduled_notification_targets t ON t.target_id = f.target_id
		WHERE f.recipient_routing_id = $1
		  AND f.status = 'fired'
		  AND f.delivery_ack_at IS NULL
		ORDER BY f.fired_at
		LIMIT $2
	`, recipient, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []PendingReminderDelivery
	for rows.Next() {
		var d PendingReminderDelivery
		var dueAt *time.Time
		var w *int
		if err := rows.Scan(
			&d.FireID, &d.TargetID, &d.RecipientRoutingID,
			&d.Domain, &d.ScopeKey, &d.ReminderKind, &d.PeriodKey,
			&dueAt, &w, &d.FiredAt,
		); err != nil {
			return nil, err
		}
		d.PeriodDueAt = dueAt
		d.RecurrencePeriodDays = w
		out = append(out, d)
	}
	return out, rows.Err()
}

// AckReminderFireDelivery marks a fired reminder as delivered to the client.
func (s *Store) AckReminderFireDelivery(
	ctx context.Context,
	recipient []byte,
	fireID []byte,
	now time.Time,
) (bool, error) {
	tag, err := s.pool.Exec(ctx, `
		UPDATE scheduled_notification_fires
		SET delivery_ack_at = $3
		WHERE fire_id = $1
		  AND recipient_routing_id = $2
		  AND status = 'fired'
		  AND delivery_ack_at IS NULL
	`, fireID, recipient, now)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// ClientScheduledFireTarget is one domain target with client-supplied fire_at list.
type ClientScheduledFireTarget struct {
	Domain             string
	ScopeKey           []byte
	RecipientRoutingID []byte
	ReminderKind       string
	PeriodKey          []byte
	DueAt              *time.Time
	Generation         int64
	FireAts            []time.Time
}

var allowedClientFireDomains = map[string]bool{
	"contacts_invitation_expiry":  true,
	"housing_proposal_deadline":   true,
}

var allowedClientFireKinds = map[string]bool{
	"before_expiry":    true,
	"expired":          true,
	"before_deadline":  true,
}

// UpsertClientScheduledFires replaces targets+pending fires for client wall-clock domains.
func (s *Store) UpsertClientScheduledFires(
	ctx context.Context,
	targets []ClientScheduledFireTarget,
	now time.Time,
) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	for _, in := range targets {
		if !allowedClientFireDomains[in.Domain] {
			return errors.New("unsupported_domain")
		}
		if !allowedClientFireKinds[in.ReminderKind] {
			return errors.New("unsupported_reminder_kind")
		}
		if len(in.ScopeKey) == 0 || len(in.RecipientRoutingID) == 0 {
			return errors.New("missing_scope_or_recipient")
		}
		gen := in.Generation
		if gen == 0 {
			gen = 1
		}

		var periodKey any
		if len(in.PeriodKey) > 0 {
			periodKey = in.PeriodKey
		}

		var targetID []byte
		err = tx.QueryRow(ctx, `
			SELECT target_id FROM scheduled_notification_targets
			WHERE domain = $1
			  AND scope_key = $2
			  AND recipient_routing_id = $3
			  AND reminder_kind = $4
			  AND period_key IS NOT DISTINCT FROM $5
		`, in.Domain, in.ScopeKey, in.RecipientRoutingID, in.ReminderKind, periodKey).Scan(&targetID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		if errors.Is(err, pgx.ErrNoRows) {
			targetID, err = randomID()
			if err != nil {
				return err
			}
			_, err = tx.Exec(ctx, `
				INSERT INTO scheduled_notification_targets (
					target_id, domain, scope_key, recipient_routing_id, reminder_kind,
					period_key, due_at, generation, cancelled_at, created_at, updated_at
				) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NULL,$9,$9)
			`, targetID, in.Domain, in.ScopeKey, in.RecipientRoutingID, in.ReminderKind,
				periodKey, in.DueAt, gen, now)
			if err != nil {
				return err
			}
		} else {
			_, err = tx.Exec(ctx, `
				UPDATE scheduled_notification_targets
				SET due_at = $2, generation = $3, cancelled_at = NULL, updated_at = $4
				WHERE target_id = $1
			`, targetID, in.DueAt, gen, now)
			if err != nil {
				return err
			}
			_, err = tx.Exec(ctx, `
				UPDATE scheduled_notification_fires
				SET status = 'cancelled'
				WHERE target_id = $1 AND status = 'pending'
			`, targetID)
			if err != nil {
				return err
			}
		}

		for _, fireAt := range in.FireAts {
			fireAt = fireAt.UTC()
			if !fireAt.After(now) {
				continue
			}
			fireID, err := randomID()
			if err != nil {
				return err
			}
			_, err = tx.Exec(ctx, `
				INSERT INTO scheduled_notification_fires (
					fire_id, target_id, recipient_routing_id, fire_at, status
				) VALUES ($1, $2, $3, $4, 'pending')
				ON CONFLICT (target_id, fire_at) DO NOTHING
			`, fireID, targetID, in.RecipientRoutingID, fireAt)
			if err != nil {
				return err
			}
		}
	}
	return tx.Commit(ctx)
}

// CancelClientScheduledByScope cancels all active targets (and pending fires)
// for the given domain and scope keys.
func (s *Store) CancelClientScheduledByScope(
	ctx context.Context,
	domain string,
	scopeKeys [][]byte,
	now time.Time,
) error {
	if !allowedClientFireDomains[domain] {
		return errors.New("unsupported_domain")
	}
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	for _, sk := range scopeKeys {
		_, err = tx.Exec(ctx, `
			UPDATE scheduled_notification_targets
			SET cancelled_at = $3, updated_at = $3
			WHERE domain = $1
			  AND scope_key = $2
			  AND cancelled_at IS NULL
		`, domain, sk, now)
		if err != nil {
			return err
		}
	}
	_, err = tx.Exec(ctx, `
		UPDATE scheduled_notification_fires f
		SET status = 'cancelled'
		FROM scheduled_notification_targets t
		WHERE f.target_id = t.target_id
		  AND f.status = 'pending'
		  AND t.cancelled_at IS NOT NULL
		  AND t.domain = $1
	`, domain)
	if err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func randomID() ([]byte, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	return b, nil
}

// Pool exposes the underlying pool for integration tests.
func (s *Store) Pool() *pgxpool.Pool { return s.pool }
