package license

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"golang.org/x/oauth2"
)

func TestPlayVerifyPurchaseActive(t *testing.T) {
	exp := time.Date(2026, 9, 15, 10, 0, 0, 0, time.UTC)
	var gotPath string
	var gotAuth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotAuth = r.Header.Get("Authorization")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"kind":              "androidpublisher#subscriptionPurchaseV2",
			"subscriptionState": SubscriptionStateActive,
			"lineItems": []map[string]string{{
				"productId":  "bojairu.housing",
				"expiryTime": exp.Format(time.RFC3339Nano),
			}},
		})
	}))
	defer srv.Close()

	p := &Play{
		HTTPClient:  srv.Client(),
		TokenSrc:    oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "test-token"}),
		PackageName: "app.incoherences.bojairu",
		APIBaseURL:  srv.URL,
		Now:         func() time.Time { return time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC) },
	}
	got, err := p.VerifyPurchase(context.Background(), Purchase{
		Platform:      PlatformGooglePlay,
		ProductID:     "bojairu.housing",
		PurchaseToken: "tok-abc",
	})
	if err != nil {
		t.Fatal(err)
	}
	if got.ValidationState != ValidationValid || !got.Active {
		t.Fatalf("%+v", got)
	}
	if gotAuth != "Bearer test-token" {
		t.Fatalf("auth %q", gotAuth)
	}
	if !strings.Contains(gotPath, "/applications/app.incoherences.bojairu/purchases/subscriptionsv2/tokens/tok-abc") {
		t.Fatalf("path %q", gotPath)
	}
}

func TestPlayVerifyPurchaseInvalidTokenHTTP404(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, `{"error":{"code":404,"message":"not found"}}`, http.StatusNotFound)
	}))
	defer srv.Close()
	p := &Play{
		HTTPClient:  srv.Client(),
		TokenSrc:    oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "t"}),
		PackageName: "app.incoherences.bojairu",
		APIBaseURL:  srv.URL,
	}
	got, err := p.VerifyPurchase(context.Background(), Purchase{
		Platform:      PlatformGooglePlay,
		ProductID:     "bojairu.housing",
		PurchaseToken: "bad",
	})
	if err != nil {
		t.Fatal(err)
	}
	if got.ValidationState != ValidationInvalid || got.Reason != "play_http_404" {
		t.Fatalf("%+v", got)
	}
}

func TestPlayVerifyPurchaseServerError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "unavailable", http.StatusInternalServerError)
	}))
	defer srv.Close()
	p := &Play{
		HTTPClient:  srv.Client(),
		TokenSrc:    oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "t"}),
		PackageName: "app.incoherences.bojairu",
		APIBaseURL:  srv.URL,
	}
	_, err := p.VerifyPurchase(context.Background(), Purchase{
		Platform:      PlatformGooglePlay,
		PurchaseToken: "tok",
	})
	if err == nil || !strings.Contains(err.Error(), "play http 500") {
		t.Fatalf("err=%v", err)
	}
}

func TestPlayVerifyPurchaseRejectsApple(t *testing.T) {
	p := &Play{
		TokenSrc: oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "t"}),
	}
	got, err := p.VerifyPurchase(context.Background(), Purchase{
		Platform:      "apple",
		PurchaseToken: "tok",
	})
	if err != nil {
		t.Fatal(err)
	}
	if got.Reason != "platform_unsupported" || got.ValidationState != ValidationInvalid {
		t.Fatalf("%+v", got)
	}
}

func TestStubVerifyPurchasePending(t *testing.T) {
	got, err := Stub{}.VerifyPurchase(context.Background(), Purchase{})
	if err != nil {
		t.Fatal(err)
	}
	if got.ValidationState != ValidationPending || got.Reason != "play_verifier_unconfigured" {
		t.Fatalf("%+v", got)
	}
}
