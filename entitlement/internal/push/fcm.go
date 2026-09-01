package push

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

const KindLicenseReceiptChanged = "license_receipt_changed"

type LicenseChange struct {
	Action         string
	InstallationID string
	ProductID      string
	Platform       string
	PurchaseToken  string
	PurchasedAt    time.Time
	ExpiresAt      time.Time
}

type FCM struct {
	HTTPClient *http.Client
	ProjectID  string
	TokenSrc   oauth2.TokenSource
	APIBaseURL string
}

func NewFCMFromServiceAccountJSON(path string) (*FCM, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read FCM service account: %w", err)
	}
	var meta struct {
		ProjectID string `json:"project_id"`
	}
	if err := json.Unmarshal(raw, &meta); err != nil {
		return nil, fmt.Errorf("parse FCM service account metadata: %w", err)
	}
	if strings.TrimSpace(meta.ProjectID) == "" {
		return nil, fmt.Errorf("FCM service account JSON missing project_id")
	}
	cfg, err := google.JWTConfigFromJSON(
		raw,
		"https://www.googleapis.com/auth/firebase.messaging",
	)
	if err != nil {
		return nil, fmt.Errorf("jwt config from FCM service account: %w", err)
	}
	return &FCM{
		HTTPClient: &http.Client{Timeout: 20 * time.Second},
		ProjectID:  meta.ProjectID,
		TokenSrc:   cfg.TokenSource(context.Background()),
	}, nil
}

func (f *FCM) SendLicenseChange(
	ctx context.Context,
	deviceToken string,
	change LicenseChange,
) error {
	if f == nil || f.TokenSrc == nil {
		return fmt.Errorf("FCM sender not configured")
	}
	data := map[string]string{
		"v":               "1",
		"kind":            KindLicenseReceiptChanged,
		"action":          change.Action,
		"installation_id": change.InstallationID,
		"product_id":      change.ProductID,
		"platform":        change.Platform,
		"purchase_token":  change.PurchaseToken,
	}
	if !change.PurchasedAt.IsZero() {
		data["purchased_at"] = change.PurchasedAt.UTC().Format(time.RFC3339Nano)
	}
	if !change.ExpiresAt.IsZero() {
		data["expires_at"] = change.ExpiresAt.UTC().Format(time.RFC3339Nano)
	}

	tok, err := f.TokenSrc.Token()
	if err != nil {
		return fmt.Errorf("FCM oauth token: %w", err)
	}
	body := struct {
		Message struct {
			Token   string            `json:"token"`
			Data    map[string]string `json:"data"`
			Android struct {
				Priority string `json:"priority"`
			} `json:"android"`
			APNS struct {
				Headers map[string]string `json:"headers"`
				Payload struct {
					APS struct {
						ContentAvailable int `json:"content-available"`
					} `json:"aps"`
				} `json:"payload"`
			} `json:"apns"`
		} `json:"message"`
	}{}
	body.Message.Token = deviceToken
	body.Message.Data = data
	body.Message.Android.Priority = "HIGH"
	body.Message.APNS.Headers = map[string]string{
		"apns-push-type": "background",
		"apns-priority":  "5",
	}
	body.Message.APNS.Payload.APS.ContentAvailable = 1

	raw, err := json.Marshal(body)
	if err != nil {
		return err
	}
	url := fmt.Sprintf(
		"https://fcm.googleapis.com/v1/projects/%s/messages:send",
		f.ProjectID,
	)
	if base := strings.TrimSpace(f.APIBaseURL); base != "" {
		url = fmt.Sprintf(
			"%s/v1/projects/%s/messages:send",
			strings.TrimSuffix(base, "/"),
			f.ProjectID,
		)
	}
	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		url,
		bytes.NewReader(raw),
	)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	client := f.HTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	res, err := client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	resBody, _ := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return fmt.Errorf(
			"FCM HTTP %d: %s",
			res.StatusCode,
			strings.TrimSpace(string(resBody)),
		)
	}
	return nil
}
