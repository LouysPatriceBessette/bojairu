package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/compartarenta/entitlement/internal/api"
	"github.com/compartarenta/entitlement/internal/config"
	"github.com/compartarenta/entitlement/internal/license"
	"github.com/compartarenta/entitlement/internal/push"
	"github.com/compartarenta/entitlement/internal/store"
	"github.com/compartarenta/entitlement/internal/version"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	connectCtx, connectCancel := context.WithTimeout(ctx, 30*time.Second)
	defer connectCancel()
	st, err := store.New(connectCtx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("store: %w", err)
	}
	defer st.Close()

	srv := api.NewServer(cfg, st)
	if cfg.PlayServiceAccountJSONPath != "" {
		play, err := license.NewPlayFromServiceAccountJSON(cfg.PlayServiceAccountJSONPath, cfg.PlayPackageName)
		if err != nil {
			return fmt.Errorf("play verifier: %w", err)
		}
		srv.SetPlayVerifier(play)
	}
	if cfg.FCMServiceAccountJSONPath != "" {
		fcm, err := push.NewFCMFromServiceAccountJSON(
			cfg.FCMServiceAccountJSONPath,
		)
		if err != nil {
			return fmt.Errorf("FCM sender: %w", err)
		}
		srv.SetLicensePushSender(fcm)
	}
	server := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		fmt.Fprintf(os.Stdout, "entitlement listening on %s build=%s schema=%d\n",
			cfg.ListenAddr, version.Build, version.Expected)
		errCh <- server.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	}

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer shutdownCancel()
	return server.Shutdown(shutdownCtx)
}
