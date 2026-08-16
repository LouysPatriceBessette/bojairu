package push

import (
	"bytes"
	"context"
	"encoding/base64"
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

// FCMDataWake sends a data-only wake message via FCM HTTP v1.
type FCMDataWake struct {
	HTTPClient *http.Client
	ProjectID  string
	TokenSrc   oauth2.TokenSource
	// APIBaseURL overrides the FCM host (tests only). Empty uses production.
	APIBaseURL string
}

// NewFCMFromServiceAccountJSON loads a Google service account JSON file
// and builds an OAuth2 token source for the FCM messaging scope.
func NewFCMFromServiceAccountJSON(path string) (*FCMDataWake, error) {
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
	cfg, err := google.JWTConfigFromJSON(raw, "https://www.googleapis.com/auth/firebase.messaging")
	if err != nil {
		return nil, fmt.Errorf("jwt config from FCM service account: %w", err)
	}
	return &FCMDataWake{
		HTTPClient: &http.Client{Timeout: 20 * time.Second},
		ProjectID:  meta.ProjectID,
		TokenSrc:   cfg.TokenSource(context.Background()),
	}, nil
}

type fcmV1Request struct {
	Message fcmV1Message `json:"message"`
}

type fcmV1Message struct {
	Token   string            `json:"token"`
	Data    map[string]string `json:"data"`
	Android *fcmAndroid       `json:"android,omitempty"`
}

type fcmAndroid struct {
	Priority string `json:"priority"`
}

const (
	// KindWakeForInbox is the data-only closed-app wake (no user-visible copy).
	KindWakeForInbox = "wake_for_inbox"
	// KindOperatorNotice is the operator-triggered Android notice (VPS CLI).
	KindOperatorNotice = "operator_notice"
)

// SendWake posts one FCM data message. recipientB64 is base64url (no padding)
// of the opaque routing id, matching the public relay API encoding.
func (f *FCMDataWake) SendWake(ctx context.Context, deviceToken string, recipientB64 string) error {
	return f.sendData(ctx, deviceToken, map[string]string{
		"v":         "1",
		"kind":      KindWakeForInbox,
		"recipient": recipientB64,
	})
}

// SendOperatorNotice posts one data-only operator notice. Long copy stays on
// the static site; this payload carries only kind, optional target build, and
// whether the in-app page should offer the site link.
func (f *FCMDataWake) SendOperatorNotice(ctx context.Context, deviceToken, targetBuild string, consultSite bool) error {
	data := map[string]string{
		"v":            "1",
		"kind":         KindOperatorNotice,
		"consult_site": "0",
	}
	if consultSite {
		data["consult_site"] = "1"
	}
	if b := strings.TrimSpace(targetBuild); b != "" {
		data["target_build"] = b
	}
	return f.sendData(ctx, deviceToken, data)
}

func (f *FCMDataWake) sendData(ctx context.Context, deviceToken string, data map[string]string) error {
	if f == nil || f.TokenSrc == nil {
		return fmt.Errorf("fcm sender not configured")
	}
	tok, err := f.TokenSrc.Token()
	if err != nil {
		return fmt.Errorf("fcm oauth token: %w", err)
	}
	body := fcmV1Request{
		Message: fcmV1Message{
			Token:   deviceToken,
			Data:    data,
			Android: &fcmAndroid{Priority: "HIGH"},
		},
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return err
	}
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", f.ProjectID)
	if b := strings.TrimSpace(f.APIBaseURL); b != "" {
		url = fmt.Sprintf("%s/v1/projects/%s/messages:send", strings.TrimSuffix(b, "/"), f.ProjectID)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)

	client := f.HTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("fcm http %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}
	return nil
}

// PermanentTokenError is returned when the push provider indicates the
// registration token is no longer valid and should be purged server-side.
type PermanentTokenError struct {
	Detail string
}

func (e *PermanentTokenError) Error() string { return "permanent token error: " + e.Detail }

// SendWakeClassify is like SendWake but maps common FCM invalid-token errors
// to [PermanentTokenError].
func (f *FCMDataWake) SendWakeClassify(ctx context.Context, deviceToken string, recipientB64 string) error {
	return classifyPermanentToken(f.SendWake(ctx, deviceToken, recipientB64))
}

// SendOperatorNoticeClassify is like SendOperatorNotice but maps common FCM
// invalid-token errors to [PermanentTokenError].
func (f *FCMDataWake) SendOperatorNoticeClassify(ctx context.Context, deviceToken, targetBuild string, consultSite bool) error {
	return classifyPermanentToken(f.SendOperatorNotice(ctx, deviceToken, targetBuild, consultSite))
}

func classifyPermanentToken(err error) error {
	if err == nil {
		return nil
	}
	s := strings.ToLower(err.Error())
	if strings.Contains(s, "not_registered") ||
		strings.Contains(s, "unregistered") ||
		strings.Contains(s, "registration_token_not_registered") {
		return &PermanentTokenError{Detail: err.Error()}
	}
	return err
}

// EncodeRecipientB64 returns standard base64url encoding without padding.
func EncodeRecipientB64(recipient []byte) string {
	return base64.RawURLEncoding.EncodeToString(recipient)
}
