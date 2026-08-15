package store

import (
	"context"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/compartarenta/entitlement/internal/version"
)

var ErrOldInstallationNotFound = errors.New("old installation not found for plan")

//go:embed schema/*.sql
var schemaFS embed.FS

type Store struct {
	pool *pgxpool.Pool
}

type Plan struct {
	PlanID             string
	LifecycleState     string
	TrialStartedAt     *time.Time
	TrialEndsAt        *time.Time
	GraceEndsAt        *time.Time
	ActiveUseStartedAt *time.Time
	UpdatedAt          time.Time
}

type LicenseStatus struct {
	ParticipantInstallationID string
	LicenseState              string
	ExpiresAt                 *time.Time
}

type PlayReceipt struct {
	InstallationID    string
	Module            string
	Platform          string
	ProductID         string
	PurchaseToken     string
	ReceiptBlob       json.RawMessage
	ValidationState   string
	ExpiresAt         *time.Time
	ValidatedAt       time.Time
	GrantedModules    []string
	SubscriptionState string
}

func New(ctx context.Context, dsn string) (*Store, error) {
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, fmt.Errorf("connect: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping: %w", err)
	}
	s := &Store{pool: pool}
	if err := s.applyMigrations(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() { s.pool.Close() }

func (s *Store) SchemaVersion(ctx context.Context) (int, error) {
	var v int
	err := s.pool.QueryRow(ctx, `SELECT version FROM schema_version WHERE id = 1`).Scan(&v)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isUndefinedTable(err) {
			return 0, nil
		}
		return 0, err
	}
	return v, nil
}

func (s *Store) RegisterInstallation(ctx context.Context, id string) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO installations (installation_id)
		VALUES ($1)
		ON CONFLICT (installation_id) DO NOTHING`, id)
	return err
}

func (s *Store) MarkTrialConsumed(ctx context.Context, ids []string, at time.Time) error {
	for _, id := range ids {
		_, err := s.pool.Exec(ctx, `
			UPDATE installations
			SET trial_housing_consumed = TRUE,
			    trial_housing_consumed_at = COALESCE(trial_housing_consumed_at, $2)
			WHERE installation_id = $1`, id, at)
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) AnyTrialConsumed(ctx context.Context, ids []string) (bool, error) {
	if len(ids) == 0 {
		return false, nil
	}
	var n int
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM installations
		WHERE installation_id = ANY($1) AND trial_housing_consumed`, ids).Scan(&n)
	return n > 0, err
}

