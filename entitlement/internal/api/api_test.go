package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/compartarenta/entitlement/internal/config"
	"github.com/compartarenta/entitlement/internal/license"
)

func TestValidateInstallationIDBounds(t *testing.T) {
	if _, ok := validateID("short", 8, 64); ok {
		t.Fatal("expected reject short id")
	}
	id := "inst-alpha-device-001"
	if got, ok := validateID(id, 8, 64); !ok || got != id {
		t.Fatalf("got %q %v", got, ok)
	}
}

func TestIntrospectUnauthorizedWithoutToken(t *testing.T) {
	cfg := config.Config{InternalToken: "secret", IDMinLen: 8, IDMaxLen: 64}
	s := NewServer(cfg, nil)
	req := httptest.NewRequest(http.MethodPost, "/v1/introspect/envelope", nil)
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("status=%d", rr.Code)
	}
}

func TestMigrateInstallationUnauthorizedWithoutToken(t *testing.T) {
	cfg := config.Config{InternalToken: "secret", IDMinLen: 8, IDMaxLen: 64}
	s := NewServer(cfg, nil)
	req := httptest.NewRequest(http.MethodPost, "/v1/installations/migrate", nil)
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("status=%d", rr.Code)
	}
}

func TestFreeLicensesUnauthorizedWithoutToken(t *testing.T) {
	cfg := config.Config{InternalToken: "secret", IDMinLen: 8, IDMaxLen: 64}
	s := NewServer(cfg, nil)
	req := httptest.NewRequest(http.MethodGet, "/v1/free-licenses", nil)
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("status=%d", rr.Code)
	}
}

func TestServerGrantTokenIsStablePerInstallation(t *testing.T) {
	const installationID = "inst-alpha-device-001"
	want := "server-grant:" + installationID
	if got := serverGrantToken(installationID); got != want {
		t.Fatalf("got=%q want=%q", got, want)
	}
}

func TestMigrateInstallationRejectsInvalidEnvelopeKind(t *testing.T) {
	cfg := config.Config{InternalToken: "secret", IDMinLen: 8, IDMaxLen: 64}
	s := NewServer(cfg, nil)
	body := `{"plan_id":"plan:a","old_participant_installation_id":"inst-old-device","new_participant_installation_id":"inst-new-device","envelope_kind":13}`
	req := httptest.NewRequest(http.MethodPost, "/v1/installations/migrate", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer secret")
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("status=%d body=%s", rr.Code, rr.Body.String())
	}
}

func TestPlayTokenUnconfigured(t *testing.T) {
	cfg := config.Config{IDMinLen: 8, IDMaxLen: 64}
	s := NewServer(cfg, nil)
	body := `{"participant_installation_id":"inst-alpha-device-001","product_id":"bojairu.housing","purchase_token":"tok","platform":"google_play"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/licenses/play-token", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusServiceUnavailable {
		t.Fatalf("status=%d body=%s", rr.Code, rr.Body.String())
	}
}

func TestPlayTokenRejectsUnknownProduct(t *testing.T) {
	cfg := config.Config{IDMinLen: 8, IDMaxLen: 64}
	s := NewServer(cfg, nil)
	s.SetPlayVerifier(stubPlayVerifier{})
	body := `{"participant_installation_id":"inst-alpha-device-001","product_id":"not.a.sku","purchase_token":"tok","platform":"google_play"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/licenses/play-token", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("status=%d body=%s", rr.Code, rr.Body.String())
	}
}

func TestPlayTokenRejectsApplePlatform(t *testing.T) {
	cfg := config.Config{IDMinLen: 8, IDMaxLen: 64}
	s := NewServer(cfg, nil)
	s.SetPlayVerifier(stubPlayVerifier{})
	body := `{"participant_installation_id":"inst-alpha-device-001","product_id":"bojairu.housing","purchase_token":"tok","platform":"apple"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/licenses/play-token", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("status=%d body=%s", rr.Code, rr.Body.String())
	}
}

func TestLicenseStatusRejectedWhenPlayEnabled(t *testing.T) {
	cfg := config.Config{IDMinLen: 8, IDMaxLen: 64}
	s := NewServer(cfg, nil)
	s.SetPlayVerifier(stubPlayVerifier{})
	body := `{"plan_id":"plan-1","participant_installation_id":"inst-alpha-device-001","license_state":"active_paid"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/housing/license-status", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusConflict {
		t.Fatalf("status=%d body=%s", rr.Code, rr.Body.String())
	}
}

func TestListLicensesRejectsShortInstallationID(t *testing.T) {
	cfg := config.Config{IDMinLen: 8, IDMaxLen: 64}
	s := NewServer(cfg, nil)
	req := httptest.NewRequest(http.MethodGet, "/v1/licenses?participant_installation_id=short", nil)
	rr := httptest.NewRecorder()
	s.Handler().ServeHTTP(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("status=%d body=%s", rr.Code, rr.Body.String())
	}
}

type stubPlayVerifier struct{}

func (stubPlayVerifier) VerifyPurchase(context.Context, license.Purchase) (license.Result, error) {
	return license.Result{ValidationState: license.ValidationInvalid, Reason: "unused"}, nil
}
