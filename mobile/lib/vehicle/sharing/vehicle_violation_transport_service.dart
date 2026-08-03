import 'dart:convert';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../vehicle_owner_contact.dart';

/// Builds and imports encrypted borrower traffic-violation payloads.
class VehicleViolationTransportService {
  VehicleViolationTransportService(this._db);

  final AppDatabase _db;

  static const String violationKind = 'vehicleTrafficViolation';

  VehiclesRepository get _vehicles => VehiclesRepository(_db);

  /// Exports violation JSON for relay AEAD (Emprunteur → Propriétaire).
  Future<String> exportViolationJson({
    required String linkId,
    required String vehicleId,
    required String remoteViolationId,
  }) async {
    final violation = await (_db.select(_db.trafficViolations)
          ..where((t) => t.id.equals(remoteViolationId)))
        .getSingleOrNull();
    if (violation == null) {
      throw StateError('traffic violation not found: $remoteViolationId');
    }
    if (violation.vehicleId != vehicleId) {
      throw StateError(
        'traffic violation vehicle mismatch: $remoteViolationId',
      );
    }
    return jsonEncode({
      'kind': violationKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'remoteViolationId': remoteViolationId,
      'violatedAt': violation.violatedAt.toUtc().toIso8601String(),
      'violationType': violation.violationType,
      'amountMinor': violation.amountMinor,
      'currency': violation.currency,
      'notes': violation.notes,
    });
  }

  /// Imports a traffic violation on the Propriétaire device.
  Future<TrafficViolation> importReceivedViolation({
    required String violationJson,
    required String borrowerContactId,
  }) async {
    final root = jsonDecode(violationJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != violationKind) {
      throw FormatException(
        'unexpected traffic violation kind: ${root['kind']}',
      );
    }
    final vehicleId = (root['vehicleId'] as String?)?.trim() ?? '';
    if (vehicleId.isEmpty) {
      throw const FormatException('missing vehicleId');
    }
    final vehicle = await _vehicles.getVehicle(vehicleId);
    if (vehicle == null) {
      throw StateError('vehicle not found for traffic violation: $vehicleId');
    }
    if (vehicle.ownerContactId != kVehicleOwnerSelfContactId) {
      throw StateError(
        'traffic violation target is not owned locally: $vehicleId',
      );
    }

    final amountMinor = root['amountMinor'] as int?;
    if (amountMinor == null) {
      throw const FormatException('missing amountMinor');
    }
    final currency = (root['currency'] as String?)?.trim() ?? '';
    if (currency.isEmpty) {
      throw const FormatException('missing currency');
    }
    final violationType = (root['violationType'] as String?)?.trim() ?? '';
    if (violationType.isEmpty) {
      throw const FormatException('missing violationType');
    }
    final violatedAtRaw = root['violatedAt'] as String?;
    final violatedAt = violatedAtRaw == null
        ? DateTime.now().toUtc()
        : (DateTime.tryParse(violatedAtRaw)?.toUtc() ?? DateTime.now().toUtc());
    final notes = (root['notes'] as String?) ?? '';

    return _vehicles.saveTrafficViolation(
      vehicleId: vehicleId,
      violatedAt: violatedAt,
      violationType: violationType,
      amountMinor: amountMinor,
      currency: currency,
      recordedByContactId: borrowerContactId,
      notes: notes,
    );
  }
}
