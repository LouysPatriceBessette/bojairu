## 1. Project setup

- [x] 1.1 Create mobile app workspace (Flutter) under the repo
- [x] 1.2 Define dev/staging/prod build profiles and configuration source of truth
- [x] 1.3 Add base navigation shell and placeholder screens (Home, Settings)
- [x] 1.4 Add in-app version/build display in Settings

## 2. Environment separation

- [x] 2.1 Configure distinct Android applicationId per environment (dev/staging/prod)
- [x] 2.2 Configure distinct iOS bundle identifier per environment (dev/staging/prod)
- [x] 2.3 Wire runtime config (API base URL, flags) per environment profile
- [x] 2.4 Verify staging and production can be installed side-by-side on a device

## 3. Quality, stability, and error handling

- [x] 3.1 Add global error boundary / safe fallback UI for unexpected errors
- [x] 3.2 Add crash/error reporting provider (e.g., Sentry) with environment tagging
- [x] 3.3 Implement standard loading and empty states for network-backed screens
- [x] 3.4 Implement offline detection and safe retry behavior for user-visible actions

## 4. Signing and provisioning

- [x] 4.1 Create Android keystore/upload key strategy compatible with Play App Signing
- [x] 4.2 Configure Android signing in build pipeline without committing secrets
- [x] 4.3 Set up iOS App ID(s), certificates, and provisioning workflow compatible with CI
- [x] 4.4 Document credential rotation/revocation steps for Android and iOS signing

## 5. CI/CD build pipeline

- [x] 5.1 Add CI workflow to build Android artifacts for dev/staging/prod with provenance metadata
- [x] 5.2 Add CI workflow to build iOS artifacts for dev/staging/prod with provenance metadata
- [x] 5.3 Add CI gate checks (lint/tests/build) required before any production submission step
- [ ] 5.4 Add beta distribution pipeline steps (Play internal testing + TestFlight)

## 6. Store metadata and assets

- [x] 6.1 Define repository structure for store metadata (text, support links, privacy policy link)
- [ ] 6.2 Create required icon set and validate platform-specific constraints
- [x] 6.3 Create screenshot plan (screen list, device sizes) and generate initial screenshots
- [x] 6.4 Define localization approach (single locale vs multi-locale) and apply to listing metadata

## 7. Google Play release process

- [ ] 7.1 Configure Play Console app entry and required app details
- [ ] 7.2 Configure internal testing track and tester access; verify distribution works
- [ ] 7.3 Complete Play declarations required for submission (content rating, target API, data safety)
- [ ] 7.4 Define staged rollout plan and validate halt/pause procedure

## 8. Apple App Store release process

- [ ] 8.1 Configure App Store Connect app entry and required app details
- [ ] 8.2 Configure TestFlight groups and verify beta distribution works
- [ ] 8.3 Prepare App Review notes (including test account credentials if applicable)
- [ ] 8.4 Define phased release / controlled release plan and mitigation steps (remove from sale/hotfix)

## 9. Privacy and compliance readiness

- [x] 9.1.1 Publish privacy policy on the marketing site and link it from in-app Settings. *(Live at `compartarenta.incoherences.org`; locale-aware URL via `product_legal_urls.dart` — Jul 2026.)*
- [ ] 9.1.2 Set privacy policy URL on the **Google Play** store listing. *(Repo metadata `mobile/store/listing/*/privacy_policy_url.txt` ready; Play Console entry pending — near-term.)*
- [ ] 9.1.3 Set privacy policy URL on the **App Store** listing. *(Deferred for this initial release — iOS store submission later.)*
- [ ] 9.2 Create a data inventory for app + third-party SDKs (collection, sharing, retention)
- [ ] 9.3 Populate Apple privacy labels and Play data safety disclosures from the data inventory
- [ ] 9.4 Add any required consent flows (only if app behavior requires consent)

## 10. Release gates and final validation

- [x] 10.1 Create a pre-submission checklist aligned to the specs (assets, metadata, disclosures, quality gates)
- [ ] 10.2 Run end-to-end release rehearsal to produce store-ready artifacts for both platforms
- [x] 10.2.1 Apply Google Cloud **application restrictions** on the Firebase **Android** API key before any beta with external/unknown testers. **Done 2026-07-25:** packages `app.incoherences.bojairu` / `.dev` / `.staging` × debug + upload **SHA-1** (6 Android-app rows) on `Android key (auto created by Firebase)` (project `bojairu`); API restrictions already Firebase-only (~25). Ops doc: `mobile/docs/firebase-android-api-key-application-restrictions.md`. Add **Play App Signing** SHA-1 after first Play upload (B5). **iOS** API key application restrictions remain **open** (placeholder key in `firebase_options.dart`; deferred until iOS beta / TestFlight).
- [ ] 10.3 Perform beta validation and resolve any high-severity issues before production submission
- [ ] 10.4 Submit to both stores and track review outcomes; iterate on any rejection feedback

## 11. Relay invite page and public store listings

After the app has **public** Play Store and App Store listing URLs, update the
relay-hosted contact invitation page (`relay/deploy/landing/contact/invite/`)
so the store badge images link to those listings. That change ships with the
**relay** static site / vhost and therefore requires a **relay release and
security audit** in addition to the mobile store publication work.

- [ ] 11.1 Add `href` targets on the Play and App Store badges on
      `relay/deploy/landing/contact/invite/` using the canonical public listing
      URLs; verify links open correctly on mobile browsers. Coordinate relay
      deploy + audit with operators.

