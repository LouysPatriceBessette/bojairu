package push

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"golang.org/x/oauth2"
)

type staticTokenSource struct{}

func (staticTokenSource) Token() (*oauth2.Token, error) {
	return &oauth2.Token{AccessToken: "access-token"}, nil
}

func TestSendLicenseChange(t *testing.T) {
	var got map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer access-token" {
			t.Fatalf("authorization=%q", r.Header.Get("Authorization"))
		}
		if err := json.NewDecoder(r.Body).Decode(&got); err != nil {
			t.Fatal(err)
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	sender := &FCM{
		HTTPClient: server.Client(),
		ProjectID:  "project",
		TokenSrc:   staticTokenSource{},
		APIBaseURL: server.URL,
	}
	err := sender.SendLicenseChange(
		context.Background(),
		"device-token",
		LicenseChange{
			Action:         "grant",
			InstallationID: "installation-1",
			ProductID:      "bojairu.bundle.all_modules",
			Platform:       "server_grant",
			PurchaseToken:  "server-grant:installation-1",
			PurchasedAt:    time.Date(2026, 9, 1, 12, 0, 0, 0, time.UTC),
			ExpiresAt:      time.Date(2126, 9, 1, 12, 0, 0, 0, time.UTC),
		},
	)
	if err != nil {
		t.Fatal(err)
	}

	message := got["message"].(map[string]any)
	if message["token"] != "device-token" {
		t.Fatalf("token=%v", message["token"])
	}
	data := message["data"].(map[string]any)
	if data["kind"] != KindLicenseReceiptChanged || data["action"] != "grant" {
		t.Fatalf("data=%v", data)
	}
	apns := message["apns"].(map[string]any)
	payload := apns["payload"].(map[string]any)
	aps := payload["aps"].(map[string]any)
	if aps["content-available"] != float64(1) {
		t.Fatalf("aps=%v", aps)
	}
}
