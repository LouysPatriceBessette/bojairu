package push

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"golang.org/x/oauth2"
)

func TestSendOperatorNoticePayload(t *testing.T) {
	var gotBody []byte
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotBody, _ = io.ReadAll(r.Body)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"name":"ok"}`))
	}))
	t.Cleanup(srv.Close)

	now := time.Now()
	fcm := &FCMDataWake{
		HTTPClient: srv.Client(),
		ProjectID:  "test-project",
		TokenSrc:   oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "test", Expiry: now.Add(time.Hour)}),
		APIBaseURL: srv.URL,
	}
	if err := fcm.SendOperatorNotice(context.Background(), "device-token", "39", true); err != nil {
		t.Fatal(err)
	}

	var req fcmV1Request
	if err := json.Unmarshal(gotBody, &req); err != nil {
		t.Fatal(err)
	}
	if req.Message.Token != "device-token" {
		t.Fatalf("token %q", req.Message.Token)
	}
	if req.Message.Android == nil || req.Message.Android.Priority != "HIGH" {
		t.Fatalf("android %+v", req.Message.Android)
	}
	if req.Message.Data["kind"] != KindOperatorNotice {
		t.Fatalf("kind %q", req.Message.Data["kind"])
	}
	if req.Message.Data["v"] != "1" || req.Message.Data["consult_site"] != "1" || req.Message.Data["target_build"] != "39" {
		t.Fatalf("data %+v", req.Message.Data)
	}
	if _, ok := req.Message.Data["recipient"]; ok {
		t.Fatal("operator notice must not carry recipient")
	}
}

func TestSendOperatorNoticeOmitsTargetBuild(t *testing.T) {
	var gotBody []byte
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotBody, _ = io.ReadAll(r.Body)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"name":"ok"}`))
	}))
	t.Cleanup(srv.Close)

	now := time.Now()
	fcm := &FCMDataWake{
		HTTPClient: srv.Client(),
		ProjectID:  "test-project",
		TokenSrc:   oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "test", Expiry: now.Add(time.Hour)}),
		APIBaseURL: srv.URL,
	}
	if err := fcm.SendOperatorNotice(context.Background(), "device-token", "", false); err != nil {
		t.Fatal(err)
	}
	var req fcmV1Request
	if err := json.Unmarshal(gotBody, &req); err != nil {
		t.Fatal(err)
	}
	if req.Message.Data["consult_site"] != "0" {
		t.Fatalf("consult_site %q", req.Message.Data["consult_site"])
	}
	if _, ok := req.Message.Data["target_build"]; ok {
		t.Fatalf("target_build should be omitted: %+v", req.Message.Data)
	}
}

func TestSendWakeStillUsesInboxKind(t *testing.T) {
	var gotBody []byte
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotBody, _ = io.ReadAll(r.Body)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"name":"ok"}`))
	}))
	t.Cleanup(srv.Close)

	now := time.Now()
	fcm := &FCMDataWake{
		HTTPClient: srv.Client(),
		ProjectID:  "test-project",
		TokenSrc:   oauth2.StaticTokenSource(&oauth2.Token{AccessToken: "test", Expiry: now.Add(time.Hour)}),
		APIBaseURL: srv.URL,
	}
	if err := fcm.SendWake(context.Background(), "device-token", "abc"); err != nil {
		t.Fatal(err)
	}
	var req fcmV1Request
	if err := json.Unmarshal(gotBody, &req); err != nil {
		t.Fatal(err)
	}
	if req.Message.Data["kind"] != KindWakeForInbox {
		t.Fatalf("kind %q", req.Message.Data["kind"])
	}
}
