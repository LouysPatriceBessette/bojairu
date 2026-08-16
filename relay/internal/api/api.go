// Package api implements the HTTP surface of the relay.
//
// Every handler enforces framing, size limit, and rate limit before
// touching the database. The handlers never log ciphertext or anything
// derived from it; only opaque identifiers, timing, and error classes
// reach the structured logger (`relay-observability-without-plaintext`
// / "Logs do not contain user-content plaintext").
package api

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/compartarenta/relay/internal/config"
	"github.com/compartarenta/relay/internal/entitlement"
	"github.com/compartarenta/relay/internal/logging"
	"github.com/compartarenta/relay/internal/metrics"
	"github.com/compartarenta/relay/internal/push"
	"github.com/compartarenta/relay/internal/ratelimit"
	"github.com/compartarenta/relay/internal/store"
	"github.com/compartarenta/relay/internal/version"
)

// Server bundles the dependencies the HTTP layer needs.
type Server struct {
	cfg          config.Config
	store        *store.Store
	logger       *logging.Logger
	identityLim  *ratelimit.Limiter
	ipLim        *ratelimit.Limiter
	now          func() time.Time
	idMinLen     int
	idMaxLen     int
	envelopeIDFn func() ([]byte, error)
	pushWake     *push.Dispatcher
	entitlement  *entitlement.Client
}

// NewServer constructs a fully-wired Server. The identity / IP rate
// limiters are owned by the server and live for the process lifetime.
func NewServer(cfg config.Config, st *store.Store, l *logging.Logger, wake *push.Dispatcher) *Server {
	s := &Server{
		cfg:          cfg,
		store:        st,
		logger:       l,
		identityLim:  ratelimit.New(cfg.RateLimitPerIdentity),
		ipLim:        ratelimit.New(cfg.RateLimitPerIP),
		now:          time.Now,
		idMinLen:     8,
		idMaxLen:     64,
		envelopeIDFn: randomEnvelopeID,
		pushWake:     wake,
	}
	if cfg.EntitlementEnabled {
		s.entitlement = entitlement.NewClient(cfg.EntitlementIntrospectURL, cfg.EntitlementInternalToken)
	}
	return s
}

// PublicHandler returns the http.Handler bound to the public listener.
// It exposes the relay protocol endpoints plus /healthz and /readyz.
func (s *Server) PublicHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/routing/push/register", s.handleRoutingPushRegister)
	mux.HandleFunc("/v1/routing/push/unregister", s.handleRoutingPushUnregister)
	mux.HandleFunc("/v1/scheduling/timezone", s.handleSchedulingTimezoneUpsert)
	mux.HandleFunc("/v1/scheduling/housing/reconcile", s.handleSchedulingHousingReconcile)
	mux.HandleFunc("/v1/scheduling/housing/cancel", s.handleSchedulingHousingCancel)
	mux.HandleFunc("/v1/scheduling/fires/upsert", s.handleSchedulingFiresUpsert)
	mux.HandleFunc("/v1/scheduling/fires/cancel", s.handleSchedulingFiresCancel)
	mux.HandleFunc("/v1/scheduling/pending-deliveries", s.handleSchedulingPendingDeliveries)
	mux.HandleFunc("/v1/scheduling/ack-delivery", s.handleSchedulingAckDelivery)
	mux.HandleFunc("/v1/envelopes", s.handleEnvelopes)
	mux.HandleFunc("/v1/envelopes/", s.handleEnvelopeSubResource)
	mux.HandleFunc("/v1/inbox/", s.handleInbox)
	mux.HandleFunc("/v1/disconnect", s.handleDisconnect)
	mux.HandleFunc("/v1/handshake/establish", s.handleEstablishRouting)
	mux.HandleFunc("/v1/participant-installation-migrate", s.handleParticipantInstallationMigrate)
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/readyz", s.handleReadyz)
	mux.HandleFunc("/", s.handleNotFound)
	return s.cors(s.middleware(mux))
}

