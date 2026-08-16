package store

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

// HasActiveRoutingForIdentity reports whether id appears as peer_a or
// peer_b on any active routing_relationships row. Used to gate push
// token registration without exposing per-row routing data.
func (s *Store) HasActiveRoutingForIdentity(ctx context.Context, id []byte) (bool, error) {
	var n int
	err := s.pool.QueryRow(ctx, `
		SELECT 1 FROM routing_relationships
		WHERE status = 'active' AND (peer_a = $1 OR peer_b = $1)
		LIMIT 1
	`, id).Scan(&n)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

// UpsertRoutingPushToken inserts or refreshes a routing push token row.
func (s *Store) UpsertRoutingPushToken(
	ctx context.Context,
	recipient []byte,
	provider string,
	pushToken string,
	country string,
	expiresAt time.Time,
	now time.Time,
) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO routing_push_tokens
			(recipient_routing_id, provider, push_token, expires_at, last_seen_at, country)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (recipient_routing_id, provider, push_token) DO UPDATE SET
			expires_at = EXCLUDED.expires_at,
			last_seen_at = EXCLUDED.last_seen_at,
			country = EXCLUDED.country
	`, recipient, provider, pushToken, expiresAt, now, country)
	return err
}

// DeleteRoutingPushToken removes one registration row.
func (s *Store) DeleteRoutingPushToken(
	ctx context.Context,
	recipient []byte,
	provider string,
	pushToken string,
) (int64, error) {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM routing_push_tokens
		WHERE recipient_routing_id = $1 AND provider = $2 AND push_token = $3
	`, recipient, provider, pushToken)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// RoutingPushTokenRow is one device registration for wake dispatch.
type RoutingPushTokenRow struct {
	Recipient []byte
	Provider  string
	PushToken string
}

// ListDistinctActiveFCMTokens returns unique non-expired FCM device tokens.
// The same physical token can be registered under several routing ids; the
// operator notice fans out once per token so the tray is not duplicated.
func (s *Store) ListDistinctActiveFCMTokens(ctx context.Context, now time.Time) ([]string, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT DISTINCT push_token
		FROM routing_push_tokens
		WHERE provider = 'fcm' AND expires_at > $1
		ORDER BY push_token
	`, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, err
		}
		out = append(out, token)
	}
	return out, rows.Err()
}

// DeleteRoutingPushTokensByProviderToken removes every row for one device
// token (all routing ids). Used when FCM reports a permanent token error.
func (s *Store) DeleteRoutingPushTokensByProviderToken(ctx context.Context, provider, pushToken string) (int64, error) {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM routing_push_tokens
		WHERE provider = $1 AND push_token = $2
	`, provider, pushToken)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// ListRoutingPushTokensForRecipient returns all non-expired tokens for a recipient.
func (s *Store) ListRoutingPushTokensForRecipient(ctx context.Context, recipient []byte, now time.Time) ([]RoutingPushTokenRow, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT recipient_routing_id, provider, push_token
		FROM routing_push_tokens
		WHERE recipient_routing_id = $1 AND expires_at > $2
	`, recipient, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []RoutingPushTokenRow
	for rows.Next() {
		var r RoutingPushTokenRow
		if err := rows.Scan(&r.Recipient, &r.Provider, &r.PushToken); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// PurgeExpiredRoutingPushTokens deletes expired rows and returns how many.
func (s *Store) PurgeExpiredRoutingPushTokens(ctx context.Context, now time.Time) (int64, error) {
	tag, err := s.pool.Exec(ctx, `
		DELETE FROM routing_push_tokens WHERE expires_at <= $1
	`, now)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// DeleteRoutingPushTokenRow removes a single row by primary key (used when
// the push provider reports a permanent token error).
func (s *Store) DeleteRoutingPushTokenRow(ctx context.Context, recipient []byte, provider, pushToken string) error {
	_, err := s.pool.Exec(ctx, `
		DELETE FROM routing_push_tokens
		WHERE recipient_routing_id = $1 AND provider = $2 AND push_token = $3
	`, recipient, provider, pushToken)
	return err
}

// MergeDayMetrics adds deltas to relay_day_metrics for the given UTC calendar day.
func (s *Store) MergeDayMetrics(ctx context.Context, dayUTC time.Time, successDelta, failureDelta, purgeDelta int64) error {
	d := time.Date(dayUTC.Year(), dayUTC.Month(), dayUTC.Day(), 0, 0, 0, 0, time.UTC)
	if successDelta == 0 && failureDelta == 0 && purgeDelta == 0 {
		return nil
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO relay_day_metrics (day_utc, dispatch_success, dispatch_failure, routing_push_token_purges)
		VALUES ($1::date, $2, $3, $4)
		ON CONFLICT (day_utc) DO UPDATE SET
			dispatch_success = relay_day_metrics.dispatch_success + EXCLUDED.dispatch_success,
			dispatch_failure = relay_day_metrics.dispatch_failure + EXCLUDED.dispatch_failure,
			routing_push_token_purges = relay_day_metrics.routing_push_token_purges + EXCLUDED.routing_push_token_purges
	`, d, successDelta, failureDelta, purgeDelta)
	return err
}

