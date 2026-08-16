// Package store is the only place in the relay where SQL is written.
// Every public method takes opaque byte identifiers and returns plain Go
// types — it does not inspect or shape ciphertext beyond storing it.
package store

import (
	"context"
	"embed"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/compartarenta/relay/internal/version"
)

//go:embed schema/*.sql
var schemaFS embed.FS

// Store is the relay's persistent state.
type Store struct {
	pool *pgxpool.Pool
}

// New opens a connection pool to the configured PostgreSQL instance and
// verifies that the on-disk schema matches the binary's expected version.
// If the schema version is missing (fresh database) or older than
// expected, the bundled migrations are applied in order.
//
// The relay refuses to start when the on-disk version is HIGHER than the
// binary's expected version — that indicates someone deployed a newer
// schema than the binary knows about, and continuing might silently
// truncate fields.
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

// Close releases all DB resources.
func (s *Store) Close() { s.pool.Close() }

// SchemaVersion reads the persisted schema version. Returns 0 when no
// row exists yet (fresh database).
func (s *Store) SchemaVersion(ctx context.Context) (int, error) {
	var v int
	row := s.pool.QueryRow(ctx,
		`SELECT version FROM schema_version WHERE id = 1`)
	if err := row.Scan(&v); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return 0, nil
		}
		if isUndefinedTable(err) {
			return 0, nil
		}
		return 0, err
	}
	return v, nil
}

func (s *Store) applyMigrations(ctx context.Context) error {
	current, err := s.SchemaVersion(ctx)
	if err != nil {
		return fmt.Errorf("read schema version: %w", err)
	}
	if current > version.Expected {
		return fmt.Errorf(
			"on-disk schema version %d is higher than this binary expects (%d); refusing to start",
			current, version.Expected)
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
			return fmt.Errorf("apply migration %s: %w", m.name, err)
		}
	}

	final, err := s.SchemaVersion(ctx)
	if err != nil {
		return fmt.Errorf("re-read schema version: %w", err)
	}
	if final != version.Expected {
		return fmt.Errorf(
			"after migration, schema version is %d but binary expects %d",
			final, version.Expected)
	}
	return nil
}

type migrationFile struct {
	version int
	name    string
	sql     string
}

func loadMigrations(fsys fs.FS) ([]migrationFile, error) {
	entries, err := fs.ReadDir(fsys, "schema")
	if err != nil {
		return nil, fmt.Errorf("read embedded schema: %w", err)
	}
	out := make([]migrationFile, 0, len(entries))
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".sql") {
			continue
		}
		var v int
		if _, err := fmt.Sscanf(e.Name(), "%04d_", &v); err != nil {
			return nil, fmt.Errorf("migration filename %q must start with NNNN_: %w", e.Name(), err)
		}
		content, err := fs.ReadFile(fsys, "schema/"+e.Name())
		if err != nil {
			return nil, err
		}
		out = append(out, migrationFile{version: v, name: e.Name(), sql: string(content)})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].version < out[j].version })
	return out, nil
}

func isUndefinedTable(err error) bool {
	return err != nil && strings.Contains(err.Error(), "SQLSTATE 42P01")
}

// ---------------------------------------------------------------------------
// Routing relationships
// ---------------------------------------------------------------------------

// EstablishRouting creates (or upserts) the canonical (peer_a, peer_b)
// row. Callers pass the peers in either order; the canonical ordering
// is enforced here.
func (s *Store) EstablishRouting(ctx context.Context, peerX, peerY []byte) error {
	a, b := canonicalPair(peerX, peerY)
	_, err := s.pool.Exec(ctx, `
		INSERT INTO routing_relationships (peer_a, peer_b)
		VALUES ($1, $2)
		ON CONFLICT (peer_a, peer_b) DO UPDATE
		SET last_seen_at = now(),
		    status = 'active',
		    disconnect_started_at = NULL
	`, a, b)
	return err
}

// HasRouting reports whether peerX and peerY have an active routing row.
func (s *Store) HasRouting(ctx context.Context, peerX, peerY []byte) (bool, error) {
	a, b := canonicalPair(peerX, peerY)
	var status string
	err := s.pool.QueryRow(ctx, `
		SELECT status FROM routing_relationships WHERE peer_a = $1 AND peer_b = $2
	`, a, b).Scan(&status)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return status == "active", nil
}

// MarkDisconnecting begins the grace window on the (peerX, peerY) row.
// Returns true when a row transitioned to disconnecting.
func (s *Store) MarkDisconnecting(ctx context.Context, peerX, peerY []byte, at time.Time) (bool, error) {
	a, b := canonicalPair(peerX, peerY)
	tag, err := s.pool.Exec(ctx, `
		UPDATE routing_relationships
		SET status = 'disconnecting', disconnect_started_at = $3
		WHERE peer_a = $1 AND peer_b = $2 AND status = 'active'
	`, a, b, at)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}

