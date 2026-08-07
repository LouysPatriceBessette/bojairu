import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/drift.dart' show OrderingTerm;

import '../db/app_database.dart';

/// Append-only relay-related activity on this device (Settings audit trail).
class RelayActivityLogService {
  RelayActivityLogService(this._db);

  final AppDatabase _db;

  static const initiatorSelf = 'self';
  static const initiatorContact = 'contact';
  static const initiatorSystem = 'system';

  Future<void> append({
    required String kind,
    required String initiatorKind,
    String? initiatorContactId,
    String? initiatorDisplayName,
    String? planId,
    String? packageId,
    String? revisionId,
    Map<String, Object?> details = const {},
    DateTime? occurredAt,
  }) async {
    final at = (occurredAt ?? DateTime.now()).toUtc();
    final id = 'log:${at.microsecondsSinceEpoch}';
    await _db
        .into(_db.relayActivityLogEntries)
        .insert(
          RelayActivityLogEntriesCompanion.insert(
            id: id,
            occurredAt: at,
            kind: kind,
            initiatorKind: initiatorKind,
            initiatorContactId: drift.Value(initiatorContactId),
            initiatorDisplayName: drift.Value(initiatorDisplayName ?? ''),
            planId: drift.Value(planId),
            packageId: drift.Value(packageId),
            revisionId: drift.Value(revisionId),
            detailsJson: drift.Value(jsonEncode(details)),
          ),
        );
  }

  /// Stable keys for the activity-log emitter filter dropdown.
  static const emitterFilterAll = '';
  static const emitterFilterSystem = 'emitter:system';
  static const emitterFilterSelf = 'emitter:self';
  static String emitterFilterContact(String contactId) =>
      'emitter:contact:$contactId';
  static String emitterFilterDisplayName(String displayName) =>
      'emitter:name:${displayName.toLowerCase()}';

  /// Distinct emitters present in the Settings log (excludes vehicle/sharing).
  Future<List<ActivityLogEmitterFilterOption>> emitterFilterOptions({
    required String selfDisplayName,
    required String allLabel,
    required String systemLabel,
    required String selfFallbackLabel,
  }) async {
    final rows = await _db.select(_db.relayActivityLogEntries).get();
    final options = <ActivityLogEmitterFilterOption>[
      ActivityLogEmitterFilterOption(key: emitterFilterAll, label: allLabel),
    ];

    var hasSystem = false;
    var hasSelf = false;
    final contactsById = <String, String>{};
    final namesWithoutId = <String>{};

    for (final row in rows) {
      if (RelayActivityLogKinds.isVehicleRelated(row.kind)) continue;
      switch (row.initiatorKind) {
        case initiatorSystem:
          hasSystem = true;
        case initiatorSelf:
          hasSelf = true;
        case initiatorContact:
          final id = row.initiatorContactId;
          if (id != null && id.isNotEmpty) {
            final name = row.initiatorDisplayName.trim();
            contactsById[id] = name.isNotEmpty ? name : contactsById[id] ?? '';
          } else {
            final name = row.initiatorDisplayName.trim();
            if (name.isNotEmpty) namesWithoutId.add(name);
          }
      }
    }

    if (hasSystem) {
      options.add(
        ActivityLogEmitterFilterOption(
          key: emitterFilterSystem,
          label: systemLabel,
        ),
      );
    }
    if (hasSelf) {
      final selfLabel = selfDisplayName.trim().isNotEmpty
          ? selfDisplayName.trim()
          : selfFallbackLabel;
      options.add(
        ActivityLogEmitterFilterOption(
          key: emitterFilterSelf,
          label: selfLabel,
        ),
      );
    }

    final sortedContacts = contactsById.entries.toList()
      ..sort(
        (a, b) => _emitterLabel(
          a.value,
          a.key,
        ).compareTo(_emitterLabel(b.value, b.key)),
      );
    for (final entry in sortedContacts) {
      options.add(
        ActivityLogEmitterFilterOption(
          key: emitterFilterContact(entry.key),
          label: _emitterLabel(entry.value, entry.key),
        ),
      );
    }

    final sortedNames = namesWithoutId.toList()..sort();
    for (final name in sortedNames) {
      if (contactsById.values.any((v) => v == name)) continue;
      options.add(
        ActivityLogEmitterFilterOption(
          key: emitterFilterDisplayName(name),
          label: name,
        ),
      );
    }

    return options;
  }

  static String _emitterLabel(String displayName, String fallback) {
    final trimmed = displayName.trim();
    return trimmed.isNotEmpty ? trimmed : fallback;
  }

  static bool matchesEmitterFilter(
    RelayActivityLogEntry row,
    String emitterFilterKey,
  ) {
    if (emitterFilterKey.isEmpty) return true;
    return switch (emitterFilterKey) {
      emitterFilterSystem => row.initiatorKind == initiatorSystem,
      emitterFilterSelf => row.initiatorKind == initiatorSelf,
      final key when key.startsWith('emitter:contact:') =>
        row.initiatorContactId == key.substring('emitter:contact:'.length),
      final key when key.startsWith('emitter:name:') =>
        row.initiatorDisplayName.trim().toLowerCase() ==
            key.substring('emitter:name:'.length),
      _ => true,
    };
  }

