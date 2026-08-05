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

/// Builds and imports encrypted fuel-purchase payloads (borrower→owner and
/// owner→borrower catch-up).
class VehicleFuelPurchaseTransportService {
  VehicleFuelPurchaseTransportService(this._db);

  final AppDatabase _db;

  static const String purchaseKind = 'vehicleFuelPurchase';
  static const String catchUpKind = 'vehicleFuelPurchaseCatchUp';

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
  ///
  /// Preserves [remotePurchaseId] as the local row id (idempotent).
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

    final remotePurchaseId =
        (root['remotePurchaseId'] as String?)?.trim() ?? '';
    if (remotePurchaseId.isEmpty) {
      throw const FormatException('missing remotePurchaseId');
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
      id: remotePurchaseId,
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

  /// Builds catch-up JSON (Propriétaire → Emprunteur).
  ///
  /// Always returns a payload (possibly with an empty `purchases` list) so the
  /// Emprunteur can clear the awaiting-catch-up flag.
  Future<String> exportCatchUpJson({
    required String linkId,
    required String vehicleId,
    String? lastKnownPurchaseId,
  }) async {
    final purchases = await _vehicles.fuelPurchasesForSessionStartCatchUp(
      vehicleId,
      lastKnownPurchaseId: lastKnownPurchaseId,
    );

    final items = <Map<String, dynamic>>[];
    for (final purchase in purchases) {
      final photoPath = purchase.meterPhotoPath ?? '';
      items.add({
        'id': purchase.id,
        'purchasedAt': purchase.purchasedAt.toUtc().toIso8601String(),
        'costMinor': purchase.costMinor,
        'currency': purchase.currency,
        'isFullTank': purchase.isFullTank,
        'volumeLiters': purchase.volumeLiters,
        'meterTenths': purchase.meterReadingValue,
        'tankFillFraction': purchase.tankFillFraction,
        'recordedByOwner':
            vehicleContactIsOwnerSelf(purchase.recordedByContactId),
        'recordedByContactId':
            vehicleContactIsOwnerSelf(purchase.recordedByContactId)
                ? null
                : purchase.recordedByContactId,
        'photoBase64': await _encodePhotoBase64(photoPath),
        'photoIsSentinel': isKnownUnchangedMeterPhotoPath(photoPath),
      });
    }

    return jsonEncode({
      'kind': catchUpKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'purchases': items,
    });
  }

  /// Imports owner catch-up purchases on the Emprunteur device (shared vehicle).
  ///
  /// Empty `purchases` is valid (ack-only). Always marks the open session's
  /// fuel catch-up response as received for [vehicleId].
  Future<List<FuelPurchase>> importCatchUpPurchases({
    required String catchUpJson,
  }) async {
    final root = jsonDecode(catchUpJson) as Map<String, dynamic>;
    if ((root['kind'] as String?) != catchUpKind) {
      throw FormatException('unexpected fuel catch-up kind: ${root['kind']}');
    }
    final vehicleId = (root['vehicleId'] as String?)?.trim() ?? '';
    if (vehicleId.isEmpty) {
      throw const FormatException('missing vehicleId');
    }
    final vehicle = await _vehicles.getVehicle(vehicleId);
    if (vehicle == null) {
      throw StateError('vehicle not found for fuel catch-up: $vehicleId');
    }
    if (vehicle.ownerContactId == kVehicleOwnerSelfContactId) {
      throw StateError(
        'fuel catch-up target must be a shared (external owner) vehicle: '
        '$vehicleId',
      );
    }

    final rawPurchases = root['purchases'];
    if (rawPurchases is! List) {
      throw const FormatException('catch-up purchases missing');
    }

    final imported = <FuelPurchase>[];
    for (final raw in rawPurchases) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final purchaseId = (item['id'] as String?)?.trim() ?? '';
      if (purchaseId.isEmpty) {
        throw const FormatException('catch-up purchase missing id');
      }
      final costMinor = item['costMinor'] as int?;
      if (costMinor == null) {
        throw const FormatException('catch-up purchase missing costMinor');
      }
      final currency = (item['currency'] as String?)?.trim() ?? '';
      if (currency.isEmpty) {
        throw const FormatException('catch-up purchase missing currency');
      }
      final isFullTank = item['isFullTank'] as bool? ?? true;
      final purchasedAtRaw = item['purchasedAt'] as String?;
      final purchasedAt = purchasedAtRaw == null
          ? DateTime.now().toUtc()
          : (DateTime.tryParse(purchasedAtRaw)?.toUtc() ??
              DateTime.now().toUtc());
      final volumeRaw = item['volumeLiters'];
      final volumeLiters = volumeRaw is num ? volumeRaw.toDouble() : null;
      final meterTenths = item['meterTenths'] as int?;
      final tankFillFraction = item['tankFillFraction'] as int?;
      final recordedByOwner = item['recordedByOwner'] == true;
      final peerRecorder = (item['recordedByContactId'] as String?)?.trim();
      final recordedByContactId = recordedByOwner
          ? vehicle.ownerContactId
          : (peerRecorder != null && peerRecorder.isNotEmpty
              ? peerRecorder
              : kVehicleBorrowerSelfContactId);
      final photoPath = await _materializePhoto(
        vehicleId: vehicleId,
        photoBase64: item['photoBase64'] as String?,
        photoIsSentinel: item['photoIsSentinel'] == true,
      );

      imported.add(
        await _vehicles.saveFuelPurchase(
          id: purchaseId,
          vehicleId: vehicleId,
          purchasedAt: purchasedAt,
          costMinor: costMinor,
          currency: currency,
          isFullTank: isFullTank,
          recordedByContactId: recordedByContactId,
          volumeLiters: volumeLiters,
          meterReadingValue: meterTenths,
          meterPhotoPath: photoPath,
          tankFillFraction: tankFillFraction,
        ),
      );
    }

    await _vehicles.markFuelCatchUpResponseReceived(vehicleId);
    return imported;
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
