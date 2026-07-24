package api

import (
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/compartarenta/relay/internal/metrics"
	"github.com/compartarenta/relay/internal/store"
)

type timezoneUpsertRequest struct {
	RecipientIdentity string `json:"recipient_identity"`
	IanaTimezone      string `json:"iana_timezone"`
}

type housingReconcileRequest struct {
	SenderIdentity string `json:"sender_identity"`
	PlanID         string `json:"plan_id"`
	Generation     int64  `json:"generation"`
	Targets        []struct {
		ScopeKey             string `json:"scope_key"`
		RecipientIdentity    string `json:"recipient_identity"`
		ReminderKind         string `json:"reminder_kind"`
		PeriodKey            string `json:"period_key"`
		RecurrencePeriodDays int    `json:"recurrence_period_days"`
		DueAt                string `json:"due_at"`
		BoundAt              string `json:"bound_at,omitempty"`
	} `json:"targets"`
}

type housingCancelRequest struct {
	SenderIdentity string   `json:"sender_identity"`
	ScopeKeys      []string `json:"scope_keys"`
	ReminderKind   string   `json:"reminder_kind"`
	PeriodKey      string   `json:"period_key"`
}

type pendingDeliveryView struct {
	FireID               string  `json:"fire_id"`
	Domain               string  `json:"domain"`
	ScopeKey             string  `json:"scope_key"`
	ReminderKind         string  `json:"reminder_kind"`
	PeriodKey            string  `json:"period_key,omitempty"`
	PeriodDueAt          *string `json:"period_due_at,omitempty"`
	RecurrencePeriodDays *int    `json:"recurrence_period_days,omitempty"`
	FiredAt              string  `json:"fired_at"`
}

func (s *Server) handleSchedulingTimezoneUpsert(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 4096))
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_timezone", "oversize")
		return
	}
	var req timezoneUpsertRequest
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "scheduling_timezone", "malformed_json")
		return
	}
	recipient, err := decodeIdentity(req.RecipientIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_timezone", err.Error())
		return
	}
	if req.IanaTimezone == "" || len(req.IanaTimezone) > 64 {
		s.rejectBadFraming(w, r, "scheduling_timezone", "invalid_timezone")
		return
	}
	if _, err := time.LoadLocation(req.IanaTimezone); err != nil {
		s.rejectBadFraming(w, r, "scheduling_timezone", "invalid_timezone")
		return
	}
	if !s.identityLim.Allow("identity:" + hex.EncodeToString(recipient)) {
		writeError(w, http.StatusTooManyRequests, "rate_limited_identity",
			"per-identity rate limit exceeded")
		return
	}
	ok, err := s.store.HasActiveRoutingForIdentity(r.Context(), recipient)
	if err != nil {
		s.writeInternal(w, r, "scheduling_timezone", err)
		return
	}
	if !ok {
		s.rejectBadFraming(w, r, "scheduling_timezone", "no_active_routing")
		return
	}
	now := s.now()
	if err := s.store.UpsertRecipientTimezone(r.Context(), recipient, req.IanaTimezone, now); err != nil {
		s.writeInternal(w, r, "scheduling_timezone", err)
		return
	}
	if err := s.store.RecomputePendingHousingFiresForRecipient(r.Context(), recipient, now); err != nil {
		s.writeInternal(w, r, "scheduling_timezone", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleSchedulingHousingReconcile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 256*1024))
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "oversize")
		return
	}
	var req housingReconcileRequest
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "malformed_json")
		return
	}
	sender, err := decodeIdentity(req.SenderIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_housing_reconcile", err.Error())
		return
	}
	planID, err := decodeIdentity(req.PlanID, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "invalid_plan_id")
		return
	}
	if req.Generation < 0 {
		s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "invalid_generation")
		return
	}
	if !s.identityLim.Allow("identity:" + hex.EncodeToString(sender)) {
		writeError(w, http.StatusTooManyRequests, "rate_limited_identity",
			"per-identity rate limit exceeded")
		return
	}
	ok, err := s.store.HasActiveRoutingForIdentity(r.Context(), sender)
	if err != nil {
		s.writeInternal(w, r, "scheduling_housing_reconcile", err)
		return
	}
	if !ok {
		s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "no_active_routing")
		return
	}

	now := s.now()
	var targets []store.HousingPaymentTargetInput
	for _, t := range req.Targets {
		if t.ReminderKind != "before_due" && t.ReminderKind != "overdue" {
			s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "invalid_reminder_kind")
			return
		}
		scopeKey, err := decodeIdentity(t.ScopeKey, s.idMinLen, 128)
		if err != nil {
			s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "invalid_scope_key")
			return
		}
		recipient, err := decodeIdentity(t.RecipientIdentity, s.idMinLen, s.idMaxLen)
		if err != nil {
			s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "invalid_recipient")
			return
		}
		periodKey, err := decodeIdentity(t.PeriodKey, 1, 64)
		if err != nil {
			s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "invalid_period_key")
			return
		}
		dueAt, err := time.Parse(time.RFC3339, t.DueAt)
		if err != nil {
			s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "invalid_due_at")
			return
		}
		var boundAt *time.Time
		if t.BoundAt != "" {
			b, err := time.Parse(time.RFC3339, t.BoundAt)
			if err != nil {
				s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "invalid_bound_at")
				return
			}
			boundAt = &b
		}
		if t.RecurrencePeriodDays <= 0 {
			s.rejectBadFraming(w, r, "scheduling_housing_reconcile", "invalid_recurrence_period_days")
			return
		}
		targets = append(targets, store.HousingPaymentTargetInput{
			ScopeKey:             scopeKey,
			RecipientRoutingID:   recipient,
			ReminderKind:         t.ReminderKind,
			PeriodKey:            periodKey,
			RecurrencePeriodDays: t.RecurrencePeriodDays,
			DueAt:                dueAt,
			BoundAt:              boundAt,
		})
	}

	if err := s.store.ReconcileHousingPaymentPlan(r.Context(), planID, req.Generation, targets, now); err != nil {
		s.writeInternal(w, r, "scheduling_housing_reconcile", err)
		return
	}
	metrics.SchedulingReconciles.Inc()
	writeJSON(w, http.StatusOK, map[string]any{"targets": len(targets)})
}

