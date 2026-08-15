-- Entitlement schema v2: Play receipt identity, expiry, and granted modules.

ALTER TABLE license_receipts
  ADD COLUMN IF NOT EXISTS product_id TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS purchase_token TEXT,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS validated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS granted_modules TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS subscription_state TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS license_receipts_platform_token
  ON license_receipts (platform, purchase_token)
  WHERE purchase_token IS NOT NULL AND purchase_token <> '';

UPDATE schema_version SET version = 2 WHERE id = 1;
