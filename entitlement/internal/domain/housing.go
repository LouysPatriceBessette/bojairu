package domain

import (
	"context"
	"encoding/json"
	"time"

	"github.com/compartarenta/entitlement/internal/config"
	"github.com/compartarenta/entitlement/internal/license"
	"github.com/compartarenta/entitlement/internal/store"
)

const (
	StateLinkedNotActive    = "linked_not_active"
	StateActiveTrial        = "active_trial"
	StateActivePaid         = "active_paid"
	StateDelinquentGrace    = "delinquent_grace"
	StateDelinquentReadonly = "delinquent_readonly"

	LicenseActivePaid = "active_paid"
	LicenseUnpaid     = "unpaid"
)

type Housing struct {
	st          *store.Store
	cfg         config.Config
	now         func() time.Time
	playEnabled bool
}

func NewHousing(st *store.Store, cfg config.Config) *Housing {
	return &Housing{st: st, cfg: cfg, now: time.Now}
}

func (h *Housing) SetClock(now func() time.Time) { h.now = now }

func (h *Housing) SetPlayVerification(enabled bool) { h.playEnabled = enabled }

func (h *Housing) PlayVerificationEnabled() bool { return h.playEnabled }

type IntrospectInput struct {
	Module                    string
	PlanID                    string
	ParticipantInstallationID string
	Operation                 string
	ExpenseID                 string
	RevisionID                string
	DecisionKind              string
	EnvelopeKind              int
}

type IntrospectResult struct {
	Allow bool
	Code  string
}

func (h *Housing) RegisterInstallation(ctx context.Context, id string) error {
	return h.st.RegisterInstallation(ctx, id)
}

func (h *Housing) MigrateInstallation(ctx context.Context, planID, oldID, newID string) error {
	return h.st.MigrateInstallation(ctx, planID, oldID, newID)
}

func (h *Housing) SetActiveRoster(ctx context.Context, planID, revisionID string, participants []string) error {
	now := h.now()
	if err := h.st.SetActiveRoster(ctx, planID, revisionID, participants, now); err != nil {
		return err
	}
	existing, err := h.st.GetPlan(ctx, planID)
	if err != nil {
		return err
	}
	if existing != nil {
		return nil
	}
	return h.st.UpsertPlan(ctx, store.Plan{
		PlanID:         planID,
		LifecycleState: StateLinkedNotActive,
		UpdatedAt:      now,
	})
}

func (h *Housing) RecordActiveUse(ctx context.Context, planID string) error {
	roster, err := h.st.ActiveRoster(ctx, planID)
	if err != nil {
		return err
	}
	if len(roster) < 2 {
		return nil
	}
	now := h.now()
	plan, err := h.st.GetPlan(ctx, planID)
	if err != nil {
		return err
	}
	if plan != nil && plan.ActiveUseStartedAt != nil {
		return nil
	}
	consumed, err := h.st.AnyTrialConsumed(ctx, roster)
	if err != nil {
		return err
	}
	activeUse := now
	p := store.Plan{
		PlanID:             planID,
		ActiveUseStartedAt: &activeUse,
		UpdatedAt:          now,
	}
	if consumed {
		p.LifecycleState = StateDelinquentGrace
		graceEnd := now.Add(h.cfg.GraceDuration)
		p.GraceEndsAt = &graceEnd
	} else {
		trialEnd := now.Add(h.cfg.TrialDuration)
		p.LifecycleState = StateActiveTrial
		p.TrialStartedAt = &activeUse
		p.TrialEndsAt = &trialEnd
		if err := h.st.MarkTrialConsumed(ctx, roster, now); err != nil {
			return err
		}
	}
	return h.st.UpsertPlan(ctx, p)
}

func (h *Housing) ReportLicense(ctx context.Context, planID, participantID, state string, expiresAt *time.Time) error {
	return h.st.UpsertLicenseStatus(ctx, planID, participantID, state, expiresAt, h.now())
}

func (h *Housing) ApplyPlayResult(ctx context.Context, installationID string, res license.Result, token string, raw []byte) error {
	if err := h.st.RegisterInstallation(ctx, installationID); err != nil {
		return err
	}
	module := "unknown"
	if len(res.GrantedModules) > 0 {
		module = res.GrantedModules[0]
	}
	productID := res.ProductID
	blob := json.RawMessage(`{}`)
	if len(raw) > 0 {
		blob = json.RawMessage(raw)
	}
	rec := store.PlayReceipt{
		InstallationID:    installationID,
		Module:            module,
		Platform:          license.PlatformGooglePlay,
		ProductID:         productID,
		PurchaseToken:     token,
		ReceiptBlob:       blob,
		ValidationState:   res.ValidationState,
		ExpiresAt:         res.ExpiresAt,
		ValidatedAt:       h.now(),
		GrantedModules:    res.GrantedModules,
		SubscriptionState: res.SubscriptionState,
	}
	if rec.GrantedModules == nil {
		rec.GrantedModules = []string{}
	}
	if err := h.st.UpsertPlayReceipt(ctx, rec); err != nil {
		return err
	}
	return h.reprojectInstallationHousing(ctx, installationID, false)
}

