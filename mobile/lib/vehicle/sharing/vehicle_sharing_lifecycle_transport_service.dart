import 'dart:convert';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import 'vehicle_usage_balance.dart';
import 'vehicle_usage_balance_reconciliation.dart';

/// Wire JSON for sharing revoke / reactivate (history-preserving).
class VehicleSharingLifecycleTransportService {
  VehicleSharingLifecycleTransportService(this._db);

  final AppDatabase _db;

  static const revokeKind = 'vehicleSharingRevoke';
  static const reactivateProposeKind = 'vehicleSharingReactivatePropose';
  static const reactivateAcceptKind = 'vehicleSharingReactivateAccept';

  VehiclesRepository get _vehicles => VehiclesRepository(_db);

  String exportRevokeJson({
    required String linkId,
    required String vehicleId,
    required DateTime revokedAt,
    required String freezeId,
    required VehicleUsageBalanceBreakdown breakdown,
    String? lastKnownPurchaseId,
  }) {
    return exportRevokeJsonStatic(
      linkId: linkId,
      vehicleId: vehicleId,
      revokedAt: revokedAt,
      freezeId: freezeId,
      breakdown: breakdown,
      lastKnownPurchaseId: lastKnownPurchaseId,
    );
  }

  static String exportRevokeJsonStatic({
    required String linkId,
    required String vehicleId,
    required DateTime revokedAt,
    required String freezeId,
    required VehicleUsageBalanceBreakdown breakdown,
    String? lastKnownPurchaseId,
  }) {
    return jsonEncode({
      'kind': revokeKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'revokedAt': revokedAt.toUtc().toIso8601String(),
      'freeze': {
        'freezeId': freezeId,
        'balanceMinor': breakdown.balanceMinor,
        'windowStart': breakdown.windowStart.toUtc().toIso8601String(),
        'windowEnd': breakdown.windowEnd.toUtc().toIso8601String(),
        'breakdownJson': UsageBalanceBreakdownCodec.encode(breakdown),
        'confirmedAt': revokedAt.toUtc().toIso8601String(),
        if (lastKnownPurchaseId != null && lastKnownPurchaseId.isNotEmpty)
          'lastKnownPurchaseId': lastKnownPurchaseId,
      },
    });
  }

  Map<String, dynamic> parseRevoke(String payloadJson) {
    return parseRevokeStatic(payloadJson);
  }

  static Map<String, dynamic> parseRevokeStatic(String payloadJson) {
    final root = jsonDecode(payloadJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != revokeKind) {
      throw FormatException('unexpected revoke kind: ${root['kind']}');
    }
    return root;
  }

  Future<String> exportReactivateProposeJson(String linkId) async {
    final link = await _vehicles.getSharingLink(linkId);
    if (link == null) {
      throw StateError('sharing link not found: $linkId');
    }
    final vehicle = await _vehicles.getVehicle(link.vehicleId);
    if (vehicle == null) {
      throw StateError('vehicle not found: ${link.vehicleId}');
    }
    return jsonEncode({
      'kind': reactivateProposeKind,
      'linkId': link.id,
      'vehicleId': link.vehicleId,
      'proposedAt': DateTime.now().toUtc().toIso8601String(),
      'vehicleLabel': vehicle.displayLabel,
      if (link.expiresAt != null)
        'expiresAt': link.expiresAt!.toUtc().toIso8601String(),
    });
  }

  Map<String, dynamic> parseReactivatePropose(String payloadJson) {
    final root = jsonDecode(payloadJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != reactivateProposeKind) {
      throw FormatException(
        'unexpected reactivate propose kind: ${root['kind']}',
      );
    }
    return root;
  }

  String exportReactivateAcceptJson({
    required String linkId,
    required String vehicleId,
  }) {
    return jsonEncode({
      'kind': reactivateAcceptKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'acceptedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Map<String, dynamic> parseReactivateAccept(String payloadJson) {
    final root = jsonDecode(payloadJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != reactivateAcceptKind) {
      throw FormatException(
        'unexpected reactivate accept kind: ${root['kind']}',
      );
    }
    return root;
  }
}
