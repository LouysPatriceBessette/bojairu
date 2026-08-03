import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../portability/bojairu_documents_layout.dart';
import '../../portability/public_documents_file_sink.dart';
import '../vehicle_gallery_storage.dart';
import '../vehicle_meter_photo_path.dart';
import '../vehicle_owner_contact.dart';

/// Builds and imports encrypted borrower maintenance payloads.
class VehicleMaintenanceTransportService {
  VehicleMaintenanceTransportService(this._db);

  final AppDatabase _db;

  static const String eventKind = 'vehicleMaintenance';

  VehiclesRepository get _vehicles => VehiclesRepository(_db);

  /// Exports maintenance JSON for relay AEAD (Emprunteur → Propriétaire).
  Future<String> exportEventJson({
    required String linkId,
    required String vehicleId,
    required String remoteEventId,
  }) async {
    final event = await (_db.select(_db.maintenanceEvents)
          ..where((t) => t.id.equals(remoteEventId)))
        .getSingleOrNull();
    if (event == null) {
      throw StateError('maintenance event not found: $remoteEventId');
    }
    if (event.vehicleId != vehicleId) {
      throw StateError('maintenance event vehicle mismatch: $remoteEventId');
    }
    final photoPath = event.attachmentPath ?? '';
    final photoB64 = await _encodePhotoBase64(photoPath);
    return jsonEncode({
      'kind': eventKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'remoteEventId': remoteEventId,
      'servicedAt': event.servicedAt.toUtc().toIso8601String(),
      'category': event.category,
      'costMinor': event.costMinor,
      'currency': event.currency,
      'notes': event.notes,
      'meterAtService': event.meterAtService,
      'photoBase64': photoB64,
      'photoIsSentinel': isKnownUnchangedMeterPhotoPath(photoPath),
    });
  }

  /// Imports a maintenance event on the Propriétaire device.
  Future<MaintenanceEvent> importReceivedEvent({
    required String eventJson,
    required String borrowerContactId,
  }) async {
    final root = jsonDecode(eventJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != eventKind) {
      throw FormatException('unexpected maintenance kind: ${root['kind']}');
    }
    final vehicleId = (root['vehicleId'] as String?)?.trim() ?? '';
    if (vehicleId.isEmpty) {
      throw const FormatException('missing vehicleId');
    }
    final vehicle = await _vehicles.getVehicle(vehicleId);
    if (vehicle == null) {
      throw StateError('vehicle not found for maintenance: $vehicleId');
    }
    if (vehicle.ownerContactId != kVehicleOwnerSelfContactId) {
      throw StateError('maintenance target is not owned locally: $vehicleId');
    }

    final costMinor = root['costMinor'] as int?;
    if (costMinor == null) {
      throw const FormatException('missing costMinor');
    }
    final currency = (root['currency'] as String?)?.trim() ?? '';
    if (currency.isEmpty) {
      throw const FormatException('missing currency');
    }
    final category = (root['category'] as String?)?.trim() ?? '';
    if (category.isEmpty) {
      throw const FormatException('missing category');
    }
    final servicedAtRaw = root['servicedAt'] as String?;
    final servicedAt = servicedAtRaw == null
        ? DateTime.now().toUtc()
        : (DateTime.tryParse(servicedAtRaw)?.toUtc() ?? DateTime.now().toUtc());
    final notes = (root['notes'] as String?) ?? '';
    final meterAtService = root['meterAtService'] as int?;
    final attachmentPath = await _materializePhoto(
      vehicleId: vehicleId,
      photoBase64: root['photoBase64'] as String?,
      photoIsSentinel: root['photoIsSentinel'] == true,
    );

    return _vehicles.saveMaintenanceEvent(
      vehicleId: vehicleId,
      servicedAt: servicedAt,
      category: category,
      costMinor: costMinor,
      currency: currency,
      recordedByContactId: borrowerContactId,
      notes: notes,
      meterAtService: meterAtService,
      attachmentPath: attachmentPath,
    );
  }

  Future<String?> _encodePhotoBase64(String photoPath) async {
    if (photoPath.isEmpty || isKnownUnchangedMeterPhotoPath(photoPath)) {
      return null;
    }
    try {
      if (!kIsWeb &&
          (photoPath.startsWith('content://') ||
              (!p.isAbsolute(photoPath) &&
                  !photoPath.contains('vehicle_meter_photos')))) {
        final bytes = await readPublicDocumentBytes(photoPath);
        return base64Encode(bytes);
      }
      if (!kIsWeb && p.isAbsolute(photoPath)) {
        final file = File(photoPath);
        if (await file.exists()) {
          return base64Encode(await file.readAsBytes());
        }
      }
    } catch (e, st) {
      debugPrint('vehicle maintenance photo encode failed: $e\n$st');
    }
    return null;
  }

  Future<String?> _materializePhoto({
    required String vehicleId,
    required String? photoBase64,
    required bool photoIsSentinel,
  }) async {
    if (photoIsSentinel) {
      return kVehicleMeterPhotoKnownUnchangedSentinel;
    }
    if (photoBase64 == null || photoBase64.isEmpty) {
      return null;
    }
    if (kIsWeb) {
      return kVehicleMeterPhotoKnownUnchangedSentinel;
    }
    final bytes = base64Decode(photoBase64);
    final fileName = vehicleGalleryTimestampFileName('.jpg');
    final relativeSubDir =
        BojairuDocumentsLayout.vehicleOdometerPhotosRelativeSubDir(
      vehicleId: vehicleId,
    );
    final written = await writePublicDocumentBytes(
      relativeSubDir: relativeSubDir,
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'image/jpeg',
    );
    return written.storageKey;
  }
}
