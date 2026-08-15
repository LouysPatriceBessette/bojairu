package license

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

const (
	playAPIBaseDefault = "https://androidpublisher.googleapis.com"
	playAuthScope      = "https://www.googleapis.com/auth/androidpublisher"
	defaultPackageName = "app.incoherences.bojairu"
)

// Play calls purchases.subscriptionsv2.get.
type Play struct {
	HTTPClient  *http.Client
	TokenSrc    oauth2.TokenSource
	PackageName string
	// APIBaseURL overrides the Play host (tests). Empty uses production.
	APIBaseURL string
	Now        Clock
}

// NewPlayFromServiceAccountJSON loads a Google service account JSON file
// (Play Android Developer API — not the Firebase FCM JSON).
func NewPlayFromServiceAccountJSON(path, packageName string) (*Play, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read Play service account: %w", err)
	}
	cfg, err := google.JWTConfigFromJSON(raw, playAuthScope)
	if err != nil {
		return nil, fmt.Errorf("jwt config from Play service account: %w", err)
	}
	pkg := strings.TrimSpace(packageName)
	if pkg == "" {
		pkg = defaultPackageName
	}
	return &Play{
		HTTPClient:  &http.Client{Timeout: 20 * time.Second},
		TokenSrc:    cfg.TokenSource(context.Background()),
		PackageName: pkg,
		Now:         time.Now,
	}, nil
}

func (p *Play) VerifyPurchase(ctx context.Context, in Purchase) (Result, error) {
	if p == nil || p.TokenSrc == nil {
		return Result{}, fmt.Errorf("play verifier not configured")
	}
	platform := strings.TrimSpace(in.Platform)
	if platform != "" && platform != PlatformGooglePlay {
		return Result{
			ValidationState: ValidationInvalid,
			Reason:          "platform_unsupported",
		}, nil
	}
	token := strings.TrimSpace(in.PurchaseToken)
	if token == "" {
		return Result{
			ValidationState: ValidationInvalid,
			Reason:          "missing_purchase_token",
		}, nil
	}
	pkg := strings.TrimSpace(p.PackageName)
	if pkg == "" {
		pkg = defaultPackageName
	}
	base := strings.TrimSpace(p.APIBaseURL)
	if base == "" {
		base = playAPIBaseDefault
	}
	u := fmt.Sprintf("%s/androidpublisher/v3/applications/%s/purchases/subscriptionsv2/tokens/%s",
		strings.TrimSuffix(base, "/"),
		url.PathEscape(pkg),
		url.PathEscape(token),
	)
	tok, err := p.TokenSrc.Token()
	if err != nil {
		return Result{}, fmt.Errorf("play oauth token: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return Result{}, err
	}
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)

	client := p.HTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	resp, err := client.Do(req)
	if err != nil {
		return Result{}, fmt.Errorf("play http: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return Result{}, fmt.Errorf("play read body: %w", err)
	}
	switch {
	case resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusGone:
		return Result{
			ValidationState: ValidationInvalid,
			Reason:          fmt.Sprintf("play_http_%d", resp.StatusCode),
			ProductID:       strings.TrimSpace(in.ProductID),
		}, nil
	case resp.StatusCode < 200 || resp.StatusCode >= 300:
		return Result{}, fmt.Errorf("play http %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	var purchase SubscriptionPurchaseV2
	if err := json.Unmarshal(body, &purchase); err != nil {
		return Result{}, fmt.Errorf("play json: %w", err)
	}
	now := time.Now()
	if p.Now != nil {
		now = p.Now()
	}
	out := EvaluateSubscription(purchase, now)
	if out.ProductID == "" {
		out.ProductID = strings.TrimSpace(in.ProductID)
	}
	return out, nil
}
