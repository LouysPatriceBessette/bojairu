package api

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/compartarenta/relay/internal/config"
)

func TestPrefersHTML(t *testing.T) {
	cases := []struct {
		accept string
		want   bool
	}{
		{"", false},
		{"application/json", false},
		{"*/*", false},
		{"text/html", true},
		{"text/html,application/xhtml+xml", true},
		{"application/json, text/html;q=0.9", true},
	}
	for _, c := range cases {
		r := httptest.NewRequest(http.MethodGet, "/healthz", nil)
		if c.accept != "" {
			r.Header.Set("Accept", c.accept)
		}
		if got := prefersHTML(r); got != c.want {
			t.Errorf("Accept=%q got %v want %v", c.accept, got, c.want)
		}
	}
}

func TestHandleHealthzHTML(t *testing.T) {
	s := &Server{}
	r := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	r.Header.Set("Accept", "text/html")
	w := httptest.NewRecorder()
	s.handleHealthz(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("status %d", w.Code)
	}
	ct := w.Header().Get("Content-Type")
	if !strings.Contains(ct, "text/html") {
		t.Fatalf("content-type %q", ct)
	}
	body := w.Body.String()
	if !strings.Contains(body, "schema_version") || !strings.Contains(body, "status") {
		t.Fatalf("unexpected body: %s", body)
	}
}

func TestDecodeIdentityRejectsBadBase64(t *testing.T) {
	if _, err := decodeIdentity("!!!not base64!!!", 8, 64); err == nil {
		t.Fatal("expected base64 error")
	}
}

func TestDecodeIdentityEnforcesLengthBounds(t *testing.T) {
	// 4 bytes of payload -> "AAECAw" (raw url, 6 chars).
	short := "AAECAw"
	if _, err := decodeIdentity(short, 8, 64); err == nil {
		t.Fatal("expected length error for short identity")
	}

	tooLongBytes := strings.Repeat("A", 200)
	if _, err := decodeIdentity(tooLongBytes, 8, 64); err == nil {
		t.Fatal("expected length error for over-cap identity")
	}
}

func TestDecodeIdentityAcceptsInRangeBytes(t *testing.T) {
	// raw url base64 of 16 bytes is 22 chars (no padding).
	good := "AAAAAAAAAAAAAAAAAAAAAA" // 16 zero bytes
	b, err := decodeIdentity(good, 8, 64)
	if err != nil {
		t.Fatalf("unexpected: %v", err)
	}
	if len(b) != 16 {
		t.Fatalf("expected 16 bytes, got %d", len(b))
	}
}

func TestDecodeCiphertextRejectsOversize(t *testing.T) {
	// 12 bytes of base64 = 9 bytes payload; cap at 8.
	if _, err := decodeCiphertext("AAAAAAAAAAAA", 8); err == nil {
		t.Fatal("expected oversize error")
	}
}

func TestEnvelopeRetentionUntil(t *testing.T) {
	s := &Server{
		cfg: config.Config{
			EnvelopeTTLMin: 24 * time.Hour,
			EnvelopeTTLMax: 168 * time.Hour,
		},
	}
	now := time.Date(2026, 8, 16, 12, 0, 0, 0, time.UTC)

	t.Run("no expires_at uses seven days", func(t *testing.T) {
		got, err := s.envelopeRetentionUntil(envelopeRequest{}, now)
		if err != nil {
			t.Fatal(err)
		}
		want := now.Add(168 * time.Hour)
		if !got.Equal(want) {
			t.Fatalf("got %s want %s", got, want)
		}
	})

	t.Run("expires_at three hours is kept", func(t *testing.T) {
		at := now.Add(3 * time.Hour)
		got, err := s.envelopeRetentionUntil(envelopeRequest{ExpiresAt: &at}, now)
		if err != nil {
			t.Fatal(err)
		}
		if !got.Equal(at) {
			t.Fatalf("got %s want %s", got, at)
		}
	})

	t.Run("past expires_at is rejected", func(t *testing.T) {
		at := now.Add(-time.Minute)
		_, err := s.envelopeRetentionUntil(envelopeRequest{ExpiresAt: &at}, now)
		if !errors.Is(err, errExpiresAtNotFuture) {
			t.Fatalf("err %v", err)
		}
	})
}

func TestClassifyEndpoint(t *testing.T) {
	cases := []struct {
		method, path, want string
	}{
		{"POST", "/v1/envelopes", "envelopes"},
		{"POST", "/v1/envelopes/abc/ack", "envelopes_ack"},
		{"GET", "/v1/inbox/xyz", "inbox"},
		{"POST", "/v1/disconnect", "disconnect"},
		{"POST", "/v1/handshake/establish", "handshake_establish"},
		{"GET", "/healthz", "healthz"},
		{"GET", "/readyz", "readyz"},
		{"GET", "/foo", "other"},
	}
	for _, c := range cases {
		t.Run(c.path, func(t *testing.T) {
			r := newRequest(c.method, c.path)
			if got := classifyEndpoint(r); got != c.want {
				t.Errorf("classifyEndpoint(%s) = %q, want %q", c.path, got, c.want)
			}
		})
	}
}

