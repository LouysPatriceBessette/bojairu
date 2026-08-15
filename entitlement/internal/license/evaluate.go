package license

import (
	"strings"
	"time"
)

// Play subscriptionState values from
// https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2
const (
	SubscriptionStateUnspecified             = "SUBSCRIPTION_STATE_UNSPECIFIED"
	SubscriptionStatePending                 = "SUBSCRIPTION_STATE_PENDING"
	SubscriptionStateActive                  = "SUBSCRIPTION_STATE_ACTIVE"
	SubscriptionStatePaused                  = "SUBSCRIPTION_STATE_PAUSED"
	SubscriptionStateInGracePeriod           = "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
	SubscriptionStateOnHold                  = "SUBSCRIPTION_STATE_ON_HOLD"
	SubscriptionStateCanceled                = "SUBSCRIPTION_STATE_CANCELED"
	SubscriptionStateExpired                 = "SUBSCRIPTION_STATE_EXPIRED"
	SubscriptionStatePendingPurchaseCanceled = "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED"
)

const (
	ValidationValid   = "valid"
	ValidationInvalid = "invalid"
	ValidationPending = "pending"
)

// SubscriptionPurchaseV2 is the documented Play purchases.subscriptionsv2.get body.
// Only fields used for entitlement are decoded.
type SubscriptionPurchaseV2 struct {
	SubscriptionState string                         `json:"subscriptionState"`
	LineItems         []SubscriptionPurchaseLineItem `json:"lineItems"`
}

// SubscriptionPurchaseLineItem is one Play line item (product + expiry).
type SubscriptionPurchaseLineItem struct {
	ProductID  string `json:"productId"`
	ExpiryTime string `json:"expiryTime"`
}

// Result is the entitlement decision for one Play purchase token.
type Result struct {
	ValidationState   string
	Active            bool
	ProductID         string
	GrantedModules    []string
	ExpiresAt         *time.Time
	SubscriptionState string
	Reason            string
}

// EvaluateSubscription classifies a Play SubscriptionPurchaseV2.
//
// Paid (valid) only when subscriptionState is SUBSCRIPTION_STATE_ACTIVE and at
// least one line item matches the documented catalog. Other Play states are
// unpaid, including SUBSCRIPTION_STATE_IN_GRACE_PERIOD (Play billing-retry
// grace — not the product 7-day housing grace after trial) and
// SUBSCRIPTION_STATE_CANCELED (canceled but not expired; Google still exposes
// lineItems.expiryTime, but this delivery does not treat that as paid).
func EvaluateSubscription(purchase SubscriptionPurchaseV2, now time.Time) Result {
	state := strings.TrimSpace(purchase.SubscriptionState)
	out := Result{
		ValidationState:   ValidationInvalid,
		SubscriptionState: state,
		Reason:            "not_active",
	}
	if state != SubscriptionStateActive {
		if state == "" {
			out.Reason = "missing_subscription_state"
		}
		return out
	}

	var bestExpiry *time.Time
	var productID string
	var modules []string
	seen := map[string]struct{}{}
	for _, item := range purchase.LineItems {
		prod, ok := LookupPlayProduct(strings.TrimSpace(item.ProductID))
		if !ok {
			continue
		}
		productID = prod.ProductID
		for _, m := range prod.GrantedModules {
			if _, dup := seen[m]; dup {
				continue
			}
			seen[m] = struct{}{}
			modules = append(modules, m)
		}
		exp, err := parsePlayTime(item.ExpiryTime)
		if err != nil || exp == nil {
			continue
		}
		if bestExpiry == nil || exp.After(*bestExpiry) {
			bestExpiry = exp
		}
	}
	if len(modules) == 0 {
		out.Reason = "unknown_product"
		return out
	}
	if bestExpiry != nil && !bestExpiry.After(now) {
		out.ProductID = productID
		out.GrantedModules = modules
		out.ExpiresAt = bestExpiry
		out.Reason = "expired_line_item"
		return out
	}
	out.ValidationState = ValidationValid
	out.Active = true
	out.ProductID = productID
	out.GrantedModules = modules
	out.ExpiresAt = bestExpiry
	out.Reason = "active"
	return out
}

func parsePlayTime(raw string) (*time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, nil
	}
	t, err := time.Parse(time.RFC3339Nano, raw)
	if err != nil {
		return nil, err
	}
	return &t, nil
}

// HousingPaidFromResults returns whether any valid result still grants housing,
// and the latest housing expiry among those sources (most favorable wins).
func HousingPaidFromResults(results []Result, now time.Time) (bool, *time.Time) {
	var best *time.Time
	paid := false
	for _, r := range results {
		if r.ValidationState != ValidationValid || !r.Active {
			continue
		}
		if !grantsModule(r.GrantedModules, ModuleHousing) {
			continue
		}
		if r.ExpiresAt != nil && !r.ExpiresAt.After(now) {
			continue
		}
		paid = true
		if r.ExpiresAt != nil && (best == nil || r.ExpiresAt.After(*best)) {
			t := *r.ExpiresAt
			best = &t
		}
	}
	return paid, best
}
