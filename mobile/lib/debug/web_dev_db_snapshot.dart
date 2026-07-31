import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';

export 'web_dev_host_session_format.dart';

/// Storage keys for every Drift table in [AppDatabase] (keep in sync with
/// `@DriftDatabase.tables` in `app_database.dart`).
const List<String> kWebDevHostDriftTableKeys = [
  'plans',
  'participants',
  'planLines',
  'planGroups',
  'planRatios',
  'planRatioTemplates',
  'agreements',
  'proposalPackages',
  'proposalRevisions',
  'proposalResponses',
  'contacts',
  'contactInvitations',
  'pendingHandshakes',
  'relayActivityLogEntries',
  'realizedExpenses',
  'realizedExpenseAttachments',
  'realizedExpenseAcceptances',
  'archivedPlanLineSnapshots',
];

/// Row counts per table key (debug logging / tests).
Future<Map<String, int>> countDevHostDriftTables(AppDatabase db) async {
  return {
    'plans': (await db.select(db.plans).get()).length,
    'participants': (await db.select(db.participants).get()).length,
    'planLines': (await db.select(db.planLines).get()).length,
    'planGroups': (await db.select(db.planGroups).get()).length,
    'planRatios': (await db.select(db.planRatios).get()).length,
    'planRatioTemplates': (await db.select(db.planRatioTemplates).get()).length,
    'agreements': (await db.select(db.agreements).get()).length,
    'proposalPackages': (await db.select(db.proposalPackages).get()).length,
    'proposalRevisions': (await db.select(db.proposalRevisions).get()).length,
    'proposalResponses': (await db.select(db.proposalResponses).get()).length,
    'contacts': (await db.select(db.contacts).get()).length,
    'contactInvitations': (await db.select(db.contactInvitations).get()).length,
    'pendingHandshakes': (await db.select(db.pendingHandshakes).get()).length,
    'relayActivityLogEntries':
        (await db.select(db.relayActivityLogEntries).get()).length,
    'realizedExpenses': (await db.select(db.realizedExpenses).get()).length,
    'realizedExpenseAttachments':
        (await db.select(db.realizedExpenseAttachments).get()).length,
    'realizedExpenseAcceptances':
        (await db.select(db.realizedExpenseAcceptances).get()).length,
    'archivedPlanLineSnapshots':
        (await db.select(db.archivedPlanLineSnapshots).get()).length,
  };
}

Future<Map<String, dynamic>> exportDriftTablesSnapshot(AppDatabase db) async {
  final tables = <String, dynamic>{};
  for (final key in kWebDevHostDriftTableKeys) {
    tables[key] = await _exportTable(db, key);
  }
  return tables;
}

Future<List<Map<String, dynamic>>> _exportTable(
  AppDatabase db,
  String key,
) async {
  switch (key) {
    case 'plans':
      return (await db.select(db.plans).get()).map((r) => r.toJson()).toList();
    case 'participants':
      return (await db.select(db.participants).get())
          .map((r) => r.toJson())
          .toList();
    case 'planLines':
      return (await db.select(db.planLines).get())
          .map((r) => r.toJson())
          .toList();
    case 'planGroups':
      return (await db.select(db.planGroups).get())
          .map((r) => r.toJson())
          .toList();
    case 'planRatios':
      return (await db.select(db.planRatios).get())
          .map((r) => r.toJson())
          .toList();
    case 'planRatioTemplates':
      return (await db.select(db.planRatioTemplates).get())
          .map((r) => r.toJson())
          .toList();
    case 'agreements':
      return (await db.select(db.agreements).get())
          .map((r) => r.toJson())
          .toList();
    case 'proposalPackages':
      return (await db.select(db.proposalPackages).get())
          .map((r) => r.toJson())
          .toList();
    case 'proposalRevisions':
      return (await db.select(db.proposalRevisions).get())
          .map((r) => r.toJson())
          .toList();
    case 'proposalResponses':
      return (await db.select(db.proposalResponses).get())
          .map((r) => r.toJson())
          .toList();
    case 'contacts':
      return (await db.select(db.contacts).get())
          .map((r) => r.toJson())
          .toList();
    case 'contactInvitations':
      return (await db.select(db.contactInvitations).get())
          .map((r) => r.toJson())
          .toList();
    case 'pendingHandshakes':
      return (await db.select(db.pendingHandshakes).get())
          .map((r) => r.toJson())
          .toList();
    case 'relayActivityLogEntries':
      return (await db.select(db.relayActivityLogEntries).get())
          .map((r) => r.toJson())
          .toList();
    case 'realizedExpenses':
      return (await db.select(db.realizedExpenses).get())
          .map((r) => r.toJson())
          .toList();
    case 'realizedExpenseAttachments':
      return (await db.select(db.realizedExpenseAttachments).get())
          .map((r) => r.toJson())
          .toList();
    case 'realizedExpenseAcceptances':
      return (await db.select(db.realizedExpenseAcceptances).get())
          .map((r) => r.toJson())
          .toList();
    case 'archivedPlanLineSnapshots':
      return (await db.select(db.archivedPlanLineSnapshots).get())
          .map((r) => r.toJson())
          .toList();
    default:
      throw StateError('Unknown dev host table key: $key');
  }
}

Future<void> importDriftTablesSnapshot(
  AppDatabase db,
  Map<String, dynamic> tables,
) async {
  if (!kDebugMode) return;

  await db.transaction(() async {
    await _clearAllDevTables(db);
    await _importRows(db, tables);
  });
  await db.syncWebStorageToDisk();
}