func TestStatusClass(t *testing.T) {
	cases := []struct {
		code int
		want string
	}{
		{200, "2xx"}, {204, "2xx"},
		{301, "3xx"}, {404, "4xx"},
		{500, "5xx"}, {503, "5xx"},
	}
	for _, c := range cases {
		if got := statusClass(c.code); got != c.want {
			t.Errorf("statusClass(%d) = %q, want %q", c.code, got, c.want)
		}
	}
}

func TestFirstNonNilReturnsFirstError(t *testing.T) {
	if got := firstNonNil(nil, nil, errors.New("a"), errors.New("b")); got == nil || got.Error() != "a" {
		t.Fatalf("unexpected: %v", got)
	}
	if got := firstNonNil(nil, nil); got != nil {
		t.Fatalf("expected nil for all-nil input, got %v", got)
	}
}

func TestCORSDisabledByDefault(t *testing.T) {
	s := &Server{cfg: config.Config{}}
	called := false
	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusNoContent)
	})
	h := s.cors(inner)

	r := httptest.NewRequest(http.MethodGet, "/v1/inbox/whatever", nil)
	r.Header.Set("Origin", "http://localhost:5001")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, r)

	if !called {
		t.Fatal("expected inner handler to run when CORS is disabled")
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("expected no Access-Control-Allow-Origin, got %q", got)
	}
}

func TestCORSEchoesMatchingOrigin(t *testing.T) {
	s := &Server{cfg: config.Config{
		CORSAllowedOrigins: []string{"http://localhost:5001", "https://app.example.tld"},
	}}
	h := s.cors(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	r := httptest.NewRequest(http.MethodPost, "/v1/handshake/establish", nil)
	r.Header.Set("Origin", "http://localhost:5001")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, r)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:5001" {
		t.Errorf("ACAO mismatch: got %q", got)
	}
	if got := rec.Header().Get("Vary"); !strings.Contains(got, "Origin") {
		t.Errorf("Vary should contain Origin, got %q", got)
	}
}

func TestCORSRejectsUnknownOrigin(t *testing.T) {
	s := &Server{cfg: config.Config{
		CORSAllowedOrigins: []string{"http://localhost:5001"},
	}}
	h := s.cors(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	r := httptest.NewRequest(http.MethodPost, "/v1/handshake/establish", nil)
	r.Header.Set("Origin", "https://evil.example")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, r)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("non-allow-listed origin should get no ACAO, got %q", got)
	}
}

func TestCORSWildcardAllowsAny(t *testing.T) {
	s := &Server{cfg: config.Config{
		CORSAllowedOrigins: []string{"*"},
	}}
	h := s.cors(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	r := httptest.NewRequest(http.MethodPost, "/v1/handshake/establish", nil)
	r.Header.Set("Origin", "https://random.example")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, r)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "*" {
		t.Errorf("wildcard origin should yield '*', got %q", got)
	}
}

func TestParticipantInstallationMigrateDisabledWhenEntitlementOff(t *testing.T) {
	s := &Server{cfg: config.Config{EntitlementEnabled: false}}
	body := `{"envelope_kind":15,"plan_id":"plan:a","old_participant_installation_id":"inst-old-device","new_participant_installation_id":"inst-new-device"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/participant-installation-migrate", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	s.handleParticipantInstallationMigrate(rr, req)
	if rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("status=%d body=%s", rr.Code, rr.Body.String())
	}
}

func TestCORSPreflightShortCircuits(t *testing.T) {
	s := &Server{cfg: config.Config{
		CORSAllowedOrigins: []string{"http://localhost:5001"},
	}}
	innerCalled := false
	h := s.cors(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		innerCalled = true
	}))

	r := httptest.NewRequest(http.MethodOptions, "/v1/handshake/establish", nil)
	r.Header.Set("Origin", "http://localhost:5001")
	r.Header.Set("Access-Control-Request-Method", "POST")
	r.Header.Set("Access-Control-Request-Headers", "content-type")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, r)

	if innerCalled {
		t.Fatal("preflight must not reach inner handler")
	}
	if rec.Code != http.StatusNoContent {
		t.Fatalf("preflight should respond 204, got %d", rec.Code)
	}
	if got := rec.Header().Get("Access-Control-Allow-Methods"); !strings.Contains(got, "POST") {
		t.Errorf("ACAM should include POST, got %q", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Headers"); !strings.Contains(got, "content-type") {
		t.Errorf("ACAH should include content-type, got %q", got)
	}
}