func (s *Store) UpsertPlan(ctx context.Context, p Plan) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO housing_plans (
			plan_id, lifecycle_state, trial_started_at, trial_ends_at,
			grace_ends_at, active_use_started_at, updated_at
		) VALUES ($1,$2,$3,$4,$5,$6,$7)
		ON CONFLICT (plan_id) DO UPDATE SET
			lifecycle_state = EXCLUDED.lifecycle_state,
			trial_started_at = EXCLUDED.trial_started_at,
			trial_ends_at = EXCLUDED.trial_ends_at,
			grace_ends_at = EXCLUDED.grace_ends_at,
			active_use_started_at = EXCLUDED.active_use_started_at,
			updated_at = EXCLUDED.updated_at`, p.PlanID, p.LifecycleState,
		p.TrialStartedAt, p.TrialEndsAt, p.GraceEndsAt, p.ActiveUseStartedAt, p.UpdatedAt)
	return err
}

func (s *Store) GetPlan(ctx context.Context, planID string) (*Plan, error) {
	var p Plan
	err := s.pool.QueryRow(ctx, `
		SELECT plan_id, lifecycle_state, trial_started_at, trial_ends_at,
		       grace_ends_at, active_use_started_at, updated_at
		FROM housing_plans WHERE plan_id = $1`, planID).Scan(
		&p.PlanID, &p.LifecycleState, &p.TrialStartedAt, &p.TrialEndsAt,
		&p.GraceEndsAt, &p.ActiveUseStartedAt, &p.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (s *Store) SetActiveRoster(ctx context.Context, planID, revisionID string, participants []string, at time.Time) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	for _, pid := range participants {
		_, err = tx.Exec(ctx, `
			INSERT INTO housing_plan_rosters
				(plan_id, revision_id, participant_installation_id, accepted_at)
			VALUES ($1,$2,$3,$4)
			ON CONFLICT DO NOTHING`, planID, revisionID, pid, at)
		if err != nil {
			return err
		}
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO housing_plan_active_revision (plan_id, revision_id, activated_at)
		VALUES ($1,$2,$3)
		ON CONFLICT (plan_id) DO UPDATE SET
			revision_id = EXCLUDED.revision_id,
			activated_at = EXCLUDED.activated_at`, planID, revisionID, at)
	if err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) ActiveRoster(ctx context.Context, planID string) ([]string, error) {
	var revisionID string
	err := s.pool.QueryRow(ctx, `
		SELECT revision_id FROM housing_plan_active_revision WHERE plan_id = $1`, planID).Scan(&revisionID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `
		SELECT participant_installation_id
		FROM housing_plan_rosters
		WHERE plan_id = $1 AND revision_id = $2
		ORDER BY participant_installation_id`, planID, revisionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

func (s *Store) RecordExpenseDecision(ctx context.Context, planID, expenseID, participantID, decision string, at time.Time) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO housing_expense_decisions
			(plan_id, expense_id, participant_installation_id, decision_kind, decided_at)
		VALUES ($1,$2,$3,$4,$5)
		ON CONFLICT (plan_id, expense_id, participant_installation_id) DO UPDATE SET
			decision_kind = EXCLUDED.decision_kind,
			decided_at = EXCLUDED.decided_at`,
		planID, expenseID, participantID, decision, at)
	return err
}

func (s *Store) UpsertLicenseStatus(ctx context.Context, planID, participantID, state string, expiresAt *time.Time, at time.Time) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO housing_plan_licenses
			(plan_id, participant_installation_id, license_state, expires_at, reported_at)
		VALUES ($1,$2,$3,$4,$5)
		ON CONFLICT (plan_id, participant_installation_id) DO UPDATE SET
			license_state = EXCLUDED.license_state,
			expires_at = EXCLUDED.expires_at,
			reported_at = EXCLUDED.reported_at`,
		planID, participantID, state, expiresAt, at)
	return err
}

func (s *Store) LicenseStatuses(ctx context.Context, planID string) ([]LicenseStatus, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT participant_installation_id, license_state, expires_at
		FROM housing_plan_licenses WHERE plan_id = $1`, planID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []LicenseStatus
	for rows.Next() {
		var ls LicenseStatus
		if err := rows.Scan(&ls.ParticipantInstallationID, &ls.LicenseState, &ls.ExpiresAt); err != nil {
			return nil, err
		}
		out = append(out, ls)
	}
	return out, rows.Err()
}

func (s *Store) StoreReceipt(ctx context.Context, installationID, module, platform string, blob json.RawMessage) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO license_receipts (installation_id, module, platform, receipt_blob, validation_state)
		VALUES ($1,$2,$3,$4,'pending')`, installationID, module, platform, blob)
	return err
}

