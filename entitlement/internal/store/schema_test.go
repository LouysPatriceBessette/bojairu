package store

import (
	"strings"
	"testing"
	"time"
)

func TestFreeLicenseMigrationShape(t *testing.T) {
	raw, err := schemaFS.ReadFile("schema/0003_free_licenses.sql")
	if err != nil {
		t.Fatal(err)
	}
	body := string(raw)
	for _, required := range []string{
		"free_user_name",
		"free_license_granted_at",
		"free_license_expires_at",
		"push_provider",
		"push_token",
		"UPDATE schema_version SET version = 3",
	} {
		if !strings.Contains(body, required) {
			t.Errorf("migration missing %q", required)
		}
	}
}

func TestPaidReceiptBlocksFreeLicense(t *testing.T) {
	now := time.Date(2026, 9, 1, 12, 0, 0, 0, time.UTC)
	future := now.Add(24 * time.Hour)
	past := now.Add(-24 * time.Hour)

	if !paidReceiptBlocksFreeLicense(
		"SUBSCRIPTION_STATE_ACTIVE",
		&future,
		now,
	) {
		t.Fatal("active non-expired Play subscription must block SET")
	}
	if paidReceiptBlocksFreeLicense(
		"SUBSCRIPTION_STATE_CANCELED",
		&future,
		now,
	) {
		t.Fatal("canceled Play subscription must allow SET")
	}
	if paidReceiptBlocksFreeLicense(
		"SUBSCRIPTION_STATE_ACTIVE",
		&past,
		now,
	) {
		t.Fatal("expired Play subscription must allow SET")
	}
}
