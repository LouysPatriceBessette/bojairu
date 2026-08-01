import 'dart:convert';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';

/// Builds and imports encrypted vehicle-sharing offer payloads.
class VehicleSharingOfferTransportService {
  VehicleSharingOfferTransportService(this._db);

  final AppDatabase _db;

  static const String offerKind = 'vehicleSharingOffer';
  static const String acceptKind = 'vehicleSharingOfferAccept';

  VehiclesRepository get _vehicles => VehiclesRepository(_db);

  /// Exports offer JSON for relay AEAD (Propriétaire → Emprunteur).
  Future<String> exportOfferJson(String linkId) async {
    final link = await _vehicles.getSharingLink(linkId);
    if (link == null) {
      throw StateError('sharing link not found: $linkId');
    }
    final vehicle = await _vehicles.getVehicle(link.vehicleId);
    if (vehicle == null) {
      throw StateError('vehicle not found: ${link.vehicleId}');
    }
    return jsonEncode({
      'kind': offerKind,
      'linkId': link.id,
      'createdAt': link.createdAt.toUtc().toIso8601String(),
      if (link.expiresAt != null)
        'expiresAt': link.expiresAt!.toUtc().toIso8601String(),
      'ratePerKmMinor': link.ratePerKmMinor,
      'rateCurrency': link.rateCurrency,
      'availabilityWeekJson': link.availabilityWeekJson,
      'ownerRulesText': link.ownerRulesText,
      'vehicle': {
        'id': vehicle.id,
        'vehicleKind': vehicle.vehicleKind,
        'displayLabel': vehicle.displayLabel,
        'make': vehicle.make,
        'model': vehicle.model,
        'color': vehicle.color,
        'modelYear': vehicle.modelYear,
        'licensePlate': vehicle.licensePlate,
        'fuelTankCapacityLiters': vehicle.fuelTankCapacityLiters,
        'consumptionEstimationMode': vehicle.consumptionEstimationMode,
        'requireDetailedDrivingMixForBorrowers':
            vehicle.requireDetailedDrivingMixForBorrowers,
      },
    });
  }

  /// Imports an offer on the Emprunteur device. Returns display label for notifs.
  Future<({String linkId, String vehicleLabel})> importReceivedOffer({
    required String offerJson,
    required String senderContactId,
  }) async {
    final root = jsonDecode(offerJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != offerKind) {
      throw FormatException('unexpected offer kind: ${root['kind']}');
    }
    final linkId = (root['linkId'] as String?)?.trim() ?? '';
    if (linkId.isEmpty) {
      throw const FormatException('missing linkId');
    }
    final vehicleRaw = root['vehicle'];
    if (vehicleRaw is! Map) {
      throw const FormatException('missing vehicle snapshot');
    }
    final vehicleMap = Map<String, dynamic>.from(vehicleRaw);
    final vehicleId = (vehicleMap['id'] as String?)?.trim() ?? '';
    if (vehicleId.isEmpty) {
      throw const FormatException('missing vehicle.id');
    }
    final displayLabel =
        ((vehicleMap['displayLabel'] as String?) ?? '').trim().isEmpty
            ? vehicleId
            : (vehicleMap['displayLabel'] as String).trim();

    final createdAtRaw = root['createdAt'] as String?;
    final createdAt = createdAtRaw == null
        ? DateTime.now().toUtc()
        : (DateTime.tryParse(createdAtRaw)?.toUtc() ?? DateTime.now().toUtc());
    final expiresAtRaw = root['expiresAt'] as String?;
    final expiresAt = expiresAtRaw == null
        ? null
        : DateTime.tryParse(expiresAtRaw)?.toUtc();

    await _vehicles.upsertExternalOwnedVehicle(
      vehicleId: vehicleId,
      ownerContactId: senderContactId,
      vehicleKind: (vehicleMap['vehicleKind'] as String?) ?? 'car',
      displayLabel: displayLabel,
      make: (vehicleMap['make'] as String?) ?? '',
      model: (vehicleMap['model'] as String?) ?? '',
      color: (vehicleMap['color'] as String?) ?? '',
      modelYear: vehicleMap['modelYear'] as int?,
      licensePlate: (vehicleMap['licensePlate'] as String?) ?? '',
      fuelTankCapacityLiters:
          (vehicleMap['fuelTankCapacityLiters'] as num?)?.toDouble(),
      consumptionEstimationMode:
          (vehicleMap['consumptionEstimationMode'] as String?) ?? 'detailed',
      requireDetailedDrivingMixForBorrowers:
          vehicleMap['requireDetailedDrivingMixForBorrowers'] == true,
    );

    await _vehicles.upsertInboundPendingOffer(
      linkId: linkId,
      vehicleId: vehicleId,
      ownerContactId: senderContactId,
      createdAt: createdAt,
      ratePerKmMinor: (root['ratePerKmMinor'] as int?) ?? 0,
      rateCurrency: (root['rateCurrency'] as String?) ?? '',
      availabilityWeekJson: (root['availabilityWeekJson'] as String?) ?? '',
      ownerRulesText: (root['ownerRulesText'] as String?) ?? '',
      expiresAt: expiresAt,
    );

    return (linkId: linkId, vehicleLabel: displayLabel);
  }

  String exportAcceptJson({
    required String linkId,
    required DateTime acceptedAt,
  }) {
    return jsonEncode({
      'kind': acceptKind,
      'linkId': linkId,
      'acceptedAt': acceptedAt.toUtc().toIso8601String(),
    });
  }

  /// Applies accept on the Propriétaire device. Returns whether a link was updated.
  Future<bool> importReceivedAccept({required String acceptJson}) async {
    final root = jsonDecode(acceptJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != acceptKind) {
      throw FormatException('unexpected accept kind: ${root['kind']}');
    }
    final linkId = (root['linkId'] as String?)?.trim() ?? '';
    if (linkId.isEmpty) {
      throw const FormatException('missing linkId');
    }
    final acceptedAtRaw = root['acceptedAt'] as String?;
    final acceptedAt = acceptedAtRaw == null
        ? null
        : DateTime.tryParse(acceptedAtRaw)?.toUtc();
    return _vehicles.applyRemoteSharingOfferAccept(
      linkId: linkId,
      acceptedAt: acceptedAt,
    );
  }
}
