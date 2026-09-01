package config

import (
	"errors"
	"fmt"
	"os"
	"strings"
	"time"
)

type Config struct {
	ListenAddr                 string
	DatabaseURL                string
	ShutdownTimeout            time.Duration
	TrialDuration              time.Duration
	GraceDuration              time.Duration
	InternalToken              string
	IDMinLen                   int
	IDMaxLen                   int
	PlayPackageName            string
	PlayServiceAccountJSONPath string
	FCMServiceAccountJSONPath  string
}

func Load() (Config, error) {
	var errs []error
	c := Config{
		ListenAddr:                 env("LISTEN_ADDR", "0.0.0.0:8080"),
		DatabaseURL:                strings.TrimSpace(os.Getenv("DATABASE_URL")),
		ShutdownTimeout:            durEnv(&errs, "SHUTDOWN_TIMEOUT", 30*time.Second),
		TrialDuration:              durEnv(&errs, "TRIAL_DURATION", 14*24*time.Hour),
		GraceDuration:              durEnv(&errs, "GRACE_DURATION", 7*24*time.Hour),
		InternalToken:              strings.TrimSpace(os.Getenv("ENTITLEMENT_INTERNAL_TOKEN")),
		IDMinLen:                   8,
		IDMaxLen:                   64,
		PlayPackageName:            env("PLAY_PACKAGE_NAME", "app.incoherences.bojairu"),
		PlayServiceAccountJSONPath: strings.TrimSpace(os.Getenv("PLAY_SERVICE_ACCOUNT_JSON_PATH")),
		FCMServiceAccountJSONPath:  strings.TrimSpace(os.Getenv("FCM_SERVICE_ACCOUNT_JSON_PATH")),
	}
	if c.DatabaseURL == "" {
		errs = append(errs, errors.New("DATABASE_URL is required"))
	}
	if len(errs) > 0 {
		return c, errors.Join(errs...)
	}
	return c, nil
}

func env(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return strings.TrimSpace(v)
	}
	return def
}

func durEnv(errs *[]error, key string, def time.Duration) time.Duration {
	raw, ok := os.LookupEnv(key)
	if !ok || strings.TrimSpace(raw) == "" {
		return def
	}
	d, err := time.ParseDuration(strings.TrimSpace(raw))
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s: invalid duration: %w", key, err))
		return def
	}
	return d
}
