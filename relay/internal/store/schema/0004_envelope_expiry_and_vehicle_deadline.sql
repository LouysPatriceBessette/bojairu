-- 0004: vehicle sharing decision-deadline domain + comment on envelope
-- retention. Envelope delivery cutoff stays in ttl_expires_at; the API
-- now sets that instant from plaintext expires_at (or 7 days when omitted).

BEGIN;

UPDATE schema_version SET version = 4, applied_at = now() WHERE id = 1;

ALTER TABLE scheduled_notification_targets
  DROP CONSTRAINT IF EXISTS scheduled_notification_targets_domain_check;

ALTER TABLE scheduled_notification_targets
  ADD CONSTRAINT scheduled_notification_targets_domain_check
  CHECK (domain IN (
    'housing_payment',
    'housing_proposal_deadline',
    'contacts_invitation_expiry',
    'vehicle_sharing_deadline'
  ));

COMMIT;