// cors wraps a handler with CORS handling for browser callers.
//
// Behaviour:
//   - When `CORS_ALLOWED_ORIGINS` is empty (default), the middleware is a
//     no-op and browser clients are blocked at the same-origin boundary,
//     same as before this feature existed.
//   - When configured, the middleware adds `Access-Control-Allow-Origin`
//     on every response whose `Origin` matches the allow-list (echoing
//     the request's origin exactly, or `*` if the operator opted in to
//     wildcarding). It also handles CORS preflight (`OPTIONS`) requests
//     directly with a 204 response and the appropriate
//     `Access-Control-Allow-Methods` / `Access-Control-Allow-Headers` /
//     `Access-Control-Max-Age` headers.
//   - Responses always carry `Vary: Origin` when CORS is active, so
//     caches don't smush together responses across different callers.
func (s *Server) cors(next http.Handler) http.Handler {
	allowed := s.cfg.CORSAllowedOrigins
	if len(allowed) == 0 {
		return next
	}
	wildcard := false
	allowSet := make(map[string]struct{}, len(allowed))
	for _, o := range allowed {
		if o == "*" {
			wildcard = true
			continue
		}
		allowSet[o] = struct{}{}
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		allow := ""
		switch {
		case origin == "":
			// Non-browser caller: don't bother emitting CORS headers.
		case wildcard:
			allow = "*"
		default:
			if _, ok := allowSet[origin]; ok {
				allow = origin
			}
		}
		if allow != "" {
			w.Header().Set("Access-Control-Allow-Origin", allow)
			w.Header().Add("Vary", "Origin")
		}
		if r.Method == http.MethodOptions && origin != "" {
			// Preflight: short-circuit even when the origin does not
			// match so the browser surfaces a clear "blocked" error
			// rather than the generic "Failed to fetch".
			if allow != "" {
				reqHeaders := r.Header.Get("Access-Control-Request-Headers")
				if reqHeaders == "" {
					reqHeaders = "content-type"
				}
				w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
				w.Header().Set("Access-Control-Allow-Headers", reqHeaders)
				w.Header().Set("Access-Control-Max-Age", "600")
			}
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// SetClock replaces the wall-clock source. Tests only.
func (s *Server) SetClock(now func() time.Time) {
	s.now = now
}

// SetEnvelopeIDFunc replaces the envelope-id generator. Tests only.
func (s *Server) SetEnvelopeIDFunc(fn func() ([]byte, error)) {
	s.envelopeIDFn = fn
}

func (s *Server) middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := s.now()
		ip := remoteIP(r)
		endpoint := classifyEndpoint(r)
		ww := &statusRecorder{ResponseWriter: w, status: 200}

		// Per-IP rate limit applies to every protocol endpoint. Health
		// and readiness probes are exempt so a container runtime can
		// still verify liveness during a flood.
		if endpoint != "healthz" && endpoint != "readyz" {
			if !s.ipLim.Allow(ip) {
				metrics.RateLimitRejections.WithLabelValues("ip").Inc()
				writeError(w, http.StatusTooManyRequests, "rate_limited_ip", "per-IP rate limit exceeded")
				s.logRejection(r.Context(), endpoint, "rate_limited_ip", time.Since(start))
				return
			}
		}
		next.ServeHTTP(ww, r)

		dur := time.Since(start)
		metrics.HTTPRequests.WithLabelValues(endpoint, statusClass(ww.status)).Inc()
		metrics.HTTPLatencySeconds.WithLabelValues(endpoint).Observe(dur.Seconds())
		s.logger.Info(r.Context(), "http.request",
			logging.F(logging.KeyEndpoint, endpoint),
			logging.F(logging.KeyMethod, r.Method),
			logging.F(logging.KeyStatus, ww.status),
			logging.F(logging.KeyDurationMS, dur.Milliseconds()),
		)
	})
}