  Future<List<RelayActivityLogEntry>> listFiltered({
    DateTime? fromUtc,
    DateTime? toUtc,
    String emitterFilterKey = emitterFilterAll,
    int limit = 500,
  }) async {
    final q = _db.select(_db.relayActivityLogEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(limit);
    final rows = await q.get();
    return rows
        .where((row) {
          if (RelayActivityLogKinds.isVehicleRelated(row.kind)) return false;
          if (fromUtc != null && row.occurredAt.isBefore(fromUtc)) return false;
          if (toUtc != null && row.occurredAt.isAfter(toUtc)) return false;
          if (!matchesEmitterFilter(row, emitterFilterKey)) return false;
          return true;
        })
        .toList(growable: false);
  }

  /// Offer + session events for a vehicle's « Sessions de partage » journal.
  ///
  /// Fuel purchase kinds are excluded (they appear under meter/fuel).
  Future<List<RelayActivityLogEntry>> listVehicleSharingSessionEvents(
    String vehicleId, {
    int limit = 500,
  }) async {
    final q = _db.select(_db.relayActivityLogEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(limit * 4);
    final rows = await q.get();
    final matched = <RelayActivityLogEntry>[];
    for (final row in rows) {
      if (!RelayActivityLogKinds.isSharingSessionJournalKind(row.kind)) {
        continue;
      }
      final resolved = await _resolveVehicleId(row);
      if (resolved != vehicleId) continue;
      matched.add(row);
      if (matched.length >= limit) break;
    }
    return matched;
  }

  Future<String?> _resolveVehicleId(RelayActivityLogEntry row) async {
    Map<String, dynamic> details;
    try {
      final decoded = jsonDecode(row.detailsJson);
      details = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      return null;
    }
    final direct = (details['vehicleId'] as String?)?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final linkId = (details['linkId'] as String?)?.trim() ?? '';
    if (linkId.isEmpty) return null;
    final link = await (_db.select(
      _db.vehicleSharingLinks,
    )..where((t) => t.id.equals(linkId))).getSingleOrNull();
    return link?.vehicleId;
  }
}

/// One row in the activity-log emitter filter dropdown.
class ActivityLogEmitterFilterOption {
  const ActivityLogEmitterFilterOption({
    required this.key,
    required this.label,
  });

  /// [RelayActivityLogService.emitterFilterAll] means no emitter filter.
  final String key;
  final String label;
}

/// Stable event kind strings for [RelayActivityLogService.append].
abstract final class RelayActivityLogKinds {
  static const contactHandshakeReceived = 'contact_handshake_received';
  static const contactDisconnected = 'contact_disconnected';
  static const contactDeleted = 'contact_deleted';
  static const housingProposalSent = 'housing_proposal_sent';
  static const housingProposalReceived = 'housing_proposal_received';
  static const housingProposalResponse = 'housing_proposal_response';
  static const housingProposalInvalidated = 'housing_proposal_invalidated';
  static const housingProposalExpired = 'housing_proposal_expired';
  static const housingProposalAgreementExpired =
      'housing_proposal_agreement_expired';
  static const housingParticipationChangeAgreementExpired =
      'housing_participation_change_agreement_expired';
  static const housingProposalForkCreated = 'housing_proposal_fork_created';
  static const housingAgreementActivated = 'housing_agreement_activated';
  static const vehicleSharingOfferSent = 'vehicle_sharing_offer_sent';
  static const vehicleSharingOfferReceived = 'vehicle_sharing_offer_received';
  static const vehicleSharingOfferResponse = 'vehicle_sharing_offer_response';
  static const vehicleSharingOfferExpired = 'vehicle_sharing_offer_expired';
  static const vehicleSharingRevokeSent = 'vehicle_sharing_revoke_sent';
  static const vehicleSharingRevokeReceived = 'vehicle_sharing_revoke_received';
  static const vehicleSharingReactivateProposeSent =
      'vehicle_sharing_reactivate_propose_sent';
  static const vehicleSharingReactivateProposeReceived =
      'vehicle_sharing_reactivate_propose_received';
  static const vehicleSharingReactivateAcceptSent =
      'vehicle_sharing_reactivate_accept_sent';
  static const vehicleSharingReactivateAcceptReceived =
      'vehicle_sharing_reactivate_accept_received';
  static const vehicleUseSessionStartSent = 'vehicle_use_session_start_sent';
  static const vehicleUseSessionStartReceived =
      'vehicle_use_session_start_received';
  static const vehicleUseSessionEndSent = 'vehicle_use_session_end_sent';
  static const vehicleUseSessionEndReceived =
      'vehicle_use_session_end_received';
  static const vehicleUseSessionEndByOwnerSent =
      'vehicle_use_session_end_by_owner_sent';
  static const vehicleUseSessionEndByOwnerReceived =
      'vehicle_use_session_end_by_owner_received';
  static const vehicleFuelPurchaseSent = 'vehicle_fuel_purchase_sent';
  static const vehicleFuelPurchaseReceived = 'vehicle_fuel_purchase_received';
  static const vehicleFuelPurchaseCatchUpSent =
      'vehicle_fuel_purchase_catch_up_sent';
  static const vehicleFuelPurchaseCatchUpReceived =
      'vehicle_fuel_purchase_catch_up_received';
  static const vehicleUsageBalanceFreezeProposeSent =
      'vehicle_usage_balance_freeze_propose_sent';
  static const vehicleUsageBalanceFreezeProposeReceived =
      'vehicle_usage_balance_freeze_propose_received';
  static const vehicleUsageBalanceFreezeDecisionSent =
      'vehicle_usage_balance_freeze_decision_sent';
  static const vehicleUsageBalanceFreezeDecisionReceived =
      'vehicle_usage_balance_freeze_decision_received';
  static const vehicleUsageBalanceFreezeCatchUpSent =
      'vehicle_usage_balance_freeze_catch_up_sent';
  static const vehicleUsageBalanceFreezeCatchUpReceived =
      'vehicle_usage_balance_freeze_catch_up_received';
  static const vehicleUsageTransferProposeSent =
      'vehicle_usage_transfer_propose_sent';
  static const vehicleUsageTransferProposeReceived =
      'vehicle_usage_transfer_propose_received';
  static const vehicleUsageTransferDecisionSent =
      'vehicle_usage_transfer_decision_sent';
  static const vehicleUsageTransferDecisionReceived =
      'vehicle_usage_transfer_decision_received';
  static const vehicleMaintenanceSent = 'vehicle_maintenance_sent';
  static const vehicleMaintenanceReceived = 'vehicle_maintenance_received';
  static const vehicleTrafficViolationSent = 'vehicle_traffic_violation_sent';
  static const vehicleTrafficViolationReceived =
      'vehicle_traffic_violation_received';

  /// All vehicle/sharing kinds (hidden from Settings event journal).
  static const Set<String> vehicleRelated = {
    vehicleSharingOfferSent,
    vehicleSharingOfferReceived,
    vehicleSharingOfferResponse,
    vehicleSharingOfferExpired,
    vehicleSharingRevokeSent,
    vehicleSharingRevokeReceived,
    vehicleSharingReactivateProposeSent,
    vehicleSharingReactivateProposeReceived,
    vehicleSharingReactivateAcceptSent,
    vehicleSharingReactivateAcceptReceived,
    vehicleUseSessionStartSent,
    vehicleUseSessionStartReceived,
    vehicleUseSessionEndSent,
    vehicleUseSessionEndReceived,
    vehicleUseSessionEndByOwnerSent,
    vehicleUseSessionEndByOwnerReceived,
    vehicleFuelPurchaseSent,
    vehicleFuelPurchaseReceived,
    vehicleFuelPurchaseCatchUpSent,
    vehicleFuelPurchaseCatchUpReceived,
    vehicleUsageBalanceFreezeProposeSent,
    vehicleUsageBalanceFreezeProposeReceived,
    vehicleUsageBalanceFreezeDecisionSent,
    vehicleUsageBalanceFreezeDecisionReceived,
    vehicleUsageBalanceFreezeCatchUpSent,
    vehicleUsageBalanceFreezeCatchUpReceived,
    vehicleUsageTransferProposeSent,
    vehicleUsageTransferProposeReceived,
    vehicleUsageTransferDecisionSent,
    vehicleUsageTransferDecisionReceived,
    vehicleMaintenanceSent,
    vehicleMaintenanceReceived,
    vehicleTrafficViolationSent,
    vehicleTrafficViolationReceived,
  };

  /// Offer / lifecycle / session kinds shown under vehicle journal « Autre ».
  static const Set<String> sharingSessionJournalKinds = {
    vehicleSharingOfferSent,
    vehicleSharingOfferReceived,
    vehicleSharingOfferResponse,
    vehicleSharingOfferExpired,
    vehicleSharingRevokeSent,
    vehicleSharingRevokeReceived,
    vehicleSharingReactivateProposeSent,
    vehicleSharingReactivateProposeReceived,
    vehicleSharingReactivateAcceptSent,
    vehicleSharingReactivateAcceptReceived,
    vehicleUseSessionStartSent,
    vehicleUseSessionStartReceived,
    vehicleUseSessionEndSent,
    vehicleUseSessionEndReceived,
    vehicleUseSessionEndByOwnerSent,
    vehicleUseSessionEndByOwnerReceived,
  };

  static bool isVehicleRelated(String kind) => vehicleRelated.contains(kind);

  static bool isSharingSessionJournalKind(String kind) =>
      sharingSessionJournalKinds.contains(kind);
}
