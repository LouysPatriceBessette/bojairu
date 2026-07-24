# Bojairũ Mobile (Flutter)

This is the Flutter app workspace for the `mobile-app-store-release` change.

## Tooling

This repo vendors a Flutter SDK in `../tools/flutter/` to avoid requiring a system install.

## Run (dev)

From the repository root (Melos):

```bash
dart run melos run run:dev
```

Optional device: `dart run melos run run:dev -- -d <deviceId>`

Reuse an existing `app-dev-debug.apk` without rebuilding (Android only), e.g.
after `./tool/melosw run qa:build-apk -- --simulation`:

```bash
./tool/melosw run run:dev -- --skip-build
./tool/melosw run run:dev -- --skip-build --fresh   # wipe app data
```

Web: `dart run melos run run:dev:web` (host session server at `http://localhost:18765`,
JSON at `~/.cache/compartarenta/web-dev-session.json` — use `localhost`, not `127.0.0.1`,
so the browser can save from `http://localhost:5001`). Ctrl+C safe.

The `mobile/tool/run_dev.sh` script is what Melos invokes; you normally do not
need to call it directly.

### Android: `MissingPluginException` at startup

If the app shows **Startup failed** with `MissingPluginException` for
`shared_preferences` or `path_provider`, the native plugins were not registered
(often after restarting the dev process without a full app reinstall on device).

1. Stop **every** Melos / `flutter run` terminal (`Ctrl+C`).
2. Rebuild and reinstall (usually enough; no `flutter clean` required):

```bash
dart run melos run run:dev
```

3. Wait until the terminal finishes **Installing…** before opening the app from
   the launcher. Do not open the app from the icon while an old process is still
   attached.

4. If the error persists: `dart run melos run clean`, then `get`, `codegen`,
   `web:assets`, and `run:dev` again. Prefer uninstalling “Bojairũ (Dev)”
   manually (Android Settings → Apps) if `--uninstall-first` did not run.

`run_dev.sh` passes `--uninstall-first` on mobile targets so reinstall clears
stale native plugins when an Android device is selected.

### Web data across melos restarts

Use `dart run melos run run:dev:web` (default app URL port **5001**). Session data
is written to `~/.cache/compartarenta/web-dev-session.json` by a loopback HTTP
server started with the script. You can stop with Ctrl+C anytime and relaunch;
the next run restores prefs, identity, and the full Drift snapshot from that file.

The dev web script passes `--no-web-resources-cdn` so CanvasKit is served from
the local Flutter dev server instead of `gstatic.com` (avoids startup failures
on slow or flaky networks).

Reset web dev data: `dart run melos run delete:web-dev-session`

Port busy: `run:dev:web` auto-picks the next free port (18766, 18767, …) when
18765 is held by an unkillable sandbox process (`sudo fuser` may still fail —
that is normal). Pin a port: `WEB_DEV_SESSION_PORT=18770 dart run melos run run:dev:web`.
Stop your server: `dart run melos run stop:web-dev-session`. Each `run:dev:web`
restarts the session server so it matches the app (stale servers reject new
session versions — look for `PUT failed … FormatException: version` in logs).

Check logs for `web_dev_host_session: saved to host tables={...}` after any Drift
write (debounced) or tab hide, and `web_dev_host_session: restored from host`
on the next `local_storage_checkpoint: reason=startup`. Every Drift table is
included (realized expenses, proposal revisions, relay log, archived line
snapshots, etc.). A stable identity avoids duplicate handshake contacts on Android.

`flutter clean` / `refresh` do not delete the host JSON (it lives under
`~/.cache/compartarenta/`). `melos run web:assets` only refreshes `sqlite3.wasm`
and `drift_worker.dart.js` after a `drift` / `sqlite3` bump.

# compartarenta

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