// ---------------------------------------------------------------------------
// Entitlement gating (housing kinds 5–9)
// ---------------------------------------------------------------------------

func (s *Server) checkEntitlement(w http.ResponseWriter, r *http.Request, kind int, gate *entitlement.Gate) error {
	if !s.cfg.EntitlementEnabled || s.entitlement == nil {
		return nil
	}
	if !entitlement.IsGatedKind(kind) {
		return nil
	}
	if code, ok := entitlement.ValidateGate(kind, gate); !ok {
		metrics.EntitlementRejections.WithLabelValues(code).Inc()
		metrics.HTTPRejections.WithLabelValues("envelopes", code).Inc()
		writeError(w, http.StatusBadRequest, code, "entitlement gate metadata required for this envelope kind")
		return errEntitlementDenied
	}
	allow, code, err := s.entitlement.IntrospectEnvelope(r.Context(), kind, gate)
	if err != nil {
		metrics.EntitlementRejections.WithLabelValues(code).Inc()
		metrics.HTTPRejections.WithLabelValues("envelopes", code).Inc()
		writeError(w, http.StatusServiceUnavailable, code, "entitlement introspection failed")
		return errEntitlementDenied
	}
	if !allow {
		metrics.EntitlementRejections.WithLabelValues(code).Inc()
		metrics.HTTPRejections.WithLabelValues("envelopes", code).Inc()
		writeError(w, http.StatusForbidden, code, "entitlement refused this envelope")
		return errEntitlementDenied
	}
	return nil
}

var errEntitlementDenied = errors.New("entitlement denied")

// ---------------------------------------------------------------------------
// POST /v1/participant-installation-migrate
// ---------------------------------------------------------------------------

type participantInstallationMigrateRequest struct {
	EnvelopeKind                 int    `json:"envelope_kind"`
	PlanID                       string `json:"plan_id"`
	OldParticipantInstallationID string `json:"old_participant_installation_id"`
	NewParticipantInstallationID string `json:"new_participant_installation_id"`
}

