import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../relay/identity_keystore.dart';

/// Shell writes this marker under app documents; bootstrap exports identity then
/// deletes the marker. See `tool/run_db_snapshot_steal.sh`.
const kQaDbSnapshotExportMarkerFileName = 'compartarenta_qa_snapshot_export';

/// Written after a successful identity export for shell polling.
const kQaDbSnapshotExportDoneFileName = 'compartarenta_qa_snapshot_export_done';

/// Plaintext X25519 private key (base64url, no padding) for debug snapshot
/// restore after `pm clear` (EncryptedSharedPreferences cannot survive wipe).
const kQaDbSnapshotIdentityPrivateFileName =
    'compartarenta_qa_identity_private.b64';

/// Optional marker: when present with the identity file, restore runs even if
/// the identity file was left from a prior steal on the same install.
const kQaDbSnapshotRestoreMarkerFileName = 'compartarenta_qa_snapshot_restore';

/// Written after a successful identity restore for shell polling.
const kQaDbSnapshotRestoreDoneFileName = 'compartarenta_qa_snapshot_restore_done';

/// If the steal export marker is present, write the identity private key for
/// `adb run-as` pull. Does not touch Drift.
Future<void> maybeExportQaDbSnapshotIdentity() async {
  if (!_qaDbSnapshotPlatformOk) return;

  final docs = await _docsDirOrNull();
  if (docs == null) return;

  final marker = File('${docs.path}/$kQaDbSnapshotExportMarkerFileName');
  if (!await marker.exists()) return;

  try {
    await marker.delete();
  } catch (e) {
    debugPrint('qa db snapshot: could not delete export marker: $e');
  }

  try {
    final b64 = await IdentityKeystore.secureStorage()
        .exportPrivateKeyB64ForDev();
    if (b64 == null || b64.isEmpty) {
      debugPrint('qa db snapshot: identity export returned empty');
      return;
    }
    final identity = File(
      '${docs.path}/$kQaDbSnapshotIdentityPrivateFileName',
    );
    await identity.writeAsString(b64.trim());
    await File(
      '${docs.path}/$kQaDbSnapshotExportDoneFileName',
    ).writeAsString('ok\n');
    debugPrint('qa db snapshot: exported identity for steal');
  } catch (e, st) {
    debugPrint('qa db snapshot: identity export failed: $e\n$st');
  }
}

/// If a restore marker or identity file is present, restore the private key
/// into secure storage before any `loadOrCreatePrivateKey` in relay bootstrap.
Future<void> maybeRestoreQaDbSnapshotIdentity() async {
  if (!_qaDbSnapshotPlatformOk) return;

  final docs = await _docsDirOrNull();
  if (docs == null) return;

  final identity = File(
    '${docs.path}/$kQaDbSnapshotIdentityPrivateFileName',
  );
  final restoreMarker = File(
    '${docs.path}/$kQaDbSnapshotRestoreMarkerFileName',
  );
  final hasIdentity = await identity.exists();
  final hasRestoreMarker = await restoreMarker.exists();
  if (!hasIdentity) {
    if (hasRestoreMarker) {
      try {
        await restoreMarker.delete();
      } catch (_) {}
      debugPrint('qa db snapshot: restore marker without identity file');
    }
    return;
  }
  // Steal leaves the identity file on device; only restore when the shell
  // asked for it (restore marker), so a post-steal cold start does not
  // rewrite secure storage unnecessarily.
  if (!hasRestoreMarker) return;

  try {
    await restoreMarker.delete();
  } catch (e) {
    debugPrint('qa db snapshot: could not delete restore marker: $e');
  }

  try {
    final b64 = (await identity.readAsString()).trim();
    if (b64.isEmpty) {
      debugPrint('qa db snapshot: identity file empty');
      return;
    }
    await IdentityKeystore.secureStorage().restorePrivateKeyB64ForDev(b64);
    try {
      await identity.delete();
    } catch (e) {
      debugPrint('qa db snapshot: could not delete identity file: $e');
    }
    await File(
      '${docs.path}/$kQaDbSnapshotRestoreDoneFileName',
    ).writeAsString('ok\n');
    debugPrint('qa db snapshot: restored identity into secure storage');
  } catch (e, st) {
    debugPrint('qa db snapshot: identity restore failed: $e\n$st');
  }
}

bool get _qaDbSnapshotPlatformOk =>
    kDebugMode && !kIsWeb && Platform.isAndroid;

Future<Directory?> _docsDirOrNull() async {
  try {
    return await getApplicationDocumentsDirectory();
  } catch (e) {
    debugPrint('qa db snapshot: documents directory unavailable: $e');
    return null;
  }
}
