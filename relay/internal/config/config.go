// Package config loads the relay's runtime configuration from environment
// variables. Secrets are never embedded in source or in the container
// image; they are sourced at runtime from an explicit secret store
// (`relay-security-baseline` / "Secrets are managed by an explicit secret
// store"). This package therefore never defaults a secret to a non-empty
// value.
package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config is the relay's loaded configuration.
type Config struct {
	// PublicListenAddr is the address:port the relay protocol binds to.
	// The reverse proxy in front of the relay terminates TLS and forwards
	// here on a private network. Default: 0.0.0.0:8080.
	PublicListenAddr string

	// PrivateListenAddr serves /metrics and any future inspection
	// endpoints. MUST be bound to a private network only; the deployment
	// manifest does not publish this port to the public internet
	// (`relay-observability-without-plaintext` / "The metrics endpoint is
	// not publicly reachable"). Default: 127.0.0.1:9090.
	PrivateListenAddr string

	// DatabaseURL is the libpq-style DSN for the PostgreSQL instance.
	// Required; no default. Loaded from the env at runtime.
	DatabaseURL string

	// EnvelopeMaxBytes caps the ciphertext size of a single envelope.
	// Oversize requests are rejected before any state is written
	// (`relay-security-baseline` / "The relay applies a documented size
	// limit per envelope"). Default: 65536 bytes (64 KiB).
	EnvelopeMaxBytes int

	// EnvelopeTTLMax is the retention cap for envelopes with no product
	// expiry (default 7 days). EnvelopeTTLMin is retained for env parsing
	// compatibility; dated envelopes use the client-supplied expires_at
	// instant and are not raised to this minimum.
	EnvelopeTTLMin time.Duration
	EnvelopeTTLMax time.Duration

	// IdempotencyTTL is the lifetime of an idempotency entry. Hours, not
	// weeks. Default: 24h.
	IdempotencyTTL time.Duration

	// DisconnectGrace is how long a relationship row stays in the
	// `disconnecting` state to allow in-flight envelopes to flush before
	// the row is deleted. Default: 5 minutes.
	DisconnectGrace time.Duration

	// RoutingInactivityTTL is the long-inactivity window after which a
	// routing relationship is pruned. The minimum window is set by the
	// spec; the operator picks a concrete value at or above the minimum.
	// Default: 26 weeks (~6 months).
	RoutingInactivityTTL time.Duration

	// SweeperInterval is how often the sweeper task runs. Default: 1m.
	SweeperInterval time.Duration

	// RateLimitPerIdentity is the per-opaque-identity submission rate.
	// Token bucket of size 4*Rate, refill at Rate tokens/sec. Default: 5.
	RateLimitPerIdentity float64

	// RateLimitPerIP is the per-source-IP submission rate. Default: 20.
	RateLimitPerIP float64

	// ShutdownTimeout caps the time the relay waits for in-flight
	// requests to complete on SIGTERM/SIGINT. Default: 30s.
	ShutdownTimeout time.Duration

	// CORSAllowedOrigins is the explicit allow-list of browser origins
	// authorised to issue cross-origin XHR / fetch requests against the
	// public protocol endpoints. Each value is matched verbatim against
	// the request's `Origin` header (scheme + host + optional port).
	// The special value `*` allows any origin (intended for development
	// only — browsers reject `*` for requests that send credentials).
	// Loaded from the env var `CORS_ALLOWED_ORIGINS` (comma-separated).
	// Default: empty (no CORS headers are emitted; browser callers are
	// blocked).
	CORSAllowedOrigins []string

	// WakePushDispatchEnabled gates best-effort FCM/APNs wake dispatch after
	// envelope persistence. Default: false (no third-party push calls).
	WakePushDispatchEnabled bool

	// FCMServiceAccountJSONPath is the filesystem path to the Firebase
	// service account JSON used for FCM HTTP v1. Empty disables FCM sends.
	FCMServiceAccountJSONPath string

	// APNsAuthKeyPath is the filesystem path to the Apple .p8 key.
	// Remaining APNs fields are required when this path is non-empty.
	APNsAuthKeyPath      string
	APNsKeyID            string
	APNsTeamID           string
	APNsBundleID         string
	APNsEnvironment      string // "sandbox" or "production"
	APNsGenericAlertBody string // optional non-personalized alert for iOS

	// RoutingPushTokenTTL is the server-side lifetime applied on each
	// successful registration refresh. Default: 336h (14 days).
	RoutingPushTokenTTL time.Duration

	// StatsListenAddr is the loopback-only HTTP bind address for the daily
	// statistics endpoint. Default: 127.0.0.1:9091. Set to "-" to disable
	// the stats listener entirely.
	StatsListenAddr string

	// ReminderCronEnabled gates the scheduled-notification fire dispatcher.
	// Default: false.
	ReminderCronEnabled bool

	// ReminderCronInterval is how often due fires are claimed. Default: 1m.
	ReminderCronInterval time.Duration

	// EntitlementEnabled gates housing envelope kinds via the entitlement
	// service when true and EntitlementIntrospectURL is set.
	EntitlementEnabled bool

	// EntitlementIntrospectURL is the base URL of the entitlement service
	// (e.g. http://entitlement:8080). Empty disables introspection calls.
	EntitlementIntrospectURL string

	// EntitlementInternalToken is sent as Bearer auth to the entitlement
	// introspection endpoint when non-empty.
	EntitlementInternalToken string
}