func (s *Server) handleParticipantInstallationMigrate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	if !s.cfg.EntitlementEnabled || s.entitlement == nil {
		writeError(w, http.StatusServiceUnavailable, "entitlement_disabled", "entitlement integration disabled")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
	if err != nil {
		writeError(w, http.StatusRequestEntityTooLarge, "oversize", "request too large")
		return
	}
	var req participantInstallationMigrateRequest
	if err := json.Unmarshal(body, &req); err != nil {
		writeError(w, http.StatusBadRequest, "malformed_json", "malformed JSON body")
		return
	}
	if req.EnvelopeKind != entitlement.KindParticipantInstallationMigration {
		writeError(w, http.StatusBadRequest, "invalid_envelope_kind", "unsupported envelope kind")
		return
	}
	oldID, ok1 := decodeInstallationID(req.OldParticipantInstallationID, s.idMinLen, s.idMaxLen)
	newID, ok2 := decodeInstallationID(req.NewParticipantInstallationID, s.idMinLen, s.idMaxLen)
	if !ok1 || !ok2 || req.PlanID == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "plan_id and installation ids required")
		return
	}
	code, err := s.entitlement.MigrateInstallation(r.Context(), req.PlanID, oldID, newID, req.EnvelopeKind)
	if err != nil {
		s.writeInternal(w, r, "participant_installation_migrate", err)
		return
	}
	if code != "" {
		status := http.StatusBadRequest
		if code == "old_installation_not_found" {
			status = http.StatusNotFound
		}
		writeError(w, status, code, "installation migration refused")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func decodeInstallationID(id string, minLen, maxLen int) (string, bool) {
	id = strings.TrimSpace(id)
	if len(id) < minLen || len(id) > maxLen {
		return "", false
	}
	return id, true
}

// ---------------------------------------------------------------------------
// POST /v1/envelopes
// ---------------------------------------------------------------------------

type envelopeRequest struct {
	SenderIdentity    string            `json:"sender_identity"`
	RecipientIdentity string            `json:"recipient_identity"`
	IdempotencyKey    string            `json:"idempotency_key"`
	Ciphertext        string            `json:"ciphertext"`
	Kind              int               `json:"kind"`
	TTLSeconds        int               `json:"ttl_seconds"`
	ExpiresAt         *time.Time        `json:"expires_at"`
	EntitlementGate   *entitlement.Gate `json:"entitlement_gate,omitempty"`
}

type envelopeResponse struct {
	EnvelopeID   string    `json:"envelope_id"`
	TTLExpiresAt time.Time `json:"ttl_expires_at"`
	Replay       bool      `json:"replay"`
}

func (s *Server) handleEnvelopes(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body,
		int64(s.cfg.EnvelopeMaxBytes)+envelopeJSONOverhead))
	if err != nil {
		metrics.HTTPRejections.WithLabelValues("envelopes", "oversize_or_io").Inc()
		writeError(w, http.StatusRequestEntityTooLarge, "oversize", "request too large")
		return
	}
	var req envelopeRequest
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "envelopes", "malformed_json")
		return
	}

	sender, err1 := decodeIdentity(req.SenderIdentity, s.idMinLen, s.idMaxLen)
	recipient, err2 := decodeIdentity(req.RecipientIdentity, s.idMinLen, s.idMaxLen)
	idemKey, err3 := decodeIdentity(req.IdempotencyKey, s.idMinLen, s.idMaxLen)
	ciphertext, err4 := decodeCiphertext(req.Ciphertext, s.cfg.EnvelopeMaxBytes)
	if firstErr := firstNonNil(err1, err2, err3, err4); firstErr != nil {
		s.rejectBadFraming(w, r, "envelopes", firstErr.Error())
		return
	}
	if req.Kind < 0 || req.Kind > 255 {
		s.rejectBadFraming(w, r, "envelopes", "kind_out_of_range")
		return
	}

	if !s.identityLim.Allow("identity:" + hex.EncodeToString(sender)) {
		metrics.RateLimitRejections.WithLabelValues("identity").Inc()
		writeError(w, http.StatusTooManyRequests, "rate_limited_identity",
			"per-identity rate limit exceeded")
		return
	}

	ok, err := s.store.HasRouting(r.Context(), sender, recipient)
	if err != nil {
		s.writeInternal(w, r, "envelopes", err)
		return
	}
	if !ok {
		s.rejectBadFraming(w, r, "envelopes", "no_routing_relationship")
		return
	}

	if err := s.checkEntitlement(w, r, req.Kind, req.EntitlementGate); err != nil {
		return
	}

	envelopeID, err := s.envelopeIDFn()
	if err != nil {
		s.writeInternal(w, r, "envelopes", err)
		return
	}
	now := s.now()
	ttlAt, err := s.envelopeRetentionUntil(req, now)
	if err != nil {
		s.rejectBadFraming(w, r, "envelopes", err.Error())
		return
	}
	storedID, replay, err := s.store.LookupOrReserveIdempotency(
		r.Context(), sender, idemKey, envelopeID, s.cfg.IdempotencyTTL, now)
	if err != nil {
		s.writeInternal(w, r, "envelopes", err)
		return
	}
	if replay {
		writeJSON(w, http.StatusOK, envelopeResponse{
			EnvelopeID:   base64.RawURLEncoding.EncodeToString(storedID),
			TTLExpiresAt: now.Add(s.cfg.IdempotencyTTL),
			Replay:       true,
		})
		return
	}

	err = s.store.StoreEnvelope(r.Context(), store.Envelope{
		EnvelopeID:        storedID,
		SenderIdentity:    sender,
		RecipientIdentity: recipient,
		Ciphertext:        ciphertext,
		Kind:              req.Kind,
		CreatedAt:         now,
		TTLExpiresAt:      ttlAt,
	})
	if err != nil {
		s.writeInternal(w, r, "envelopes", err)
		return
	}
	_ = s.store.TouchRouting(r.Context(), sender, recipient)
	metrics.EnvelopesAccepted.Inc()
	writeJSON(w, http.StatusCreated, envelopeResponse{
		EnvelopeID:   base64.RawURLEncoding.EncodeToString(storedID),
		TTLExpiresAt: ttlAt,
		Replay:       false,
	})

	if s.cfg.WakePushDispatchEnabled && s.pushWake != nil {
		recipientCopy := append([]byte(nil), recipient...)
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()
			s.pushWake.WakeRecipient(ctx, recipientCopy)
		}()
	}

	s.logger.Info(r.Context(), "envelope.accepted",
		logging.F(logging.KeyEndpoint, "envelopes"),
		logging.Bytes(logging.KeyEnvelopeID, storedID),
		logging.Bytes(logging.KeySenderIdentity, sender),
		logging.Bytes(logging.KeyRecipientIdent, recipient),
	)
}

