package license

import (
	"testing"
	"time"
)

func TestLookupPlayProductCatalog(t *testing.T) {
	ids := KnownPlayProductIDs()
	if len(ids) != 7 {
		t.Fatalf("want 7 SKUs, got %d", len(ids))
	}
	housing, ok := LookupPlayProduct("bojairu.housing")
	if !ok || len(housing.GrantedModules) != 1 || housing.GrantedModules[0] != ModuleHousing {
		t.Fatalf("housing: %+v ok=%v", housing, ok)
	}
	all, ok := LookupPlayProduct("bojairu.bundle.all_modules")
	if !ok || len(all.GrantedModules) != 3 {
		t.Fatalf("all_modules: %+v ok=%v", all, ok)
	}
	if _, ok := LookupPlayProduct("not.a.sku"); ok {
		t.Fatal("unknown sku")
	}
}

func TestEvaluateActiveHousing(t *testing.T) {
	now := time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC)
	exp := now.Add(30 * 24 * time.Hour)
	got := EvaluateSubscription(SubscriptionPurchaseV2{
		SubscriptionState: SubscriptionStateActive,
		LineItems: []SubscriptionPurchaseLineItem{{
			ProductID:  "bojairu.housing",
			ExpiryTime: exp.Format(time.RFC3339Nano),
		}},
	}, now)
	if got.ValidationState != ValidationValid || !got.Active {
		t.Fatalf("%+v", got)
	}
	if got.ProductID != "bojairu.housing" || !grantsModule(got.GrantedModules, ModuleHousing) {
		t.Fatalf("%+v", got)
	}
	if got.ExpiresAt == nil || !got.ExpiresAt.Equal(exp) {
		t.Fatalf("expiry %+v want %s", got.ExpiresAt, exp)
	}
}

func TestEvaluateActiveBundleGrantsHousing(t *testing.T) {
	now := time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC)
	exp := now.Add(24 * time.Hour)
	got := EvaluateSubscription(SubscriptionPurchaseV2{
		SubscriptionState: SubscriptionStateActive,
		LineItems: []SubscriptionPurchaseLineItem{{
			ProductID:  "bojairu.bundle.all_modules",
			ExpiryTime: exp.Format(time.RFC3339Nano),
		}},
	}, now)
	if got.ValidationState != ValidationValid {
		t.Fatalf("%+v", got)
	}
	for _, m := range []string{ModuleHousing, ModuleVehicle, ModuleVehicleSharing} {
		if !grantsModule(got.GrantedModules, m) {
			t.Fatalf("missing module %s in %+v", m, got.GrantedModules)
		}
	}
}

func TestEvaluateNonActiveStatesAreInvalid(t *testing.T) {
	now := time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC)
	exp := now.Add(24 * time.Hour).Format(time.RFC3339Nano)
	states := []string{
		SubscriptionStateInGracePeriod,
		SubscriptionStateCanceled,
		SubscriptionStateExpired,
		SubscriptionStateOnHold,
		SubscriptionStatePaused,
		SubscriptionStatePending,
		SubscriptionStatePendingPurchaseCanceled,
		SubscriptionStateUnspecified,
		"",
	}
	for _, state := range states {
		got := EvaluateSubscription(SubscriptionPurchaseV2{
			SubscriptionState: state,
			LineItems: []SubscriptionPurchaseLineItem{{
				ProductID:  "bojairu.housing",
				ExpiryTime: exp,
			}},
		}, now)
		if got.ValidationState != ValidationInvalid || got.Active {
			t.Fatalf("state %q: %+v", state, got)
		}
	}
}

func TestEvaluateUnknownProductInvalid(t *testing.T) {
	now := time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC)
	got := EvaluateSubscription(SubscriptionPurchaseV2{
		SubscriptionState: SubscriptionStateActive,
		LineItems: []SubscriptionPurchaseLineItem{{
			ProductID:  "other.app.sku",
			ExpiryTime: now.Add(time.Hour).Format(time.RFC3339Nano),
		}},
	}, now)
	if got.ValidationState != ValidationInvalid || got.Reason != "unknown_product" {
		t.Fatalf("%+v", got)
	}
}

func TestEvaluateActiveButLineItemExpired(t *testing.T) {
	now := time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC)
	got := EvaluateSubscription(SubscriptionPurchaseV2{
		SubscriptionState: SubscriptionStateActive,
		LineItems: []SubscriptionPurchaseLineItem{{
			ProductID:  "bojairu.housing",
			ExpiryTime: now.Add(-time.Minute).Format(time.RFC3339Nano),
		}},
	}, now)
	if got.ValidationState != ValidationInvalid || got.Reason != "expired_line_item" {
		t.Fatalf("%+v", got)
	}
}

func TestHousingPaidFromResultsMostFavorableWins(t *testing.T) {
	now := time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC)
	early := now.Add(24 * time.Hour)
	late := now.Add(48 * time.Hour)
	paid, exp := HousingPaidFromResults([]Result{
		{
			ValidationState: ValidationInvalid,
			Active:          false,
			GrantedModules:  []string{ModuleHousing},
			ExpiresAt:       &early,
		},
		{
			ValidationState: ValidationValid,
			Active:          true,
			GrantedModules:  []string{ModuleHousing, ModuleVehicleSharing},
			ExpiresAt:       &late,
		},
		{
			ValidationState: ValidationValid,
			Active:          true,
			GrantedModules:  []string{ModuleVehicle},
			ExpiresAt:       &late,
		},
	}, now)
	if !paid || exp == nil || !exp.Equal(late) {
		t.Fatalf("paid=%v exp=%v", paid, exp)
	}
}

func TestHousingPaidFromResultsVehicleOnlyUnpaid(t *testing.T) {
	now := time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC)
	exp := now.Add(time.Hour)
	paid, _ := HousingPaidFromResults([]Result{{
		ValidationState: ValidationValid,
		Active:          true,
		GrantedModules:  []string{ModuleVehicle},
		ExpiresAt:       &exp,
	}}, now)
	if paid {
		t.Fatal("vehicle-only must not pay housing")
	}
}