// Load reads configuration from environment variables. Errors are
// aggregated so the operator sees every problem at once.
func Load() (Config, error) {
	var errs []error
	routingTTLSeconds := intEnv(&errs, "ROUTING_PUSH_TOKEN_TTL_SECONDS", 1209600)
	c := Config{
		PublicListenAddr:          env("PUBLIC_LISTEN_ADDR", "0.0.0.0:8080"),
		PrivateListenAddr:         env("PRIVATE_LISTEN_ADDR", "127.0.0.1:9090"),
		DatabaseURL:               os.Getenv("DATABASE_URL"),
		EnvelopeMaxBytes:          intEnv(&errs, "ENVELOPE_MAX_BYTES", 65536),
		EnvelopeTTLMin:            durEnv(&errs, "ENVELOPE_TTL_MIN", 24*time.Hour),
		EnvelopeTTLMax:            durEnv(&errs, "ENVELOPE_TTL_MAX", 168*time.Hour),
		IdempotencyTTL:            durEnv(&errs, "IDEMPOTENCY_TTL", 24*time.Hour),
		DisconnectGrace:           durEnv(&errs, "DISCONNECT_GRACE", 5*time.Minute),
		RoutingInactivityTTL:      durEnv(&errs, "ROUTING_INACTIVITY_TTL", 26*7*24*time.Hour),
		SweeperInterval:           durEnv(&errs, "SWEEPER_INTERVAL", time.Minute),
		RateLimitPerIdentity:      floatEnv(&errs, "RATE_LIMIT_PER_IDENTITY", 5),
		RateLimitPerIP:            floatEnv(&errs, "RATE_LIMIT_PER_IP", 20),
		ShutdownTimeout:           durEnv(&errs, "SHUTDOWN_TIMEOUT", 30*time.Second),
		CORSAllowedOrigins:        listEnv("CORS_ALLOWED_ORIGINS"),
		WakePushDispatchEnabled:   boolEnv(&errs, "WAKE_PUSH_DISPATCH_ENABLED", false),
		FCMServiceAccountJSONPath: strings.TrimSpace(os.Getenv("FCM_SERVICE_ACCOUNT_JSON_PATH")),
		APNsAuthKeyPath:           strings.TrimSpace(os.Getenv("APNS_AUTH_KEY_PATH")),
		APNsKeyID:                 strings.TrimSpace(os.Getenv("APNS_KEY_ID")),
		APNsTeamID:                strings.TrimSpace(os.Getenv("APNS_TEAM_ID")),
		APNsBundleID:              strings.TrimSpace(os.Getenv("APNS_BUNDLE_ID")),
		APNsEnvironment:           strings.TrimSpace(env("APNS_ENVIRONMENT", "production")),
		APNsGenericAlertBody:      strings.TrimSpace(os.Getenv("APNS_GENERIC_ALERT_BODY")),
		RoutingPushTokenTTL:       time.Duration(routingTTLSeconds) * time.Second,
		StatsListenAddr:           env("STATS_LISTEN_ADDR", "127.0.0.1:9091"),
		ReminderCronEnabled:       boolEnv(&errs, "REMINDER_CRON_ENABLED", false),
		ReminderCronInterval:      durEnv(&errs, "REMINDER_CRON_INTERVAL", time.Minute),
		EntitlementEnabled:        boolEnv(&errs, "ENTITLEMENT_ENABLED", false),
		EntitlementIntrospectURL:  strings.TrimSpace(os.Getenv("ENTITLEMENT_INTROSPECT_URL")),
		EntitlementInternalToken:  strings.TrimSpace(os.Getenv("ENTITLEMENT_INTERNAL_TOKEN")),
	}
	if c.EntitlementEnabled && c.EntitlementIntrospectURL == "" {
		errs = append(errs, errors.New("ENTITLEMENT_ENABLED requires ENTITLEMENT_INTROSPECT_URL"))
	}
	if c.DatabaseURL == "" {
		errs = append(errs, errors.New("DATABASE_URL is required and must come from an explicit secret store (not committed)"))
	}
	if c.EnvelopeTTLMin <= 0 || c.EnvelopeTTLMax <= 0 || c.EnvelopeTTLMin > c.EnvelopeTTLMax {
		errs = append(errs, fmt.Errorf("ENVELOPE_TTL_MIN (%s) and ENVELOPE_TTL_MAX (%s) must be > 0 and MIN <= MAX",
			c.EnvelopeTTLMin, c.EnvelopeTTLMax))
	}
	if c.EnvelopeTTLMax > 30*24*time.Hour {
		errs = append(errs, fmt.Errorf("ENVELOPE_TTL_MAX (%s) exceeds the spec's conservative ceiling (~30 days); reduce it",
			c.EnvelopeTTLMax))
	}
	if c.IdempotencyTTL > 7*24*time.Hour {
		errs = append(errs, fmt.Errorf("IDEMPOTENCY_TTL (%s) exceeds the spec's conservative ceiling (~7 days); reduce it",
			c.IdempotencyTTL))
	}
	if c.EnvelopeMaxBytes <= 0 || c.EnvelopeMaxBytes > 1<<20 {
		errs = append(errs, fmt.Errorf("ENVELOPE_MAX_BYTES (%d) must be in (0, 1 MiB]", c.EnvelopeMaxBytes))
	}
	if c.RoutingPushTokenTTL < 24*time.Hour || c.RoutingPushTokenTTL > 90*24*time.Hour {
		errs = append(errs, fmt.Errorf("ROUTING_PUSH_TOKEN_TTL_SECONDS must be between 86400 and 7776000 (1–90 days); got %s",
			c.RoutingPushTokenTTL))
	}
	if c.APNsAuthKeyPath != "" {
		if c.APNsKeyID == "" || c.APNsTeamID == "" || c.APNsBundleID == "" {
			errs = append(errs, errors.New("when APNS_AUTH_KEY_PATH is set, APNS_KEY_ID, APNS_TEAM_ID, and APNS_BUNDLE_ID are required"))
		}
	}
	if len(errs) > 0 {
		return c, errors.Join(errs...)
	}
	return c, nil
}

