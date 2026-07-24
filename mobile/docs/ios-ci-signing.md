# iOS builds and signing from CI (requires macOS)

You **cannot** build iOS releases from Ubuntu. iOS release builds require Xcode and must run on **macOS**.

This repo is set up to:
- build Android on Ubuntu
- build iOS on a macOS CI runner (e.g., GitHub Actions `macos-latest`)

## Recommended CI approach

Use **Automatic signing** + **App Store Connect API key** (preferred) or a managed certificate/provisioning approach
such as Fastlane `match`.

### Option A (recommended): Automatic signing + App Store Connect API key

Prereqs in Apple Developer / App Store Connect:
- Create app entries for bundle IDs:
  - `app.incoherences.bojairu` (prod)
  - `app.incoherences.bojairu.staging` (staging)
  - `app.incoherences.bojairu.dev` (dev)
- Create an **App Store Connect API key** (Issuer ID, Key ID, and the `.p8` file)

CI secrets to add:
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_P8_BASE64` (base64 of the `.p8` content)

Your macOS workflow can decode the key to a file at runtime and use it for submission tooling.

### Option B: Fastlane match (teams with multiple developers)

Use Fastlane `match` with a private git repo or cloud storage to share certificates/profiles.

CI secrets to add:
- `MATCH_PASSWORD`
- credentials for the match storage backend
- optional App Store Connect API key (still useful)

## Bundle ID mapping in this repo

To support side-by-side installs and a simple 3-env mapping without Xcode schemes:
- **Debug** → `app.incoherences.bojairu.dev`
- **Profile** → `app.incoherences.bojairu.staging`
- **Release** → `app.incoherences.bojairu`

If you later want “dev/staging/prod” *all as Debug*, we can introduce explicit Xcode build configurations/schemes.