// DayMetricRow is persisted per-UTC-day technical counters.
type DayMetricRow struct {
	DispatchSuccess        int64
	DispatchFailure        int64
	RoutingPushTokenPurges int64
}

// GetDayMetrics returns metrics for a UTC calendar day, or zeros if absent.
func (s *Store) GetDayMetrics(ctx context.Context, dayUTC time.Time) (DayMetricRow, error) {
	d := time.Date(dayUTC.Year(), dayUTC.Month(), dayUTC.Day(), 0, 0, 0, 0, time.UTC)
	var r DayMetricRow
	err := s.pool.QueryRow(ctx, `
		SELECT dispatch_success, dispatch_failure, routing_push_token_purges
		FROM relay_day_metrics WHERE day_utc = $1::date
	`, d).Scan(&r.DispatchSuccess, &r.DispatchFailure, &r.RoutingPushTokenPurges)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return DayMetricRow{}, nil
		}
		return DayMetricRow{}, err
	}
	return r, nil
}

// CountRoutingPushTokens returns the current number of rows (any expiry).
func (s *Store) CountRoutingPushTokens(ctx context.Context) (int64, error) {
	var n int64
	err := s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM routing_push_tokens`).Scan(&n)
	return n, err
}

// DailyActiveSnapshot holds aggregate inbox activity for a UTC day window.
type DailyActiveSnapshot struct {
	ActiveTotal int64
	ByCountry   map[string]int64
	ByProvider  map[string]int64
}

// DailyActiveSnapshotForRange counts rows whose last_seen_at falls in
// [start, end) (half-open interval, UTC).
func (s *Store) DailyActiveSnapshotForRange(ctx context.Context, start, end time.Time) (DailyActiveSnapshot, error) {
	var snap DailyActiveSnapshot
	snap.ByCountry = make(map[string]int64)
	snap.ByProvider = make(map[string]int64)

	err := s.pool.QueryRow(ctx, `
		SELECT COUNT(*)::bigint FROM routing_push_tokens
		WHERE last_seen_at >= $1 AND last_seen_at < $2
	`, start, end).Scan(&snap.ActiveTotal)
	if err != nil {
		return snap, err
	}

	rows, err := s.pool.Query(ctx, `
		SELECT country, COUNT(*)::bigint FROM routing_push_tokens
		WHERE last_seen_at >= $1 AND last_seen_at < $2
		GROUP BY country
	`, start, end)
	if err != nil {
		return snap, err
	}
	defer rows.Close()
	for rows.Next() {
		var country string
		var c int64
		if err := rows.Scan(&country, &c); err != nil {
			return snap, err
		}
		snap.ByCountry[country] = c
	}
	if err := rows.Err(); err != nil {
		return snap, err
	}

	prows, err := s.pool.Query(ctx, `
		SELECT provider, COUNT(*)::bigint FROM routing_push_tokens
		WHERE last_seen_at >= $1 AND last_seen_at < $2
		GROUP BY provider
	`, start, end)
	if err != nil {
		return snap, err
	}
	defer prows.Close()
	for prows.Next() {
		var provider string
		var c int64
		if err := prows.Scan(&provider, &c); err != nil {
			return snap, err
		}
		snap.ByProvider[provider] = c
	}
	return snap, prows.Err()
}

// NormalizeCountryCode returns a 2-letter uppercase ISO code or UNDISCLOSED.
func NormalizeCountryCode(raw string) string {
	s := trimASCII(raw)
	if len(s) == 0 {
		return "UNDISCLOSED"
	}
	if len(s) == 11 && equalsFoldASCII(s, "UNDISCLOSED") {
		return "UNDISCLOSED"
	}
	if len(s) != 2 {
		return "UNDISCLOSED"
	}
	b0, b1 := s[0], s[1]
	if !isASCIILetter(b0) || !isASCIILetter(b1) {
		return "UNDISCLOSED"
	}
	return string([]byte{toUpper(b0), toUpper(b1)})
}

func trimASCII(s string) string {
	for len(s) > 0 && (s[0] == ' ' || s[0] == '\t') {
		s = s[1:]
	}
	for len(s) > 0 && (s[len(s)-1] == ' ' || s[len(s)-1] == '\t') {
		s = s[:len(s)-1]
	}
	return s
}

func equalsFoldASCII(a, b string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := 0; i < len(a); i++ {
		if toUpper(a[i]) != toUpper(b[i]) {
			return false
		}
	}
	return true
}

func isASCIILetter(b byte) bool {
	return (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z')
}

func toUpper(b byte) byte {
	if b >= 'a' && b <= 'z' {
		return b - ('a' - 'A')
	}
	return b
}
