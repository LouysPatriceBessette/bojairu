-- Entitlement schema v3: operator-granted all-module licenses and device push.

ALTER TABLE installations
  ADD COLUMN IF NOT EXISTS free_user_name TEXT,
  ADD COLUMN IF NOT EXISTS free_license_granted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS free_license_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS push_provider TEXT,
  ADD COLUMN IF NOT EXISTS push_token TEXT,
  ADD COLUMN IF NOT EXISTS push_token_updated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS installations_free_user_name
  ON installations (free_user_name)
  WHERE free_user_name IS NOT NULL;

UPDATE schema_version SET version = 3 WHERE id = 1;
