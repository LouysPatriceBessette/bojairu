import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'db_paths.dart';
import 'vehicle_tables.dart';
import '../debug/web_dev_db_write_observer.dart';

part 'app_database.g.dart';

/// Debug web: called after [syncWebStorageToDisk] to push host session backup.
typedef DebugWebDbFlushHook = void Function(AppDatabase db);
DebugWebDbFlushHook? debugWebDbFlushHook;

class PlanLines extends Table {
  TextColumn get id => text()(); // stable id
  TextColumn get planId => text()();

  // For housing: recurring fixed vs one-off estimate.
  BoolColumn get isRecurring => boolean()();

  // Free-text label, e.g. Rent / Electricity / Internet.
  TextColumn get title => text()();

  // Currency code (ISO 4217), should match plan currency.
  TextColumn get currency => text()();

  // Amounts stored as integer minor units (e.g., cents).
  /// When false: [amountMinor] is the fixed amount (per month if recurring, total if one-off).
  /// When true: [minAmountMinor] / [maxAmountMinor] define an approximate band (both types).
  BoolColumn get amountUsesRange =>
      boolean().withDefault(const Constant(false))();

  IntColumn get amountMinor => integer().nullable()();
  IntColumn get minAmountMinor => integer().nullable()();
  IntColumn get maxAmountMinor => integer().nullable()();

  /// Optional longer description for the expense.
  TextColumn get description => text().withDefault(const Constant(''))();

  // Cadence for recurring items (initially monthly only).
  TextColumn get cadence => text().withDefault(const Constant('monthly'))();

  /// Day of month (1–31) when a monthly recurring charge applies.
  IntColumn get recurrenceDayOfMonth => integer().nullable()();

  /// Display order within the plan (lower first).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  // Optional group bucket (legacy; unified expense flow does not set this).
  TextColumn get groupId => text().nullable()();

  /// When true, [amountMinor] is a budget ceiling (high estimate), not a fixed amount.
  BoolColumn get amountIsBudgetCap =>
      boolean().withDefault(const Constant(false))();

  /// Nullable; null means all participants (notification routing deferred).
  TextColumn get paymentResponsibleParticipantId => text().nullable()();

  /// JSON recurrence spec (see `ExpenseRecurrenceSpec`).
  TextColumn get recurrenceSpecJson => text().withDefault(const Constant(''))();

  /// Optional link to a ratio template used at save (UI aid only).
  TextColumn get ratioTemplateId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PlanRatioTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  TextColumn get displayTitle => text()();

  /// JSON map participantId -> weight basis points (sum 10000).
  TextColumn get weightsJson => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PlanGroups extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  TextColumn get title => text()();

  /// Optional guidance for what expenses belong in this category.
  TextColumn get description => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PlanRatios extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  TextColumn get participantId => text()();

  // Either applies to a line or a group. Exactly one should be set.
  TextColumn get lineId => text().nullable()();
  TextColumn get groupId => text().nullable()();

  // Weight, e.g. out of 10000 (basis points), or arbitrary weights.
  IntColumn get weight => integer()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Agreement')
class Agreements extends Table {
  @override
  String get tableName => 'agreement_contracts';

  TextColumn get id => text()();
  TextColumn get planId => text()();

  // Period bounds for the arrangement.
  DateTimeColumn get periodStart => dateTime()();
  DateTimeColumn get periodEnd => dateTime()();

  // Early withdrawal minimum floor.
  IntColumn get minNoticeDays => integer().withDefault(const Constant(0))();
  IntColumn get penaltyMinor => integer().withDefault(const Constant(0))();

  // Optional flexible clauses (bounded length in UI).
  TextColumn get clauses => text().withDefault(const Constant(''))();

  /// When false: JSON map per participant id -> { minNoticeDays, penaltyMinor }.
  TextColumn get withdrawalSameForAll =>
      text().withDefault(const Constant('true'))();

  TextColumn get withdrawalPerParticipantJson =>
      text().withDefault(const Constant('{}'))();

  /// Structured agreement rules (curfew, toggles, custom rules, dismissed suggestions).
  TextColumn get agreementRulesJson =>
      text().withDefault(const Constant('{}'))();