func (h *Housing) ReprojectInstallationLicense(
	ctx context.Context,
	installationID string,
	revokeImmediately bool,
) error {
	return h.reprojectInstallationHousing(
		ctx,
		installationID,
		revokeImmediately,
	)
}

func (h *Housing) reprojectInstallationHousing(
	ctx context.Context,
	installationID string,
	revokeImmediately bool,
) error {
	rows, err := h.st.PlayReceiptsForInstallation(ctx, installationID)
	if err != nil {
		return err
	}
	results := make([]license.Result, 0, len(rows))
	for _, r := range rows {
		results = append(results, license.Result{
			ValidationState:   r.ValidationState,
			Active:            r.ValidationState == license.ValidationValid,
			ProductID:         r.ProductID,
			GrantedModules:    r.GrantedModules,
			ExpiresAt:         r.ExpiresAt,
			SubscriptionState: r.SubscriptionState,
		})
	}
	free, err := h.st.FreeLicenseForInstallation(ctx, installationID)
	if err != nil {
		return err
	}
	if free != nil && free.ExpiresAt.After(h.now()) {
		results = append(results, license.Result{
			ValidationState: license.ValidationValid,
			Active:          true,
			ProductID:       license.ProductAllModules,
			GrantedModules: []string{
				license.ModuleHousing,
				license.ModuleVehicle,
				license.ModuleVehicleSharing,
			},
			ExpiresAt:         &free.ExpiresAt,
			SubscriptionState: license.SubscriptionStateActive,
		})
	}
	paid, expires := license.HousingPaidFromResults(results, h.now())
	state := LicenseUnpaid
	if paid {
		state = LicenseActivePaid
	}
	plans, err := h.st.PlansForInstallation(ctx, installationID)
	if err != nil {
		return err
	}
	for _, planID := range plans {
		if err := h.st.UpsertLicenseStatus(ctx, planID, installationID, state, expires, h.now()); err != nil {
			return err
		}
		if revokeImmediately && !paid {
			plan, err := h.st.GetPlan(ctx, planID)
			if err != nil {
				return err
			}
			if plan != nil && plan.ActiveUseStartedAt != nil {
				plan.LifecycleState = StateDelinquentReadonly
				plan.UpdatedAt = h.now()
				if err := h.st.UpsertPlan(ctx, *plan); err != nil {
					return err
				}
				continue
			}
		}
		if err := h.RefreshPlanLifecycle(ctx, planID); err != nil {
			return err
		}
	}
	return nil
}

func (h *Housing) RecordExpenseDecision(ctx context.Context, planID, expenseID, participantID, decision string) error {
	return h.st.RecordExpenseDecision(ctx, planID, expenseID, participantID, decision, h.now())
}

func (h *Housing) RefreshPlanLifecycle(ctx context.Context, planID string) error {
	plan, err := h.st.GetPlan(ctx, planID)
	if err != nil || plan == nil {
		return err
	}
	roster, err := h.st.ActiveRoster(ctx, planID)
	if err != nil {
		return err
	}
	if len(roster) == 0 {
		return nil
	}
	now := h.now()
	allPaid, err := h.allParticipantsPaid(ctx, planID, roster)
	if err != nil {
		return err
	}
	if allPaid {
		plan.LifecycleState = StateActivePaid
		plan.GraceEndsAt = nil
		plan.UpdatedAt = now
		return h.st.UpsertPlan(ctx, *plan)
	}
	if plan.LifecycleState == StateActiveTrial && plan.TrialEndsAt != nil && now.After(*plan.TrialEndsAt) {
		graceEnd := now.Add(h.cfg.GraceDuration)
		plan.LifecycleState = StateDelinquentGrace
		plan.GraceEndsAt = &graceEnd
		plan.UpdatedAt = now
		return h.st.UpsertPlan(ctx, *plan)
	}
	if plan.LifecycleState == StateDelinquentGrace && plan.GraceEndsAt != nil && now.After(*plan.GraceEndsAt) {
		plan.LifecycleState = StateDelinquentReadonly
		plan.UpdatedAt = now
		return h.st.UpsertPlan(ctx, *plan)
	}
	return nil
}