// ---------------------------------------------------------------------------
// POST /v1/envelopes/:id/ack
// ---------------------------------------------------------------------------

func (s *Server) handleEnvelopeSubResource(w http.ResponseWriter, r *http.Request) {
	const prefix = "/v1/envelopes/"
	rest := strings.TrimPrefix(r.URL.Path, prefix)
	parts := strings.SplitN(rest, "/", 2)
	if len(parts) != 2 || parts[1] != "ack" {
		s.handleNotFound(w, r)
		return
	}
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	envelopeID, err := decodeIdentity(parts[0], s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "envelopes_ack", err.Error())
		return
	}

	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 512))
	if err != nil {
		s.rejectBadFraming(w, r, "envelopes_ack", "oversize")
		return
	}
	var req struct {
		RecipientIdentity string `json:"recipient_identity"`
	}
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "envelopes_ack", "malformed_json")
		return
	}
	recipient, err := decodeIdentity(req.RecipientIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "envelopes_ack", err.Error())
		return
	}

	deleted, err := s.store.AckEnvelope(r.Context(), envelopeID, recipient)
	if err != nil {
		s.writeInternal(w, r, "envelopes_ack", err)
		return
	}
	if !deleted {
		writeError(w, http.StatusNotFound, "not_found",
			"no envelope addressed to that recipient with that id")
		return
	}
	metrics.EnvelopesDelivered.Inc()
	w.WriteHeader(http.StatusNoContent)
	s.logger.Info(r.Context(), "envelope.delivered",
		logging.F(logging.KeyEndpoint, "envelopes_ack"),
		logging.Bytes(logging.KeyEnvelopeID, envelopeID),
		logging.Bytes(logging.KeyRecipientIdent, recipient),
	)
}

// ---------------------------------------------------------------------------
// GET /v1/inbox/:recipient
// ---------------------------------------------------------------------------

type inboxResponse struct {
	Envelopes []envelopeView `json:"envelopes"`
}

type envelopeView struct {
	EnvelopeID        string    `json:"envelope_id"`
	SenderIdentity    string    `json:"sender_identity"`
	RecipientIdentity string    `json:"recipient_identity"`
	Ciphertext        string    `json:"ciphertext"`
	Kind              int       `json:"kind"`
	CreatedAt         time.Time `json:"created_at"`
	TTLExpiresAt      time.Time `json:"ttl_expires_at"`
}

