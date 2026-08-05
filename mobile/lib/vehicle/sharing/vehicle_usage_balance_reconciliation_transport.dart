import 'dart:convert';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import 'vehicle_fuel_purchase_transport_service.dart';
import 'vehicle_usage_balance.dart';
import 'vehicle_usage_balance_reconciliation.dart';

/// Wire JSON builders / parsers for usage-balance freeze and transfer.
class VehicleUsageBalanceReconciliationTransport {
  VehicleUsageBalanceReconciliationTransport(this._db);

  final AppDatabase _db;

  static const freezeProposeKind = 'vehicleUsageBalanceFreezePropose';
  static const freezeDecisionKind = 'vehicleUsageBalanceFreezeDecision';
  static const freezeCatchUpKind = 'vehicleUsageBalanceFreezeCatchUp';
  static const transferProposeKind = 'vehicleUsageTransferPropose';
  static const transferDecisionKind = 'vehicleUsageTransferDecision';

  VehiclesRepository get _vehicles => VehiclesRepository(_db);

  String exportFreezeProposeJson({
    required String freezeId,
    required String linkId,
    required String vehicleId,
    required String initiatedByRole,
    required DateTime proposedAt,
    required VehicleUsageBalanceBreakdown breakdown,
    String? lastKnownPurchaseId,
  }) {
    return jsonEncode({
      'kind': freezeProposeKind,
      'freezeId': freezeId,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'initiatedByRole': initiatedByRole,
      'proposedAt': proposedAt.toUtc().toIso8601String(),
      'balanceMinor': breakdown.balanceMinor,
      'windowStart': breakdown.windowStart.toUtc().toIso8601String(),
      'windowEnd': breakdown.windowEnd.toUtc().toIso8601String(),
      'breakdownJson': UsageBalanceBreakdownCodec.encode(breakdown),
      if (lastKnownPurchaseId != null && lastKnownPurchaseId.isNotEmpty)
        'lastKnownPurchaseId': lastKnownPurchaseId,
    });
  }

  Map<String, dynamic> parseFreezePropose(String payloadJson) {
    final root = jsonDecode(payloadJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != freezeProposeKind) {
      throw FormatException('unexpected freeze propose kind: ${root['kind']}');
    }
    return root;
  }

  String exportFreezeDecisionJson({
    required String freezeId,
    required String linkId,
    required String vehicleId,
    required bool accepted,
    String? lastKnownPurchaseId,
  }) {
    return jsonEncode({
      'kind': freezeDecisionKind,
      'freezeId': freezeId,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'decision': accepted ? 'accepted' : 'rejected',
      if (lastKnownPurchaseId != null && lastKnownPurchaseId.isNotEmpty)
        'lastKnownPurchaseId': lastKnownPurchaseId,
    });
  }

  Map<String, dynamic> parseFreezeDecision(String payloadJson) {
    final root = jsonDecode(payloadJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != freezeDecisionKind) {
      throw FormatException('unexpected freeze decision kind: ${root['kind']}');
    }
    return root;
  }

  Future<String> exportFreezeCatchUpJson({
    required String freezeId,
    required String linkId,
    required String vehicleId,
    required DateTime confirmedAt,
    String? lastKnownPurchaseId,
  }) async {
    final catchUp = await VehicleFuelPurchaseTransportService(_db)
        .exportCatchUpJson(
      linkId: linkId,
      vehicleId: vehicleId,
      lastKnownPurchaseId: lastKnownPurchaseId,
    );
    final catchRoot = jsonDecode(catchUp) as Map<String, dynamic>;
    return jsonEncode({
      'kind': freezeCatchUpKind,
      'freezeId': freezeId,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'confirmedAt': confirmedAt.toUtc().toIso8601String(),
      'purchases': catchRoot['purchases'] ?? const <dynamic>[],
    });
  }

  Map<String, dynamic> parseFreezeCatchUp(String payloadJson) {
    final root = jsonDecode(payloadJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != freezeCatchUpKind) {
      throw FormatException(
        'unexpected freeze catch-up kind: ${root['kind']}',
      );
    }
    return root;
  }

  /// Imports fuel purchases from a freeze catch-up payload (Emprunteur).
  Future<void> importFreezeCatchUpPurchases(String payloadJson) async {
    final root = parseFreezeCatchUp(payloadJson);
    final synthetic = jsonEncode({
      'kind': VehicleFuelPurchaseTransportService.catchUpKind,
      'linkId': root['linkId'],
      'vehicleId': root['vehicleId'],
      'purchases': root['purchases'] ?? const <dynamic>[],
    });
    await VehicleFuelPurchaseTransportService(_db)
        .importCatchUpPurchases(catchUpJson: synthetic);
  }

  String exportTransferProposeJson({
    required String transferId,
    required String linkId,
    required String vehicleId,
    required String initiatedByRole,
    required int amountMinor,
    required DateTime proposedAt,
  }) {
    return jsonEncode({
      'kind': transferProposeKind,
      'transferId': transferId,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'initiatedByRole': initiatedByRole,
      'amountMinor': amountMinor,
      'proposedAt': proposedAt.toUtc().toIso8601String(),
    });
  }

  Map<String, dynamic> parseTransferPropose(String payloadJson) {
    final root = jsonDecode(payloadJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != transferProposeKind) {
      throw FormatException(
        'unexpected transfer propose kind: ${root['kind']}',
      );
    }
    return root;
  }

  String exportTransferDecisionJson({
    required String transferId,
    required String linkId,
    required String vehicleId,
    required bool accepted,
  }) {
    return jsonEncode({
      'kind': transferDecisionKind,
      'transferId': transferId,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'decision': accepted ? 'accepted' : 'rejected',
    });
  }

  Map<String, dynamic> parseTransferDecision(String payloadJson) {
    final root = jsonDecode(payloadJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != transferDecisionKind) {
      throw FormatException(
        'unexpected transfer decision kind: ${root['kind']}',
      );
    }
    return root;
  }

  Future<String?> latestLocalFuelPurchaseId(String vehicleId) async {
    final latest = await _vehicles.latestFuelPurchase(vehicleId);
    return latest?.id;
  }
}