func (s *Store) UpsertPlayReceipt(ctx context.Context, r PlayReceipt) error {
	blob := r.ReceiptBlob
	if len(blob) == 0 {
		blob = json.RawMessage(`{}`)
	}
	mods := r.GrantedModules
	if mods == nil {
		mods = []string{}
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO license_receipts (
			installation_id, module, platform, receipt_blob, validation_state,
			product_id, purchase_token, expires_at, validated_at, granted_modules,
			subscription_state
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		ON CONFLICT (platform, purchase_token) WHERE purchase_token IS NOT NULL AND purchase_token <> ''
		DO UPDATE SET
			installation_id = EXCLUDED.installation_id,
			module = EXCLUDED.module,
			receipt_blob = EXCLUDED.receipt_blob,
			validation_state = EXCLUDED.validation_state,
			product_id = EXCLUDED.product_id,
			expires_at = EXCLUDED.expires_at,
			validated_at = EXCLUDED.validated_at,
			granted_modules = EXCLUDED.granted_modules,
			subscription_state = EXCLUDED.subscription_state`,
		r.InstallationID, r.Module, r.Platform, blob, r.ValidationState,
		r.ProductID, r.PurchaseToken, r.ExpiresAt, r.ValidatedAt, mods,
		r.SubscriptionState)
	return err
}

func (s *Store) PlayReceiptsForInstallation(ctx context.Context, installationID string) ([]PlayReceipt, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT installation_id, module, platform, receipt_blob, validation_state,
		       product_id, purchase_token, expires_at, COALESCE(validated_at, created_at),
		       granted_modules, COALESCE(subscription_state, '')
		FROM license_receipts
		WHERE installation_id = $1 AND purchase_token IS NOT NULL AND purchase_token <> ''`,
		installationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []PlayReceipt
	for rows.Next() {
		var r PlayReceipt
		if err := rows.Scan(
			&r.InstallationID, &r.Module, &r.Platform, &r.ReceiptBlob, &r.ValidationState,
			&r.ProductID, &r.PurchaseToken, &r.ExpiresAt, &r.ValidatedAt,
			&r.GrantedModules, &r.SubscriptionState,
		); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Store) PlansForInstallation(ctx context.Context, installationID string) ([]string, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT DISTINCT r.plan_id
		FROM housing_plan_rosters r
		JOIN housing_plan_active_revision a
		  ON a.plan_id = r.plan_id AND a.revision_id = r.revision_id
		WHERE r.participant_installation_id = $1
		ORDER BY r.plan_id`, installationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

func (s *Store) MigrateInstallation(ctx context.Context, planID, oldID, newID string) error {
	roster, err := s.ActiveRoster(ctx, planID)
	if err != nil {
		return err
	}
	if !containsString(roster, oldID) {
		if containsString(roster, newID) {
			return nil
		}
		return ErrOldInstallationNotFound
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		UPDATE housing_plan_rosters
		SET participant_installation_id = $3
		WHERE plan_id = $1 AND participant_installation_id = $2`,
		planID, oldID, newID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		UPDATE housing_expense_decisions
		SET participant_installation_id = $3
		WHERE plan_id = $1 AND participant_installation_id = $2`,
		planID, oldID, newID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		UPDATE housing_plan_licenses
		SET participant_installation_id = $3
		WHERE plan_id = $1 AND participant_installation_id = $2`,
		planID, oldID, newID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		UPDATE license_receipts
		SET installation_id = $2
		WHERE installation_id = $1`, oldID, newID)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO installations (installation_id)
		VALUES ($1)
		ON CONFLICT (installation_id) DO NOTHING`, newID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `
		UPDATE installations AS new
		SET trial_housing_consumed = new.trial_housing_consumed OR old.trial_housing_consumed,
		    trial_housing_consumed_at = COALESCE(new.trial_housing_consumed_at, old.trial_housing_consumed_at)
		FROM installations AS old
		WHERE new.installation_id = $1 AND old.installation_id = $2`,
		newID, oldID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `DELETE FROM installations WHERE installation_id = $1`, oldID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func containsString(list []string, target string) bool {
	for _, v := range list {
		if v == target {
			return true
		}
	}
	return false
}

func (s *Store) applyMigrations(ctx context.Context) error {
	current, err := s.SchemaVersion(ctx)
	if err != nil {
		return fmt.Errorf("read schema version: %w", err)
	}
	if current > version.Expected {
		return fmt.Errorf("on-disk schema %d > binary %d", current, version.Expected)
	}
	files, err := loadMigrations(schemaFS)
	if err != nil {
		return err
	}
	for _, m := range files {
		if m.version <= current {
			continue
		}
		if _, err := s.pool.Exec(ctx, m.sql); err != nil {
			return fmt.Errorf("apply %s: %w", m.name, err)
		}
	}
	return nil
}

type migration struct {
	version int
	name    string
	sql     string
}

func loadMigrations(fsys embed.FS) ([]migration, error) {
	entries, err := fs.ReadDir(fsys, "schema")
	if err != nil {
		return nil, err
	}
	var out []migration
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".sql") {
			continue
		}
		var ver int
		if _, err := fmt.Sscanf(e.Name(), "%04d_", &ver); err != nil {
			return nil, fmt.Errorf("bad migration name %q", e.Name())
		}
		b, err := fs.ReadFile(fsys, "schema/"+e.Name())
		if err != nil {
			return nil, err
		}
		out = append(out, migration{version: ver, name: e.Name(), sql: string(b)})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].version < out[j].version })
	return out, nil
}

func isUndefinedTable(err error) bool {
	return err != nil && strings.Contains(err.Error(), "42P01")
}