func (s *Server) handleInbox(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET only")
		return
	}
	rest := strings.TrimPrefix(r.URL.Path, "/v1/inbox/")
	recipient, err := decodeIdentity(rest, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "inbox", err.Error())
		return
	}
	limit := 32
	if q := r.URL.Query().Get("limit"); q != "" {
		n, err := strconv.Atoi(q)
		if err != nil || n < 1 || n > 128 {
			s.rejectBadFraming(w, r, "inbox", "invalid_limit")
			return
		}
		limit = n
	}
	rows, err := s.store.FetchInbox(r.Context(), recipient, limit, s.now())
	if err != nil {
		s.writeInternal(w, r, "inbox", err)
		return
	}
	views := make([]envelopeView, 0, len(rows))
	for _, e := range rows {
		views = append(views, envelopeView{
			EnvelopeID:        base64.RawURLEncoding.EncodeToString(e.EnvelopeID),
			SenderIdentity:    base64.RawURLEncoding.EncodeToString(e.SenderIdentity),
			RecipientIdentity: base64.RawURLEncoding.EncodeToString(e.RecipientIdentity),
			Ciphertext:        base64.RawURLEncoding.EncodeToString(e.Ciphertext),
			Kind:              e.Kind,
			CreatedAt:         e.CreatedAt,
			TTLExpiresAt:      e.TTLExpiresAt,
		})
	}
	writeJSON(w, http.StatusOK, inboxResponse{Envelopes: views})
}

// ---------------------------------------------------------------------------
// POST /v1/handshake/establish
// ---------------------------------------------------------------------------
//
// The Contacts handshake (client-side, in `contacts-module`) negotiates
// peer keys end-to-end. When both clients are satisfied with the
// handshake outcome, they each call this endpoint with their own
// opaque routing identifier and the peer's opaque routing identifier;
// the relay records the relationship so subsequent envelopes are
// admitted. The relay does not inspect or verify the handshake content
// itself.

type establishRequest struct {
	SelfIdentity string `json:"self_identity"`
	PeerIdentity string `json:"peer_identity"`
}

func (s *Server) handleEstablishRouting(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 4096))
	if err != nil {
		s.rejectBadFraming(w, r, "handshake_establish", "oversize")
		return
	}
	var req establishRequest
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "handshake_establish", "malformed_json")
		return
	}
	self, err := decodeIdentity(req.SelfIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "handshake_establish", err.Error())
		return
	}
	peer, err := decodeIdentity(req.PeerIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "handshake_establish", err.Error())
		return
	}
	if !s.identityLim.Allow("identity:" + hex.EncodeToString(self)) {
		metrics.RateLimitRejections.WithLabelValues("identity").Inc()
		writeError(w, http.StatusTooManyRequests, "rate_limited_identity",
			"per-identity rate limit exceeded")
		return
	}
	if err := s.store.EstablishRouting(r.Context(), self, peer); err != nil {
		s.writeInternal(w, r, "handshake_establish", err)
		return
	}
	metrics.RoutingCreated.Inc()
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------------------
// POST /v1/disconnect
// ---------------------------------------------------------------------------

type disconnectRequest struct {
	SelfIdentity string `json:"self_identity"`
	PeerIdentity string `json:"peer_identity"`
}

