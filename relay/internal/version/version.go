// Package version exposes the schema version expected by this binary.
//
// The relay refuses to start when the persisted schema version does not
// equal `Expected`. Bump it whenever a new migration ships, in the same
// commit that ships the migration.
package version

// Expected is the schema version this binary requires. The relay refuses
// to start when the value persisted in the schema_version table differs.
//
// Bump together with a new migration file in `relay/migrations/`. The
// migration filename's leading 4-digit number IS the schema version.
const Expected = 4

// Build is overwritten via -ldflags at release time with the immutable
// container image digest the binary was built into. The value is exposed
// via the /healthz response so an auditor can compare it to the digest
// declared in the repository's deployment manifest
// (`relay-public-auditability` / "Each deployed version maps to a tagged
// release").
var Build = "dev"
