import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../prefs/app_preferences.dart';
import '../sandbox/sandbox_bot_catalog.dart';
import 'qa_vehicle_seed_helpers.dart';
import 'web_dev_db_snapshot.dart';

/// Applies `--dart-define=CARDEV=true` seed: flush DB, Simulation catalog
/// contacts, and [qaSeedE2eVehicle]. Debug builds only.
Future<void> maybeApplyCarDevSeed(
  AppDatabase db, {
  required bool enabled,
}) async {
  if (!enabled || !kDebugMode) return;

  await clearDevOperationalTables(db);
  await _seedCarDevContacts(db);
  await qaSeedE2eVehicle(db);
  await _ensureCarDevOnboarding();
  await db.syncWebStorageToDisk();
  debugPrint('cardev seed: applied');
}

Future<void> _seedCarDevContacts(AppDatabase db) async {
  final now = DateTime.now().toUtc();
  for (var i = 0; i < SandboxBotCatalog.displayNames.length; i++) {
    final name = SandboxBotCatalog.displayNames[i];
    await db.upsertContact(
      ContactsCompanion.insert(
        id: 'contact:cardev:$name',
        kind: 'connected',
        displayName: name,
        avatarId: SandboxBotCatalog.avatarIdForCatalogIndex(i),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

Future<void> _ensureCarDevOnboarding() async {
  final prefs = await AppPreferences.load();
  await prefs.setProfileIdentity(
    displayName: 'Louys',
    avatarId: SandboxBotCatalog.avatarIdForCatalogIndex(0),
  );
  if (prefs.currency.isEmpty) {
    await prefs.setCurrency('CAD');
  }
  if (prefs.dateFormat.isEmpty) {
    await prefs.setDateFormat('yyyy-MM-dd');
  }
  if (prefs.languageCode == null || prefs.languageCode!.isEmpty) {
    await prefs.setLanguageCode('fr');
  }
  await prefs.completeOnboarding();
}