// PruneExpiredRouting removes (a) rows whose disconnect grace has
// elapsed and (b) rows older than the inactivity threshold. Returns the
// number deleted.
func (s *Store) PruneExpiredRouting(ctx context.Context, now time.Time, disconnectGrace, inactivityTTL time.Duration) (int64, error) {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM routing_relationships
		WHERE (status = 'disconnecting' AND disconnect_started_at IS NOT NULL
		         AND disconnect_started_at + ($2 || ' seconds')::interval <= $1)
		   OR (status = 'active' AND last_seen_at + ($3 || ' seconds')::interval <= $1)
	`, now, fmtSeconds(disconnectGrace), fmtSeconds(inactivityTTL))
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// TouchRouting bumps `last_seen_at` so an active relationship survives
// the inactivity TTL. Called whenever an envelope is accepted.
func (s *Store) TouchRouting(ctx context.Context, peerX, peerY []byte) error {
	a, b := canonicalPair(peerX, peerY)
	_, err := s.pool.Exec(ctx, `
		UPDATE routing_relationships
		SET last_seen_at = now()
		WHERE peer_a = $1 AND peer_b = $2 AND status = 'active'
	`, a, b)
	return err
}

// ---------------------------------------------------------------------------
// Idempotency
// ---------------------------------------------------------------------------

// LookupOrReserveIdempotency returns the envelope id previously
// associated with (senderIdentity, idempotencyKey) if such a row exists
// and is not yet expired. When no row exists, a new one is inserted
// pointing at `newEnvelopeID`. The returned bool is true when the row
// pre-existed (the caller should treat the request as a replay).
func (s *Store) LookupOrReserveIdempotency(
	ctx context.Context,
	senderIdentity, idempotencyKey, newEnvelopeID []byte,
	ttl time.Duration,
	now time.Time,
) ([]byte, bool, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, false, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var existing []byte
	var ttlAt time.Time
	row := tx.QueryRow(ctx, `
		SELECT envelope_id, ttl_expires_at
		FROM idempotency_entries
		WHERE sender_identity = $1 AND idempotency_key = $2
	`, senderIdentity, idempotencyKey)
	switch err := row.Scan(&existing, &ttlAt); {
	case errors.Is(err, pgx.ErrNoRows):
	case err != nil:
		return nil, false, err
	default:
		if ttlAt.After(now) {
			return existing, true, tx.Commit(ctx)
		}
		if _, err := tx.Exec(ctx, `
			DELETE FROM idempotency_entries
			WHERE sender_identity = $1 AND idempotency_key = $2
		`, senderIdentity, idempotencyKey); err != nil {
			return nil, false, err
		}
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO idempotency_entries
		(sender_identity, idempotency_key, envelope_id, created_at, ttl_expires_at)
		VALUES ($1, $2, $3, $4, $5)
	`, senderIdentity, idempotencyKey, newEnvelopeID, now, now.Add(ttl)); err != nil {
		return nil, false, err
	}
	return newEnvelopeID, false, tx.Commit(ctx)
}

// SweepIdempotency deletes idempotency rows past TTL.
func (s *Store) SweepIdempotency(ctx context.Context, now time.Time) (int64, error) {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM idempotency_entries WHERE ttl_expires_at <= $1
	`, now)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// ---------------------------------------------------------------------------
// Envelopes
// ---------------------------------------------------------------------------

// StoreEnvelope inserts a per-recipient envelope row. Returns
// pgx.ErrNoRows when a row with the same (envelope_id, recipient_identity)
// already exists, which the API layer reports as success-via-idempotency.
func (s *Store) StoreEnvelope(ctx context.Context, e Envelope) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO envelopes
		(envelope_id, sender_identity, recipient_identity, ciphertext, kind,
		 created_at, ttl_expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (envelope_id, recipient_identity) DO NOTHING
	`, e.EnvelopeID, e.SenderIdentity, e.RecipientIdentity, e.Ciphertext,
		e.Kind, e.CreatedAt, e.TTLExpiresAt)
	return err
}

