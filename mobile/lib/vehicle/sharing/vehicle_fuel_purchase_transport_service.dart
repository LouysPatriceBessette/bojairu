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

/// Builds and imports encrypted borrower fuel-purchase payloads.
class VehicleFuelPurchaseTransportService {
  VehicleFuelPurchaseTransportService(this._db);

  final AppDatabase _db;

  static const String purchaseKind = 'vehicleFuelPurchase';

  VehiclesRepository get _vehicles => VehiclesRepository(_db);

  /// Exports purchase JSON for relay AEAD (Emprunteur → Propriétaire).
  Future<String> exportPurchaseJson({
    required String linkId,
    required String vehicleId,
    required String remotePurchaseId,
  }) async {
    final purchase = await (_db.select(_db.fuelPurchases)
          ..where((t) => t.id.equals(remotePurchaseId)))
        .getSingleOrNull();
    if (purchase == null) {
      throw StateError('fuel purchase not found: $remotePurchaseId');
    }
    if (purchase.vehicleId != vehicleId) {
      throw StateError('fuel purchase vehicle mismatch: $remotePurchaseId');
    }
    final photoPath = purchase.meterPhotoPath ?? '';
    final photoB64 = await _encodePhotoBase64(photoPath);
    return jsonEncode({
      'kind': purchaseKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'remotePurchaseId': remotePurchaseId,
      'purchasedAt': purchase.purchasedAt.toUtc().toIso8601String(),
      'costMinor': purchase.costMinor,
      'currency': purchase.currency,
      'isFullTank': purchase.isFullTank,
      'volumeLiters': purchase.volumeLiters,
      'meterTenths': purchase.meterReadingValue,
      'tankFillFraction': purchase.tankFillFraction,
      'photoBase64': photoB64,
      'photoIsSentinel': isKnownUnchangedMeterPhotoPath(photoPath),
    });
  }

  /// Imports a fuel purchase on the Propriétaire device.
  Future<FuelPurchase> importReceivedPurchase({
    required String purchaseJson,
    required String borrowerContactId,
  }) async {
    final root = jsonDecode(purchaseJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != purchaseKind) {
      throw FormatException('unexpected fuel purchase kind: ${root['kind']}');
    }
    final vehicleId = (root['vehicleId'] as String?)?.trim() ?? '';
    if (vehicleId.isEmpty) {
      throw const FormatException('missing vehicleId');
    }
    final vehicle = await _vehicles.getVehicle(vehicleId);
    if (vehicle == null) {
      throw StateError('vehicle not found for fuel purchase: $vehicleId');
    }
    if (vehicle.ownerContactId != kVehicleOwnerSelfContactId) {
      throw StateError('fuel purchase target is not owned locally: $vehicleId');
    }

    final costMinor = root['costMinor'] as int?;
    if (costMinor == null) {
      throw const FormatException('missing costMinor');
    }
    final currency = (root['currency'] as String?)?.trim() ?? '';
    if (currency.isEmpty) {
      throw const FormatException('missing currency');
    }
    final isFullTank = root['isFullTank'] as bool? ?? true;
    final purchasedAtRaw = root['purchasedAt'] as String?;
    final purchasedAt = purchasedAtRaw == null
        ? DateTime.now().toUtc()
        : (DateTime.tryParse(purchasedAtRaw)?.toUtc() ??
            DateTime.now().toUtc());
    final volumeRaw = root['volumeLiters'];
    final volumeLiters = volumeRaw is num ? volumeRaw.toDouble() : null;
    final meterTenths = root['meterTenths'] as int?;
    final tankFillFraction = root['tankFillFraction'] as int?;
    final photoPath = await _materializePhoto(
      vehicleId: vehicleId,
      photoBase64: root['photoBase64'] as String?,
      photoIsSentinel: root['photoIsSentinel'] == true,
    );

    return _vehicles.saveFuelPurchase(
      vehicleId: vehicleId,
      purchasedAt: purchasedAt,
      costMinor: costMinor,
      currency: currency,
      isFullTank: isFullTank,
      recordedByContactId: borrowerContactId,
      volumeLiters: volumeLiters,
      meterReadingValue: meterTenths,
      meterPhotoPath: photoPath,
      tankFillFraction: tankFillFraction,
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
      debugPrint('vehicle fuel photo encode failed: $e\n$st');
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
