import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../portability/bojairu_documents_layout.dart';
import '../../portability/public_documents_file_sink.dart';
import '../vehicle_gap_correction.dart';
import '../vehicle_gap_flow.dart';
import '../vehicle_gallery_storage.dart';
import '../vehicle_meter_photo_path.dart';
import '../vehicle_owner_contact.dart';

/// Result of importing a remote borrower session start on the owner device.
class VehicleUseSessionStartImportResult {
  const VehicleUseSessionStartImportResult({
    required this.vehicleId,
    required this.vehicleLabel,
    required this.conflictWithOpenSession,
    this.correctionReadingId,
    this.localUseId,
  });

  final String vehicleId;
  final String vehicleLabel;
  final bool conflictWithOpenSession;
  final String? correctionReadingId;
  final String? localUseId;
}

/// Builds and imports encrypted borrower use-session payloads.
class VehicleUseSessionTransportService {
  VehicleUseSessionTransportService(this._db);

  final AppDatabase _db;

  static const String startKind = 'vehicleUseSessionStart';
  static const String endKind = 'vehicleUseSessionEnd';

  VehiclesRepository get _vehicles => VehiclesRepository(_db);

  /// Exports start JSON for relay AEAD (Emprunteur → Propriétaire).
  Future<String> exportSessionStartJson({
    required String linkId,
    required String vehicleId,
    required String remoteUseId,
    required String startReadingId,
  }) async {
    final reading = await _vehicles.getMeterReading(startReadingId);
    if (reading == null) {
      throw StateError('start reading not found: $startReadingId');
    }
    final photoB64 = await _encodePhotoBase64(reading.photoPath);
    final lastKnown = await _vehicles.latestFuelPurchase(vehicleId);
    return jsonEncode({
      'kind': startKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'remoteUseId': remoteUseId,
      'startedAt': reading.recordedAt.toUtc().toIso8601String(),
      'meterTenths': reading.value,
      'unit': reading.unit,
      'isFullTank': reading.isFullTank,
      'tankFillFraction': reading.tankFillFraction,
      'photoBase64': photoB64,
      'photoIsSentinel': isKnownUnchangedMeterPhotoPath(reading.photoPath),
      if (lastKnown != null) 'lastKnownPurchaseId': lastKnown.id,
    });
  }