  // Versioning for renegotiation later.
  IntColumn get version => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Plans extends Table {
  TextColumn get id => text()(); // stable id (UUID/ULID later)
  TextColumn get type => text()(); // e.g. housing | car
  TextColumn get title => text().withDefault(const Constant(''))();

  // Added in schema v2 to demonstrate a forward-only migration.
  TextColumn get notes => text().nullable()();

  // Default currency for the plan context.
  TextColumn get currency => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Participants extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get avatarId => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Reference to the authoritative identity in [Contacts]. Nullable for
  /// legacy rows that existed before the Contacts module shipped. The
  /// `displayName` and `avatarId` columns on this row act as the historical
  /// display snapshot if the referenced Contact is later deleted.
  TextColumn get contactId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Identity record for a person the local user knows.
///
/// A Contact is either `local-only` (no relay routing material; cannot
/// receive module proposals) or `connected` (has the routing identifier
/// and public key material populated and may receive proposals).
class Contacts extends Table {
  TextColumn get id => text()();

  /// `local-only` | `connected` | `archived`.
  TextColumn get kind => text()();

  TextColumn get displayName => text()();
  TextColumn get avatarId => text()();

  /// Free-text notes the local user keeps about this contact.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Local-only flag. When true, inbound envelopes from this contact are
  /// dropped on receipt regardless of their kind.
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();

  /// Opaque relay routing identifier exchanged during the handshake.
  /// Populated only when kind = connected.
  TextColumn get relayRoutingId => text().nullable()();

  /// Peer public key material (base64 or similar) exchanged during the
  /// handshake. Populated only when kind = connected.
  TextColumn get peerPublicMaterial => text().nullable()();

  /// Optional label **only on this device** for how the user wants this
  /// contact to appear in lists. When null or empty, [displayName] is the
  /// effective name (peer canonical / stub name).
  TextColumn get localDisplayLabel => text().nullable()();

  /// How **this contact** currently labels the **local user** on their
  /// device, learned from encrypted steady-state profile updates. Null when
  /// unknown or never shared.
  TextColumn get theirLabelForMe => text().nullable()();

  /// Opaque device-binding hash reported by the peer during handshake.
  TextColumn get peerDeviceBindingId => text().nullable()();

  /// Set when a previously `connected` contact was demoted after disconnect.
  /// Null for stubs that were never connected.
  DateTimeColumn get disconnectedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// When the Contact was logically deleted by the local user.
  /// Module participant rows that referenced this contact continue to render
  /// from their stored snapshot (`Participants.displayName` / `avatarId`).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per outstanding outgoing invitation code.
class ContactInvitations extends Table {
  /// Stable identifier; not the human-readable code.
  TextColumn get id => text()();

  /// Opaque local copy of the nonce embedded in the invitation code.
  /// Consumed when a matching `hello` envelope is validated locally.
  TextColumn get nonce => text()();

  /// `pending` | `used` | `expired` | `revoked`.
  TextColumn get status => text()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  /// Set when the invitation has been consumed (used/revoked/expired).
  DateTimeColumn get consumedAt => dateTime().nullable()();

  /// When the handshake completes, points to the Contact stub on this
  /// device that should be promoted to `connected`.
  TextColumn get contactStubId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per in-flight Contacts handshake on this device. Created on
/// both sides:
///
/// * On the **inviter** side, immediately after generating a code and
///   pre-registering the handshake routing on the relay.
/// * On the **invitee** side, immediately after the invitee taps "Send
///   request" in the redeem screen and the hello envelope is being
///   dispatched.
///
/// Rows are removed (or marked `completed` / `rejected` / `failed`) once
/// the handshake reaches a terminal state. The orchestrator inspects
/// non-terminal rows on app start, and periodically while the app is in
/// the foreground, to drive the polling loop.
class PendingHandshakes extends Table {
  /// `${invitationIdHex}:${role}` — uniquely identifies a row even if
  /// the same user happens to generate AND receive a code with the same
  /// invitation id (collision probability ≈ 1/2^64).
  TextColumn get id => text()();

  /// Hex of the 8-byte invitation id.
  TextColumn get invitationIdHex => text()();

  /// Hex of the 12-byte invitation nonce. Stored on both sides so the
  /// orchestrator does not need to re-derive it from the code on every
  /// envelope decryption.
  TextColumn get nonceHex => text()();

  /// `inviter` (we generated the code) | `invitee` (we received it).
  TextColumn get role => text()();

  /// Lifecycle. `awaiting_hello`, `dispatching_hello`, and `awaiting_ack` are
  /// the polling states; the rest are terminal.
  ///   * inviter: `awaiting_hello` → `accepted`|`rejected` → `completed`
  ///   * invitee: `dispatching_hello` → `awaiting_ack` → `completed`|`rejected`
  ///   * either:  `failed` on unrecoverable error (e.g., expired code).
  TextColumn get state => text()();

  /// Local Contact id to promote on success. On the inviter side this is
  /// the stub created when the code was generated. On the invitee side
  /// it is the stub created when the hello was dispatched.
  TextColumn get contactStubId => text()();

  /// Filled when the peer's long-term X25519 public key is known. For
  /// the inviter, after the hello is decrypted. For the invitee, after
  /// the ack is decrypted.
  TextColumn get peerLongTermPublicMaterialB64 => text().nullable()();

  /// Self-reported display name from the peer (informational; the local
  /// Contact's displayName is the authoritative one).
  TextColumn get peerDisplayName => text().withDefault(const Constant(''))();

  /// Self-reported avatar id from the peer.
  TextColumn get peerAvatarId => text().withDefault(const Constant(''))();

  /// Device-binding hash from the peer's hello or ack.
  TextColumn get peerDeviceBindingId =>
      text().withDefault(const Constant(''))();

  /// Last error code captured by the orchestrator (for diagnostics).
  /// Empty string when no error.
  TextColumn get lastErrorCode => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProposalPackages extends Table {
  TextColumn get id => text()(); // stable id
  TextColumn get planId => text()();

  // Active revision becomes binding only after unanimous acceptance.
  TextColumn get activeRevisionId => text().nullable()();

  // Current pending revision (if any).
  TextColumn get pendingRevisionId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProposalRevisions extends Table {
  TextColumn get id => text()(); // unique per revision
  TextColumn get packageId => text()();
  TextColumn get contentHash => text()(); // normalized content hash string
  TextColumn get proposerParticipantId => text()();

  // Self-contained proposal payload (JSON string for now).
  TextColumn get payloadJson => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProposalResponses extends Table {
  TextColumn get id => text()();
  TextColumn get revisionId => text()();
  TextColumn get participantId => text()();

  // 'pending' | 'accepted' | 'rejected'
  TextColumn get status => text()();

  DateTimeColumn get respondedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only audit log of relay-related events on this device.
class RelayActivityLogEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get kind => text()();
  TextColumn get initiatorKind => text()();
  TextColumn get initiatorContactId => text().nullable()();
  TextColumn get initiatorDisplayName =>
      text().withDefault(const Constant(''))();
  TextColumn get planId => text().nullable()();
  TextColumn get packageId => text().nullable()();
  TextColumn get revisionId => text().nullable()();
  TextColumn get detailsJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A realized (actual) payment recorded against an active housing agreement.
class RealizedExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get packageId => text()();
  TextColumn get planId => text()();
  TextColumn get planLineId => text()();

  /// `draft` | `proposed` | `accepted` | `published` | `rejected`
  TextColumn get status => text()();

  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  DateTimeColumn get paymentDate => dateTime()();
  TextColumn get payerParticipantId => text()();

  /// `normal` | `reimbursement` | `advance` | `transfer`
  TextColumn get kind => text()();
  TextColumn get beneficiaryParticipantId => text().nullable()();
  TextColumn get description => text().nullable()();

  /// Prior proposal when this row is a resubmit (pass 3+).
  TextColumn get priorExpenseId => text().nullable()();

  /// Frozen plan line title when the live line is removed from the plan.
  TextColumn get planLineTitleSnapshot => text().nullable()();

  /// JSON array of `{participantId, weight}` basis points at proposal time.
  TextColumn get splitRatiosJson => text().nullable()();

  /// Amount of this payment deferred to the next month on the payment-status chart.
  IntColumn get paymentChartCarryForwardMinor =>
      integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Split ratios and title preserved when a plan line is removed.
class ArchivedPlanLineSnapshots extends Table {
  TextColumn get planId => text()();
  TextColumn get lineId => text()();
  TextColumn get title => text()();
  TextColumn get splitRatiosJson => text()();
  DateTimeColumn get archivedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {planId, lineId};
}

class RealizedExpenseAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get expenseId => text()();
  TextColumn get filePath => text()();
  TextColumn get displayFileName => text()();
  TextColumn get contentHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-participant review of a realized expense (unanimous acceptance).
class RealizedExpenseAcceptances extends Table {
  TextColumn get expenseId => text()();
  TextColumn get participantId => text()();

  /// `pending` | `accepted` | `rejected`
  TextColumn get decision => text()();
  TextColumn get rejectionJustification => text().nullable()();
  DateTimeColumn get decidedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {expenseId, participantId};
}

/// Participation change request (voluntary withdrawal, ejection).
class HousingParticipationChanges extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  TextColumn get packageId => text()();

  /// `voluntary_withdrawal` | `ejection`
  TextColumn get kind => text()();
  TextColumn get initiatorParticipantId => text()();
  TextColumn get targetParticipantId => text().nullable()();
  DateTimeColumn get departureDate => dateTime().nullable()();

  /// `pending` | `effective` | `aborted`
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get settledAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-decider vote on a participation change (#1 and #3).
class HousingParticipationDecisions extends Table {
  TextColumn get changeId => text()();
  TextColumn get participantId => text()();

  /// `accepted` | `rejected`
  TextColumn get status => text()();
  DateTimeColumn get decidedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {changeId, participantId};
}

/// Per-participant membership state for an active housing plan.
class HousingPlanMemberships extends Table {
  TextColumn get planId => text()();
  TextColumn get participantId => text()();

  /// `active` | `departed`
  TextColumn get status => text()();
  DateTimeColumn get departedAt => dateTime().nullable()();
  TextColumn get departureKind => text().nullable()();
  TextColumn get changeId => text().nullable()();

  @override
  Set<Column> get primaryKey => {planId, participantId};
}

/// Ledger-only ghost participant after a departure (#2/#3).
class HousingInactiveParticipants extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  TextColumn get sourceParticipantId => text()();
  TextColumn get displayNameSnapshot => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get clearedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local payment-reminder journal cards on Accepted expenses.
///
/// [reminderKind] is `before_due` (#10, orange) or `overdue` (#11, red).
class HousingPaymentOverdueJournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  TextColumn get planLineId => text()();
  TextColumn get periodKey => text()();
  DateTimeColumn get periodDueAt => dateTime()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get reminderKind =>
      text().withDefault(const Constant('overdue'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Inbound watch list and outbound/inbound pending state for plan-mediated
/// peer contact establishment (known public keys from proposal snapshots).
class PlanPeerEstablishments extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  TextColumn get participantId => text()();
  TextColumn get peerPublicMaterialB64 => text()();
  TextColumn get peerDisplayName => text()();
  TextColumn get peerAvatarId => text()();
  TextColumn get proposerDisplayName => text()();
  TextColumn get revisionId => text().nullable()();
  DateTimeColumn get outboundPendingAt => dateTime().nullable()();
  DateTimeColumn get refusedAt => dateTime().nullable()();
  DateTimeColumn get inboundPendingAt => dateTime().nullable()();
  TextColumn get inboundRequesterDisplayName => text().nullable()();
  TextColumn get inboundRequesterAvatarId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Plans,
    Participants,
    PlanLines,
    PlanGroups,
    PlanRatios,
    PlanRatioTemplates,
    Agreements,
    ProposalPackages,
    ProposalRevisions,
    ProposalResponses,
    RelayActivityLogEntries,
    Contacts,
    ContactInvitations,
    PendingHandshakes,
    RealizedExpenses,
    RealizedExpenseAttachments,
    RealizedExpenseAcceptances,
    ArchivedPlanLineSnapshots,
    HousingParticipationChanges,
    HousingParticipationDecisions,
    HousingPlanMemberships,
    HousingInactiveParticipants,
    HousingPaymentOverdueJournalEntries,
    PlanPeerEstablishments,
    Vehicles,
    VehicleMeterReadings,
    VehicleUses,
    VehicleConsumptionEstimateHistory,
    VehicleOdometerGaps,
    FuelPurchases,
    MaintenanceEvents,
    VehicleMaintenanceRules,
    TrafficViolations,
    VehicleSharingLinks,
    VehicleUsageBalanceFreezes,
    VehicleUsageTransfers,
    VehiclePhotoGalleries,
    VehicleGalleryPhotos,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  /// Single process-wide database used by UI and relay code. Bound in
  /// [bootstrap] before [runApp]. Do not call [AppDatabase]'s public
  /// constructor from widgets — use [processScope] instead.
  static AppDatabase? _processScope;

  static void bindProcessScope(AppDatabase db) {
    _processScope = db;
  }

  static AppDatabase? get maybeProcessScope => _processScope;

  static AppDatabase get processScope {
    final s = _processScope;
    if (s == null) {
      throw StateError(
        'AppDatabase.processScope is not bound. '
        'bootstrap.dart must call AppDatabase.bindProcessScope before runApp.',
      );
    }
    return s;
  }

  /// Opens the native/web SQLite file while platform channels are registered.
  ///
  /// Call once from [bootstrap] after [WidgetsFlutterBinding.ensureInitialized].
  /// Skipping this and touching the DB after a hot restart can surface
  /// [MissingPluginException] from `path_provider` during relay polling.
  Future<void> warmUpStorage() => customSelect('SELECT 1').get();

  /// Clears the global reference after [close] (e.g. dev database reset).
  static void clearProcessScopeIfReferencing(AppDatabase db) {
    if (identical(_processScope, db)) {
      _processScope = null;
    }
  }

  /// Nudges Drift's web WASM storage to flush after important housing writes.
  Future<void> syncWebStorageToDisk() async {
    if (!kIsWeb) return;
    try {
      await customStatement('PRAGMA synchronous = FULL');
    } catch (_) {
      // Ignore on backends that reject the pragma.
    }
    try {
      await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // WAL is not available on all web sqlite builds.
    }
    if (kDebugMode && kIsWeb) {
      debugWebDbFlushHook?.call(this);
    }
  }

  /// True when `pragma_table_info` lists [columnSqlName] on [tableSqlName].
  ///
  /// [Migrator.createTable] uses the **current** table definition. Older
  /// `user_version` upgrades may still have `addColumn` steps for columns that
  /// are now part of that definition — skip those to avoid duplicate column
  /// errors (e.g. `contacts` created at v9 already includes v11+ columns).
  Future<bool> _sqliteTableHasColumn(
    String tableSqlName,
    String columnSqlName,
  ) async {
    final rows = await customSelect(
      "SELECT 1 AS x FROM pragma_table_info('$tableSqlName') "
      "WHERE name = '$columnSqlName' LIMIT 1",
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _sqliteTableExists(String tableSqlName) async {
    final rows = await customSelect(
      "SELECT 1 AS x FROM sqlite_master "
      "WHERE type = 'table' AND name = '$tableSqlName' LIMIT 1",
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> _migrateAddColumn(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final tableName = table.actualTableName;
    if (!await _sqliteTableExists(tableName)) {
      return;
    }
    if (await _sqliteTableHasColumn(tableName, column.name)) {
      return;
    }
    await m.addColumn(table, column);
  }

  @override
  int get schemaVersion => 43;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Forward-only migrations. Always handle ranges.
      if (from < 2) {
        await _migrateAddColumn(m, plans, plans.notes);
      }
      if (from < 3) {
        await _migrateAddColumn(m, plans, plans.currency);
        await m.createTable(planGroups);
        await m.createTable(planLines);
        await m.createTable(planRatios);
        await m.createTable(agreements);
      }
      if (from < 4) {
        await m.createTable(proposalPackages);
        await m.createTable(proposalRevisions);
        await m.createTable(proposalResponses);
      }
      if (from < 5) {
        await _migrateAddColumn(m, planLines, planLines.recurrenceDayOfMonth);
        await _migrateAddColumn(m, planLines, planLines.sortOrder);
        await _migrateAddColumn(m, agreements, agreements.withdrawalSameForAll);
        await _migrateAddColumn(
          m,
          agreements,
          agreements.withdrawalPerParticipantJson,
        );
      }
      if (from < 6) {
        await _migrateAddColumn(m, planLines, planLines.amountUsesRange);
        await _migrateAddColumn(m, planLines, planLines.description);
        await customStatement('''
              UPDATE plan_lines
              SET amount_uses_range = CASE
                WHEN is_recurring = 0
                    AND IFNULL(min_amount_minor, -1) != IFNULL(max_amount_minor, -2)
                THEN 1
                ELSE 0
              END
              ''');
        await customStatement('''
              UPDATE plan_lines
              SET amount_minor = min_amount_minor
              WHERE is_recurring = 0
                AND amount_uses_range = 0
                AND amount_minor IS NULL
                AND min_amount_minor IS NOT NULL
              ''');
      }
      if (from < 7) {
        await _migrateAddColumn(m, planGroups, planGroups.description);
      }
      if (from < 8) {
        await _migrateAddColumn(m, agreements, agreements.agreementRulesJson);
      }
      if (from < 9) {
        await m.createTable(contacts);
        await m.createTable(contactInvitations);
        await _migrateAddColumn(m, participants, participants.contactId);
        await _mirrorParticipantsIntoContacts();
      }
      if (from < 10) {
        await m.createTable(pendingHandshakes);
      }
      if (from < 11) {
        await _migrateAddColumn(m, contacts, contacts.localDisplayLabel);
        await _migrateAddColumn(m, contacts, contacts.disconnectedAt);
      }
      if (from < 12) {
        // Contacts disconnected before `disconnected_at` existed never got
        // the column set; backfill for rows that are clearly not active
        // invitation stubs (see `contact_display.showsDisconnectedStatus`).
        await customStatement('''
              UPDATE contacts
              SET disconnected_at = COALESCE(updated_at, created_at)
              WHERE kind = 'local-only'
                AND disconnected_at IS NULL
                AND (relay_routing_id IS NULL OR relay_routing_id = '')
                AND (peer_public_material IS NULL OR peer_public_material = '')
                AND id LIKE 'contact:handshake:%'
                AND NOT EXISTS (
                  SELECT 1 FROM pending_handshakes ph
                  WHERE ph.contact_stub_id = contacts.id
                    AND ph.state IN (
                      'awaiting_hello',
                      'dispatching_hello',
                      'awaiting_ack',
                      'hello_received'
                    )
                )
                AND NOT EXISTS (
                  SELECT 1 FROM contact_invitations ci
                  WHERE ci.contact_stub_id = contacts.id
                    AND ci.status = 'pending'
                )
            ''');
      }
      if (from < 13) {
        // v12 only matched `contact:handshake:` (inviter stubs). Invitees
        // keep `contact:redeemed:` ids — same demotion shape but backfill
        // missed them, so UI stayed on `contactsKindLocalOnly`.
        await customStatement('''
              UPDATE contacts
              SET disconnected_at = COALESCE(updated_at, created_at)
              WHERE kind = 'local-only'
                AND disconnected_at IS NULL
                AND (relay_routing_id IS NULL OR relay_routing_id = '')
                AND (peer_public_material IS NULL OR peer_public_material = '')
                AND id LIKE 'contact:redeemed:%'
                AND NOT EXISTS (
                  SELECT 1 FROM pending_handshakes ph
                  WHERE ph.contact_stub_id = contacts.id
                    AND ph.state IN (
                      'awaiting_hello',
                      'dispatching_hello',
                      'awaiting_ack',
                      'hello_received'
                    )
                )
                AND NOT EXISTS (
                  SELECT 1 FROM contact_invitations ci
                  WHERE ci.contact_stub_id = contacts.id
                    AND ci.status = 'pending'
                )
            ''');
      }
      if (from < 14) {
        await _migrateAddColumn(m, contacts, contacts.theirLabelForMe);
      }
      if (from < 15) {
        if (!await _sqliteTableExists('plan_ratio_templates')) {
          await m.createTable(planRatioTemplates);
        }
        // v8-only DBs (participants/contacts) never had housing tables; skip
        // plan line backfill when jumping past v3 in one upgrade.
        if (await _sqliteTableExists('plan_lines')) {
          await _migrateAddColumn(m, planLines, planLines.amountIsBudgetCap);
          await _migrateAddColumn(
            m,
            planLines,
            planLines.paymentResponsibleParticipantId,
          );
          await _migrateAddColumn(m, planLines, planLines.recurrenceSpecJson);
          await _migrateAddColumn(m, planLines, planLines.ratioTemplateId);
          // amountUsesRange meant approximate band → budget cap.
          await customStatement('''
                UPDATE plan_lines
                SET amount_is_budget_cap = amount_uses_range
                WHERE amount_uses_range = 1
              ''');
          await customStatement('''
                UPDATE plan_lines
                SET recurrence_spec_json = json_object(
                  'kind', 'monthlyDay',
                  'day', recurrence_day_of_month,
                  'anchor', NULL
                )
                WHERE is_recurring = 1
                  AND recurrence_day_of_month IS NOT NULL
                  AND (recurrence_spec_json IS NULL OR recurrence_spec_json = '')
              ''');
        }
      }
      if (from < 16) {
        await m.createTable(relayActivityLogEntries);
      }
      if (from < 17) {
        await m.createTable(realizedExpenses);
        await m.createTable(realizedExpenseAttachments);
        await m.createTable(realizedExpenseAcceptances);
      }
      if (from < 18) {
        await _migrateAddColumn(
          m,
          realizedExpenses,
          realizedExpenses.description,
        );
      }
      if (from < 19) {
        await _migrateAddColumn(
          m,
          realizedExpenses,
          realizedExpenses.planLineTitleSnapshot,
        );
        await _migrateAddColumn(
          m,
          realizedExpenses,
          realizedExpenses.splitRatiosJson,
        );
        await m.createTable(archivedPlanLineSnapshots);
      }
      if (from < 20) {
        await m.createTable(housingParticipationChanges);
        await m.createTable(housingParticipationDecisions);
        await m.createTable(housingPlanMemberships);
        await m.createTable(housingInactiveParticipants);
      }
      if (from < 21) {
        await m.createTable(planPeerEstablishments);
      }
      if (from < 22) {
        await _migrateAddColumn(
          m,
          realizedExpenses,
          realizedExpenses.paymentChartCarryForwardMinor,
        );
      }
      if (from < 23) {
        await m.createTable(housingPaymentOverdueJournalEntries);
      }
      if (from < 24) {
        await m.createTable(vehicles);
        await m.createTable(vehicleMeterReadings);
        await m.createTable(vehicleUses);
        await m.createTable(vehicleOdometerGaps);
        await m.createTable(fuelPurchases);
        await m.createTable(maintenanceEvents);
        await m.createTable(vehicleMaintenanceRules);
        await m.createTable(trafficViolations);
        await m.createTable(vehicleSharingLinks);
      }
      if (from < 25) {
        await _migrateAddColumn(m, vehicles, vehicles.color);
        await _migrateAddColumn(m, vehicles, vehicles.modelYear);
        await _migrateAddColumn(m, vehicles, vehicles.licensePlate);
        await _migrateAddColumn(m, vehicles, vehicles.vin);
        await m.createTable(vehiclePhotoGalleries);
        await m.createTable(vehicleGalleryPhotos);
      }
      if (from < 26) {
        await _migrateAddColumn(m, vehicles, vehicles.fuelTankCapacityLiters);
        await _migrateAddColumn(
          m,
          fuelPurchases,
          fuelPurchases.tankFillFraction,
        );
        await customStatement('''
              UPDATE vehicle_meter_readings
              SET value = value * 10
              WHERE unit = 'odometer_km'
              ''');
        await customStatement('''
              UPDATE fuel_purchases
              SET meter_reading_value = meter_reading_value * 10
              WHERE meter_reading_value IS NOT NULL
                AND vehicle_id IN (
                  SELECT id FROM vehicles WHERE vehicle_kind != 'boat'
                )
              ''');
        await customStatement('''
              UPDATE maintenance_events
              SET meter_at_service = meter_at_service * 10
              WHERE meter_at_service IS NOT NULL
                AND vehicle_id IN (
                  SELECT id FROM vehicles WHERE vehicle_kind != 'boat'
                )
              ''');
        await customStatement('''
              UPDATE vehicle_odometer_gaps
              SET latest_reading_before_gap = latest_reading_before_gap * 10,
                  start_reading_after_gap = start_reading_after_gap * 10,
                  gap_amount = gap_amount * 10
              ''');
        await customStatement('''
              UPDATE vehicle_maintenance_rules
              SET interval_amount = interval_amount * 10,
                  preview_window_amount = preview_window_amount * 10
              WHERE vehicle_id IN (
                SELECT id FROM vehicles WHERE vehicle_kind != 'boat'
              )
              ''');
      }
      if (from < 27) {
        await _migrateAddColumn(
          m,
          vehicleMeterReadings,
          vehicleMeterReadings.isFullTank,
        );
        await _migrateAddColumn(
          m,
          vehicleMeterReadings,
          vehicleMeterReadings.tankFillFraction,
        );
      }
      if (from < 28) {
        await _migrateAddColumn(
          m,
          vehicleUses,
          vehicleUses.drivingRoutePercent,
        );
        await _migrateAddColumn(m, vehicleUses, vehicleUses.drivingCityPercent);
        await _migrateAddColumn(
          m,
          vehicleUses,
          vehicleUses.drivingTrafficPercent,
        );
      }
      if (from < 29) {
        await m.createTable(vehicleConsumptionEstimateHistory);
      }
      if (from < 30) {
        await _migrateAddColumn(
          m,
          vehicles,
          vehicles.consumptionEstimationMode,
        );
        await _migrateAddColumn(
          m,
          vehicles,
          vehicles.requireDetailedDrivingMixForBorrowers,
        );
        await _migrateAddColumn(
          m,
          vehicleUses,
          vehicleUses.sessionConsumptionMode,
        );
      }
      if (from < 31) {
        await _migrateAddColumn(
          m,
          vehicleMeterReadings,
          vehicleMeterReadings.resolvedAt,
        );
        await _migrateAddColumn(
          m,
          vehicleOdometerGaps,
          vehicleOdometerGaps.correctionReadingId,
        );
        await _migrateAddColumn(
          m,
          vehicleOdometerGaps,
          vehicleOdometerGaps.previousReadingId,
        );
        await _migrateAddColumn(
          m,
          vehicleOdometerGaps,
          vehicleOdometerGaps.triggerReadingId,
        );
      }
      if (from < 32) {
        await _migrateAddColumn(
          m,
          vehicleMeterReadings,
          vehicleMeterReadings.supersedesReadingId,
        );
      }
      if (from < 33) {
        await _migrateAddColumn(m, contacts, contacts.peerDeviceBindingId);
        await _migrateAddColumn(
          m,
          pendingHandshakes,
          pendingHandshakes.peerDeviceBindingId,
        );
      }
      if (from < 34) {
        await _migrateAddColumn(
          m,
          housingPaymentOverdueJournalEntries,
          housingPaymentOverdueJournalEntries.reminderKind,
        );
      }
      if (from < 35) {
        await _migrateAddColumn(m, vehicles, vehicles.deactivatedAt);
      }
      if (from < 36) {
        await _migrateAddColumn(m, vehicles, vehicles.saleImportUndoAvailable);
      }
      if (from < 37) {
        await _migrateAddColumn(
          m,
          vehicleSharingLinks,
          vehicleSharingLinks.ratePerKmMinor,
        );
        await _migrateAddColumn(
          m,
          vehicleSharingLinks,
          vehicleSharingLinks.rateCurrency,
        );
        await _migrateAddColumn(
          m,
          vehicleSharingLinks,
          vehicleSharingLinks.availabilityStart,
        );
        await _migrateAddColumn(
          m,
          vehicleSharingLinks,
          vehicleSharingLinks.availabilityEnd,
        );
        await _migrateAddColumn(
          m,
          vehicleSharingLinks,
          vehicleSharingLinks.ownerRulesText,
        );
      }
      if (from < 38) {
        await _migrateAddColumn(
          m,
          vehicleSharingLinks,
          vehicleSharingLinks.availabilityWeekJson,
        );
      }
      if (from < 39) {
        await _migrateAddColumn(
          m,
          vehicleSharingLinks,
          vehicleSharingLinks.expiresAt,
        );
      }
      if (from < 40) {
        await _migrateAddColumn(
          m,
          vehicleUses,
          vehicleUses.fuelCatchUpResponseReceived,
        );
      }
      if (from < 41) {
        await m.createTable(vehicleUsageBalanceFreezes);
        await m.createTable(vehicleUsageTransfers);
      }
      if (from < 42) {
        await _migrateAddColumn(
          m,
          vehicleUsageBalanceFreezes,
          vehicleUsageBalanceFreezes.lastKnownPurchaseId,
        );
      }
      if (from < 43) {
        await _migrateAddColumn(
          m,
          vehicleUsageTransfers,
          vehicleUsageTransfers.initiatedByContactId,
        );
      }
    },
    beforeOpen: (details) async {
      // Drift will run onCreate/onUpgrade automatically.
      // This is a hook for sanity checks if needed later.
    },
  );

  Future<void> upsertPlan(PlansCompanion plan) =>
      into(plans).insertOnConflictUpdate(plan);

  Future<List<Plan>> listPlans() =>
      (select(plans)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  Future<void> upsertAgreement(AgreementsCompanion row) =>
      into(agreements).insertOnConflictUpdate(row);

  /// True when a proposal package for [planId] has an active (accepted) revision.
  /// Used to lock removal of agreement rules that were part of a binding package.
  Future<bool> planHasActiveAcceptedProposal(String planId) async {
    final packages = await (select(
      proposalPackages,
    )..where((t) => t.planId.equals(planId))).get();
    for (final pkg in packages) {
      final id = pkg.activeRevisionId;
      if (id == null || id.isEmpty) continue;
      final rev = await (select(
        proposalRevisions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (rev == null) continue;
      try {
        final payload = jsonDecode(rev.payloadJson) as Map<String, dynamic>;
        final state = (payload['lifecycleState'] as String?) ?? 'open';
        if (state != 'archived') continue;
        final invalidated = payload['invalidatedByStatus']?.toString() ?? '';
        if (invalidated.isEmpty) return true;
      } catch (_) {
        // Ignore malformed payloads.
      }
    }
    return false;
  }

  Future<Agreement?> getAgreementForPlan(String planId) async {
    final rows =
        await (select(agreements)
              ..where((t) => t.planId.equals(planId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.version),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    if (rows.isEmpty) return null;
    if (rows.length == 1) return rows.first;

    // `getSingleOrNull` throws when more than one row matches. Duplicates can
    // appear if older inserts used a different primary key than upserts.
    final canonicalId = 'agreement:$planId';
    Agreement? canonicalRow;
    for (final r in rows) {
      if (r.id == canonicalId) {
        canonicalRow = r;
        break;
      }
    }
    final keep = canonicalRow ?? rows.first;

    await batch((b) {
      for (final r in rows) {
        if (r.id != keep.id) {
          b.deleteWhere(agreements, (t) => t.id.equals(r.id));
        }
      }
    });
    return keep;
  }

  Future<void> upsertHousingPaymentOverdueJournalEntry({
    required String id,
    required String planId,
    required String planLineId,
    required String periodKey,
    required DateTime periodDueAt,
    required DateTime recordedAt,
    String reminderKind = 'overdue',
  }) async {
    await into(housingPaymentOverdueJournalEntries).insertOnConflictUpdate(
      HousingPaymentOverdueJournalEntriesCompanion.insert(
        id: id,
        planId: planId,
        planLineId: planLineId,
        periodKey: periodKey,
        periodDueAt: periodDueAt,
        recordedAt: recordedAt,
        reminderKind: Value(reminderKind),
      ),
    );
  }

  Future<List<HousingPaymentOverdueJournalEntry>>
  listHousingPaymentOverdueJournalForPlan(String planId) async {
    return (select(housingPaymentOverdueJournalEntries)
          ..where((t) => t.planId.equals(planId))
          ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]))
        .get();
  }

  Future<void> upsertPlanLine(PlanLinesCompanion line) =>
      into(planLines).insertOnConflictUpdate(line);

  Future<List<PlanLine>> listPlanLines(String planId) =>
      (select(planLines)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get();

  Future<List<PlanGroup>> listPlanGroups(String planId) =>
      (select(planGroups)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> upsertPlanGroup(PlanGroupsCompanion row) =>
      into(planGroups).insertOnConflictUpdate(row);

  Future<void> upsertPlanRatio(PlanRatiosCompanion row) =>
      into(planRatios).insertOnConflictUpdate(row);

  Future<List<PlanRatio>> listPlanRatios(String planId) =>
      (select(planRatios)..where((t) => t.planId.equals(planId))).get();

  Future<void> upsertArchivedPlanLineSnapshot(
    ArchivedPlanLineSnapshotsCompanion row,
  ) => into(archivedPlanLineSnapshots).insertOnConflictUpdate(row);

  Future<ArchivedPlanLineSnapshot?> getArchivedPlanLineSnapshot({
    required String planId,
    required String lineId,
  }) =>
      (select(archivedPlanLineSnapshots)
            ..where((t) => t.planId.equals(planId))
            ..where((t) => t.lineId.equals(lineId)))
          .getSingleOrNull();

  Future<void> upsertPlanRatioTemplate(PlanRatioTemplatesCompanion row) =>
      into(planRatioTemplates).insertOnConflictUpdate(row);

  Future<List<PlanRatioTemplate>> listPlanRatioTemplates(String planId) =>
      (select(planRatioTemplates)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> deletePlanRatioTemplate(String id) =>
      (delete(planRatioTemplates)..where((t) => t.id.equals(id))).go();

  /// Deletes plan lines, ratios, agreement, groups, proposal state, and
  /// participants whose ids start with `planId:p` (housing draft roster).
  Future<void> deletePlanRelatedData(String planId) async {
    await transaction(() async {
      final pkgs = await (select(
        proposalPackages,
      )..where((t) => t.planId.equals(planId))).get();
      for (final pkg in pkgs) {
        final revs = await (select(
          proposalRevisions,
        )..where((t) => t.packageId.equals(pkg.id))).get();
        for (final r in revs) {
          await (delete(
            proposalResponses,
          )..where((t) => t.revisionId.equals(r.id))).go();
        }
        await (delete(
          proposalRevisions,
        )..where((t) => t.packageId.equals(pkg.id))).go();
        await (delete(
          proposalPackages,
        )..where((t) => t.id.equals(pkg.id))).go();
      }
      await (delete(planRatios)..where((t) => t.planId.equals(planId))).go();
      await (delete(
        planRatioTemplates,
      )..where((t) => t.planId.equals(planId))).go();
      await (delete(planLines)..where((t) => t.planId.equals(planId))).go();
      await (delete(agreements)..where((t) => t.planId.equals(planId))).go();
      await (delete(planGroups)..where((t) => t.planId.equals(planId))).go();

      final all = await listParticipants();
      for (final p in all) {
        if (p.id.startsWith('$planId:p') || p.id == '$planId:self') {
          await (delete(participants)..where((t) => t.id.equals(p.id))).go();
        }
      }
    });
  }

  Future<void> upsertParticipant(ParticipantsCompanion participant) =>
      into(participants).insertOnConflictUpdate(participant);

  Future<List<Participant>> listParticipants() =>
      (select(participants)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  /// Returns the distinct list of [Plan]s in which [contactId] is currently
  /// referenced as a participant (other than as the local user's own "self"
  /// slot). Used to block destructive Contact operations such as deletion
  /// when the contact still anchors a module plan; see
  /// `contact-privacy-and-deletion` spec.
  ///
  /// Participant rows are stored with composite ids of the form
  /// `<planId>:self` and `<planId>:p<n>`. The plan id is recovered by
  /// stripping everything from the last `:` onward.
  Future<List<Plan>> listPlansContainingContact(String contactId) async {
    final rows = await (select(
      participants,
    )..where((t) => t.contactId.equals(contactId))).get();
    final planIds = <String>{};
    for (final p in rows) {
      final i = p.id.lastIndexOf(':');
      if (i <= 0) continue;
      planIds.add(p.id.substring(0, i));
    }
    if (planIds.isEmpty) return const <Plan>[];
    final result = await (select(
      plans,
    )..where((t) => t.id.isIn(planIds))).get();
    result.sort((a, b) {
      final ta = a.title.isEmpty ? a.id : a.title;
      final tb = b.title.isEmpty ? b.id : b.title;
      return ta.toLowerCase().compareTo(tb.toLowerCase());
    });
    return result;
  }

  Future<void> upsertContact(ContactsCompanion row) =>
      into(contacts).insertOnConflictUpdate(row);

  Future<Contact?> getContact(String id) =>
      (select(contacts)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns visible contacts (not deleted). Deleted contacts remain in the
  /// database so historical module ledger snapshots stay readable.
  Future<List<Contact>> listContacts({bool includeDeleted = false}) {
    final q = select(contacts);
    if (!includeDeleted) {
      q.where((t) => t.deletedAt.isNull());
    }
    q.orderBy([
      (t) => OrderingTerm.asc(t.displayName),
      (t) => OrderingTerm.asc(t.id),
    ]);
    return q.get();
  }

  Future<void> upsertContactInvitation(ContactInvitationsCompanion row) =>
      into(contactInvitations).insertOnConflictUpdate(row);

  Future<List<ContactInvitation>> listContactInvitations() => (select(
    contactInvitations,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<void> upsertPendingHandshake(PendingHandshakesCompanion row) =>
      into(pendingHandshakes).insertOnConflictUpdate(row);

  Future<PendingHandshake?> getPendingHandshake(String id) => (select(
    pendingHandshakes,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<PendingHandshake>> listPendingHandshakes({
    Iterable<String>? statesIn,
  }) {
    final q = select(pendingHandshakes);
    if (statesIn != null && statesIn.isNotEmpty) {
      q.where((t) => t.state.isIn(statesIn));
    }
    q.orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.get();
  }

  Future<void> deletePendingHandshake(String id) async {
    await (delete(pendingHandshakes)..where((t) => t.id.equals(id))).go();
  }

  Future<void> upsertPlanPeerEstablishment(
    PlanPeerEstablishmentsCompanion row,
  ) => into(planPeerEstablishments).insertOnConflictUpdate(row);

  Future<PlanPeerEstablishment?> getPlanPeerEstablishment(String id) => (select(
    planPeerEstablishments,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<PlanPeerEstablishment?> getPlanPeerEstablishmentByPeer(
    String peerPublicMaterialB64,
  ) =>
      (select(planPeerEstablishments)..where(
            (t) => t.peerPublicMaterialB64.equals(peerPublicMaterialB64),
          ))
          .getSingleOrNull();

  Future<List<PlanPeerEstablishment>> listPlanPeerEstablishmentsForPlan(
    String planId,
  ) =>
      (select(planPeerEstablishments)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm.asc(t.peerDisplayName)]))
          .get();

  Future<List<PlanPeerEstablishment>> listAllPlanPeerEstablishments() =>
      (select(
        planPeerEstablishments,
      )..orderBy([(t) => OrderingTerm.asc(t.planId)])).get();

  Future<void> deletePlanPeerEstablishment(String id) async {
    await (delete(planPeerEstablishments)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deletePlanPeerEstablishmentsForPlan(String planId) async {
    await (delete(
      planPeerEstablishments,
    )..where((t) => t.planId.equals(planId))).go();
  }

  /// Mirrors every existing `participants` row into a `contacts` row and
  /// re-points the participant's `contact_id` foreign key. Identical
  /// `(displayName, avatarId)` pairs are unified into a single Contact;
  /// otherwise distinct Contacts are created. Runs only when invoked from
  /// the v9 migration and is idempotent against repeated invocations.
  Future<void> _mirrorParticipantsIntoContacts() async {
    final now = DateTime.now().toUtc();
    final partRows = await select(participants).get();
    if (partRows.isEmpty) return;

    final indexByKey = <String, String>{};
    for (final p in partRows) {
      if (p.contactId != null) continue;
      final key = '${p.displayName}\u0000${p.avatarId}';
      var contactId = indexByKey[key];
      if (contactId == null) {
        contactId = 'contact:p:${p.id}';
        indexByKey[key] = contactId;
        await into(contacts).insertOnConflictUpdate(
          ContactsCompanion.insert(
            id: contactId,
            kind: 'local-only',
            displayName: p.displayName,
            avatarId: p.avatarId,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await (update(participants)..where((t) => t.id.equals(p.id))).write(
        ParticipantsCompanion(contactId: Value(contactId)),
      );
    }
  }
}

QueryExecutor _openConnection() {
  final base = driftDatabase(
    name: 'compartarenta.sqlite',
    native: DriftNativeOptions(
      // Avoid drift_flutter's default getTemporaryDirectory() call during lazy
      // open. On Android this can race plugin registration during early relay
      // polling; SQLite can keep temporary data in memory for our workload.
      tempDirectoryPath: () async => null,
      databaseDirectory: () async {
        final dir = await DbPaths.dbDirectory();
        return Directory(p.join(dir.path));
      },
    ),
    // Web build: drift loads sqlite3 as WebAssembly and offloads queries
    // to a background worker. Both assets ship under `mobile/web/` and
    // must match the versions of the `drift` and `sqlite3` packages
    // pinned in `pubspec.lock` (see docs/development-roadmap.md for the
    // refresh recipe).
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
      onResult: kDebugMode
          ? (result) {
              debugPrint(
                'Drift web storage: ${result.chosenImplementation} '
                '(missing: ${result.missingFeatures})',
              );
            }
          : null,
    ),
  );
  if (kDebugMode && kIsWeb) {
    return devHostSessionWriteObserver(base);
  }
  return base;
}