// FetchInbox returns up to `limit` undelivered envelopes addressed to
// `recipient` whose retention instant is still in the future, ordered
// by creation time. Expired rows are omitted even before the sweeper
// deletes them.
func (s *Store) FetchInbox(ctx context.Context, recipient []byte, limit int, now time.Time) ([]Envelope, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT envelope_id, sender_identity, recipient_identity, ciphertext,
		       kind, created_at, ttl_expires_at
		FROM envelopes
		WHERE recipient_identity = $1 AND delivered_at IS NULL
		  AND ttl_expires_at > $3
		ORDER BY created_at ASC
		LIMIT $2
	`, recipient, limit, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Envelope
	for rows.Next() {
		var e Envelope
		if err := rows.Scan(&e.EnvelopeID, &e.SenderIdentity, &e.RecipientIdentity,
			&e.Ciphertext, &e.Kind, &e.CreatedAt, &e.TTLExpiresAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// AckEnvelope deletes the per-recipient row, satisfying the
// "delete-on-delivery" requirement
// (`relay-state-schema-and-retention` /
// "Envelopes are deleted after successful delivery to all intended
// recipients"). Returns true when a row was actually deleted.
func (s *Store) AckEnvelope(ctx context.Context, envelopeID, recipient []byte) (bool, error) {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM envelopes
		WHERE envelope_id = $1 AND recipient_identity = $2
	`, envelopeID, recipient)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}

// SweepEnvelopes deletes envelopes whose TTL has passed without delivery.
func (s *Store) SweepEnvelopes(ctx context.Context, now time.Time) (int64, error) {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM envelopes
		WHERE delivered_at IS NULL AND ttl_expires_at <= $1
	`, now)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// QueueDepth returns the count of undelivered envelopes.
func (s *Store) QueueDepth(ctx context.Context) (int64, error) {
	var n int64
	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM envelopes WHERE delivered_at IS NULL
	`).Scan(&n)
	return n, err
}

// OldestUndeliveredAge returns the age of the oldest undelivered envelope.
// Returns 0 when the queue is empty.
func (s *Store) OldestUndeliveredAge(ctx context.Context, now time.Time) (time.Duration, error) {
	var oldest *time.Time
	err := s.pool.QueryRow(ctx, `
		SELECT MIN(created_at) FROM envelopes WHERE delivered_at IS NULL
	`).Scan(&oldest)
	if err != nil || oldest == nil {
		return 0, err
	}
	return now.Sub(*oldest), nil
}

// RecordCheckpoint updates the sweeper's last-run snapshot.
func (s *Store) RecordCheckpoint(ctx context.Context, at time.Time, ee, ie, rp int64) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE sweeper_checkpoint SET
			last_run_at = $1,
			last_envelopes_expired = $2,
			last_idempotency_expired = $3,
			last_routing_pruned = $4,
			total_envelopes_expired = total_envelopes_expired + $2,
			total_idempotency_expired = total_idempotency_expired + $3,
			total_routing_pruned = total_routing_pruned + $4
		WHERE id = 1
	`, at, ee, ie, rp)
	return err
}

// RecordOperatorAction appends a row to the operator-actions audit log.
func (s *Store) RecordOperatorAction(ctx context.Context, action OperatorAction) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO operator_actions (occurred_at, actor, action, reason, target_kind, target_a, target_b)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, action.OccurredAt, action.Actor, action.Action, action.Reason,
		action.TargetKind, action.TargetA, action.TargetB)
	return err
}

// Envelope is the row representation of a relay envelope (per-recipient).
type Envelope struct {
	EnvelopeID        []byte
	SenderIdentity    []byte
	RecipientIdentity []byte
	Ciphertext        []byte
	Kind              int
	CreatedAt         time.Time
	TTLExpiresAt      time.Time
}

// OperatorAction is the row representation of an operator-log entry.
type OperatorAction struct {
	OccurredAt time.Time
	Actor      string
	Action     string
	Reason     string
	TargetKind *string
	TargetA    []byte
	TargetB    []byte
}

// canonicalPair returns (a, b) such that a < b lexicographically. The
// schema requires this ordering so a relationship has a unique row.
func canonicalPair(x, y []byte) ([]byte, []byte) {
	if compareBytes(x, y) <= 0 {
		return x, y
	}
	return y, x
}

func compareBytes(a, b []byte) int {
	switch {
	case len(a) < len(b):
		min := len(a)
		for i := 0; i < min; i++ {
			if a[i] != b[i] {
				return int(a[i]) - int(b[i])
			}
		}
		return -1
	case len(a) > len(b):
		min := len(b)
		for i := 0; i < min; i++ {
			if a[i] != b[i] {
				return int(a[i]) - int(b[i])
			}
		}
		return 1
	default:
		for i := 0; i < len(a); i++ {
			if a[i] != b[i] {
				return int(a[i]) - int(b[i])
			}
		}
		return 0
	}
}

func fmtSeconds(d time.Duration) string {
	return fmt.Sprintf("%.0f", d.Seconds())
}