  /// Reads the optional fuel catch-up cursor from a session-start payload.
  static String? lastKnownPurchaseIdFromSessionJson(String sessionJson) {
    final root = jsonDecode(sessionJson) as Map<String, dynamic>;
    final id = (root['lastKnownPurchaseId'] as String?)?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Exports end JSON for relay AEAD (Emprunteur → Propriétaire).
  Future<String> exportSessionEndJson({
    required String linkId,
    required String vehicleId,
    required String remoteUseId,
    required String endReadingId,
    int? drivingRoutePercent,
    int? drivingCityPercent,
    int? drivingTrafficPercent,
  }) async {
    final reading = await _vehicles.getMeterReading(endReadingId);
    if (reading == null) {
      throw StateError('end reading not found: $endReadingId');
    }
    final photoB64 = await _encodePhotoBase64(reading.photoPath);
    return jsonEncode({
      'kind': endKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'remoteUseId': remoteUseId,
      'endedAt': reading.recordedAt.toUtc().toIso8601String(),
      'meterTenths': reading.value,
      'unit': reading.unit,
      'isFullTank': reading.isFullTank,
      'tankFillFraction': reading.tankFillFraction,
      'photoBase64': photoB64,
      'photoIsSentinel': isKnownUnchangedMeterPhotoPath(reading.photoPath),
      'drivingRoutePercent': ?drivingRoutePercent,
      'drivingCityPercent': ?drivingCityPercent,
      'drivingTrafficPercent': ?drivingTrafficPercent,
    });
  }

  /// Imports a session start on the Propriétaire device.
  Future<VehicleUseSessionStartImportResult> importReceivedSessionStart({
    required String sessionJson,
    required String borrowerContactId,
  }) async {
    final root = jsonDecode(sessionJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != startKind) {
      throw FormatException('unexpected session start kind: ${root['kind']}');
    }
    final vehicleId = (root['vehicleId'] as String?)?.trim() ?? '';
    if (vehicleId.isEmpty) {
      throw const FormatException('missing vehicleId');
    }
    final vehicle = await _vehicles.getVehicle(vehicleId);
    if (vehicle == null) {
      throw StateError('vehicle not found for session start: $vehicleId');
    }
    if (vehicle.ownerContactId != kVehicleOwnerSelfContactId) {
      throw StateError('session start target is not owned locally: $vehicleId');
    }

    final meterTenths = root['meterTenths'] as int?;
    if (meterTenths == null) {
      throw const FormatException('missing meterTenths');
    }
    final startedAtRaw = root['startedAt'] as String?;
    final startedAt = startedAtRaw == null
        ? DateTime.now().toUtc()
        : (DateTime.tryParse(startedAtRaw)?.toUtc() ?? DateTime.now().toUtc());
    final photoPath = await _materializePhoto(
      vehicleId: vehicleId,
      photoBase64: root['photoBase64'] as String?,
      photoIsSentinel: root['photoIsSentinel'] == true,
    );
    final unit = (root['unit'] as String?)?.trim().isNotEmpty == true
        ? (root['unit'] as String).trim()
        : _vehicles.meterUnitForVehicle(vehicle);
    final isFullTank = root['isFullTank'] as bool?;
    final tankFillFraction = root['tankFillFraction'] as int?;
    final label = vehicle.displayLabel.trim().isEmpty
        ? vehicleId
        : vehicle.displayLabel.trim();

    final openUse = await _vehicles.openUseForVehicle(vehicleId);
    final previous = await _vehicles.latestNonCorrectionMeterReading(vehicleId);

    if (openUse == null) {
      VehicleOdometerGap? pendingGap;
      if (previous != null && meterTenths > previous.value) {
        final persisted = await persistConfirmedMeterDivergence(
          repo: _vehicles,
          vehicle: vehicle,
          previousReading: previous,
          parsedMeter: meterTenths,
          divergenceTenths: meterTenths - previous.value,
          photoPath: photoPath,
          actingContactId: borrowerContactId,
          correctionContext: GapCorrectionContext.sessionStart,
          correctionRecordedAt: startedAt,
        );
        pendingGap = persisted.gap;
      }

      final reading = await _vehicles.saveMeterReading(
        vehicleId: vehicleId,
        value: meterTenths,
        unit: unit,
        photoPath: photoPath,
        recordedByContactId: borrowerContactId,
        role: MeterReadingRole.sessionStart,
        isFullTank: isFullTank,
        tankFillFraction: tankFillFraction,
        recordedAt: startedAt,
      );
      if (pendingGap != null && previous != null) {
        await linkGapTriggerReading(
          repo: _vehicles,
          gapId: pendingGap.id,
          correctionReadingId: pendingGap.correctionReadingId!,
          previousReadingId: previous.id,
          triggerReadingId: reading.id,
        );
      }
      final use = await _vehicles.openUseSession(
        vehicleId: vehicleId,
        attributedContactId: borrowerContactId,
        startReadingId: reading.id,
      );
      return VehicleUseSessionStartImportResult(
        vehicleId: vehicleId,
        vehicleLabel: label,
        conflictWithOpenSession: false,
        localUseId: use.id,
        correctionReadingId: pendingGap?.correctionReadingId,
      );
    }

    if (previous == null) {
      throw StateError('open session without prior meter reading: $vehicleId');
    }

    VehicleOdometerGap? pendingGap;
    if (meterTenths > previous.value) {
      final persisted = await persistConfirmedMeterDivergence(
        repo: _vehicles,
        vehicle: vehicle,
        previousReading: previous,
        parsedMeter: meterTenths,
        divergenceTenths: meterTenths - previous.value,
        photoPath: photoPath,
        actingContactId: borrowerContactId,
        correctionContext: GapCorrectionContext.sessionStart,
        vehicleUseId: openUse.id,
        correctionRecordedAt: startedAt,
      );
      pendingGap = persisted.gap;
    }

    final trigger = await _vehicles.saveMeterReading(
      vehicleId: vehicleId,
      value: meterTenths,
      unit: unit,
      photoPath: photoPath,
      recordedByContactId: borrowerContactId,
      role: MeterReadingRole.sessionStart,
      isFullTank: isFullTank,
      tankFillFraction: tankFillFraction,
      recordedAt: startedAt,
    );
    if (pendingGap != null) {
      await linkGapTriggerReading(
        repo: _vehicles,
        gapId: pendingGap.id,
        correctionReadingId: pendingGap.correctionReadingId!,
        previousReadingId: previous.id,
        triggerReadingId: trigger.id,
      );
    }

    return VehicleUseSessionStartImportResult(
      vehicleId: vehicleId,
      vehicleLabel: label,
      conflictWithOpenSession: true,
      correctionReadingId: pendingGap?.correctionReadingId ?? trigger.id,
    );
  }

  /// Imports a session end on the Propriétaire device.
  ///
  /// Returns whether an open session was closed.
  Future<bool> importReceivedSessionEnd({
    required String sessionJson,
    required String borrowerContactId,
  }) async {
    final root = jsonDecode(sessionJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != endKind) {
      throw FormatException('unexpected session end kind: ${root['kind']}');
    }
    final vehicleId = (root['vehicleId'] as String?)?.trim() ?? '';
    if (vehicleId.isEmpty) {
      throw const FormatException('missing vehicleId');
    }
    final vehicle = await _vehicles.getVehicle(vehicleId);
    if (vehicle == null) {
      return false;
    }
    final openUse = await _vehicles.openUseForVehicle(vehicleId);
    if (openUse == null) {
      return false;
    }
    if (openUse.attributedContactId != borrowerContactId) {
      // Likely a conflict residue (different actor still open).
      return false;
    }

    final meterTenths = root['meterTenths'] as int?;
    if (meterTenths == null) {
      throw const FormatException('missing meterTenths');
    }
    final endedAtRaw = root['endedAt'] as String?;
    final endedAt = endedAtRaw == null
        ? DateTime.now().toUtc()
        : (DateTime.tryParse(endedAtRaw)?.toUtc() ?? DateTime.now().toUtc());
    final photoPath = await _materializePhoto(
      vehicleId: vehicleId,
      photoBase64: root['photoBase64'] as String?,
      photoIsSentinel: root['photoIsSentinel'] == true,
    );
    final unit = (root['unit'] as String?)?.trim().isNotEmpty == true
        ? (root['unit'] as String).trim()
        : _vehicles.meterUnitForVehicle(vehicle);
    final isFullTank = root['isFullTank'] as bool?;
    final tankFillFraction = root['tankFillFraction'] as int?;

    final endReading = await _vehicles.saveMeterReading(
      vehicleId: vehicleId,
      value: meterTenths,
      unit: unit,
      photoPath: photoPath,
      recordedByContactId: borrowerContactId,
      role: MeterReadingRole.sessionEnd,
      vehicleUseId: openUse.id,
      isFullTank: isFullTank,
      tankFillFraction: tankFillFraction,
      recordedAt: endedAt,
    );
    await _vehicles.closeUseSession(
      useId: openUse.id,
      endReadingId: endReading.id,
      drivingRoutePercent: root['drivingRoutePercent'] as int?,
      drivingCityPercent: root['drivingCityPercent'] as int?,
      drivingTrafficPercent: root['drivingTrafficPercent'] as int?,
    );
    return true;
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
      debugPrint('vehicle session photo encode failed: $e\n$st');
    }
    return null;
  }

  Future<String> _materializePhoto({
    required String vehicleId,
    required String? photoBase64,
    required bool photoIsSentinel,
  }) async {
    if (photoIsSentinel || photoBase64 == null || photoBase64.isEmpty) {
      return kVehicleMeterPhotoKnownUnchangedSentinel;
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