/// Wipes operational Drift tables (debug / QA seeding only).
Future<void> clearDevOperationalTables(AppDatabase db) async {
  if (!kDebugMode) return;
  await db.transaction(() async {
    await _clearAllDevTables(db);
  });
  await db.syncWebStorageToDisk();
}

Future<void> _clearAllDevTables(AppDatabase db) async {
  await db.delete(db.realizedExpenseAcceptances).go();
  await db.delete(db.realizedExpenseAttachments).go();
  await db.delete(db.realizedExpenses).go();
  await db.delete(db.archivedPlanLineSnapshots).go();
  await db.delete(db.relayActivityLogEntries).go();
  await db.delete(db.proposalResponses).go();
  await db.delete(db.proposalRevisions).go();
  await db.delete(db.proposalPackages).go();
  await db.delete(db.agreements).go();
  await db.delete(db.planRatios).go();
  await db.delete(db.planGroups).go();
  await db.delete(db.planLines).go();
  await db.delete(db.planRatioTemplates).go();
  await db.delete(db.participants).go();
  await db.delete(db.plans).go();
  await db.delete(db.housingParticipationDecisions).go();
  await db.delete(db.housingParticipationChanges).go();
  await db.delete(db.housingPlanMemberships).go();
  await db.delete(db.housingInactiveParticipants).go();
  await db.delete(db.housingPaymentOverdueJournalEntries).go();
  await db.delete(db.planPeerEstablishments).go();
  await db.delete(db.vehicleGalleryPhotos).go();
  await db.delete(db.vehiclePhotoGalleries).go();
  await db.delete(db.vehicleSharingLinks).go();
  await db.delete(db.vehicleOdometerGaps).go();
  await db.delete(db.vehicleConsumptionEstimateHistory).go();
  await db.delete(db.fuelPurchases).go();
  await db.delete(db.maintenanceEvents).go();
  await db.delete(db.trafficViolations).go();
  await db.delete(db.vehicleMaintenanceRules).go();
  await db.delete(db.vehicleUses).go();
  await db.delete(db.vehicleMeterReadings).go();
  await db.delete(db.vehicles).go();
  await db.delete(db.pendingHandshakes).go();
  await db.delete(db.contactInvitations).go();
  await db.delete(db.contacts).go();
}

Future<void> _importRows(AppDatabase db, Map<String, dynamic> tables) async {
  for (final key in kWebDevHostDriftTableKeys) {
    await _importTableKey(db, key, tables[key]);
  }
}

Future<void> _importTableKey(
  AppDatabase db,
  String key,
  Object? rawList,
) async {
  switch (key) {
    case 'plans':
      return _importTable(db, db.plans, rawList, Plan.fromJson);
    case 'participants':
      return _importTable(db, db.participants, rawList, Participant.fromJson);
    case 'planLines':
      return _importTable(db, db.planLines, rawList, PlanLine.fromJson);
    case 'planGroups':
      return _importTable(db, db.planGroups, rawList, PlanGroup.fromJson);
    case 'planRatios':
      return _importTable(db, db.planRatios, rawList, PlanRatio.fromJson);
    case 'planRatioTemplates':
      return _importTable(
        db,
        db.planRatioTemplates,
        rawList,
        PlanRatioTemplate.fromJson,
      );
    case 'agreements':
      return _importTable(db, db.agreements, rawList, Agreement.fromJson);
    case 'proposalPackages':
      return _importTable(
        db,
        db.proposalPackages,
        rawList,
        ProposalPackage.fromJson,
      );
    case 'proposalRevisions':
      return _importTable(
        db,
        db.proposalRevisions,
        rawList,
        ProposalRevision.fromJson,
      );
    case 'proposalResponses':
      return _importTable(
        db,
        db.proposalResponses,
        rawList,
        ProposalResponse.fromJson,
      );
    case 'contacts':
      return _importTable(db, db.contacts, rawList, Contact.fromJson);
    case 'contactInvitations':
      return _importTable(
        db,
        db.contactInvitations,
        rawList,
        ContactInvitation.fromJson,
      );
    case 'pendingHandshakes':
      return _importTable(
        db,
        db.pendingHandshakes,
        rawList,
        PendingHandshake.fromJson,
      );
    case 'relayActivityLogEntries':
      return _importTable(
        db,
        db.relayActivityLogEntries,
        rawList,
        RelayActivityLogEntry.fromJson,
      );
    case 'realizedExpenses':
      return _importTable(
        db,
        db.realizedExpenses,
        rawList,
        RealizedExpense.fromJson,
      );
    case 'realizedExpenseAttachments':
      return _importTable(
        db,
        db.realizedExpenseAttachments,
        rawList,
        RealizedExpenseAttachment.fromJson,
      );
    case 'realizedExpenseAcceptances':
      return _importTable(
        db,
        db.realizedExpenseAcceptances,
        rawList,
        RealizedExpenseAcceptance.fromJson,
      );
    case 'archivedPlanLineSnapshots':
      return _importTable(
        db,
        db.archivedPlanLineSnapshots,
        rawList,
        ArchivedPlanLineSnapshot.fromJson,
      );
    default:
      throw StateError('Unknown dev host table key: $key');
  }
}

Future<void> _importTable(
  AppDatabase db,
  TableInfo<Table, DataClass> table,
  Object? rawList,
  DataClass Function(Map<String, dynamic> json) fromJson,
) async {
  if (rawList is! List<dynamic>) return;
  for (final entry in rawList) {
    if (entry is! Map<String, dynamic>) continue;
    final row = fromJson(entry);
    final insertable =
        (row as dynamic).toCompanion(true) as Insertable<DataClass>;
    await db.into(table).insertOnConflictUpdate(insertable);
  }
}