func env(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return v
	}
	return def
}

func intEnv(errs *[]error, key string, def int) int {
	raw, ok := os.LookupEnv(key)
	if !ok || strings.TrimSpace(raw) == "" {
		return def
	}
	n, err := strconv.Atoi(strings.TrimSpace(raw))
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s: invalid integer: %w", key, err))
		return def
	}
	return n
}

func boolEnv(errs *[]error, key string, def bool) bool {
	raw, ok := os.LookupEnv(key)
	if !ok || strings.TrimSpace(raw) == "" {
		return def
	}
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "1", "true", "yes", "y", "on":
		return true
	case "0", "false", "no", "n", "off":
		return false
	default:
		*errs = append(*errs, fmt.Errorf("%s: expected a boolean (true/false/1/0)", key))
		return def
	}
}

func floatEnv(errs *[]error, key string, def float64) float64 {
	raw, ok := os.LookupEnv(key)
	if !ok || strings.TrimSpace(raw) == "" {
		return def
	}
	v, err := strconv.ParseFloat(strings.TrimSpace(raw), 64)
	if err != nil {
		*errs = append(*errs, fmt.Errorf("%s: invalid float: %w", key, err))
		return def
	}
	return v
}

func listEnv(key string) []string {
	raw, ok := os.LookupEnv(key)
	if !ok {
		return nil
	}
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		s := strings.TrimSpace(p)
		if s == "" {
			continue
		}
		out = append(out, s)
	}
	if len(out) == 0 {
		return nil
	}
	return out
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
