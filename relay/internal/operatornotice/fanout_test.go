package operatornotice

import (
	"context"
	"testing"
	"time"

	"github.com/compartarenta/relay/internal/push"
	"github.com/compartarenta/relay/internal/store"
)

type fakeStore struct {
	tokens  []string
	deleted []string
	actions []store.OperatorAction
	listErr error
}

func (f *fakeStore) ListDistinctActiveFCMTokens(context.Context, time.Time) ([]string, error) {
	return f.tokens, f.listErr
}

func (f *fakeStore) DeleteRoutingPushTokensByProviderToken(_ context.Context, provider, pushToken string) (int64, error) {
	if provider != "fcm" {
		return 0, errUnexpectedPayload{targetBuild: provider, consultSite: false}
	}
	f.deleted = append(f.deleted, pushToken)
	return 2, nil
}

func (f *fakeStore) RecordOperatorAction(_ context.Context, action store.OperatorAction) error {
	f.actions = append(f.actions, action)
	return nil
}

type fakeSender struct {
	sent []string
	fail map[string]error
}

func (f *fakeSender) SendOperatorNoticeClassify(_ context.Context, deviceToken, targetBuild string, consultSite bool) error {
	if targetBuild != "39" || !consultSite {
		return errUnexpectedPayload{targetBuild, consultSite}
	}
	f.sent = append(f.sent, deviceToken)
	if err, ok := f.fail[deviceToken]; ok {
		return err
	}
	return nil
}

type errUnexpectedPayload struct {
	targetBuild string
	consultSite bool
}

func (e errUnexpectedPayload) Error() string {
	return "unexpected payload"
}

func TestFanoutDryRunDoesNotSend(t *testing.T) {
	st := &fakeStore{tokens: []string{"a", "b"}}
	sender := &fakeSender{}
	opts := Options{ConsultSite: true}
	now := time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC)
	got, err := Fanout(context.Background(), st, sender, opts, now)
	if err != nil {
		t.Fatal(err)
	}
	if got.DistinctTokens != 2 || got.Sent != 0 || len(sender.sent) != 0 || len(st.actions) != 0 {
		t.Fatalf("got %+v sent=%v actions=%d", got, sender.sent, len(st.actions))
	}
}

func TestFanoutConfirmSendsAndPurgesPermanent(t *testing.T) {
	st := &fakeStore{tokens: []string{"good", "dead", "also-good"}}
	sender := &fakeSender{fail: map[string]error{
		"dead": &push.PermanentTokenError{Detail: "UNREGISTERED"},
	}}
	opts := Options{TargetBuild: 39, ConsultSite: true, Confirm: true}
	now := time.Date(2026, 8, 15, 12, 0, 0, 0, time.UTC)
	got, err := Fanout(context.Background(), st, sender, opts, now)
	if err != nil {
		t.Fatal(err)
	}
	if got.DistinctTokens != 3 || got.Sent != 2 || got.Failed != 1 || got.Purged != 2 {
		t.Fatalf("got %+v", got)
	}
	if len(st.deleted) != 1 || st.deleted[0] != "dead" {
		t.Fatalf("deleted %v", st.deleted)
	}
	if len(st.actions) != 1 {
		t.Fatalf("actions %d", len(st.actions))
	}
	if st.actions[0].Action != "operator_notice" || st.actions[0].Actor != "compartarenta-relay" {
		t.Fatalf("action %+v", st.actions[0])
	}
}

func TestFanoutConfirmRequiresSender(t *testing.T) {
	st := &fakeStore{tokens: []string{"a"}}
	_, err := Fanout(context.Background(), st, nil, Options{ConsultSite: true, Confirm: true}, time.Now())
	if err == nil {
		t.Fatal("expected error")
	}
}
