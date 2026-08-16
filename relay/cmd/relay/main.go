// Command relay is the Compartarenta relay server entry point.
//
// Subcommands (do not bind listeners):
//   - operator-notice: VPS-only FCM fan-out of kind operator_notice.
//
// The process binds listeners:
//   - PublicListenAddr: the relay protocol + /healthz + /readyz.
//   - PrivateListenAddr: /metrics. The deployment manifest does not
//     publish this port to the public internet.
//   - StatsListenAddr (default 127.0.0.1:9091): GET /internal/stats/daily
//     loopback-only daily aggregates. Set STATS_LISTEN_ADDR=- to disable.
//
// On startup the relay:
//  1. Loads configuration from env vars (no secrets in source).
//  2. Connects to PostgreSQL and applies any pending migrations.
//  3. Verifies the on-disk schema version matches the binary's expected
//     version; otherwise it refuses to start
//     (`relay-state-schema-and-retention` /
//     "Schema migrations are versioned and reviewable").
//  4. Starts the periodic sweeper that enforces TTL-based deletion.
//  5. Serves HTTP until SIGTERM/SIGINT, then drains in-flight requests
//     up to ShutdownTimeout.
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

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/compartarenta/relay/internal/api"
	"github.com/compartarenta/relay/internal/config"
	"github.com/compartarenta/relay/internal/logging"
	"github.com/compartarenta/relay/internal/metrics"
	"github.com/compartarenta/relay/internal/operatornotice"
	"github.com/compartarenta/relay/internal/push"
	"github.com/compartarenta/relay/internal/remindercron"
	"github.com/compartarenta/relay/internal/stats"
	"github.com/compartarenta/relay/internal/store"
	"github.com/compartarenta/relay/internal/sweeper"
	"github.com/compartarenta/relay/internal/version"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "operator-notice" {
		ctx, cancel := signal.NotifyContext(context.Background(),
			os.Interrupt, syscall.SIGTERM)
		defer cancel()
		if err := operatornotice.RunCLI(ctx, os.Args[2:], os.Stdout); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	logger := logging.New()
	ctx, cancel := signal.NotifyContext(context.Background(),
		os.Interrupt, syscall.SIGTERM)
	defer cancel()

	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}

	connectCtx, connectCancel := context.WithTimeout(ctx, 30*time.Second)
	defer connectCancel()
	st, err := store.New(connectCtx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("store: %w", err)
	}
	defer st.Close()

	logger.Info(ctx, "relay.start",
		logging.F(logging.KeyBuild, version.Build),
		logging.F(logging.KeySchemaVersion, version.Expected),
	)

	var wake *push.Dispatcher
	if cfg.WakePushDispatchEnabled {
		var fcm *push.FCMDataWake
		if cfg.FCMServiceAccountJSONPath != "" {
			fcm, err = push.NewFCMFromServiceAccountJSON(cfg.FCMServiceAccountJSONPath)
			if err != nil {
				logger.Warn(ctx, "push.fcm_init_failed",
					logging.F(logging.KeyError, err.Error()),
				)
				fcm = nil
			}
		}
		var apnsSender *push.APNsWake
		if cfg.APNsAuthKeyPath != "" {
			apnsSender, err = push.NewAPNsFromKeyFile(
				cfg.APNsAuthKeyPath,
				cfg.APNsKeyID,
				cfg.APNsTeamID,
				cfg.APNsBundleID,
				cfg.APNsEnvironment,
				cfg.APNsGenericAlertBody,
			)
			if err != nil {
				logger.Warn(ctx, "push.apns_init_failed",
					logging.F(logging.KeyError, err.Error()),
				)
				apnsSender = nil
			}
		}
		wake = push.NewDispatcher(st, logger, fcm, apnsSender)
	}

	srv := api.NewServer(cfg, st, logger, wake)
	sw := sweeper.New(cfg, st, logger)
	go sw.Loop(ctx)
	rc := remindercron.New(cfg, st, logger, wake)
	go rc.Loop(ctx)

	publicServer := &http.Server{
		Addr:              cfg.PublicListenAddr,
		Handler:           srv.PublicHandler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	privateMux := http.NewServeMux()
	privateMux.Handle("/metrics", promhttp.HandlerFor(metrics.Registry(),
		promhttp.HandlerOpts{}))
	privateServer := &http.Server{
		Addr:              cfg.PrivateListenAddr,
		Handler:           privateMux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
	}

	var statsServer *http.Server
	if cfg.StatsListenAddr != "" && cfg.StatsListenAddr != "-" {
		statsMux := http.NewServeMux()
		statsMux.Handle("/internal/stats/daily", stats.Handler(st, time.Now))
		statsServer = &http.Server{
			Addr:              cfg.StatsListenAddr,
			Handler:           statsMux,
			ReadHeaderTimeout: 5 * time.Second,
			ReadTimeout:       15 * time.Second,
			WriteTimeout:      30 * time.Second,
		}
	}

	errCh := make(chan error, 3)
	go func() {
		logger.Info(ctx, "listener.public",
			logging.F(logging.KeyAddr, publicServer.Addr))
		errCh <- publicServer.ListenAndServe()
	}()
	go func() {
		logger.Info(ctx, "listener.private",
			logging.F(logging.KeyAddr, privateServer.Addr))
		errCh <- privateServer.ListenAndServe()
	}()
	if statsServer != nil {
		go func() {
			logger.Info(ctx, "listener.stats",
				logging.F(logging.KeyAddr, statsServer.Addr))
			errCh <- statsServer.ListenAndServe()
		}()
	}

	select {
	case <-ctx.Done():
		logger.Info(ctx, "relay.shutdown_signal")
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			logger.Error(ctx, "listener.failed",
				logging.F(logging.KeyError, err.Error()))
		}
	}

	shutdownCtx, shutdownCancel := context.WithTimeout(
		context.Background(), cfg.ShutdownTimeout)
	defer shutdownCancel()
	_ = publicServer.Shutdown(shutdownCtx)
	_ = privateServer.Shutdown(shutdownCtx)
	if statsServer != nil {
		_ = statsServer.Shutdown(shutdownCtx)
	}
	return nil
}