func (h *Housing) Introspect(ctx context.Context, in IntrospectInput) (IntrospectResult, error) {
	if in.Module != "housing" {
		return IntrospectResult{Allow: false, Code: "entitlement_module_unsupported"}, nil
	}
	if in.PlanID == "" || in.ParticipantInstallationID == "" {
		return IntrospectResult{Allow: false, Code: "entitlement_gate_required"}, nil
	}
	op := in.Operation
	if op == "" {
		op = operationFromKind(in.EnvelopeKind)
	}
	if isActiveUseOperation(op) {
		if err := h.RecordActiveUse(ctx, in.PlanID); err != nil {
			return IntrospectResult{}, err
		}
	}
	if in.DecisionKind != "" && in.ExpenseID != "" {
		if err := h.RecordExpenseDecision(ctx, in.PlanID, in.ExpenseID, in.ParticipantInstallationID, in.DecisionKind); err != nil {
			return IntrospectResult{}, err
		}
	}
	if err := h.RefreshPlanLifecycle(ctx, in.PlanID); err != nil {
		return IntrospectResult{}, err
	}
	plan, err := h.st.GetPlan(ctx, in.PlanID)
	if err != nil {
		return IntrospectResult{}, err
	}
	if isPreActiveUse(plan) && isNegotiationOperation(op) {
		return IntrospectResult{Allow: true, Code: "allowed"}, nil
	}
	if plan == nil {
		if isMutatingOperation(op) {
			return IntrospectResult{Allow: false, Code: "entitlement_not_entitled"}, nil
		}
		return IntrospectResult{Allow: true, Code: "allowed"}, nil
	}
	if plan.LifecycleState == StateDelinquentReadonly && isMutatingOperation(op) {
		return IntrospectResult{Allow: false, Code: "entitlement_plan_read_only"}, nil
	}
	roster, err := h.st.ActiveRoster(ctx, in.PlanID)
	if err != nil {
		return IntrospectResult{}, err
	}
	if !participantInRoster(roster, in.ParticipantInstallationID) && isMutatingOperation(op) {
		return IntrospectResult{Allow: false, Code: "entitlement_not_entitled"}, nil
	}
	allPaid, err := h.allParticipantsPaid(ctx, in.PlanID, roster)
	if err != nil {
		return IntrospectResult{}, err
	}
	if allPaid {
		return IntrospectResult{Allow: true, Code: "allowed"}, nil
	}
	switch plan.LifecycleState {
	case StateLinkedNotActive, StateActiveTrial:
		if plan.TrialEndsAt != nil && h.now().After(*plan.TrialEndsAt) {
			return IntrospectResult{Allow: false, Code: "entitlement_trial_expired"}, nil
		}
		return IntrospectResult{Allow: true, Code: "allowed"}, nil
	case StateActivePaid:
		return IntrospectResult{Allow: true, Code: "allowed"}, nil
	case StateDelinquentGrace:
		return IntrospectResult{Allow: true, Code: "allowed"}, nil
	case StateDelinquentReadonly:
		if isMutatingOperation(op) {
			return IntrospectResult{Allow: false, Code: "entitlement_plan_read_only"}, nil
		}
		return IntrospectResult{Allow: true, Code: "allowed"}, nil
	default:
		if isMutatingOperation(op) {
			return IntrospectResult{Allow: false, Code: "entitlement_not_entitled"}, nil
		}
		return IntrospectResult{Allow: true, Code: "allowed"}, nil
	}
}

func (h *Housing) allParticipantsPaid(ctx context.Context, planID string, roster []string) (bool, error) {
	if len(roster) == 0 {
		return false, nil
	}
	statuses, err := h.st.LicenseStatuses(ctx, planID)
	if err != nil {
		return false, err
	}
	byID := map[string]string{}
	for _, s := range statuses {
		byID[s.ParticipantInstallationID] = s.LicenseState
	}
	for _, id := range roster {
		if byID[id] != LicenseActivePaid {
			return false, nil
		}
	}
	return true, nil
}

func participantInRoster(roster []string, id string) bool {
	for _, r := range roster {
		if r == id {
			return true
		}
	}
	return false
}

func isActiveUseOperation(op string) bool {
	return op == "housing_realized_expense_propose" || op == "realized_expense_propose"
}

// Negotiation (proposal offer/response) is free until qualifying active use
// starts; roster and trial gating apply to ledger sync afterward.
func isNegotiationOperation(op string) bool {
	return op == "housing_proposal" || op == "housing_proposal_response"
}

func isPreActiveUse(plan *store.Plan) bool {
	if plan == nil {
		return true
	}
	return plan.ActiveUseStartedAt == nil
}

func isMutatingOperation(op string) bool {
	switch op {
	case "housing_proposal", "housing_proposal_response",
		"housing_realized_expense_propose", "realized_expense_propose",
		"housing_realized_expense_accept", "realized_expense_accept",
		"housing_realized_expense_reject", "realized_expense_reject":
		return true
	default:
		return false
	}
}

func operationFromKind(kind int) string {
	switch kind {
	case 5:
		return "housing_proposal"
	case 6:
		return "housing_proposal_response"
	case 7:
		return "housing_realized_expense_propose"
	case 8:
		return "housing_realized_expense_accept"
	case 9:
		return "housing_realized_expense_reject"
	default:
		return ""
	}
}
