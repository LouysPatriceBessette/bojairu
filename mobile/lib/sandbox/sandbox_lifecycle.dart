import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../db/db_reset.dart';
import '../housing/proposals/housing_proposal_transport_service.dart';
import '../portability/device_data_export_service.dart';
import '../portability/device_data_snapshot_codec.dart';
import '../prefs/app_preferences.dart';
import '../relay/handshake_orchestrator.dart';
import '../screens/housing/housing_module_entry_screen.dart';
import 'peer_simulator.dart';
import 'sandbox_mode.dart';
import 'sandbox_relay.dart';

/// Enter / exit simulation and dual-verified real-data checkpoint.
abstract final class SandboxLifecycle {
  static const checkpointFileName = 'sandbox_real_checkpoint.json';

  static Future<File> checkpointFile() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'sandbox'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, checkpointFileName));
  }

  /// True when Mode simulation entry is blocked (real draft or active plan).
  static Future<bool> hasBlockingRealHousingPlan([AppDatabase? db]) async {
    final database = db ?? AppDatabase.processScope;
    final withSelf = await housingPlansWithSelfParticipant(database);
    if (withSelf.isNotEmpty) return true;
    final transport = HousingProposalTransportService(database);
    for (final plan in await database.listPlans()) {
      if (plan.type != 'housing') continue;
      if (await transport.hasActiveRevision(plan.id)) return true;
    }
    return false;
  }

  static Future<bool> deviceHasPreservableOperationalData(
    AppDatabase db,
  ) async {
    final plans = await db.listPlans();
    if (plans.isNotEmpty) return true;
    final contacts = await db.select(db.contacts).get();
    return contacts.isNotEmpty;
  }

  /// Export → verify → fixed copy → verify. Returns false if either check fails.
  static Future<bool> writeDualVerifiedCheckpoint({
    required AppDatabase db,
    required String participantInstallationId,
  }) async {
    final export = DeviceDataExportService(db);
    final jsonText = await export.exportJsonString(
      participantInstallationId: participantInstallationId,
    );
    final decoded1 = jsonDecode(jsonText);
    if (decoded1 is! Map) return false;
    final bundle1 = Map<String, Object?>.from(decoded1);
    if (!await DeviceDataExportService.verifyChecksum(bundle1)) {
      return false;
    }

    final primaryPath = await _writeTempPrimaryCopy(jsonText);
    final primaryRead = await File(primaryPath).readAsString();
    final decodedPrimary = jsonDecode(primaryRead);
    if (decodedPrimary is! Map) return false;
    final bundlePrimary = Map<String, Object?>.from(decodedPrimary);
    if (!await DeviceDataExportService.verifyChecksum(bundlePrimary)) {
      return false;
    }

    final checkpoint = await checkpointFile();
    await checkpoint.writeAsString(jsonText, flush: true);
    final secondRead = await checkpoint.readAsString();
    final decoded2 = jsonDecode(secondRead);
    if (decoded2 is! Map) return false;
    final bundle2 = Map<String, Object?>.from(decoded2);
    if (!await DeviceDataExportService.verifyChecksum(bundle2)) {
      try {
        await checkpoint.delete();
      } catch (_) {}
      return false;
    }
    try {
      await File(primaryPath).delete();
    } catch (_) {}
    return true;
  }

  static Future<String> _writeTempPrimaryCopy(String jsonText) async {
    final support = await getApplicationSupportDirectory();
    final file = File(
      p.join(support.path, 'sandbox', 'sandbox_export_primary_tmp.json'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonText, flush: true);
    return file.path;
  }

  /// Prefs first, then optional checkpoint, wipe DB, clear orchestrator.
  /// Caller shows "reopen the app" UI.
  static Future<void> enterSimulation({
    required AppPreferences prefs,
    required AppDatabase db,
    required String participantInstallationId,
  }) async {
    final hasData = await deviceHasPreservableOperationalData(db);
    if (hasData) {
      final ok = await writeDualVerifiedCheckpoint(
        db: db,
        participantInstallationId: participantInstallationId,
      );
      if (!ok) {
        throw StateError('sandbox_checkpoint_verify_failed');
      }
    } else {
      final existing = await checkpointFile();
      if (await existing.exists()) {
        await existing.delete();
      }
    }

    await prefs.setSandboxEnteredAt(DateTime.now().toUtc());
    await prefs.setSandboxMode(true);
    await prefs.setSandboxInvitedBotCount(0);
    await prefs.setSandboxEightHourNudgeShownForEntryMs(null);
    await prefs.setSandboxShowHomeWelcome(true);

    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      await orch.releaseLocalDatabaseConnectionForDevReset();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
    }
    PeerSimulator.clearInstalled();
    SandboxRelay.clear();
    await DbReset.deleteLocalDbFiles(prefs: prefs);
  }

  static Future<bool> checkpointExistsAndValid() async {
    final file = await checkpointFile();
    if (!await file.exists()) return false;
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) return false;
      final bundle = Map<String, Object?>.from(decoded);
      return DeviceDataExportService.verifyChecksum(bundle);
    } catch (_) {
      return false;
    }
  }

  /// Wipe sim DB, optionally import checkpoint, clear sandbox prefs.
  static Future<void> exitSimulation({
    required AppPreferences prefs,
    required AppDatabase db,
  }) async {
    if (SandboxMode.lockedByBuild) return;

    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      await orch.releaseLocalDatabaseConnectionForDevReset();
      HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
    }
    PeerSimulator.clearInstalled();
    SandboxRelay.clear();
    await DbReset.deleteLocalDbFiles(prefs: prefs);

    final file = await checkpointFile();
    final hasCheckpoint = await file.exists();
    if (hasCheckpoint) {
      // Re-open a fresh process-scoped DB after wipe is the caller's job on
      // restart. Here we only clear flags; import runs after cold start when
      // sandboxMode is still true until we clear it — so clear AFTER importing
      // on the next process if needed.
      // Spec: wipe then import. Import requires a live AppDatabase. After wipe
      // the process DB handle is invalid; restart is required. Persist a
      // pending-import flag via leaving checkpoint in place and clearing
      // sandboxMode only after import on next real-mode boot.
    }

    // Mark that exit was requested: clear sandbox mode; leave checkpoint for
    // [maybeRestoreCheckpointOnRealBoot].
    await prefs.setSandboxMode(false);
    await prefs.setSandboxEnteredAt(null);
    await prefs.setSandboxInvitedBotCount(0);
    await prefs.setSandboxEightHourNudgeShownForEntryMs(null);
    await prefs.setSandboxShowHomeWelcome(false);
  }

  /// After cold start in real mode, import checkpoint if present.
  static Future<void> maybeRestoreCheckpointOnRealBoot({
    required AppPreferences prefs,
    required AppDatabase db,
  }) async {
    if (SandboxMode.isActive(prefs)) return;
    final file = await checkpointFile();
    if (!await file.exists()) return;
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw StateError('checkpoint not a map');
      }
      final bundle = Map<String, Object?>.from(decoded);
      if (!await DeviceDataExportService.verifyChecksum(bundle)) {
        throw StateError('checkpoint checksum mismatch');
      }
      final tables = bundle['tables'];
      if (tables is! Map) {
        throw StateError('checkpoint missing tables');
      }
      await importDeviceDataTables(
        db,
        Map<String, dynamic>.from(tables),
      );
      await db.syncWebStorageToDisk();
      await file.delete();
      debugPrint('SandboxLifecycle: restored real checkpoint after exit');
    } catch (e, st) {
      debugPrint('SandboxLifecycle: checkpoint restore failed: $e\n$st');
    }
  }
}
