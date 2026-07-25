# Android signing (Play App Signing)

This project is set up for **Play App Signing**:

- Google Play holds the **app signing key** used to deliver to users.
- We keep and protect an **upload key** used to sign uploads (AAB).

## 1) Create an upload keystore (local)

From `mobile/`:

```bash
mkdir -p android/keystore
keytool -genkeypair \
  -v \
  -storetype JKS \
  -keystore android/keystore/upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

## 2) Create `android/key.properties`

Copy the example and fill it in:

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties` with your real passwords.

`storeFile` is resolved relative to `android/app/` (the Gradle app module). Use `../keystore/upload-keystore.jks` when the JKS lives under `android/keystore/` as above.

## 3) Build a signed release AAB

```bash
./tool/flutterw build appbundle --release --flavor prod -t lib/main.dart
```

The output should be in `build/app/outputs/bundle/prodRelease/`.

## Notes

- `android/key.properties` and `android/keystore/**` are ignored by `.gitignore` and must never be committed.
- For CI signing, use the same file format but populate it from your CI secret store (typically by decoding a base64 keystore into `android/keystore/upload-keystore.jks` at build time).

## Firebase API key

After creating the upload keystore, register its **SHA-1** (and the debug keystore SHA-1) as
**application restrictions** on the Firebase Android API key — see
[`firebase-android-api-key-application-restrictions.md`](firebase-android-api-key-application-restrictions.md).
(Google Cloud’s Android app restriction field uses SHA-1, not SHA-256.)

