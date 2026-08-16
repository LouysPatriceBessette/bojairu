package operatornotice

import (
	"context"
	"fmt"
	"io"
	"time"

	"github.com/compartarenta/relay/internal/config"
	"github.com/compartarenta/relay/internal/push"
	"github.com/compartarenta/relay/internal/store"
)

// RunCLI is the `relay operator-notice` entry: load env, connect to Postgres,
// optionally send. It does not bind HTTP listeners.
func RunCLI(ctx context.Context, args []string, stdout io.Writer) error {
	opts, err := ParseArgs(args)
	if err != nil {
		return err
	}

	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}

	connectCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	st, err := store.New(connectCtx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("store: %w", err)
	}
	defer st.Close()

	var sender Sender
	if opts.Confirm {
		if cfg.FCMServiceAccountJSONPath == "" {
			return fmt.Errorf("FCM_SERVICE_ACCOUNT_JSON_PATH is not set; operator-notice cannot send")
		}
		fcm, err := push.NewFCMFromServiceAccountJSON(cfg.FCMServiceAccountJSONPath)
		if err != nil {
			return fmt.Errorf("fcm init: %w", err)
		}
		sender = fcm
	}

	now := time.Now().UTC()
	result, err := Fanout(ctx, st, sender, opts, now)
	if err != nil {
		return err
	}

	if !opts.Confirm {
		fmt.Fprintf(stdout, "operator-notice dry-run: %d distinct FCM token(s)\n%s\nRe-run with --confirm to send.\n",
			result.DistinctTokens, opts.Summary())
		return nil
	}
	fmt.Fprintf(stdout, "operator-notice sent: %d ok, %d failed (%d distinct FCM token(s), %d purged)\n%s\n",
		result.Sent, result.Failed, result.DistinctTokens, result.Purged, opts.Summary())
	return nil
}
