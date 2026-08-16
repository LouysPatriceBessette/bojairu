package store

import (
	"io/fs"
	"regexp"
	"strings"
	"testing"
)

// forbiddenColumnPatterns are substrings that, if found in any column
// name in the relay's schema, raise an audit-level red flag. The relay
// must never grow a column whose name suggests user-facing content.
//
// Required by `relay-state-schema-and-retention` /
// "The relay database SHALL NOT store user payload plaintext".
var forbiddenColumnPatterns = []string{
	"display_name",
	"displayname",
	"avatar",
	"email",
	"phone",
	"address",
	"first_name",
	"last_name",
	"real_name",
	"city",
	"postal",
	"description",
	"note", // singular; matches "note" and "notes"
	"comment",
	"plaintext",
	"clear_text",
	"cleartext",
	"amount",
	"price",
	"cost",
	"category",
	"ip_address",
	"client_ip",
	"user_agent",
}

// columnPattern extracts column name lines from CREATE TABLE bodies.
// Matches a leading identifier followed by whitespace and a type
// keyword. Lines starting with PRIMARY KEY / CHECK / CONSTRAINT are
// ignored.
var columnPattern = regexp.MustCompile(`(?m)^\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+(TEXT|VARCHAR|CHARACTER|BYTEA|INTEGER|BIGINT|SMALLINT|BOOLEAN|TIMESTAMPTZ|JSONB|JSON|BIGSERIAL|SERIAL)`)

func TestSchemaContainsNoUserPlaintextColumns(t *testing.T) {
	entries, err := fs.ReadDir(schemaFS, "schema")
	if err != nil {
		t.Fatalf("read schema dir: %v", err)
	}
	if len(entries) == 0 {
		t.Fatalf("expected at least one migration")
	}

	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".sql") {
			continue
		}
		raw, err := fs.ReadFile(schemaFS, "schema/"+e.Name())
		if err != nil {
			t.Fatalf("read %s: %v", e.Name(), err)
		}
		body := strings.ToLower(string(raw))
		for _, m := range columnPattern.FindAllStringSubmatch(string(raw), -1) {
			column := strings.ToLower(m[1])
			for _, bad := range forbiddenColumnPatterns {
				if strings.Contains(column, bad) {
					t.Errorf(
						"migration %s declares forbidden column %q (matches pattern %q); "+
							"the relay schema must not contain user-facing plaintext",
						e.Name(), column, bad)
				}
			}
		}
		// Belt-and-braces: also scan the raw text for the literal
		// substrings so a hand-written DDL outside the regex still trips.
		for _, bad := range forbiddenColumnPatterns {
			if strings.Contains(body, "\n  "+bad) || strings.Contains(body, "\n    "+bad) {
				t.Errorf(
					"migration %s appears to introduce a column starting with %q; "+
						"the relay schema must not contain user-facing plaintext",
					e.Name(), bad)
			}
		}
	}
}

func TestExactlyOnePayloadColumn(t *testing.T) {
	files := []string{"0001_init.sql", "0002_routing_push_tokens.sql"}
	for _, name := range files {
		raw, err := fs.ReadFile(schemaFS, "schema/"+name)
		if err != nil {
			t.Fatalf("read %s: %v", name, err)
		}
		bodyLower := strings.ToLower(string(raw))
		if name == "0001_init.sql" {
			if !strings.Contains(bodyLower, "ciphertext         bytea") {
				t.Errorf("envelopes.ciphertext must be declared BYTEA in %s", name)
			}
		}
		for _, bad := range []string{"payload", "blob", "data ", "content", "message"} {
			if strings.Contains(bodyLower, bad+" bytea") {
				t.Errorf("schema %s declares an unexpected payload-shaped BYTEA column matching %q", name, bad)
			}
		}
	}
}

func TestSchemaVersionRowIsAuthoritative(t *testing.T) {
	raw, err := fs.ReadFile(schemaFS, "schema/0001_init.sql")
	if err != nil {
		t.Fatalf("read 0001_init.sql: %v", err)
	}
	body := string(raw)
	if !strings.Contains(body, "CREATE TABLE schema_version") {
		t.Errorf("0001_init.sql must define the schema_version table")
	}
	if !strings.Contains(body, "INSERT INTO schema_version (id, version) VALUES (1, 1)") {
		t.Errorf("0001_init.sql must insert the initial schema_version row")
	}
}

func TestLoadMigrationsSortsByVersionPrefix(t *testing.T) {
	migs, err := loadMigrations(schemaFS)
	if err != nil {
		t.Fatalf("loadMigrations: %v", err)
	}
	if len(migs) == 0 {
		t.Fatalf("expected at least one migration")
	}
	for i := 1; i < len(migs); i++ {
		if migs[i].version <= migs[i-1].version {
			t.Errorf("migrations are not strictly increasing: %s -> %s",
				migs[i-1].name, migs[i].name)
		}
	}
	if migs[0].version != 1 {
		t.Errorf("first migration must be version 1, got %d", migs[0].version)
	}
	raw2, err := fs.ReadFile(schemaFS, "schema/0002_routing_push_tokens.sql")
	if err != nil {
		t.Fatalf("read 0002: %v", err)
	}
	if !strings.Contains(string(raw2), "UPDATE schema_version SET version = 2") {
		t.Errorf("0002 migration must bump schema_version to 2")
	}
	raw3, err := fs.ReadFile(schemaFS, "schema/0003_scheduled_notifications.sql")
	if err != nil {
		t.Fatalf("read 0003: %v", err)
	}
	if !strings.Contains(string(raw3), "UPDATE schema_version SET version = 3") {
		t.Errorf("0003 migration must bump schema_version to 3")
	}
	raw4, err := fs.ReadFile(schemaFS, "schema/0004_envelope_expiry_and_vehicle_deadline.sql")
	if err != nil {
		t.Fatalf("read 0004: %v", err)
	}
	if !strings.Contains(string(raw4), "UPDATE schema_version SET version = 4") {
		t.Errorf("0004 migration must bump schema_version to 4")
	}
}