func (s *Server) handleDisconnect(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 4096))
	if err != nil {
		s.rejectBadFraming(w, r, "disconnect", "oversize")
		return
	}
	var req disconnectRequest
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "disconnect", "malformed_json")
		return
	}
	self, err := decodeIdentity(req.SelfIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "disconnect", err.Error())
		return
	}
	peer, err := decodeIdentity(req.PeerIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "disconnect", err.Error())
		return
	}
	transitioned, err := s.store.MarkDisconnecting(r.Context(), self, peer, s.now())
	if err != nil {
		s.writeInternal(w, r, "disconnect", err)
		return
	}
	if !transitioned {
		writeError(w, http.StatusNotFound, "not_found", "no active routing relationship")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------------------
// Health / readiness
// ---------------------------------------------------------------------------

type healthResponse struct {
	Status        string `json:"status"`
	Build         string `json:"build"`
	SchemaVersion int    `json:"schema_version"`
}

func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	resp := healthResponse{
		Status:        "ok",
		Build:         version.Build,
		SchemaVersion: version.Expected,
	}
	if prefersHTML(r) {
		writeHealthHTML(w, http.StatusOK, resp)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func prefersHTML(r *http.Request) bool {
	accept := r.Header.Get("Accept")
	if accept == "" {
		return false
	}
	// Browsers send text/html first; curl/JSON clients typically send */* or application/json.
	if containsToken(accept, "text/html") {
		return true
	}
	return false
}

func containsToken(header, token string) bool {
	lower := strings.ToLower(header)
	tok := strings.ToLower(token)
	for _, part := range strings.Split(lower, ",") {
		part = strings.TrimSpace(part)
		if i := strings.IndexByte(part, ';'); i >= 0 {
			part = strings.TrimSpace(part[:i])
		}
		if part == tok {
			return true
		}
	}
	return false
}

func writeHealthHTML(w http.ResponseWriter, code int, resp healthResponse) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(code)
	_, _ = fmt.Fprintf(w, `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Bojairũ relay health</title>
<style>
  body{font-family:system-ui,-apple-system,sans-serif;margin:1.25rem;line-height:1.45;color:#111;background:#fafafa}
  h1{font-size:1.25rem;margin:0 0 .75rem}
  dl{margin:0}
  dt{font-weight:600;margin-top:.5rem}
  dd{margin:0 0 0 .25rem;font-family:ui-monospace,monospace;word-break:break-all}
</style>
</head>
<body>
<h1>Relay health</h1>
<dl>
<dt>status</dt><dd>%s</dd>
<dt>build</dt><dd>%s</dd>
<dt>schema_version</dt><dd>%d</dd>
</dl>
</body>
</html>
`, htmlEscape(resp.Status), htmlEscape(resp.Build), resp.SchemaVersion)
}

func htmlEscape(s string) string {
	replacer := strings.NewReplacer(
		`&`, "&amp;",
		`<`, "&lt;",
		`>`, "&gt;",
		`"`, "&quot;",
	)
	return replacer.Replace(s)
}

func (s *Server) handleReadyz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	v, err := s.store.SchemaVersion(ctx)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "degraded", "db unavailable")
		return
	}
	if v != version.Expected {
		writeError(w, http.StatusServiceUnavailable, "starting", "schema not at expected version")
		return
	}
	writeJSON(w, http.StatusOK, healthResponse{
		Status:        "ready",
		Build:         version.Build,
		SchemaVersion: v,
	})
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func (s *Server) handleNotFound(w http.ResponseWriter, r *http.Request) {
	writeError(w, http.StatusNotFound, "not_found", "no such endpoint")
}

func (s *Server) rejectBadFraming(w http.ResponseWriter, r *http.Request, endpoint, reason string) {
	metrics.HTTPRejections.WithLabelValues(endpoint, reason).Inc()
	s.logRejection(r.Context(), endpoint, reason, 0)
	writeError(w, http.StatusBadRequest, "bad_envelope", reason)
}

func (s *Server) writeInternal(w http.ResponseWriter, r *http.Request, endpoint string, err error) {
	if errors.Is(err, pgx.ErrTxClosed) || errors.Is(err, context.Canceled) {
		writeError(w, http.StatusServiceUnavailable, "shutting_down", "service shutting down")
		return
	}
	s.logger.Error(r.Context(), "internal_error",
		logging.F(logging.KeyEndpoint, endpoint),
		logging.F(logging.KeyError, err.Error()),
	)
	metrics.HTTPRejections.WithLabelValues(endpoint, "internal").Inc()
	writeError(w, http.StatusInternalServerError, "internal", "internal error")
}

func (s *Server) logRejection(ctx context.Context, endpoint, reason string, dur time.Duration) {
	s.logger.Warn(ctx, "http.rejection",
		logging.F(logging.KeyEndpoint, endpoint),
		logging.F(logging.KeyRejectionReason, reason),
		logging.F(logging.KeyDurationMS, dur.Milliseconds()),
	)
}

