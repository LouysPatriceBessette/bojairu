//go:build integration

package integration

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	dto "github.com/prometheus/client_model/go"

	"github.com/compartarenta/relay/internal/api"
	"github.com/compartarenta/relay/internal/config"
	"github.com/compartarenta/relay/internal/logging"
	"github.com/compartarenta/relay/internal/metrics"
	"github.com/compartarenta/relay/internal/store"
	"github.com/compartarenta/relay/internal/sweeper"
)

const integrationDSNEnv = "RELAY_INTEGRATION_TEST_DSN"

func integrationDSN(t *testing.T) string {
	t.Helper()
	dsn := os.Getenv(integrationDSNEnv)
	if dsn == "" {
		t.Skipf("set %s to a PostgreSQL DSN to run integration tests", integrationDSNEnv)
	}
	return dsn
}

func resetRelayData(ctx context.Context, t *testing.T, dsn string) {
	t.Helper()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("pgxpool: %v", err)
	}
	defer pool.Close()
	_, err = pool.Exec(ctx, `
		DELETE FROM envelopes;
		DELETE FROM idempotency_entries;
		DELETE FROM routing_relationships;
		DELETE FROM operator_actions;
		DELETE FROM routing_push_tokens;
		DELETE FROM relay_day_metrics;
	`)
	if err != nil {
		t.Fatalf("reset relay tables: %v", err)
	}
}

func testConfig(dsn string) config.Config {
	return config.Config{
		PublicListenAddr:     "127.0.0.1:0",
		PrivateListenAddr:    "127.0.0.1:0",
		DatabaseURL:          dsn,
		EnvelopeMaxBytes:     65536,
		EnvelopeTTLMin:       24 * time.Hour,
		EnvelopeTTLMax:       168 * time.Hour,
		IdempotencyTTL:       24 * time.Hour,
		DisconnectGrace:      5 * time.Minute,
		RoutingInactivityTTL: 26 * 7 * 24 * time.Hour,
		SweeperInterval:      time.Minute,
		RateLimitPerIdentity: 1e6,
		RateLimitPerIP:       1e6,
		ShutdownTimeout:      10 * time.Second,
		RoutingPushTokenTTL:  336 * time.Hour,
		StatsListenAddr:      "-",
	}
}

func counterValue(c interface{ Write(*dto.Metric) error }) float64 {
	var m dto.Metric
	if err := c.Write(&m); err != nil {
		panic(err)
	}
	return m.GetCounter().GetValue()
}

