package operatornotice

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/compartarenta/relay/internal/push"
	"github.com/compartarenta/relay/internal/store"
)

// TokenStore is the relay persistence used by the operator-notice CLI.
type TokenStore interface {
	ListDistinctActiveFCMTokens(ctx context.Context, now time.Time) ([]string, error)
	DeleteRoutingPushTokensByProviderToken(ctx context.Context, provider, pushToken string) (int64, error)
	RecordOperatorAction(ctx context.Context, action store.OperatorAction) error
}

// Sender posts one operator_notice FCM data message.
type Sender interface {
	SendOperatorNoticeClassify(ctx context.Context, deviceToken, targetBuild string, consultSite bool) error
}

// Result is the fan-out outcome (no device tokens are included).
type Result struct {
	DistinctTokens int
	Sent           int
	Failed         int
	Purged         int
}

// Fanout lists distinct non-expired FCM tokens and, when confirm is set,
// sends operator_notice. Android / FCM only — APNs is not used.
func Fanout(ctx context.Context, st TokenStore, sender Sender, opts Options, now time.Time) (Result, error) {
	tokens, err := st.ListDistinctActiveFCMTokens(ctx, now)
	if err != nil {
		return Result{}, fmt.Errorf("list fcm tokens: %w", err)
	}
	out := Result{DistinctTokens: len(tokens)}
	if !opts.Confirm {
		return out, nil
	}
	if sender == nil {
		return out, errors.New("FCM sender is not configured")
	}
	target := opts.TargetBuildString()
	for _, token := range tokens {
		err := sender.SendOperatorNoticeClassify(ctx, token, target, opts.ConsultSite)
		if err == nil {
			out.Sent++
			continue
		}
		out.Failed++
		var perm *push.PermanentTokenError
		if errors.As(err, &perm) {
			n, delErr := st.DeleteRoutingPushTokensByProviderToken(ctx, "fcm", token)
			if delErr == nil {
				out.Purged += int(n)
			}
		}
	}
	reason := fmt.Sprintf("%s tokens=%d sent=%d failed=%d purged=%d",
		opts.Summary(), out.DistinctTokens, out.Sent, out.Failed, out.Purged)
	_ = st.RecordOperatorAction(ctx, store.OperatorAction{
		OccurredAt: now,
		Actor:      "compartarenta-relay",
		Action:     "operator_notice",
		Reason:     reason,
	})
	return out, nil
}