func (s *Server) clampTTL(d time.Duration) time.Duration {
	if d < s.cfg.EnvelopeTTLMin {
		return s.cfg.EnvelopeTTLMin
	}
	if d > s.cfg.EnvelopeTTLMax {
		return s.cfg.EnvelopeTTLMax
	}
	return d
}

var errExpiresAtNotFuture = errors.New("expires_at_not_future")

// envelopeRetentionUntil is the delivery cutoff stored as ttl_expires_at.
// A plaintext expires_at is a product deadline: keep until that instant
// (capped at EnvelopeTTLMax). With no expires_at, keep EnvelopeTTLMax
// (7 days). ttl_seconds is ignored.
func (s *Server) envelopeRetentionUntil(req envelopeRequest, now time.Time) (time.Time, error) {
	maxAt := now.Add(s.cfg.EnvelopeTTLMax)
	if req.ExpiresAt == nil {
		return maxAt, nil
	}
	at := req.ExpiresAt.UTC()
	if !at.After(now) {
		return time.Time{}, errExpiresAtNotFuture
	}
	if at.After(maxAt) {
		return maxAt, nil
	}
	return at, nil
}

const envelopeJSONOverhead = 2048

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

type errorBody struct {
	Code   string `json:"code"`
	Detail string `json:"detail,omitempty"`
}

func writeError(w http.ResponseWriter, status int, code, detail string) {
	writeJSON(w, status, errorBody{Code: code, Detail: detail})
}

func decodeIdentity(s string, min, max int) ([]byte, error) {
	if s == "" {
		return nil, errors.New("empty_identity")
	}
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return nil, errors.New("invalid_base64_identity")
	}
	if len(b) < min || len(b) > max {
		return nil, errors.New("identity_length")
	}
	return b, nil
}

func decodeCiphertext(s string, maxBytes int) ([]byte, error) {
	if s == "" {
		return nil, errors.New("empty_ciphertext")
	}
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return nil, errors.New("invalid_base64_ciphertext")
	}
	if len(b) == 0 {
		return nil, errors.New("empty_ciphertext")
	}
	if len(b) > maxBytes {
		return nil, errors.New("ciphertext_too_large")
	}
	return b, nil
}

func firstNonNil(errs ...error) error {
	for _, e := range errs {
		if e != nil {
			return e
		}
	}
	return nil
}

func remoteIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		if comma := strings.IndexByte(xff, ','); comma >= 0 {
			return strings.TrimSpace(xff[:comma])
		}
		return strings.TrimSpace(xff)
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func statusClass(s int) string {
	switch {
	case s >= 500:
		return "5xx"
	case s >= 400:
		return "4xx"
	case s >= 300:
		return "3xx"
	case s >= 200:
		return "2xx"
	default:
		return "1xx"
	}
}

func classifyEndpoint(r *http.Request) string {
	p := r.URL.Path
	switch {
	case p == "/v1/routing/push/register":
		return "routing_push_register"
	case p == "/v1/routing/push/unregister":
		return "routing_push_unregister"
	case p == "/v1/envelopes":
		return "envelopes"
	case strings.HasPrefix(p, "/v1/envelopes/") && strings.HasSuffix(p, "/ack"):
		return "envelopes_ack"
	case strings.HasPrefix(p, "/v1/inbox/"):
		return "inbox"
	case p == "/v1/disconnect":
		return "disconnect"
	case p == "/v1/handshake/establish":
		return "handshake_establish"
	case p == "/v1/scheduling/fires/upsert":
		return "scheduling_fires_upsert"
	case p == "/v1/scheduling/fires/cancel":
		return "scheduling_fires_cancel"
	case p == "/healthz":
		return "healthz"
	case p == "/readyz":
		return "readyz"
	default:
		return "other"
	}
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func randomEnvelopeID() ([]byte, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	return b, nil
}