func b64ID(seed byte, n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = seed + byte(i)
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

// TestIntegrationEnvelopeSubmitDeliverDelete (OpenSpec 7.3) exercises
// POST /v1/envelopes → ack → row removal and checks Prometheus counters.
func TestIntegrationEnvelopeSubmitDeliverDelete(t *testing.T) {
	ctx := context.Background()
	dsn := integrationDSN(t)

	st, err := store.New(ctx, dsn)
	if err != nil {
		t.Fatalf("store.New: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	resetRelayData(ctx, t, dsn)

	sender := mustDecodeB64ID(t, b64ID(0x10, 8))
	recipient := mustDecodeB64ID(t, b64ID(0x20, 8))
	if err := st.EstablishRouting(ctx, sender, recipient); err != nil {
		t.Fatalf("EstablishRouting: %v", err)
	}

	cfg := testConfig(dsn)
	srv := api.NewServer(cfg, st, logging.NewForTest(), nil)
	h := srv.PublicHandler()

	accepted0 := counterValue(metrics.EnvelopesAccepted)
	delivered0 := counterValue(metrics.EnvelopesDelivered)

	idemKey := b64ID(0x30, 8)
	cipher := base64.RawURLEncoding.EncodeToString([]byte{0x01, 0x02, 0x03})

	body := map[string]any{
		"sender_identity":    b64ID(0x10, 8),
		"recipient_identity": b64ID(0x20, 8),
		"idempotency_key":    idemKey,
		"ciphertext":         cipher,
		"kind":               1,
		"ttl_seconds":        int((48 * time.Hour).Seconds()),
	}
	payload, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/v1/envelopes", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("POST /v1/envelopes: status %d body %s", rr.Code, rr.Body.String())
	}

	var envResp struct {
		EnvelopeID string `json:"envelope_id"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &envResp); err != nil {
		t.Fatalf("decode envelope response: %v", err)
	}
	if envResp.EnvelopeID == "" {
		t.Fatal("empty envelope_id")
	}

	if got := counterValue(metrics.EnvelopesAccepted) - accepted0; got != 1 {
		t.Fatalf("EnvelopesAccepted want +1 got %v", got)
	}

	ackPath := fmt.Sprintf("/v1/envelopes/%s/ack", envResp.EnvelopeID)
	ackBody := map[string]string{"recipient_identity": b64ID(0x20, 8)}
	ackPayload, _ := json.Marshal(ackBody)
	ackReq := httptest.NewRequest(http.MethodPost, ackPath, bytes.NewReader(ackPayload))
	ackReq.Header.Set("Content-Type", "application/json")
	ackRR := httptest.NewRecorder()
	h.ServeHTTP(ackRR, ackReq)
	if ackRR.Code != http.StatusNoContent {
		t.Fatalf("POST ack: status %d body %s", ackRR.Code, ackRR.Body.String())
	}

	if got := counterValue(metrics.EnvelopesDelivered) - delivered0; got != 1 {
		t.Fatalf("EnvelopesDelivered want +1 got %v", got)
	}

	inbox, err := st.FetchInbox(ctx, recipient, 10, time.Now().UTC())
	if err != nil {
		t.Fatalf("FetchInbox: %v", err)
	}
	if len(inbox) != 0 {
		t.Fatalf("FetchInbox after ack: want 0 rows got %d", len(inbox))
	}
}

func mustDecodeB64ID(t *testing.T, s string) []byte {
	t.Helper()
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		t.Fatalf("decode id: %v", err)
	}
	return b
}

// TestIntegrationSweeperExpiresUndeliveredEnvelope (OpenSpec 7.4) inserts
// an undelivered envelope with TTL in the past relative to the sweeper
// clock, runs one sweep, and checks deletion + metrics.
func TestIntegrationSweeperExpiresUndeliveredEnvelope(t *testing.T) {
	ctx := context.Background()
	dsn := integrationDSN(t)

	st, err := store.New(ctx, dsn)
	if err != nil {
		t.Fatalf("store.New: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	resetRelayData(ctx, t, dsn)

	sweepAt := time.Date(2024, 6, 1, 12, 0, 0, 0, time.UTC)
	created := sweepAt.Add(-48 * time.Hour)
	ttlAt := sweepAt.Add(-1 * time.Hour)

	envID := bytes.Repeat([]byte{0x77}, 16)
	sender := bytes.Repeat([]byte{0x11}, 8)
	recipient := bytes.Repeat([]byte{0x22}, 8)

	if err := st.StoreEnvelope(ctx, store.Envelope{
		EnvelopeID:        envID,
		SenderIdentity:    sender,
		RecipientIdentity: recipient,
		Ciphertext:        []byte{0xab},
		Kind:              2,
		CreatedAt:         created,
		TTLExpiresAt:      ttlAt,
	}); err != nil {
		t.Fatalf("StoreEnvelope: %v", err)
	}

	cfg := testConfig(dsn)
	log := logging.NewForTest()
	sw := sweeper.New(cfg, st, log)
	sw.SetClock(func() time.Time { return sweepAt })

	expired0 := counterValue(metrics.EnvelopesExpired)
	runs0 := counterValue(metrics.SweeperRuns)

	stats, err := sw.Run(ctx)
	if err != nil {
		t.Fatalf("sweeper.Run: %v", err)
	}
	if stats.EnvelopesExpired != 1 {
		t.Fatalf("stats.EnvelopesExpired want 1 got %d", stats.EnvelopesExpired)
	}

	if got := counterValue(metrics.EnvelopesExpired) - expired0; got != 1 {
		t.Fatalf("metrics.EnvelopesExpired want +1 got %v", got)
	}
	if got := counterValue(metrics.SweeperRuns) - runs0; got != 1 {
		t.Fatalf("metrics.SweeperRuns want +1 got %v", got)
	}

	inbox, err := st.FetchInbox(ctx, recipient, 10, time.Now().UTC())
	if err != nil {
		t.Fatalf("FetchInbox: %v", err)
	}
	if len(inbox) != 0 {
		t.Fatalf("after sweep want 0 inbox rows got %d", len(inbox))
	}
}

func TestIntegrationInboxOmitsExpiredEnvelope(t *testing.T) {
	ctx := context.Background()
	dsn := integrationDSN(t)

	st, err := store.New(ctx, dsn)
	if err != nil {
		t.Fatalf("store.New: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	resetRelayData(ctx, t, dsn)

	now := time.Date(2026, 8, 16, 12, 0, 0, 0, time.UTC)
	envID := bytes.Repeat([]byte{0x88}, 16)
	sender := bytes.Repeat([]byte{0x11}, 8)
	recipient := bytes.Repeat([]byte{0x22}, 8)

	if err := st.StoreEnvelope(ctx, store.Envelope{
		EnvelopeID:        envID,
		SenderIdentity:    sender,
		RecipientIdentity: recipient,
		Ciphertext:        []byte{0xab},
		Kind:              2,
		CreatedAt:         now.Add(-4 * time.Hour),
		TTLExpiresAt:      now.Add(-time.Minute),
	}); err != nil {
		t.Fatalf("StoreEnvelope: %v", err)
	}

	inbox, err := st.FetchInbox(ctx, recipient, 10, now)
	if err != nil {
		t.Fatalf("FetchInbox: %v", err)
	}
	if len(inbox) != 0 {
		t.Fatalf("expired envelope still in inbox: %d rows", len(inbox))
	}
}