func (s *Server) handleSchedulingHousingCancel(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 64*1024))
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_housing_cancel", "oversize")
		return
	}
	var req housingCancelRequest
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "scheduling_housing_cancel", "malformed_json")
		return
	}
	sender, err := decodeIdentity(req.SenderIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_housing_cancel", err.Error())
		return
	}
	if !s.identityLim.Allow("identity:" + hex.EncodeToString(sender)) {
		writeError(w, http.StatusTooManyRequests, "rate_limited_identity",
			"per-identity rate limit exceeded")
		return
	}
	ok, err := s.store.HasActiveRoutingForIdentity(r.Context(), sender)
	if err != nil {
		s.writeInternal(w, r, "scheduling_housing_cancel", err)
		return
	}
	if !ok {
		s.rejectBadFraming(w, r, "scheduling_housing_cancel", "no_active_routing")
		return
	}
	var scopeKeys [][]byte
	for _, sk := range req.ScopeKeys {
		b, err := decodeIdentity(sk, s.idMinLen, 128)
		if err != nil {
			s.rejectBadFraming(w, r, "scheduling_housing_cancel", "invalid_scope_key")
			return
		}
		scopeKeys = append(scopeKeys, b)
	}
	var periodKey []byte
	if req.PeriodKey != "" {
		periodKey, err = decodeIdentity(req.PeriodKey, 1, 64)
		if err != nil {
			s.rejectBadFraming(w, r, "scheduling_housing_cancel", "invalid_period_key")
			return
		}
	}
	now := s.now()
	if err := s.store.CancelHousingPaymentTargets(
		r.Context(), scopeKeys, req.ReminderKind, periodKey, now,
	); err != nil {
		s.writeInternal(w, r, "scheduling_housing_cancel", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

type clientFiresUpsertRequest struct {
	SenderIdentity string `json:"sender_identity"`
	Targets        []struct {
		Domain            string `json:"domain"`
		ScopeKey          string `json:"scope_key"`
		RecipientIdentity string `json:"recipient_identity"`
		ReminderKind      string `json:"reminder_kind"`
		PeriodKey         string `json:"period_key,omitempty"`
		DueAt             string `json:"due_at,omitempty"`
		Generation        int64  `json:"generation,omitempty"`
		Fires             []struct {
			FireAt string `json:"fire_at"`
		} `json:"fires"`
	} `json:"targets"`
}

func (s *Server) handleSchedulingFiresUpsert(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 256*1024))
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_fires_upsert", "oversize")
		return
	}
	var req clientFiresUpsertRequest
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "scheduling_fires_upsert", "malformed_json")
		return
	}
	sender, err := decodeIdentity(req.SenderIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_fires_upsert", err.Error())
		return
	}
	if !s.identityLim.Allow("identity:" + hex.EncodeToString(sender)) {
		writeError(w, http.StatusTooManyRequests, "rate_limited_identity",
			"per-identity rate limit exceeded")
		return
	}
	ok, err := s.store.HasActiveRoutingForIdentity(r.Context(), sender)
	if err != nil {
		s.writeInternal(w, r, "scheduling_fires_upsert", err)
		return
	}
	if !ok {
		s.rejectBadFraming(w, r, "scheduling_fires_upsert", "no_active_routing")
		return
	}

	now := s.now()
	var targets []store.ClientScheduledFireTarget
	for _, t := range req.Targets {
		scopeKey, err := decodeIdentity(t.ScopeKey, s.idMinLen, 128)
		if err != nil {
			s.rejectBadFraming(w, r, "scheduling_fires_upsert", "invalid_scope_key")
			return
		}
		recipient, err := decodeIdentity(t.RecipientIdentity, s.idMinLen, s.idMaxLen)
		if err != nil {
			s.rejectBadFraming(w, r, "scheduling_fires_upsert", "invalid_recipient")
			return
		}
		var periodKey []byte
		if t.PeriodKey != "" {
			periodKey, err = decodeIdentity(t.PeriodKey, 1, 64)
			if err != nil {
				s.rejectBadFraming(w, r, "scheduling_fires_upsert", "invalid_period_key")
				return
			}
		}
		var dueAt *time.Time
		if t.DueAt != "" {
			parsed, err := time.Parse(time.RFC3339, t.DueAt)
			if err != nil {
				s.rejectBadFraming(w, r, "scheduling_fires_upsert", "invalid_due_at")
				return
			}
			u := parsed.UTC()
			dueAt = &u
		}
		var fireAts []time.Time
		for _, f := range t.Fires {
			parsed, err := time.Parse(time.RFC3339, f.FireAt)
			if err != nil {
				s.rejectBadFraming(w, r, "scheduling_fires_upsert", "invalid_fire_at")
				return
			}
			fireAts = append(fireAts, parsed.UTC())
		}
		targets = append(targets, store.ClientScheduledFireTarget{
			Domain:             t.Domain,
			ScopeKey:           scopeKey,
			RecipientRoutingID: recipient,
			ReminderKind:       t.ReminderKind,
			PeriodKey:          periodKey,
			DueAt:              dueAt,
			Generation:         t.Generation,
			FireAts:            fireAts,
		})
	}
	if err := s.store.UpsertClientScheduledFires(r.Context(), targets, now); err != nil {
		if err.Error() == "unsupported_domain" || err.Error() == "unsupported_reminder_kind" ||
			err.Error() == "missing_scope_or_recipient" {
			s.rejectBadFraming(w, r, "scheduling_fires_upsert", err.Error())
			return
		}
		s.writeInternal(w, r, "scheduling_fires_upsert", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

type clientFiresCancelRequest struct {
	SenderIdentity string   `json:"sender_identity"`
	Domain         string   `json:"domain"`
	ScopeKeys      []string `json:"scope_keys"`
}

func (s *Server) handleSchedulingFiresCancel(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 64*1024))
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_fires_cancel", "oversize")
		return
	}
	var req clientFiresCancelRequest
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "scheduling_fires_cancel", "malformed_json")
		return
	}
	sender, err := decodeIdentity(req.SenderIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_fires_cancel", err.Error())
		return
	}
	if !s.identityLim.Allow("identity:" + hex.EncodeToString(sender)) {
		writeError(w, http.StatusTooManyRequests, "rate_limited_identity",
			"per-identity rate limit exceeded")
		return
	}
	ok, err := s.store.HasActiveRoutingForIdentity(r.Context(), sender)
	if err != nil {
		s.writeInternal(w, r, "scheduling_fires_cancel", err)
		return
	}
	if !ok {
		s.rejectBadFraming(w, r, "scheduling_fires_cancel", "no_active_routing")
		return
	}
	var scopeKeys [][]byte
	for _, sk := range req.ScopeKeys {
		b, err := decodeIdentity(sk, s.idMinLen, 128)
		if err != nil {
			s.rejectBadFraming(w, r, "scheduling_fires_cancel", "invalid_scope_key")
			return
		}
		scopeKeys = append(scopeKeys, b)
	}
	if err := s.store.CancelClientScheduledByScope(r.Context(), req.Domain, scopeKeys, s.now()); err != nil {
		if err.Error() == "unsupported_domain" {
			s.rejectBadFraming(w, r, "scheduling_fires_cancel", err.Error())
			return
		}
		s.writeInternal(w, r, "scheduling_fires_cancel", err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleSchedulingPendingDeliveries(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "GET only")
		return
	}
	recipientB64 := r.URL.Query().Get("recipient_identity")
	if recipientB64 == "" {
		s.rejectBadFraming(w, r, "scheduling_pending", "missing_recipient")
		return
	}
	recipient, err := decodeIdentity(recipientB64, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_pending", err.Error())
		return
	}
	if !s.identityLim.Allow("identity:" + hex.EncodeToString(recipient)) {
		writeError(w, http.StatusTooManyRequests, "rate_limited_identity",
			"per-identity rate limit exceeded")
		return
	}
	ok, err := s.store.HasActiveRoutingForIdentity(r.Context(), recipient)
	if err != nil {
		s.writeInternal(w, r, "scheduling_pending", err)
		return
	}
	if !ok {
		s.rejectBadFraming(w, r, "scheduling_pending", "no_active_routing")
		return
	}
	limit := 32
	if raw := r.URL.Query().Get("limit"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n > 0 && n <= 64 {
			limit = n
		}
	}
	rows, err := s.store.ListUndeliveredReminderFires(r.Context(), recipient, limit)
	if err != nil {
		s.writeInternal(w, r, "scheduling_pending", err)
		return
	}
	out := make([]pendingDeliveryView, 0, len(rows))
	for _, row := range rows {
		v := pendingDeliveryView{
			FireID:       base64.RawURLEncoding.EncodeToString(row.FireID),
			Domain:       row.Domain,
			ScopeKey:     base64.RawURLEncoding.EncodeToString(row.ScopeKey),
			ReminderKind: row.ReminderKind,
			FiredAt:      row.FiredAt.UTC().Format(time.RFC3339),
		}
		if len(row.PeriodKey) > 0 {
			v.PeriodKey = base64.RawURLEncoding.EncodeToString(row.PeriodKey)
		}
		if row.PeriodDueAt != nil {
			s := row.PeriodDueAt.UTC().Format(time.RFC3339)
			v.PeriodDueAt = &s
		}
		v.RecurrencePeriodDays = row.RecurrencePeriodDays
		out = append(out, v)
	}
	writeJSON(w, http.StatusOK, map[string]any{"deliveries": out})
}

func (s *Server) handleSchedulingAckDelivery(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "POST only")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 4096))
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_ack", "oversize")
		return
	}
	var req struct {
		RecipientIdentity string `json:"recipient_identity"`
		FireID            string `json:"fire_id"`
	}
	if err := json.Unmarshal(body, &req); err != nil {
		s.rejectBadFraming(w, r, "scheduling_ack", "malformed_json")
		return
	}
	recipient, err := decodeIdentity(req.RecipientIdentity, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_ack", err.Error())
		return
	}
	fireID, err := decodeIdentity(req.FireID, s.idMinLen, s.idMaxLen)
	if err != nil {
		s.rejectBadFraming(w, r, "scheduling_ack", "invalid_fire_id")
		return
	}
	if !s.identityLim.Allow("identity:" + hex.EncodeToString(recipient)) {
		writeError(w, http.StatusTooManyRequests, "rate_limited_identity",
			"per-identity rate limit exceeded")
		return
	}
	ok, err := s.store.AckReminderFireDelivery(r.Context(), recipient, fireID, s.now())
	if err != nil {
		s.writeInternal(w, r, "scheduling_ack", err)
		return
	}
	if !ok {
		writeError(w, http.StatusNotFound, "not_found", "fire not found or already acked")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
