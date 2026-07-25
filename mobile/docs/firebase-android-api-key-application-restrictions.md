# Firebase Android API key — application restrictions

**Purpose:** Before widening Play closed testers beyond the core developer, restrict the
Firebase **Android** API key so it only works for Bojairũ package names signed with known
certificates. Client keys are committed in `mobile/android/app/google-services.json` and
`mobile/lib/firebase_options.dart` on the public repo.

**Related:** OpenSpec `mobile-app-store-release` task **10.2.1**; closed-test plan item **A2**;
[`android-signing-play-app-signing.md`](android-signing-play-app-signing.md).

**Project:** Google Cloud / Firebase `bojairu`  
**Credentials UI:** [APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials?project=bojairu)

API restrictions (Firebase-only allowlist, ~25 APIs) are already configured. This document
covers the **application restrictions** panel only.

## Packages to allow

| `applicationId` | Flavor |
| --- | --- |
| `app.incoherences.bojairu` | prod |
| `app.incoherences.bojairu.dev` | dev |
| `app.incoherences.bojairu.staging` | staging |

All three Android clients in `google-services.json` share the same Android API key.

## SHA-1 certificates to register

Google Cloud **application restrictions** for Android apps require the **SHA-1** certificate
fingerprint (not SHA-256). Register **both** fingerprints below for **each** package (six
entries, or three packages × two SHA-1 values — follow the Console UI).

| Certificate | Typical use | SHA-1 (local machine, 2026-07-25) |
| --- | --- | --- |
| Debug (`~/.android/debug.keystore`, alias `androiddebugkey`) | `run:dev` / debug APK | `58:E1:BD:B9:4C:24:20:DB:AF:DC:1B:BA:53:E7:3B:32:8B:92:5B:BA` |
| Upload / release (`android/keystore/upload-keystore.jks`, alias `upload`) | prod release AAB/APK; Play **upload** key | `E3:6E:F2:E7:EC:67:DC:6C:88:31:11:E2:B1:83:98:C2:ED:BC:E7:E1` |

Re-print fingerprints before pasting into the Console (paths from `mobile/`):

```bash
# Debug
keytool -list -v -keystore ~/.android/debug.keystore \
  -storepass android -alias androiddebugkey | grep SHA1

# Upload (uses gitignored android/key.properties — do not commit or paste passwords)
STORE_PASS=$(grep '^storePassword=' android/key.properties | cut -d= -f2-)
keytool -list -v -keystore android/keystore/upload-keystore.jks \
  -storepass "$STORE_PASS" -alias upload | grep SHA1
unset STORE_PASS
```

### Play App Signing certificate (after first Play upload)

Google Play may re-sign installs with an **App Signing** key different from the upload key.
After the first AAB is enrolled in Play App Signing (closed-test plan **B3** / **B5**):

1. Play Console → App integrity → App signing → copy **SHA-1** (for this API-key panel).
2. Add that fingerprint for package `app.incoherences.bojairu` (and any flavor you distribute
   via Play) on the same API key.

Until that upload exists, debug + upload fingerprints are enough to lock the key to local
and sideloaded release builds.

## Console steps

1. Open [Credentials for project `bojairu`](https://console.cloud.google.com/apis/credentials?project=bojairu).
2. Open the key named **Android key (auto created by Firebase)** (same key as in
   `google-services.json` — do not confuse with a browser / iOS key).
3. You will first see **API restrictions** (“APIs this key can call” / FR: *API accessibles…*)
   with ~25 Firebase APIs — that block is already correct; leave it alone.
4. Find **Application restrictions** (FR: *Restrictions relatives aux applications*). On the
   redesigned Credentials page this block is often **below** the long API list — **scroll
   down** past “Selected APIs”. It is a separate radio group: None / HTTP referrers / IP /
   **Android apps** / iOS apps. It is **not** inside the “25 API” dropdown.
5. Choose **Android apps** (FR: *Applications Android*).
6. For each package name above, add an entry with the **debug** SHA-1 and another with the
   **upload** SHA-1 (or both SHA-1 values per package if the UI allows).
7. Save. Propagation can take a few minutes.

## Process gate (closed testing)

Do **not** invite unknown closed testers until application restrictions are saved and a
smoke check passes (app still initializes Firebase / FCM on a **prod release** install and on
a **dev** build if you use it).

## Smoke check after save

1. Cold-start prod release APK/AAB install (`app.incoherences.bojairu`) — no Firebase API-key /
   App Check failures in logcat related to the restricted key.
2. Cold-start a debug/dev build (`app.incoherences.bojairu.dev`) if used in daily QA.
3. If either fails with API-key / permission errors, verify package name + SHA-1 match the
   installed signing cert (`keytool -list -v` / Play App Signing SHA-1).

## Out of scope here

- iOS API key application restrictions (iOS key still placeholder in `firebase_options.dart`;
  defer until iOS beta).
- Rotating or regenerating the Android API key (see Firebase Console if compromise is
  suspected).
- Relay or entitlement configuration.
