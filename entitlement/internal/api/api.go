package api

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/compartarenta/entitlement/internal/config"
	"github.com/compartarenta/entitlement/internal/domain"
	"github.com/compartarenta/entitlement/internal/license"
	"github.com/compartarenta/entitlement/internal/push"
	"github.com/compartarenta/entitlement/internal/store"
	"github.com/compartarenta/entitlement/internal/version"
)

type Server struct {
	cfg      config.Config
	store    *store.Store
	housing  *domain.Housing
	verifier license.Verifier
	push     licensePushSender
}

type licensePushSender interface {
	SendLicenseChange(
		context.Context,
		string,
		push.LicenseChange,
	) error
}

func NewServer(cfg config.Config, st *store.Store) *Server {
	return &Server{
		cfg:      cfg,
		store:    st,
		housing:  domain.NewHousing(st, cfg),
		verifier: license.Stub{},
	}
}

// SetPlayVerifier enables Play-backed verification. Client-reported
// license-status writes are then rejected.
func (s *Server) SetPlayVerifier(v license.Verifier) {
	if v == nil {
		v = license.Stub{}
	}
	s.verifier = v
	s.housing.SetPlayVerification(true)
}

func (s *Server) SetLicensePushSender(sender licensePushSender) {
	s.push = sender
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/installations/register", s.handleRegisterInstallation)
	mux.HandleFunc("/v1/installations/push-token", s.handleInstallationPushToken)
	mux.HandleFunc("/v1/installations/migrate", s.handleMigrateInstallation)
	mux.HandleFunc("/v1/housing/plan-roster", s.handlePlanRoster)
	mux.HandleFunc("/v1/housing/license-status", s.handleLicenseStatus)
	mux.HandleFunc("/v1/licenses/play-token", s.handlePlayToken)
	mux.HandleFunc("/v1/licenses", s.handleListLicenses)
	mux.HandleFunc("/v1/free-licenses", s.handleFreeLicenses)
	mux.HandleFunc("/v1/housing/expense-decision", s.handleExpenseDecision)
	mux.HandleFunc("/v1/housing/active-use", s.handleActiveUse)
	mux.HandleFunc("/v1/introspect/envelope", s.handleIntrospectEnvelope)
	mux.HandleFunc("/v1/housing/plans/", s.handlePlanStatus)
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/readyz", s.handleReadyz)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/v1/introspect/envelope" && !s.authorizeInternal(r) {
			writeError(w, http.StatusUnauthorized, "unauthorized", "missing or invalid internal token")
			return
		}
		if r.URL.Path == "/v1/installations/migrate" && !s.authorizeInternal(r) {
			writeError(w, http.StatusUnauthorized, "unauthorized", "missing or invalid internal token")
			return
		}
		if r.URL.Path == "/v1/free-licenses" && !s.authorizeInternal(r) {
			writeError(w, http.StatusUnauthorized, "unauthorized", "missing or invalid internal token")
			return
		}
		mux.ServeHTTP(w, r)
	})
}

func (s *Server) authorizeInternal(r *http.Request) bool {
	if s.cfg.InternalToken == "" {
		return true
	}
	auth := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	return auth == s.cfg.InternalToken
}

func (s *Server) handleRegisterInstallation(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	var req struct {
		ParticipantInstallationID string `json:"participant_installation_id"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	id, ok := validateID(req.ParticipantInstallationID, s.cfg.IDMinLen, s.cfg.IDMaxLen)
	if !ok {
		writeError(w, http.StatusBadRequest, "invalid_installation_id", "installation id invalid")
		return
	}
	if err := s.housing.RegisterInstallation(r.Context(), id); err != nil {
		writeInternal(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleInstallationPushToken(
	w http.ResponseWriter,
	r *http.Request,
) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	var req struct {
		ParticipantInstallationID string `json:"participant_installation_id"`
		Provider                  string `json:"provider"`
		PushToken                 string `json:"push_token"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	id, ok := validateID(
		req.ParticipantInstallationID,
		s.cfg.IDMinLen,
		s.cfg.IDMaxLen,
	)
	if !ok {
		writeError(w, http.StatusBadRequest, "invalid_installation_id", "installation id invalid")
		return
	}
	if req.Provider != "fcm" {
		writeError(w, http.StatusBadRequest, "invalid_push_provider", "provider must be fcm")
		return
	}
	req.PushToken = strings.TrimSpace(req.PushToken)
	if req.PushToken == "" || len(req.PushToken) > 512 {
		writeError(w, http.StatusBadRequest, "invalid_push_token", "push token invalid")
		return
	}
	if err := s.store.UpsertInstallationPushToken(
		r.Context(),
		id,
		req.Provider,
		req.PushToken,
		time.Now().UTC(),
	); err != nil {
		writeInternal(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleMigrateInstallation(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	var req struct {
		PlanID                       string `json:"plan_id"`
		OldParticipantInstallationID string `json:"old_participant_installation_id"`
		NewParticipantInstallationID string `json:"new_participant_installation_id"`
		EnvelopeKind                 int    `json:"envelope_kind"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.EnvelopeKind != 15 {
		writeError(w, http.StatusBadRequest, "invalid_envelope_kind", "unsupported envelope kind")
		return
	}
	oldID, ok := validateID(req.OldParticipantInstallationID, s.cfg.IDMinLen, s.cfg.IDMaxLen)
	if !ok {
		writeError(w, http.StatusBadRequest, "invalid_installation_id", "old installation id invalid")
		return
	}
	newID, ok := validateID(req.NewParticipantInstallationID, s.cfg.IDMinLen, s.cfg.IDMaxLen)
	if !ok || req.PlanID == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "plan_id and new installation id required")
		return
	}
	if err := s.housing.MigrateInstallation(r.Context(), req.PlanID, oldID, newID); err != nil {
		if errors.Is(err, store.ErrOldInstallationNotFound) {
			writeError(w, http.StatusNotFound, "old_installation_not_found", "old installation id not found for plan")
			return
		}
		writeInternal(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handlePlanRoster(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	var req struct {
		PlanID                     string   `json:"plan_id"`
		RevisionID                 string   `json:"revision_id"`
		ParticipantInstallationIDs []string `json:"participant_installation_ids"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	if req.PlanID == "" || req.RevisionID == "" || len(req.ParticipantInstallationIDs) < 2 {
		writeError(w, http.StatusBadRequest, "invalid_roster", "plan_id, revision_id, and at least two participants required")
		return
	}
	ids := make([]string, 0, len(req.ParticipantInstallationIDs))
	for _, raw := range req.ParticipantInstallationIDs {
		id, ok := validateID(raw, s.cfg.IDMinLen, s.cfg.IDMaxLen)
		if !ok {
			writeError(w, http.StatusBadRequest, "invalid_installation_id", "participant installation id invalid")
			return
		}
		ids = append(ids, id)
	}
	if err := s.housing.SetActiveRoster(r.Context(), req.PlanID, req.RevisionID, ids); err != nil {
		writeInternal(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleLicenseStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	if s.housing.PlayVerificationEnabled() {
		writeError(w, http.StatusConflict, "play_verification_required",
			"client-reported license status is not accepted; POST /v1/licenses/play-token")
		return
	}
	var req struct {
		PlanID                    string `json:"plan_id"`
		ParticipantInstallationID string `json:"participant_installation_id"`
		LicenseState              string `json:"license_state"`
		ExpiresAt                 string `json:"expires_at"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	pid, ok := validateID(req.ParticipantInstallationID, s.cfg.IDMinLen, s.cfg.IDMaxLen)
	if !ok || req.PlanID == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "plan_id and installation id required")
		return
	}
	state := req.LicenseState
	if state != domain.LicenseActivePaid && state != domain.LicenseUnpaid {
		writeError(w, http.StatusBadRequest, "invalid_license_state", "license_state must be active_paid or unpaid")
		return
	}
	var expires *time.Time
	if req.ExpiresAt != "" {
		t, err := time.Parse(time.RFC3339, req.ExpiresAt)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid_expires_at", "expires_at must be RFC3339")
			return
		}
		expires = &t
	}
	if err := s.housing.ReportLicense(r.Context(), req.PlanID, pid, state, expires); err != nil {
		writeInternal(w, err)
		return
	}
	_ = s.housing.RefreshPlanLifecycle(r.Context(), req.PlanID)
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleExpenseDecision(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	var req struct {
		PlanID                    string `json:"plan_id"`
		ExpenseID                 string `json:"expense_id"`
		ParticipantInstallationID string `json:"participant_installation_id"`
		DecisionKind              string `json:"decision_kind"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	pid, ok := validateID(req.ParticipantInstallationID, s.cfg.IDMinLen, s.cfg.IDMaxLen)
	if !ok || req.PlanID == "" || req.ExpenseID == "" || req.DecisionKind == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "missing required fields")
		return
	}
	if err := s.housing.RecordExpenseDecision(r.Context(), req.PlanID, req.ExpenseID, pid, req.DecisionKind); err != nil {
		writeInternal(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleActiveUse(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	var req struct {
		PlanID string `json:"plan_id"`
	}
	if !decodeJSON(w, r, &req) || req.PlanID == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "plan_id required")
		return
	}
	if err := s.housing.RecordActiveUse(r.Context(), req.PlanID); err != nil {
		writeInternal(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleIntrospectEnvelope(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	var req struct {
		Module                    string `json:"module"`
		PlanID                    string `json:"plan_id"`
		ParticipantInstallationID string `json:"participant_installation_id"`
		Operation                 string `json:"operation"`
		ExpenseID                 string `json:"expense_id"`
		RevisionID                string `json:"revision_id"`
		DecisionKind              string `json:"decision_kind"`
		EnvelopeKind              int    `json:"envelope_kind"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	res, err := s.housing.Introspect(r.Context(), domain.IntrospectInput{
		Module:                    req.Module,
		PlanID:                    req.PlanID,
		ParticipantInstallationID: req.ParticipantInstallationID,
		Operation:                 req.Operation,
		ExpenseID:                 req.ExpenseID,
		RevisionID:                req.RevisionID,
		DecisionKind:              req.DecisionKind,
		EnvelopeKind:              req.EnvelopeKind,
	})
	if err != nil {
		writeInternal(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"allow": res.Allow,
		"code":  res.Code,
	})
}

func (s *Server) handlePlanStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET only")
		return
	}
	planID := strings.TrimPrefix(r.URL.Path, "/v1/housing/plans/")
	if planID == "" || strings.Contains(planID, "/") {
		writeError(w, http.StatusNotFound, "not_found", "plan not found")
		return
	}
	plan, err := s.store.GetPlan(r.Context(), planID)
	if err != nil {
		writeInternal(w, err)
		return
	}
	if plan == nil {
		writeError(w, http.StatusNotFound, "not_found", "plan not found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"plan_id":               plan.PlanID,
		"lifecycle_state":       plan.LifecycleState,
		"trial_started_at":      plan.TrialStartedAt,
		"trial_ends_at":         plan.TrialEndsAt,
		"grace_ends_at":         plan.GraceEndsAt,
		"active_use_started_at": plan.ActiveUseStartedAt,
	})
}

func (s *Server) handlePlayToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	if !s.housing.PlayVerificationEnabled() {
		writeError(w, http.StatusServiceUnavailable, "play_verifier_unconfigured",
			"Play purchase verification is not configured")
		return
	}
	var req struct {
		ParticipantInstallationID string `json:"participant_installation_id"`
		ProductID                 string `json:"product_id"`
		PurchaseToken             string `json:"purchase_token"`
		Platform                  string `json:"platform"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	pid, ok := validateID(req.ParticipantInstallationID, s.cfg.IDMinLen, s.cfg.IDMaxLen)
	if !ok {
		writeError(w, http.StatusBadRequest, "invalid_installation_id", "installation id invalid")
		return
	}
	platform := strings.TrimSpace(req.Platform)
	if platform == "" {
		platform = license.PlatformGooglePlay
	}
	if platform != license.PlatformGooglePlay {
		writeError(w, http.StatusBadRequest, "platform_unsupported", "only google_play is supported")
		return
	}
	productID := strings.TrimSpace(req.ProductID)
	token := strings.TrimSpace(req.PurchaseToken)
	if productID == "" || token == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "product_id and purchase_token required")
		return
	}
	if _, known := license.LookupPlayProduct(productID); !known {
		writeError(w, http.StatusBadRequest, "unknown_product_id", "product_id is not a documented Play SKU")
		return
	}
	res, err := s.verifier.VerifyPurchase(r.Context(), license.Purchase{
		Platform:      platform,
		ProductID:     productID,
		PurchaseToken: token,
	})
	if err != nil {
		writeError(w, http.StatusBadGateway, "play_verify_failed", err.Error())
		return
	}
	if res.ProductID == "" {
		res.ProductID = productID
	}
	blob, _ := json.Marshal(map[string]any{
		"product_id":         res.ProductID,
		"subscription_state": res.SubscriptionState,
		"validation_state":   res.ValidationState,
		"granted_modules":    res.GrantedModules,
	})
	if err := s.housing.ApplyPlayResult(r.Context(), pid, res, token, blob); err != nil {
		writeInternal(w, err)
		return
	}
	body := map[string]any{
		"validation_state":   res.ValidationState,
		"product_id":         res.ProductID,
		"granted_modules":    res.GrantedModules,
		"subscription_state": res.SubscriptionState,
		"reason":             res.Reason,
	}
	if res.ExpiresAt != nil {
		body["expires_at"] = res.ExpiresAt.UTC().Format(time.RFC3339Nano)
	}
	writeJSON(w, http.StatusOK, body)
}

func (s *Server) handleListLicenses(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET only")
		return
	}
	pid, ok := validateID(r.URL.Query().Get("participant_installation_id"), s.cfg.IDMinLen, s.cfg.IDMaxLen)
	if !ok {
		writeError(w, http.StatusBadRequest, "invalid_installation_id", "installation id invalid")
		return
	}
	rows, err := s.store.PlayReceiptsForInstallation(r.Context(), pid)
	if err != nil {
		writeInternal(w, err)
		return
	}
	items := make([]map[string]any, 0, len(rows))
	for _, rec := range rows {
		item := map[string]any{
			"product_id":         rec.ProductID,
			"platform":           rec.Platform,
			"validation_state":   rec.ValidationState,
			"granted_modules":    rec.GrantedModules,
			"subscription_state": rec.SubscriptionState,
		}
		if rec.ExpiresAt != nil {
			item["expires_at"] = rec.ExpiresAt.UTC().Format(time.RFC3339Nano)
		}
		items = append(items, item)
	}
	free, err := s.store.FreeLicenseForInstallation(r.Context(), pid)
	if err != nil {
		writeInternal(w, err)
		return
	}
	if free != nil && free.ExpiresAt.After(time.Now().UTC()) {
		items = append(items, map[string]any{
			"product_id":         license.ProductAllModules,
			"platform":           license.PlatformServerGrant,
			"purchase_token":     serverGrantToken(pid),
			"purchased_at":       free.GrantedAt.UTC().Format(time.RFC3339Nano),
			"expires_at":         free.ExpiresAt.UTC().Format(time.RFC3339Nano),
			"validation_state":   license.ValidationValid,
			"granted_modules":    []string{license.ModuleHousing, license.ModuleVehicle, license.ModuleVehicleSharing},
			"subscription_state": license.SubscriptionStateActive,
			"auto_renewing":      false,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"receipts": items})
}

func (s *Server) handleFreeLicenses(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		s.handleListFreeLicenses(w, r)
	case http.MethodPost:
		s.handleSetFreeLicense(w, r)
	case http.MethodDelete:
		s.handleDeleteFreeLicense(w, r)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET, POST, or DELETE only")
	}
}

func (s *Server) handleListFreeLicenses(w http.ResponseWriter, r *http.Request) {
	rows, err := s.store.ListFreeLicenses(r.Context())
	if err != nil {
		writeInternal(w, err)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	writer := csv.NewWriter(w)
	if err := writer.Write([]string{"Nom", "InstallationId"}); err != nil {
		return
	}
	for _, row := range rows {
		if err := writer.Write([]string{row.UserName, row.InstallationID}); err != nil {
			return
		}
	}
	writer.Flush()
}

func (s *Server) handleSetFreeLicense(w http.ResponseWriter, r *http.Request) {
	if s.push == nil {
		writeError(w, http.StatusServiceUnavailable, "push_unconfigured", "FCM sender not configured")
		return
	}
	var req struct {
		ParticipantInstallationID string `json:"participant_installation_id"`
		UserName                  string `json:"free_user_name"`
	}
	if !decodeJSON(w, r, &req) {
		return
	}
	id, ok := validateID(
		req.ParticipantInstallationID,
		s.cfg.IDMinLen,
		s.cfg.IDMaxLen,
	)
	name := strings.TrimSpace(req.UserName)
	if !ok || name == "" || len(name) > 200 {
		writeError(w, http.StatusBadRequest, "invalid_request", "installation id and free user name required")
		return
	}
	grantedAt := time.Now().UTC()
	expiresAt := grantedAt.AddDate(100, 0, 0)
	free, err := s.store.SetFreeLicense(
		r.Context(),
		id,
		name,
		grantedAt,
		expiresAt,
	)
	if err != nil {
		switch {
		case errors.Is(err, store.ErrPaidLicenseStillValid):
			writeError(w, http.StatusConflict, "paid_license_still_valid", err.Error())
		case errors.Is(err, store.ErrFreeLicenseExists):
			writeError(w, http.StatusConflict, "free_license_exists", err.Error())
		case errors.Is(err, store.ErrInstallationNotFound):
			writeError(w, http.StatusNotFound, "installation_not_found", err.Error())
		default:
			writeInternal(w, err)
		}
		return
	}
	if free.PushProvider != "fcm" || free.PushToken == "" {
		_ = s.store.ClearFreeLicense(r.Context(), id)
		writeError(w, http.StatusConflict, "push_token_missing", "installation has no registered FCM token")
		return
	}
	change := push.LicenseChange{
		Action:         "grant",
		InstallationID: id,
		ProductID:      license.ProductAllModules,
		Platform:       license.PlatformServerGrant,
		PurchaseToken:  serverGrantToken(id),
		PurchasedAt:    grantedAt,
		ExpiresAt:      expiresAt,
	}
	if err := s.push.SendLicenseChange(
		r.Context(),
		free.PushToken,
		change,
	); err != nil {
		_ = s.store.ClearFreeLicense(r.Context(), id)
		writeError(w, http.StatusBadGateway, "push_failed", err.Error())
		return
	}
	if err := s.housing.ReprojectInstallationLicense(r.Context(), id, false); err != nil {
		writeInternal(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{
		"participant_installation_id": id,
		"free_user_name":              name,
		"expires_at":                  expiresAt.Format(time.RFC3339Nano),
	})
}

func (s *Server) handleDeleteFreeLicense(w http.ResponseWriter, r *http.Request) {
	if s.push == nil {
		writeError(w, http.StatusServiceUnavailable, "push_unconfigured", "FCM sender not configured")
		return
	}
	id, ok := validateID(
		r.URL.Query().Get("participant_installation_id"),
		s.cfg.IDMinLen,
		s.cfg.IDMaxLen,
	)
	if !ok {
		writeError(w, http.StatusBadRequest, "invalid_installation_id", "installation id invalid")
		return
	}
	free, err := s.store.FreeLicenseForInstallation(r.Context(), id)
	if err != nil {
		writeInternal(w, err)
		return
	}
	if free == nil {
		writeError(w, http.StatusNotFound, "free_license_not_found", "free license not found")
		return
	}
	if free.PushProvider != "fcm" || free.PushToken == "" {
		writeError(w, http.StatusConflict, "push_token_missing", "installation has no registered FCM token")
		return
	}
	if err := s.push.SendLicenseChange(
		r.Context(),
		free.PushToken,
		push.LicenseChange{
			Action:         "revoke",
			InstallationID: id,
			ProductID:      license.ProductAllModules,
			Platform:       license.PlatformServerGrant,
			PurchaseToken:  serverGrantToken(id),
		},
	); err != nil {
		writeError(w, http.StatusBadGateway, "push_failed", err.Error())
		return
	}
	if err := s.store.ClearFreeLicense(r.Context(), id); err != nil {
		writeInternal(w, err)
		return
	}
	if err := s.housing.ReprojectInstallationLicense(r.Context(), id, true); err != nil {
		writeInternal(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func serverGrantToken(installationID string) string {
	return "server-grant:" + installationID
}

func (s *Server) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status":         "ok",
		"build":          version.Build,
		"schema_version": itoa(version.Expected),
	})
}

func (s *Server) handleReadyz(w http.ResponseWriter, r *http.Request) {
	if _, err := s.store.SchemaVersion(r.Context()); err != nil {
		writeError(w, http.StatusServiceUnavailable, "not_ready", "database unavailable")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
	if err != nil {
		writeError(w, http.StatusRequestEntityTooLarge, "oversize", "request too large")
		return false
	}
	if err := json.Unmarshal(body, dst); err != nil {
		writeError(w, http.StatusBadRequest, "malformed_json", "malformed JSON body")
		return false
	}
	return true
}

func validateID(id string, minLen, maxLen int) (string, bool) {
	id = strings.TrimSpace(id)
	if len(id) < minLen || len(id) > maxLen {
		return "", false
	}
	return id, true
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, code, msg string) {
	writeJSON(w, status, map[string]string{"error": code, "message": msg})
}

func writeInternal(w http.ResponseWriter, err error) {
	writeError(w, http.StatusInternalServerError, "internal_error", err.Error())
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [20]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}

// SetHousingClock is for tests.
func (s *Server) SetHousingClock(now func() time.Time) { s.housing.SetClock(now) }

// HousingDomain exposes domain for tests.
func (s *Server) HousingDomain() *domain.Housing { return s.housing }

// PingStore checks DB for tests.
func (s *Server) PingStore(ctx context.Context) error {
	_, err := s.store.SchemaVersion(ctx)
	return err
}
