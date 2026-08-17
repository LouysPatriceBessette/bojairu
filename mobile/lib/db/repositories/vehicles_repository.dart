import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' as drift;

import '../../activity/relay_activity_log_service.dart';
import '../app_database.dart';
import '../../vehicle/vehicle_gallery_storage.dart';
import '../../vehicle/vehicle_meter_photo_picker.dart';
import '../../vehicle/vehicle_meter_photo_path.dart';
import '../../vehicle/vehicle_maintenance_categories.dart';
import '../../vehicle/vehicle_consumption_estimation_mode.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../vehicle/vehicle_gap_correction.dart';
import '../../vehicle/vehicle_meter_journal_sort.dart';
import '../../vehicle/vehicle_meter_reading_effective.dart';
import '../../vehicle/vehicle_owner_contact.dart';
import '../../vehicle/vehicle_owned_active_cap.dart';
import '../../vehicle/vehicle_emprunteur_cap.dart';
import '../../entitlement/vehicle_license_lifecycle_sync.dart';

const String kVehicleGapAttributionUnknown = 'unknown';

bool vehicleIsActive(Vehicle vehicle) => vehicle.deactivatedAt == null;

class VehicleGalleryPhotoDraft {
  VehicleGalleryPhotoDraft({required this.sourcePath, this.description = ''});

  final String sourcePath;
  String description;
}

class VehicleGalleryDraft {
  VehicleGalleryDraft({
    List<VehicleGalleryPhotoDraft>? photos,
    this.displayTitle,
  }) : photos = photos ?? <VehicleGalleryPhotoDraft>[];

  final List<VehicleGalleryPhotoDraft> photos;
  final String? displayTitle;
}

String _newVehicleId(String prefix) {
  final bytes = List<int>.generate(12, (_) => Random.secure().nextInt(256));
  return '$prefix${base64Url.encode(bytes).replaceAll('=', '')}';
}

enum VehicleSharingLinkStatus {
  pending,
  active,
  expired,
  revoked,
  /// Owner proposed reactivation; Emprunteur has not accepted yet.
  reactivatePending;

  String get wire => name;

  static VehicleSharingLinkStatus? fromWire(String? raw) {
    if (raw == null) return null;
    for (final s in VehicleSharingLinkStatus.values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

enum MeterReadingRole {
  sessionStart,
  sessionEnd,
  standalone,
  fuelPurchase,
  maintenance,
  correction;

  String get wire => name;

  static MeterReadingRole? fromWire(String? raw) {
    if (raw == null) return null;
    for (final r in MeterReadingRole.values) {
      if (r.name == raw) return r;
    }
    return null;
  }
}

class VehiclesRepository {
  VehiclesRepository(this._db);

  final AppDatabase _db;

  Future<List<Vehicle>> listOwnedVehicles() async {
    final rows = await (_db.select(
      _db.vehicles,
    )..where((t) => t.ownerContactId.equals(kVehicleOwnerSelfContactId))).get();
    rows.sort((a, b) {
      final aInactive = a.deactivatedAt != null;
      final bInactive = b.deactivatedAt != null;
      if (aInactive != bInactive) {
        return aInactive ? 1 : -1;
      }
      return a.displayLabel.toLowerCase().compareTo(
        b.displayLabel.toLowerCase(),
      );
    });
    return rows;
  }

  Future<List<Vehicle>> listActiveOwnedVehicles() async {
    final rows = await listOwnedVehicles();
    return rows.where(vehicleIsActive).toList();
  }

  Future<int> countActiveOwnedVehicles() async {
    final rows =
        await (_db.select(_db.vehicles)..where(
              (t) =>
                  t.ownerContactId.equals(kVehicleOwnerSelfContactId) &
                  t.deactivatedAt.isNull(),
            ))
            .get();
    return rows.length;
  }

  Future<Vehicle?> getVehicle(String id) => (_db.select(
    _db.vehicles,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> clearSaleImportUndoAvailable(String vehicleId) async {
    await (_db.update(
      _db.vehicles,
    )..where((t) => t.id.equals(vehicleId))).write(
      VehiclesCompanion(saleImportUndoAvailable: const drift.Value(false)),
    );
  }

  Future<void> ensureVehicleActiveForWrite(String vehicleId) async {
    final vehicle = await getVehicle(vehicleId);
    if (vehicle == null) {
      throw StateError('vehicle missing: $vehicleId');
    }
    if (!vehicleIsActive(vehicle)) {
      throw VehicleDeactivatedException(vehicleId);
    }
  }

  /// Permanently deactivates an owned vehicle (read-only thereafter).
  Future<Vehicle> deactivateOwnedVehicle(String vehicleId) async {
    final vehicle = await getVehicle(vehicleId);
    if (vehicle == null) {
      throw StateError('vehicle missing: $vehicleId');
    }
    if (vehicle.ownerContactId != kVehicleOwnerSelfContactId) {
      throw StateError('only the owner may deactivate this vehicle');
    }
    if (!vehicleIsActive(vehicle)) {
      return vehicle;
    }
    final open = await openUseForVehicle(vehicleId);
    if (open != null) {
      throw VehicleHasOpenUseException(vehicleId);
    }
    final now = DateTime.now().toUtc();
    await (_db.update(
      _db.vehicles,
    )..where((t) => t.id.equals(vehicleId))).write(
      VehiclesCompanion(
        deactivatedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    return (await getVehicle(vehicleId)) ??
        (throw StateError('vehicle missing after deactivate'));
  }

  Future<Vehicle> createVehicle({
    required VehicleKind kind,
    required String displayLabel,
    required String make,
    required String model,
    required String color,
    required int modelYear,
    String licensePlate = '',
    String vin = '',
    double? fuelTankCapacityLiters,
    required int oilChangeIntervalAmount,
    required int initialMeterValue,
    required String initialMeterPhotoPath,
    VehicleConsumptionEstimationMode consumptionEstimationMode =
        VehicleConsumptionEstimationMode.detailed,
    bool requireDetailedDrivingMixForBorrowers = false,
    List<VehicleGalleryDraft> galleries = const [],
  }) async {
    final activeCount = await countActiveOwnedVehicles();
    if (activeCount >= kMaxActiveOwnedVehicles) {
      throw const VehicleActiveCapExceededException();
    }
    final now = DateTime.now().toUtc();
    final id = _newVehicleId('vehicle:');
    await _db
        .into(_db.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: id,
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: kind.wire,
            displayLabel: displayLabel.trim(),
            make: drift.Value(make.trim()),
            model: drift.Value(model.trim()),
            color: drift.Value(color.trim()),
            modelYear: drift.Value(modelYear),
            licensePlate: drift.Value(licensePlate.trim()),
            vin: drift.Value(vin.trim()),
            fuelTankCapacityLiters: drift.Value(fuelTankCapacityLiters),
            consumptionEstimationMode: drift.Value(
              consumptionEstimationMode.wire,
            ),
            requireDetailedDrivingMixForBorrowers: drift.Value(
              requireDetailedDrivingMixForBorrowers,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final preview = (oilChangeIntervalAmount ~/ 10).clamp(
      1,
      oilChangeIntervalAmount,
    );
    await _db
        .into(_db.vehicleMaintenanceRules)
        .insert(
          VehicleMaintenanceRulesCompanion.insert(
            id: '$id:rule:oil',
            vehicleId: id,
            category: VehicleMaintenanceCategoryWire.oil.wire,
            intervalAmount: oilChangeIntervalAmount,
            previewWindowAmount: drift.Value(preview),
          ),
        );
    await saveMeterReading(
      vehicleId: id,
      value: initialMeterValue,
      unit: meterUnitForKind(kind),
      photoPath: isKnownUnchangedMeterPhotoPath(initialMeterPhotoPath)
          ? initialMeterPhotoPath
          : await storeVehicleMeterPhotoFromSource(
              vehicleId: id,
              sourcePath: initialMeterPhotoPath,
            ),
      recordedByContactId: kVehicleOwnerSelfContactId,
      role: MeterReadingRole.standalone,
    );
    await _persistGalleryDrafts(id, galleries);
    return (await getVehicle(id)) ??
        (throw StateError('vehicle missing after insert'));
  }

  String meterUnitForKind(VehicleKind kind) {
    return kind.usesHorometer ? 'horometer_tenths' : 'odometer_km';
  }

  Future<void> _persistGalleryDrafts(
    String vehicleId,
    List<VehicleGalleryDraft> galleries,
  ) async {
    var nextIndex = await _nextGalleryIndex(vehicleId);
    for (final draft in galleries) {
      if (draft.photos.isEmpty) continue;
      final relativeDirectory = vehicleGalleryRelativeSubDir(
        vehicleId: vehicleId,
        galleryIndex: nextIndex,
      );
      final galleryId = _newVehicleId('vgal:');
      final now = DateTime.now().toUtc();
      await _db
          .into(_db.vehiclePhotoGalleries)
          .insert(
            VehiclePhotoGalleriesCompanion.insert(
              id: galleryId,
              vehicleId: vehicleId,
              galleryIndex: nextIndex,
              relativeDirectory: relativeDirectory,
              createdAt: now,
            ),
          );
      var sortOrder = 0;
      for (final photo in draft.photos) {
        final storageKey = await storeVehicleGalleryPhotoFromSource(
          vehicleId: vehicleId,
          galleryIndex: nextIndex,
          sourcePath: photo.sourcePath,
        );
        await _db
            .into(_db.vehicleGalleryPhotos)
            .insert(
              VehicleGalleryPhotosCompanion.insert(
                id: _newVehicleId('vphoto:'),
                galleryId: galleryId,
                relativeFilePath: storageKey,
                description: drift.Value(photo.description.trim()),
                capturedAt: now,
                sortOrder: drift.Value(sortOrder),
              ),
            );
        sortOrder++;
      }
      nextIndex++;
    }
  }

  Future<void> addGalleryDrafts(
    String vehicleId,
    List<VehicleGalleryDraft> galleries,
  ) async {
    await ensureVehicleActiveForWrite(vehicleId);
    return _persistGalleryDrafts(vehicleId, galleries);
  }

  Future<Vehicle> updateVehicleEditableDetails({
    required String vehicleId,
    required String displayLabel,
    required String color,
    String licensePlate = '',
    required int oilChangeIntervalAmount,
    VehicleConsumptionEstimationMode? consumptionEstimationMode,
    bool? requireDetailedDrivingMixForBorrowers,
  }) async {
    await ensureVehicleActiveForWrite(vehicleId);
    final now = DateTime.now().toUtc();
    await (_db.update(
      _db.vehicles,
    )..where((t) => t.id.equals(vehicleId))).write(
      VehiclesCompanion(
        displayLabel: drift.Value(displayLabel.trim()),
        color: drift.Value(color.trim()),
        licensePlate: drift.Value(licensePlate.trim()),
        consumptionEstimationMode: consumptionEstimationMode == null
            ? const drift.Value.absent()
            : drift.Value(consumptionEstimationMode.wire),
        requireDetailedDrivingMixForBorrowers:
            requireDetailedDrivingMixForBorrowers == null
            ? const drift.Value.absent()
            : drift.Value(requireDetailedDrivingMixForBorrowers),
        updatedAt: drift.Value(now),
      ),
    );
    await _upsertOilChangeInterval(
      vehicleId: vehicleId,
      intervalAmount: oilChangeIntervalAmount,
    );
    return (await getVehicle(vehicleId)) ??
        (throw StateError('vehicle missing after update'));
  }

  Future<int?> oilChangeIntervalAmountForVehicle(String vehicleId) async {
    final rule =
        await (_db.select(_db.vehicleMaintenanceRules)..where(
              (t) =>
                  t.vehicleId.equals(vehicleId) &
                  t.category.equals(VehicleMaintenanceCategoryWire.oil.wire),
            ))
            .getSingleOrNull();
    return rule?.intervalAmount;
  }

  Future<void> _upsertOilChangeInterval({
    required String vehicleId,
    required int intervalAmount,
  }) async {
    final preview = (intervalAmount ~/ 10).clamp(1, intervalAmount);
    final existing =
        await (_db.select(_db.vehicleMaintenanceRules)..where(
              (t) =>
                  t.vehicleId.equals(vehicleId) &
                  t.category.equals(VehicleMaintenanceCategoryWire.oil.wire),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.update(
        _db.vehicleMaintenanceRules,
      )..where((t) => t.id.equals(existing.id))).write(
        VehicleMaintenanceRulesCompanion(
          intervalAmount: drift.Value(intervalAmount),
          previewWindowAmount: drift.Value(preview),
        ),
      );
      return;
    }
    await _db
        .into(_db.vehicleMaintenanceRules)
        .insert(
          VehicleMaintenanceRulesCompanion.insert(
            id: '$vehicleId:rule:oil',
            vehicleId: vehicleId,
            category: VehicleMaintenanceCategoryWire.oil.wire,
            intervalAmount: intervalAmount,
            previewWindowAmount: drift.Value(preview),
          ),
        );
  }

  Future<List<VehicleMeterReading>> listMeterReadings(String vehicleId) async {
    final rows = await (_db.select(
      _db.vehicleMeterReadings,
    )..where((t) => t.vehicleId.equals(vehicleId))).get();
    rows.sort(compareMeterReadingsNewestFirst);
    return rows;
  }

  Future<VehicleMeterReading?> getMeterReading(String id) => (_db.select(
    _db.vehicleMeterReadings,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<FuelPurchase?> getFuelPurchase(String id) => (_db.select(
    _db.fuelPurchases,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<MaintenanceEvent?> getMaintenanceEvent(String id) => (_db.select(
    _db.maintenanceEvents,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<TrafficViolation?> getTrafficViolation(String id) => (_db.select(
    _db.trafficViolations,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int?> initialMeterBaseline(String vehicleId) async {
    final rows =
        await (_db.select(_db.vehicleMeterReadings)
              ..where((t) => t.vehicleId.equals(vehicleId))
              ..orderBy([
                (t) => drift.OrderingTerm.asc(t.recordedAt),
                (t) => drift.OrderingTerm.asc(t.id),
              ])
              ..limit(1))
            .get();
    return rows.firstOrNull?.value;
  }

  Future<int> _nextGalleryIndex(String vehicleId) async {
    final rows = await (_db.select(
      _db.vehiclePhotoGalleries,
    )..where((t) => t.vehicleId.equals(vehicleId))).get();
    if (rows.isEmpty) return 1;
    return rows.map((r) => r.galleryIndex).reduce(max) + 1;
  }

  Future<List<VehiclePhotoGallery>> listPhotoGalleries(String vehicleId) {
    return (_db.select(_db.vehiclePhotoGalleries)
          ..where((t) => t.vehicleId.equals(vehicleId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.galleryIndex)]))
        .get();
  }

  Future<List<VehicleGalleryPhoto>> listGalleryPhotos(String galleryId) {
    return (_db.select(_db.vehicleGalleryPhotos)
          ..where((t) => t.galleryId.equals(galleryId))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<int?> latestMeterValue(String vehicleId) async {
    final anchor = await latestMeterAnchor(vehicleId);
    return anchor?.value;
  }

  /// Most recent meter value with an optional photo path from the same source.
  Future<({DateTime recordedAt, int value, String? photoPath})?>
  latestMeterAnchorDetail(String vehicleId) async {
    ({DateTime recordedAt, int value, String? photoPath})? best;

    void consider(DateTime recordedAt, int? value, String? photoPath) {
      if (value == null) return;
      if (best == null || recordedAt.isAfter(best!.recordedAt)) {
        best = (recordedAt: recordedAt, value: value, photoPath: photoPath);
      }
    }

    final reading =
        await (_db.select(_db.vehicleMeterReadings)
              ..where((t) => t.vehicleId.equals(vehicleId))
              ..orderBy([
                (t) => drift.OrderingTerm.desc(t.recordedAt),
                (t) => drift.OrderingTerm.desc(t.id),
              ]))
            .get();
    final effective = latestEffectiveMeterReading(reading);
    if (effective != null) {
      consider(effective.recordedAt, effective.value, effective.photoPath);
    }

    final purchase =
        await (_db.select(_db.fuelPurchases)
              ..where(
                (t) =>
                    t.vehicleId.equals(vehicleId) &
                    t.meterReadingValue.isNotNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.purchasedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (purchase != null) {
      consider(
        purchase.purchasedAt,
        purchase.meterReadingValue,
        purchase.meterPhotoPath,
      );
    }

    final maintenance =
        await (_db.select(_db.maintenanceEvents)
              ..where(
                (t) =>
                    t.vehicleId.equals(vehicleId) &
                    t.meterAtService.isNotNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.servicedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (maintenance != null) {
      consider(
        maintenance.servicedAt,
        maintenance.meterAtService,
        maintenance.attachmentPath,
      );
    }

    return best;
  }

  /// Most recent meter value across canonical readings, fuel purchases, and
  /// maintenance events (by timestamp).
  Future<({DateTime recordedAt, int value})?> latestMeterAnchor(
    String vehicleId,
  ) async {
    ({DateTime recordedAt, int value})? best;

    void consider(DateTime recordedAt, int? value) {
      if (value == null) return;
      if (best == null || recordedAt.isAfter(best!.recordedAt)) {
        best = (recordedAt: recordedAt, value: value);
      }
    }

    final readings =
        await (_db.select(_db.vehicleMeterReadings)
              ..where((t) => t.vehicleId.equals(vehicleId))
              ..orderBy([
                (t) => drift.OrderingTerm.desc(t.recordedAt),
                (t) => drift.OrderingTerm.desc(t.id),
              ]))
            .get();
    final effective = latestEffectiveMeterReading(readings);
    if (effective != null) {
      consider(effective.recordedAt, effective.value);
    }

    final purchase =
        await (_db.select(_db.fuelPurchases)
              ..where(
                (t) =>
                    t.vehicleId.equals(vehicleId) &
                    t.meterReadingValue.isNotNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.purchasedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (purchase != null) {
      consider(purchase.purchasedAt, purchase.meterReadingValue);
    }

    final maintenance =
        await (_db.select(_db.maintenanceEvents)
              ..where(
                (t) =>
                    t.vehicleId.equals(vehicleId) &
                    t.meterAtService.isNotNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.servicedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (maintenance != null) {
      consider(maintenance.servicedAt, maintenance.meterAtService);
    }

    return best;
  }

  /// Earliest meter value across canonical readings, fuel purchases, and
  /// maintenance events (by timestamp).
  Future<({DateTime recordedAt, int value})?> earliestMeterAnchor(
    String vehicleId,
  ) async {
    ({DateTime recordedAt, int value})? best;

    void consider(DateTime recordedAt, int? value) {
      if (value == null) return;
      if (best == null || recordedAt.isBefore(best!.recordedAt)) {
        best = (recordedAt: recordedAt, value: value);
      }
    }

    final reading =
        await (_db.select(_db.vehicleMeterReadings)
              ..where((t) => t.vehicleId.equals(vehicleId))
              ..orderBy([
                (t) => drift.OrderingTerm.asc(t.recordedAt),
                (t) => drift.OrderingTerm.asc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (reading != null) {
      consider(reading.recordedAt, reading.value);
    }

    final purchase =
        await (_db.select(_db.fuelPurchases)
              ..where(
                (t) =>
                    t.vehicleId.equals(vehicleId) &
                    t.meterReadingValue.isNotNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.asc(t.purchasedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (purchase != null) {
      consider(purchase.purchasedAt, purchase.meterReadingValue);
    }

    final maintenance =
        await (_db.select(_db.maintenanceEvents)
              ..where(
                (t) =>
                    t.vehicleId.equals(vehicleId) &
                    t.meterAtService.isNotNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.asc(t.servicedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (maintenance != null) {
      consider(maintenance.servicedAt, maintenance.meterAtService);
    }

    return best;
  }

  Future<DateTime> _nextMeterRecordedAt(String vehicleId) async {
    final rows =
        await (_db.select(_db.vehicleMeterReadings)
              ..where((t) => t.vehicleId.equals(vehicleId))
              ..orderBy([(t) => drift.OrderingTerm.desc(t.recordedAt)])
              ..limit(1))
            .get();
    final now = DateTime.now().toUtc();
    final latest = rows.firstOrNull?.recordedAt;
    if (latest == null || now.isAfter(latest)) return now;
    return latest.add(const Duration(milliseconds: 1));
  }

  /// Timestamp for the session-start or standalone reading that immediately
  /// follows a gap correction. The correction row is stored one second earlier.
  Future<DateTime> reserveGapCorrectionTimestamp(String vehicleId) async {
    return _nextMeterRecordedAt(vehicleId);
  }

  Future<VehicleMeterReading> saveMeterReading({
    required String vehicleId,
    required int value,
    required String unit,
    required String photoPath,
    required String recordedByContactId,
    required MeterReadingRole role,
    String? vehicleUseId,
    bool isCorrection = false,
    String correctionNote = '',
    bool negativeGapAcknowledged = false,
    bool? isFullTank,
    int? tankFillFraction,
    DateTime? recordedAt,
  }) async {
    await ensureVehicleActiveForWrite(vehicleId);
    final id = _newVehicleId('meter:');
    final now = recordedAt ?? await _nextMeterRecordedAt(vehicleId);
    await _db
        .into(_db.vehicleMeterReadings)
        .insert(
          VehicleMeterReadingsCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            value: value,
            unit: unit,
            photoPath: photoPath,
            recordedAt: now,
            recordedByContactId: recordedByContactId,
            vehicleUseId: drift.Value(vehicleUseId),
            readingRole: role.wire,
            isCorrection: drift.Value(isCorrection),
            correctionNote: drift.Value(correctionNote),
            negativeGapAcknowledged: drift.Value(negativeGapAcknowledged),
            isFullTank: drift.Value(isFullTank),
            tankFillFraction: drift.Value(
              isFullTank == true ? null : tankFillFraction,
            ),
          ),
        );
    return (await (_db.select(
      _db.vehicleMeterReadings,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Future<VehicleMeterReading> saveGapCorrectionReading({
    required Vehicle vehicle,
    required int meterValue,
    required int gapTenths,
    required String photoPath,
    required String recordedByContactId,
    required GapCorrectionContext correctionContext,
    String? vehicleUseId,
    DateTime? recordedAt,
  }) async {
    final followUpAt = recordedAt ?? await _nextMeterRecordedAt(vehicle.id);
    return saveMeterReading(
      vehicleId: vehicle.id,
      value: meterValue,
      unit: meterUnitForVehicle(vehicle),
      photoPath: photoPath,
      recordedByContactId: recordedByContactId,
      role: MeterReadingRole.correction,
      vehicleUseId: vehicleUseId,
      isCorrection: true,
      correctionNote: encodeGapCorrectionNote(
        gapTenths: gapTenths,
        context: correctionContext,
      ),
      recordedAt: followUpAt.subtract(const Duration(seconds: 1)),
    );
  }

  Future<VehicleOdometerGap> recordPositiveGap({
    required String vehicleId,
    required int latestBefore,
    required int startAfter,
    required String attributedContactId,
    required String recordedByContactId,
    String? vehicleUseId,
    String? correctionReadingId,
    String? previousReadingId,
    String? triggerReadingId,
  }) async {
    await ensureVehicleActiveForWrite(vehicleId);
    final id = _newVehicleId('gap:');
    final now = DateTime.now().toUtc();
    final gap = startAfter - latestBefore;
    await _db
        .into(_db.vehicleOdometerGaps)
        .insert(
          VehicleOdometerGapsCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            latestReadingBeforeGap: latestBefore,
            startReadingAfterGap: startAfter,
            gapAmount: gap,
            attributedContactId: attributedContactId,
            recordedByContactId: recordedByContactId,
            recordedAt: now,
            vehicleUseId: drift.Value(vehicleUseId),
            correctionReadingId: drift.Value(correctionReadingId),
            previousReadingId: drift.Value(previousReadingId),
            triggerReadingId: drift.Value(triggerReadingId),
          ),
        );
    return (await (_db.select(
      _db.vehicleOdometerGaps,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Future<VehicleMeterReading?> latestNonCorrectionMeterReading(
    String vehicleId,
  ) async {
    final rows = await listMeterReadings(vehicleId);
    return latestEffectiveMeterReading(rows);
  }

  Future<int> countPendingGapVerifications(String vehicleId) async {
    final rows = await listMeterReadings(vehicleId);
    return rows.where(isGapVerificationCorrectionReading).length;
  }

  Future<List<VehicleMeterReading>> listPendingGapVerifications(
    String vehicleId,
  ) async {
    final rows = await listMeterReadings(vehicleId);
    return rows.where(isGapVerificationCorrectionReading).toList();
  }

  Future<VehicleOdometerGap?> getOdometerGapByCorrectionReadingId(
    String correctionReadingId,
  ) =>
      (_db.select(_db.vehicleOdometerGaps)
            ..where((t) => t.correctionReadingId.equals(correctionReadingId)))
          .getSingleOrNull();

  /// Creates a replacement reading and keeps the superseded row unchanged.
  Future<VehicleMeterReading> replaceMeterReading({
    required VehicleMeterReading superseded,
    required int newValue,
    bool? isFullTank,
    int? tankFillFraction,
    required GapResolutionKind kind,
  }) async {
    await ensureVehicleActiveForWrite(superseded.vehicleId);
    final id = _newVehicleId('meter:');
    final note = encodeMeterReadingReplacementNote(kind: kind);
    await _db
        .into(_db.vehicleMeterReadings)
        .insert(
          VehicleMeterReadingsCompanion.insert(
            id: id,
            vehicleId: superseded.vehicleId,
            value: newValue,
            unit: superseded.unit,
            photoPath: superseded.photoPath,
            recordedAt: superseded.recordedAt,
            recordedByContactId: superseded.recordedByContactId,
            vehicleUseId: drift.Value(superseded.vehicleUseId),
            readingRole: superseded.readingRole,
            isCorrection: const drift.Value(true),
            correctionNote: drift.Value(note),
            supersedesReadingId: drift.Value(superseded.id),
            isFullTank: isFullTank == null
                ? drift.Value(superseded.isFullTank)
                : drift.Value(isFullTank),
            tankFillFraction: tankFillFraction == null
                ? drift.Value(superseded.tankFillFraction)
                : drift.Value(tankFillFraction),
          ),
        );
    final replacement = (await getMeterReading(id))!;
    await _repointUseSessionsFromReading(
      oldReadingId: superseded.id,
      newReadingId: replacement.id,
    );
    return replacement;
  }

  Future<void> _repointUseSessionsFromReading({
    required String oldReadingId,
    required String newReadingId,
  }) async {
    final startUses = await (_db.select(
      _db.vehicleUses,
    )..where((t) => t.startReadingId.equals(oldReadingId))).get();
    for (final use in startUses) {
      await (_db.update(
        _db.vehicleUses,
      )..where((t) => t.id.equals(use.id))).write(
        VehicleUsesCompanion(startReadingId: drift.Value(newReadingId)),
      );
      if (use.endReadingId != null) {
        await _recomputeUseSessionAmount(use.id);
      }
    }
    final endUses = await (_db.select(
      _db.vehicleUses,
    )..where((t) => t.endReadingId.equals(oldReadingId))).get();
    for (final use in endUses) {
      await (_db.update(_db.vehicleUses)..where((t) => t.id.equals(use.id)))
          .write(VehicleUsesCompanion(endReadingId: drift.Value(newReadingId)));
      await _recomputeUseSessionAmount(use.id);
    }
  }

  Future<void> _recomputeUseSessionAmount(String useId) async {
    final use = await getVehicleUse(useId);
    if (use == null || use.endReadingId == null) return;
    final start = await getMeterReading(use.startReadingId);
    final end = await getMeterReading(use.endReadingId!);
    if (start == null || end == null) return;
    await (_db.update(_db.vehicleUses)..where((t) => t.id.equals(useId))).write(
      VehicleUsesCompanion(usageAmount: drift.Value(end.value - start.value)),
    );
  }

  Future<void> linkOdometerGapReadings({
    required String gapId,
    required String correctionReadingId,
    required String previousReadingId,
    required String triggerReadingId,
  }) async {
    await (_db.update(
      _db.vehicleOdometerGaps,
    )..where((t) => t.id.equals(gapId))).write(
      VehicleOdometerGapsCompanion(
        correctionReadingId: drift.Value(correctionReadingId),
        previousReadingId: drift.Value(previousReadingId),
        triggerReadingId: drift.Value(triggerReadingId),
      ),
    );
  }

  Future<void> deleteOdometerGap(String gapId) async {
    await (_db.delete(
      _db.vehicleOdometerGaps,
    )..where((t) => t.id.equals(gapId))).go();
  }

  Future<void> markGapVerificationResolved(String correctionReadingId) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.vehicleMeterReadings)
          ..where((t) => t.id.equals(correctionReadingId)))
        .write(VehicleMeterReadingsCompanion(resolvedAt: drift.Value(now)));
  }

  Future<VehicleMeterReading> saveAppliedGapCorrectionReading({
    required Vehicle vehicle,
    required int kmAppliedTenths,
    required String attributedContactId,
    required String previousReadingId,
    required String triggerReadingId,
    required GapResolutionKind kind,
    required String recordedByContactId,
    bool splitResolution = false,
  }) async {
    final note = encodeAppliedGapCorrectionNote(
      kmAppliedTenths: kmAppliedTenths,
      attributedContactId: splitResolution ? 'split' : attributedContactId,
      previousReadingId: previousReadingId,
      triggerReadingId: triggerReadingId,
      kind: kind,
    );
    return saveMeterReading(
      vehicleId: vehicle.id,
      value: kmAppliedTenths,
      unit: meterUnitForVehicle(vehicle),
      photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      recordedByContactId: recordedByContactId,
      role: MeterReadingRole.correction,
      isCorrection: true,
      correctionNote: note,
    );
  }

  Future<List<String>> listVehicleParticipantContactIds(
    String vehicleId,
  ) async {
    final out = <String>[kVehicleOwnerSelfContactId];
    final links = await listSharingLinksForVehicle(vehicleId);
    for (final link in links) {
      if (link.status != VehicleSharingLinkStatus.active.wire) continue;
      if (!out.contains(link.borrowerContactId)) {
        out.add(link.borrowerContactId);
      }
    }
    return out;
  }

  Future<({int route, int city, int traffic})?>
  averageDetailedDrivingMixForContact({
    required String vehicleId,
    required String contactId,
  }) async {
    final uses =
        await (_db.select(_db.vehicleUses)
              ..where(
                (t) =>
                    t.vehicleId.equals(vehicleId) &
                    t.attributedContactId.equals(contactId) &
                    t.endedAt.isNotNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.endedAt)]))
            .get();
    var routeSum = 0;
    var citySum = 0;
    var trafficSum = 0;
    var count = 0;
    for (final use in uses) {
      if (use.drivingRoutePercent == null ||
          use.drivingCityPercent == null ||
          use.drivingTrafficPercent == null) {
        continue;
      }
      routeSum += use.drivingRoutePercent!;
      citySum += use.drivingCityPercent!;
      trafficSum += use.drivingTrafficPercent!;
      count++;
      if (count >= 10) break;
    }
    if (count == 0) return null;
    return (
      route: (routeSum / count).round(),
      city: (citySum / count).round(),
      traffic: (trafficSum / count).round(),
    );
  }

  Future<DateTime?> previousSessionEndDateForReading(
    VehicleMeterReading previousReading,
  ) async {
    if (previousReading.vehicleUseId == null) {
      return previousReading.recordedAt;
    }
    final use = await getVehicleUse(previousReading.vehicleUseId!);
    return use?.endedAt ?? previousReading.recordedAt;
  }

  Future<VehicleUse> openUseSession({
    required String vehicleId,
    required String attributedContactId,
    required String startReadingId,
  }) async {
    await ensureVehicleActiveForWrite(vehicleId);
    final existing = await openUseForVehicle(vehicleId);
    if (existing != null) {
      return existing;
    }
    final reading = await (_db.select(
      _db.vehicleMeterReadings,
    )..where((t) => t.id.equals(startReadingId))).getSingle();
    final id = _newVehicleId('use:');
    await _db
        .into(_db.vehicleUses)
        .insert(
          VehicleUsesCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            attributedContactId: attributedContactId,
            startedAt: reading.recordedAt,
            startReadingId: startReadingId,
          ),
        );
    return (await (_db.select(
      _db.vehicleUses,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Future<VehicleUse?> getVehicleUse(String id) => (_db.select(
    _db.vehicleUses,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<VehicleUse?> openUseForVehicle(String vehicleId) async {
    final rows =
        await (_db.select(_db.vehicleUses)
              ..where((t) => t.vehicleId.equals(vehicleId) & t.endedAt.isNull())
              ..orderBy([(t) => drift.OrderingTerm.desc(t.startedAt)])
              ..limit(1))
            .get();
    return rows.firstOrNull;
  }

  Future<VehicleUse?> findAnyOpenUse() async {
    final rows =
        await (_db.select(_db.vehicleUses)
              ..where((t) => t.endedAt.isNull())
              ..orderBy([(t) => drift.OrderingTerm.desc(t.startedAt)])
              ..limit(1))
            .get();
    return rows.firstOrNull;
  }

  Future<VehicleUse> closeUseSession({
    required String useId,
    required String endReadingId,
    int? drivingRoutePercent,
    int? drivingCityPercent,
    int? drivingTrafficPercent,
    VehicleConsumptionEstimationMode? sessionConsumptionMode,
  }) async {
    final use = await (_db.select(
      _db.vehicleUses,
    )..where((t) => t.id.equals(useId))).getSingle();
    final start = await (_db.select(
      _db.vehicleMeterReadings,
    )..where((t) => t.id.equals(use.startReadingId))).getSingle();
    final end = await (_db.select(
      _db.vehicleMeterReadings,
    )..where((t) => t.id.equals(endReadingId))).getSingle();
    final amount = end.value - start.value;
    await (_db.update(_db.vehicleUses)..where((t) => t.id.equals(useId))).write(
      VehicleUsesCompanion(
        endedAt: drift.Value(end.recordedAt),
        endReadingId: drift.Value(endReadingId),
        usageAmount: drift.Value(amount),
        drivingRoutePercent: drift.Value(drivingRoutePercent),
        drivingCityPercent: drift.Value(drivingCityPercent),
        drivingTrafficPercent: drift.Value(drivingTrafficPercent),
        sessionConsumptionMode: drift.Value(sessionConsumptionMode?.wire),
      ),
    );
    final closed = await (_db.select(
      _db.vehicleUses,
    )..where((t) => t.id.equals(useId))).getSingle();
    await VehicleLicenseLifecycleSync.maybeStartTrialFromOwnerFact(
      actingContactId: closed.attributedContactId,
    );
    return closed;
  }

  /// Emprunteur: mark open session as awaiting Propriétaire fuel catch-up (kind 23).
  Future<void> markFuelCatchUpResponsePending(String useId) async {
    await (_db.update(_db.vehicleUses)..where((t) => t.id.equals(useId))).write(
      const VehicleUsesCompanion(
        fuelCatchUpResponseReceived: drift.Value(false),
      ),
    );
  }

  /// Emprunteur: Propriétaire catch-up received (empty or not) for [vehicleId].
  Future<void> markFuelCatchUpResponseReceived(String vehicleId) async {
    await (_db.update(_db.vehicleUses)..where(
          (t) =>
              t.vehicleId.equals(vehicleId) &
              t.endedAt.isNull() &
              t.fuelCatchUpResponseReceived.equals(false),
        ))
        .write(
          const VehicleUsesCompanion(
            fuelCatchUpResponseReceived: drift.Value(true),
          ),
        );
  }

  /// Inserts a fully closed use session (gap resolution retroactive entry).
  Future<VehicleUse> insertRetroactiveClosedUseSession({
    required String vehicleId,
    required String attributedContactId,
    required String startReadingId,
    required String endReadingId,
    required DateTime startedAt,
    required DateTime endedAt,
    int? drivingRoutePercent,
    int? drivingCityPercent,
    int? drivingTrafficPercent,
    VehicleConsumptionEstimationMode? sessionConsumptionMode,
  }) async {
    await ensureVehicleActiveForWrite(vehicleId);
    final start = await (_db.select(
      _db.vehicleMeterReadings,
    )..where((t) => t.id.equals(startReadingId))).getSingle();
    final end = await (_db.select(
      _db.vehicleMeterReadings,
    )..where((t) => t.id.equals(endReadingId))).getSingle();
    final id = _newVehicleId('use:');
    await _db
        .into(_db.vehicleUses)
        .insert(
          VehicleUsesCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            attributedContactId: attributedContactId,
            startedAt: startedAt,
            startReadingId: startReadingId,
            endedAt: drift.Value(endedAt),
            endReadingId: drift.Value(endReadingId),
            usageAmount: drift.Value(end.value - start.value),
            drivingRoutePercent: drift.Value(drivingRoutePercent),
            drivingCityPercent: drift.Value(drivingCityPercent),
            drivingTrafficPercent: drift.Value(drivingTrafficPercent),
            sessionConsumptionMode: drift.Value(sessionConsumptionMode?.wire),
          ),
        );
    return (await (_db.select(
      _db.vehicleUses,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Future<FuelPurchase> saveFuelPurchase({
    required String vehicleId,
    required DateTime purchasedAt,
    required int costMinor,
    required String currency,
    required bool isFullTank,
    required String recordedByContactId,
    double? volumeLiters,
    int? meterReadingValue,
    String? meterPhotoPath,
    int? tankFillFraction,

    /// Stable creator id for cross-device sync; when null a new local id is
    /// allocated. When set and a row already exists, returns that row (no-op).
    String? id,
  }) async {
    await ensureVehicleActiveForWrite(vehicleId);
    final resolvedId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : _newVehicleId('fuel:');
    final existing = await getFuelPurchase(resolvedId);
    if (existing != null) {
      return existing;
    }
    await _db
        .into(_db.fuelPurchases)
        .insert(
          FuelPurchasesCompanion.insert(
            id: resolvedId,
            vehicleId: vehicleId,
            purchasedAt: purchasedAt,
            costMinor: costMinor,
            currency: currency,
            isFullTank: isFullTank,
            recordedByContactId: recordedByContactId,
            volumeLiters: drift.Value(volumeLiters),
            meterReadingValue: drift.Value(meterReadingValue),
            meterPhotoPath: drift.Value(meterPhotoPath),
            tankFillFraction: drift.Value(isFullTank ? null : tankFillFraction),
          ),
        );
    final saved = await (_db.select(
      _db.fuelPurchases,
    )..where((t) => t.id.equals(resolvedId))).getSingle();
    await VehicleLicenseLifecycleSync.maybeStartTrialFromOwnerFact(
      actingContactId: recordedByContactId,
    );
    return saved;
  }

  Future<MaintenanceEvent> saveMaintenanceEvent({
    required String vehicleId,
    required DateTime servicedAt,
    required String category,
    required int costMinor,
    required String currency,
    required String recordedByContactId,
    String notes = '',
    String? attachmentPath,
    int? meterAtService,
  }) async {
    await ensureVehicleActiveForWrite(vehicleId);
    final id = _newVehicleId('maint:');
    await _db
        .into(_db.maintenanceEvents)
        .insert(
          MaintenanceEventsCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            servicedAt: servicedAt,
            category: category,
            costMinor: costMinor,
            currency: currency,
            recordedByContactId: recordedByContactId,
            notes: drift.Value(notes),
            attachmentPath: drift.Value(attachmentPath),
            meterAtService: drift.Value(meterAtService),
          ),
        );
    // Oil (and any category with a meter) also advances the vehicle odometer
    // via a canonical meter reading — including Emprunteur → Propriétaire import.
    if (meterAtService != null) {
      final vehicle = await getVehicle(vehicleId);
      if (vehicle != null) {
        final photoPath = (attachmentPath != null && attachmentPath.isNotEmpty)
            ? attachmentPath
            : kVehicleMeterPhotoKnownUnchangedSentinel;
        await saveMeterReading(
          vehicleId: vehicleId,
          value: meterAtService,
          unit: meterUnitForVehicle(vehicle),
          photoPath: photoPath,
          recordedByContactId: recordedByContactId,
          role: MeterReadingRole.maintenance,
          recordedAt: servicedAt,
        );
      }
    }
    return (await (_db.select(
      _db.maintenanceEvents,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Future<TrafficViolation> saveTrafficViolation({
    required String vehicleId,
    required DateTime violatedAt,
    required String violationType,
    required int amountMinor,
    required String currency,
    required String recordedByContactId,
    String? responsibilityContactId,
    String notes = '',
  }) async {
    await ensureVehicleActiveForWrite(vehicleId);
    final id = _newVehicleId('violation:');
    await _db
        .into(_db.trafficViolations)
        .insert(
          TrafficViolationsCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            violatedAt: violatedAt,
            violationType: violationType,
            amountMinor: amountMinor,
            currency: currency,
            recordedByContactId: recordedByContactId,
            responsibilityContactId: drift.Value(responsibilityContactId),
            notes: drift.Value(notes),
          ),
        );
    return (await (_db.select(
      _db.trafficViolations,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  Future<List<FuelPurchase>> listFuelPurchases(String vehicleId) {
    return (_db.select(_db.fuelPurchases)
          ..where((t) => t.vehicleId.equals(vehicleId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.purchasedAt)]))
        .get();
  }

  /// Newest fuel purchase by [purchasedAt], then meter, then id.
  Future<FuelPurchase?> latestFuelPurchase(String vehicleId) async {
    final rows = await listFuelPurchases(vehicleId);
    if (rows.isEmpty) return null;
    rows.sort(_compareFuelPurchasesNewestFirst);
    return rows.first;
  }

  /// Purchases strictly after [cursor] (same vehicle), oldest-first for catch-up.
  Future<List<FuelPurchase>> listFuelPurchasesStrictlyAfter(
    FuelPurchase cursor,
  ) async {
    final rows = await listFuelPurchases(cursor.vehicleId);
    final after = rows
        .where((p) => _fuelPurchaseIsStrictlyAfter(p, cursor))
        .toList();
    after.sort(_compareFuelPurchasesOldestFirst);
    return after;
  }

  /// Last full-tank purchase (with meter) and every purchase at or after it.
  /// Oldest-first. Empty when no full-tank anchor exists.
  Future<List<FuelPurchase>> listFuelPurchasesFromLastFullTankInclusive(
    String vehicleId,
  ) async {
    final anchor = await latestFullTankFuelPurchase(vehicleId);
    if (anchor == null) return const [];
    final rows = await listFuelPurchases(vehicleId);
    final selected = rows
        .where(
          (p) => p.id == anchor.id || _fuelPurchaseIsStrictlyAfter(p, anchor),
        )
        .toList();
    selected.sort(_compareFuelPurchasesOldestFirst);
    return selected;
  }

  /// Catch-up set for session-start sync (Propriétaire → Emprunteur).
  ///
  /// When [lastKnownPurchaseId] resolves on this vehicle, returns purchases
  /// strictly after that row. Otherwise returns last full-tank + following.
  Future<List<FuelPurchase>> fuelPurchasesForSessionStartCatchUp(
    String vehicleId, {
    String? lastKnownPurchaseId,
  }) async {
    final cursorId = lastKnownPurchaseId?.trim();
    if (cursorId != null && cursorId.isNotEmpty) {
      final cursor = await getFuelPurchase(cursorId);
      if (cursor != null && cursor.vehicleId == vehicleId) {
        return listFuelPurchasesStrictlyAfter(cursor);
      }
    }
    return listFuelPurchasesFromLastFullTankInclusive(vehicleId);
  }

  static int _compareFuelPurchasesNewestFirst(FuelPurchase a, FuelPurchase b) {
    final byDate = b.purchasedAt.compareTo(a.purchasedAt);
    if (byDate != 0) return byDate;
    final am = a.meterReadingValue ?? -1;
    final bm = b.meterReadingValue ?? -1;
    if (am != bm) return bm.compareTo(am);
    return b.id.compareTo(a.id);
  }

  static int _compareFuelPurchasesOldestFirst(FuelPurchase a, FuelPurchase b) {
    return -_compareFuelPurchasesNewestFirst(a, b);
  }

  static bool _fuelPurchaseIsStrictlyAfter(
    FuelPurchase candidate,
    FuelPurchase cursor,
  ) {
    final byDate = candidate.purchasedAt.compareTo(cursor.purchasedAt);
    if (byDate > 0) return true;
    if (byDate < 0) return false;
    final cm = candidate.meterReadingValue ?? -1;
    final um = cursor.meterReadingValue ?? -1;
    if (cm != um) return cm > um;
    return candidate.id.compareTo(cursor.id) > 0;
  }

  /// Sum of [FuelPurchase.volumeLiters] recorded since [use.startedAt].
  Future<double> fuelLitersPurchasedDuringOpenUse(VehicleUse use) async {
    final rows =
        await (_db.select(_db.fuelPurchases)..where(
              (t) =>
                  t.vehicleId.equals(use.vehicleId) &
                  t.purchasedAt.isBiggerOrEqualValue(use.startedAt),
            ))
            .get();
    var total = 0.0;
    for (final purchase in rows) {
      final volume = purchase.volumeLiters;
      if (volume != null && volume > 0) {
        total += volume;
      }
    }
    return total;
  }

  /// Newest full-tank purchase that has a meter reading, or `null`.
  Future<FuelPurchase?> latestFullTankFuelPurchase(String vehicleId) async {
    final rows =
        await (_db.select(_db.fuelPurchases)
              ..where(
                (t) =>
                    t.vehicleId.equals(vehicleId) &
                    t.isFullTank.equals(true) &
                    t.meterReadingValue.isNotNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.purchasedAt)])
              ..limit(1))
            .get();
    return rows.firstOrNull;
  }

  /// Sum of [FuelPurchase.volumeLiters] with [purchasedAt] strictly after
  /// [afterPurchasedAt] (typically the last full-tank purchase).
  Future<double> fuelVolumeLitersPurchasedAfter(
    String vehicleId, {
    required DateTime afterPurchasedAt,
  }) async {
    final rows =
        await (_db.select(_db.fuelPurchases)..where(
              (t) =>
                  t.vehicleId.equals(vehicleId) &
                  t.purchasedAt.isBiggerThanValue(afterPurchasedAt),
            ))
            .get();
    var total = 0.0;
    for (final purchase in rows) {
      final volume = purchase.volumeLiters;
      if (volume != null && volume > 0) {
        total += volume;
      }
    }
    return total;
  }

  /// Positive odometer/horometer delta since the latest fuel purchase with a
  /// meter reading, or `null` when unavailable.
  Future<int?> distanceTenthsSinceLastFuelPurchase(
    String vehicleId, {
    required int currentMeterTenths,
  }) async {
    final rows =
        await (_db.select(_db.fuelPurchases)
              ..where(
                (t) =>
                    t.vehicleId.equals(vehicleId) &
                    t.meterReadingValue.isNotNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.purchasedAt)])
              ..limit(1))
            .get();
    final anchor = rows.firstOrNull?.meterReadingValue;
    if (anchor == null) return null;
    final delta = currentMeterTenths - anchor;
    if (delta <= 0) return null;
    return delta;
  }

  Future<List<MaintenanceEvent>> listMaintenanceEvents(String vehicleId) {
    return (_db.select(_db.maintenanceEvents)
          ..where((t) => t.vehicleId.equals(vehicleId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.servicedAt)]))
        .get();
  }

  Future<List<TrafficViolation>> listViolations(String vehicleId) {
    return (_db.select(_db.trafficViolations)
          ..where((t) => t.vehicleId.equals(vehicleId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.violatedAt)]))
        .get();
  }

  Future<List<VehicleUse>> listUses(String vehicleId) {
    return (_db.select(_db.vehicleUses)
          ..where((t) => t.vehicleId.equals(vehicleId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<List<VehicleOdometerGap>> listOdometerGaps(String vehicleId) {
    return (_db.select(_db.vehicleOdometerGaps)
          ..where((t) => t.vehicleId.equals(vehicleId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.recordedAt)]))
        .get();
  }

  // --- Sharing ---

  Future<VehicleSharingLink> createSharingOffer({
    required String vehicleId,
    required String borrowerContactId,
    int ratePerKmMinor = 0,
    String rateCurrency = '',
    String availabilityWeekJson = '',
    String ownerRulesText = '',
    DateTime? expiresAt,
  }) async {
    await ensureVehicleActiveForWrite(vehicleId);
    final vehicle = await getVehicle(vehicleId);
    if (vehicle == null ||
        vehicle.ownerContactId != kVehicleOwnerSelfContactId) {
      throw const SelfBorrowForbiddenException();
    }
    if (vehicleContactIsOwnerSelf(borrowerContactId) ||
        vehicleContactIsBorrowerSelf(borrowerContactId)) {
      throw const SelfBorrowForbiddenException();
    }
    final counting = await distinctEmprunteurContactIdsCountingTowardCap();
    if (EmprunteurCapLogic.wouldExceedCap(
      countingContactIds: counting,
      borrowerContactId: borrowerContactId,
    )) {
      throw const EmprunteurCapExceededException();
    }
    final id = _newVehicleId('vshare:');
    final now = DateTime.now().toUtc();
    await _db
        .into(_db.vehicleSharingLinks)
        .insert(
          VehicleSharingLinksCompanion.insert(
            id: id,
            vehicleId: vehicleId,
            ownerContactId: kVehicleOwnerSelfContactId,
            borrowerContactId: borrowerContactId,
            status: VehicleSharingLinkStatus.pending.wire,
            createdAt: now,
            ratePerKmMinor: drift.Value(ratePerKmMinor),
            rateCurrency: drift.Value(rateCurrency),
            availabilityWeekJson: drift.Value(availabilityWeekJson),
            ownerRulesText: drift.Value(ownerRulesText),
            expiresAt: drift.Value(expiresAt?.toUtc()),
          ),
        );
    return (await (_db.select(
      _db.vehicleSharingLinks,
    )..where((t) => t.id.equals(id))).getSingle());
  }

  /// Distinct borrower Contact ids that count toward [kMaxDistinctEmprunteurs]
  /// on this device's owned fleet (`active`, `pending`, `reactivatePending`).
  Future<Set<String>> distinctEmprunteurContactIdsCountingTowardCap({
    DateTime? nowUtc,
  }) async {
    await expirePendingOffersPastDeadline(nowUtc: nowUtc);
    final rows =
        await (_db.select(_db.vehicleSharingLinks)..where(
              (t) =>
                  t.ownerContactId.equals(kVehicleOwnerSelfContactId) &
                  (t.status.equals(VehicleSharingLinkStatus.active.wire) |
                      t.status.equals(VehicleSharingLinkStatus.pending.wire) |
                      t.status.equals(
                        VehicleSharingLinkStatus.reactivatePending.wire,
                      )),
            ))
            .get();
    return {for (final r in rows) r.borrowerContactId};
  }

  /// Marks pending offers past [expiresAt] as expired, and past-deadline
  /// reactivate proposals back to revoked (local wall-clock only).
  /// Appends one activity-log row per newly expired pending offer.
  Future<void> expirePendingOffersPastDeadline({DateTime? nowUtc}) async {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final pending =
        await (_db.select(_db.vehicleSharingLinks)..where(
              (t) => t.status.equals(VehicleSharingLinkStatus.pending.wire),
            ))
            .get();
    final log = RelayActivityLogService(_db);
    for (final link in pending) {
      final expires = link.expiresAt;
      if (expires == null) continue;
      if (!expires.toUtc().isAfter(now)) {
        await (_db.update(
          _db.vehicleSharingLinks,
        )..where((t) => t.id.equals(link.id))).write(
          VehicleSharingLinksCompanion(
            status: drift.Value(VehicleSharingLinkStatus.expired.wire),
          ),
        );
        await log.append(
          kind: RelayActivityLogKinds.vehicleSharingOfferExpired,
          initiatorKind: RelayActivityLogService.initiatorSystem,
          details: {'linkId': link.id, 'vehicleId': link.vehicleId},
          occurredAt: now,
        );
      }
    }

    final reactivatePending =
        await (_db.select(_db.vehicleSharingLinks)..where(
              (t) => t.status.equals(
                VehicleSharingLinkStatus.reactivatePending.wire,
              ),
            ))
            .get();
    for (final link in reactivatePending) {
      final expires = link.expiresAt;
      if (expires == null) continue;
      if (!expires.toUtc().isAfter(now)) {
        await (_db.update(
          _db.vehicleSharingLinks,
        )..where((t) => t.id.equals(link.id))).write(
          VehicleSharingLinksCompanion(
            status: drift.Value(VehicleSharingLinkStatus.revoked.wire),
            expiresAt: const drift.Value(null),
          ),
        );
      }
    }
  }

  Future<void> acceptSharingLink(String linkId) async {
    final now = DateTime.now().toUtc();
    await (_db.update(
      _db.vehicleSharingLinks,
    )..where((t) => t.id.equals(linkId))).write(
      VehicleSharingLinksCompanion(
        status: drift.Value(VehicleSharingLinkStatus.active.wire),
        acceptedAt: drift.Value(now),
      ),
    );
  }

  Future<VehicleSharingLink?> getSharingLink(String linkId) {
    return (_db.select(
      _db.vehicleSharingLinks,
    )..where((t) => t.id.equals(linkId))).getSingleOrNull();
  }

  /// Upserts a peer-owned vehicle snapshot received with a sharing offer.
  Future<void> upsertExternalOwnedVehicle({
    required String vehicleId,
    required String ownerContactId,
    required String vehicleKind,
    required String displayLabel,
    String make = '',
    String model = '',
    String color = '',
    int? modelYear,
    String licensePlate = '',
    double? fuelTankCapacityLiters,
    String consumptionEstimationMode = 'detailed',
    bool requireDetailedDrivingMixForBorrowers = false,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = await getVehicle(vehicleId);
    if (existing != null) {
      if (existing.ownerContactId == kVehicleOwnerSelfContactId) {
        throw StateError('cannot overwrite locally owned vehicle $vehicleId');
      }
      await (_db.update(
        _db.vehicles,
      )..where((t) => t.id.equals(vehicleId))).write(
        VehiclesCompanion(
          ownerContactId: drift.Value(ownerContactId),
          vehicleKind: drift.Value(vehicleKind),
          displayLabel: drift.Value(displayLabel.trim()),
          make: drift.Value(make.trim()),
          model: drift.Value(model.trim()),
          color: drift.Value(color.trim()),
          modelYear: drift.Value(modelYear),
          licensePlate: drift.Value(licensePlate.trim()),
          fuelTankCapacityLiters: drift.Value(fuelTankCapacityLiters),
          consumptionEstimationMode: drift.Value(consumptionEstimationMode),
          requireDetailedDrivingMixForBorrowers: drift.Value(
            requireDetailedDrivingMixForBorrowers,
          ),
          updatedAt: drift.Value(now),
        ),
      );
      return;
    }
    await _db
        .into(_db.vehicles)
        .insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: ownerContactId,
            vehicleKind: vehicleKind,
            displayLabel: displayLabel.trim(),
            make: drift.Value(make.trim()),
            model: drift.Value(model.trim()),
            color: drift.Value(color.trim()),
            modelYear: drift.Value(modelYear),
            licensePlate: drift.Value(licensePlate.trim()),
            fuelTankCapacityLiters: drift.Value(fuelTankCapacityLiters),
            consumptionEstimationMode: drift.Value(consumptionEstimationMode),
            requireDetailedDrivingMixForBorrowers: drift.Value(
              requireDetailedDrivingMixForBorrowers,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Upserts a pending inbound sharing offer for the local Emprunteur.
  ///
  /// Revokes other pending offers from the same owner so a re-offer (or a
  /// leftover relay envelope after a prior QA run) does not stack duplicates.
  Future<VehicleSharingLink> upsertInboundPendingOffer({
    required String linkId,
    required String vehicleId,
    required String ownerContactId,
    required DateTime createdAt,
    int ratePerKmMinor = 0,
    String rateCurrency = '',
    String availabilityWeekJson = '',
    String ownerRulesText = '',
    DateTime? expiresAt,
  }) async {
    await _revokeOtherPendingOffersFromOwner(
      ownerContactId: ownerContactId,
      exceptLinkId: linkId,
    );
    final existing = await getSharingLink(linkId);
    if (existing != null) {
      if (existing.status == VehicleSharingLinkStatus.active.wire ||
          existing.status == VehicleSharingLinkStatus.revoked.wire) {
        return existing;
      }
      await (_db.update(
        _db.vehicleSharingLinks,
      )..where((t) => t.id.equals(linkId))).write(
        VehicleSharingLinksCompanion(
          vehicleId: drift.Value(vehicleId),
          ownerContactId: drift.Value(ownerContactId),
          borrowerContactId: const drift.Value(kVehicleBorrowerSelfContactId),
          status: drift.Value(VehicleSharingLinkStatus.pending.wire),
          ratePerKmMinor: drift.Value(ratePerKmMinor),
          rateCurrency: drift.Value(rateCurrency),
          availabilityWeekJson: drift.Value(availabilityWeekJson),
          ownerRulesText: drift.Value(ownerRulesText),
          expiresAt: drift.Value(expiresAt?.toUtc()),
        ),
      );
      return (await getSharingLink(linkId))!;
    }
    await _db
        .into(_db.vehicleSharingLinks)
        .insert(
          VehicleSharingLinksCompanion.insert(
            id: linkId,
            vehicleId: vehicleId,
            ownerContactId: ownerContactId,
            borrowerContactId: kVehicleBorrowerSelfContactId,
            status: VehicleSharingLinkStatus.pending.wire,
            createdAt: createdAt.toUtc(),
            ratePerKmMinor: drift.Value(ratePerKmMinor),
            rateCurrency: drift.Value(rateCurrency),
            availabilityWeekJson: drift.Value(availabilityWeekJson),
            ownerRulesText: drift.Value(ownerRulesText),
            expiresAt: drift.Value(expiresAt?.toUtc()),
          ),
        );
    return (await getSharingLink(linkId))!;
  }

  Future<void> _revokeOtherPendingOffersFromOwner({
    required String ownerContactId,
    required String exceptLinkId,
  }) async {
    final others =
        await (_db.select(_db.vehicleSharingLinks)..where(
              (t) =>
                  t.ownerContactId.equals(ownerContactId) &
                  t.status.equals(VehicleSharingLinkStatus.pending.wire) &
                  t.id.equals(exceptLinkId).not(),
            ))
            .get();
    for (final row in others) {
      await revokeSharingLink(row.id);
    }
  }

  /// Applies a remote accept on the Propriétaire device (link stays owned locally).
  Future<bool> applyRemoteSharingOfferAccept({
    required String linkId,
    DateTime? acceptedAt,
  }) async {
    final existing = await getSharingLink(linkId);
    if (existing == null) return false;
    if (existing.status == VehicleSharingLinkStatus.active.wire) return true;
    if (existing.status != VehicleSharingLinkStatus.pending.wire) return false;
    final at = (acceptedAt ?? DateTime.now()).toUtc();
    await (_db.update(
      _db.vehicleSharingLinks,
    )..where((t) => t.id.equals(linkId))).write(
      VehicleSharingLinksCompanion(
        status: drift.Value(VehicleSharingLinkStatus.active.wire),
        acceptedAt: drift.Value(at),
      ),
    );
    return true;
  }

  Future<void> revokeSharingLink(String linkId) async {
    final now = DateTime.now().toUtc();
    await (_db.update(
      _db.vehicleSharingLinks,
    )..where((t) => t.id.equals(linkId))).write(
      VehicleSharingLinksCompanion(
        status: drift.Value(VehicleSharingLinkStatus.revoked.wire),
        revokedAt: drift.Value(now),
      ),
    );
  }

  /// Marks a revoked link as waiting for Emprunteur reactivation accept.
  Future<void> markSharingLinkReactivatePending(
    String linkId, {
    DateTime? expiresAt,
  }) async {
    final link = await getSharingLink(linkId);
    if (link == null) {
      throw StateError('sharing link not found: $linkId');
    }
    if (link.ownerContactId == kVehicleOwnerSelfContactId) {
      final counting = await distinctEmprunteurContactIdsCountingTowardCap();
      if (EmprunteurCapLogic.wouldExceedCap(
        countingContactIds: counting,
        borrowerContactId: link.borrowerContactId,
      )) {
        throw const EmprunteurCapExceededException();
      }
    }
    await (_db.update(
      _db.vehicleSharingLinks,
    )..where((t) => t.id.equals(linkId))).write(
      VehicleSharingLinksCompanion(
        status: drift.Value(VehicleSharingLinkStatus.reactivatePending.wire),
        expiresAt: drift.Value(expiresAt?.toUtc()),
      ),
    );
  }

  /// Restores a revoked / reactivate-pending link to active (history kept).
  Future<void> reactivateSharingLink(String linkId) async {
    final now = DateTime.now().toUtc();
    await (_db.update(
      _db.vehicleSharingLinks,
    )..where((t) => t.id.equals(linkId))).write(
      VehicleSharingLinksCompanion(
        status: drift.Value(VehicleSharingLinkStatus.active.wire),
        acceptedAt: drift.Value(now),
        revokedAt: const drift.Value(null),
        expiresAt: const drift.Value(null),
      ),
    );
  }

  /// True when a freeze or transfer still awaits a peer decision on [linkId].
  Future<bool> hasPendingUsageBalanceDecision(String linkId) async {
    final freeze = await pendingUsageBalanceFreezeForLink(linkId);
    if (freeze != null) return true;
    final transfer = await pendingUsageTransferForLink(linkId);
    return transfer != null;
  }

  Future<List<VehicleSharingLink>> listSharingLinksForVehicle(
    String vehicleId,
  ) async {
    await expirePendingOffersPastDeadline();
    return (_db.select(_db.vehicleSharingLinks)
          ..where((t) => t.vehicleId.equals(vehicleId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Pending outbound offers on a vehicle owned on this device.
  Future<List<VehicleSharingLink>> listPendingOwnerOffersForVehicle(
    String vehicleId,
  ) async {
    await expirePendingOffersPastDeadline();
    return (_db.select(_db.vehicleSharingLinks)
          ..where(
            (t) =>
                t.vehicleId.equals(vehicleId) &
                t.ownerContactId.equals(kVehicleOwnerSelfContactId) &
                t.status.equals(VehicleSharingLinkStatus.pending.wire),
          )
          ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Contact ids with an active or pending outbound share on [vehicleId].
  Future<Set<String>> borrowerContactIdsBlockingNewOffer(
    String vehicleId,
  ) async {
    await expirePendingOffersPastDeadline();
    final rows =
        await (_db.select(_db.vehicleSharingLinks)..where(
              (t) =>
                  t.vehicleId.equals(vehicleId) &
                  t.ownerContactId.equals(kVehicleOwnerSelfContactId) &
                  (t.status.equals(VehicleSharingLinkStatus.active.wire) |
                      t.status.equals(VehicleSharingLinkStatus.pending.wire) |
                      t.status.equals(VehicleSharingLinkStatus.revoked.wire) |
                      t.status.equals(
                        VehicleSharingLinkStatus.reactivatePending.wire,
                      )),
            ))
            .get();
    return {for (final r in rows) r.borrowerContactId};
  }

  Future<List<VehicleSharingLink>> listPendingOffersForBorrower(
    String borrowerContactId,
  ) async {
    await expirePendingOffersPastDeadline();
    final rows =
        await (_db.select(_db.vehicleSharingLinks)
              ..where(
                (t) =>
                    t.borrowerContactId.equals(borrowerContactId) &
                    t.status.equals(VehicleSharingLinkStatus.pending.wire),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
            .get();
    return _linksOnExternalOwnedVehicles(rows);
  }

  Future<List<VehicleSharingLink>> listPendingBorrowerOffers() async {
    await expirePendingOffersPastDeadline();
    final rows =
        await (_db.select(_db.vehicleSharingLinks)
              ..where(
                (t) => t.status.equals(VehicleSharingLinkStatus.pending.wire),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
            .get();
    return _linksOnExternalOwnedVehicles(rows);
  }

  Future<List<VehicleSharingLink>> listActiveLinksAsBorrower(
    String borrowerContactId,
  ) {
    return (_db.select(_db.vehicleSharingLinks)..where(
          (t) =>
              t.borrowerContactId.equals(borrowerContactId) &
              t.status.equals(VehicleSharingLinkStatus.active.wire),
        ))
        .get();
  }

  /// Active or revoked sharing links on vehicles **not** owned on this device
  /// (Emprunteur accessible — including revoked, for settlement / journals).
  Future<List<({Vehicle vehicle, VehicleSharingLink link})>>
  listBorrowerAccessibleEntries() async {
    final rows =
        await (_db.select(_db.vehicleSharingLinks)
              ..where(
                (t) =>
                    t.status.equals(VehicleSharingLinkStatus.active.wire) |
                    t.status.equals(VehicleSharingLinkStatus.revoked.wire) |
                    t.status.equals(
                      VehicleSharingLinkStatus.reactivatePending.wire,
                    ),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
            .get();
    final out = <({Vehicle vehicle, VehicleSharingLink link})>[];
    for (final link in rows) {
      final v = await getVehicle(link.vehicleId);
      if (v == null) continue;
      if (v.ownerContactId == kVehicleOwnerSelfContactId) continue;
      out.add((vehicle: v, link: link));
    }
    return out;
  }

  /// Inbound reactivation proposals waiting for local Emprunteur accept.
  Future<List<({VehicleSharingLink link, String vehicleLabel})>>
  listPendingReactivateOffersForBorrower() async {
    final rows =
        await (_db.select(_db.vehicleSharingLinks)
              ..where(
                (t) => t.status.equals(
                  VehicleSharingLinkStatus.reactivatePending.wire,
                ),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
            .get();
    final external = await _linksOnExternalOwnedVehicles(rows);
    final out = <({VehicleSharingLink link, String vehicleLabel})>[];
    for (final link in external) {
      final v = await getVehicle(link.vehicleId);
      out.add((
        link: link,
        vehicleLabel: v?.displayLabel.trim().isNotEmpty == true
            ? v!.displayLabel.trim()
            : link.vehicleId,
      ));
    }
    return out;
  }

  Future<List<Vehicle>> listAccessibleVehiclesAsBorrower(
    String borrowerContactId,
  ) async {
    final links = await listActiveLinksAsBorrower(borrowerContactId);
    final out = <Vehicle>[];
    for (final link in links) {
      final v = await getVehicle(link.vehicleId);
      if (v == null) continue;
      if (v.ownerContactId == kVehicleOwnerSelfContactId) continue;
      out.add(v);
    }
    return out;
  }

  Future<List<VehicleSharingLink>> _linksOnExternalOwnedVehicles(
    List<VehicleSharingLink> links,
  ) async {
    final out = <VehicleSharingLink>[];
    for (final link in links) {
      final v = await getVehicle(link.vehicleId);
      if (v == null) continue;
      if (v.ownerContactId == kVehicleOwnerSelfContactId) continue;
      out.add(link);
    }
    return out;
  }

  Future<List<VehicleSharingLink>> listActiveLinksAsOwner() {
    return (_db.select(_db.vehicleSharingLinks)..where(
          (t) =>
              t.ownerContactId.equals(kVehicleOwnerSelfContactId) &
              t.status.equals(VehicleSharingLinkStatus.active.wire),
        ))
        .get();
  }

  String meterUnitForVehicle(Vehicle vehicle) {
    final kind = VehicleKind.fromWire(vehicle.vehicleKind);
    return meterUnitForKind(kind ?? VehicleKind.car);
  }

  // --- Usage balance freeze / transfer ---

  Future<DateTime?> latestConfirmedFreezeAt(String sharingLinkId) async {
    final row =
        await (_db.select(_db.vehicleUsageBalanceFreezes)
              ..where(
                (t) =>
                    t.sharingLinkId.equals(sharingLinkId) &
                    t.status.equals('confirmed'),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.confirmedAt)]))
            .getSingleOrNull();
    return row?.confirmedAt?.toUtc();
  }

  Future<VehicleUsageBalanceFreeze?> getUsageBalanceFreeze(String id) {
    return (_db.select(
      _db.vehicleUsageBalanceFreezes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<VehicleUsageBalanceFreeze>> listUsageBalanceFreezesForLink(
    String sharingLinkId,
  ) {
    return (_db.select(_db.vehicleUsageBalanceFreezes)
          ..where((t) => t.sharingLinkId.equals(sharingLinkId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.proposedAt)]))
        .get();
  }

  Future<VehicleUsageBalanceFreeze?> pendingUsageBalanceFreezeForLink(
    String sharingLinkId,
  ) {
    return (_db.select(_db.vehicleUsageBalanceFreezes)..where(
          (t) =>
              t.sharingLinkId.equals(sharingLinkId) &
              (t.status.equals('pending') |
                  t.status.equals('acceptedAwaitingCatchUp')),
        ))
        .getSingleOrNull();
  }

  Future<void> upsertUsageBalanceFreeze({
    required String id,
    required String sharingLinkId,
    required String vehicleId,
    required String status,
    required String initiatedByContactId,
    required DateTime proposedAt,
    DateTime? confirmedAt,
    required int balanceMinor,
    required DateTime windowStart,
    required DateTime windowEnd,
    required String breakdownJson,
    String? lastKnownPurchaseId,
  }) {
    return _db
        .into(_db.vehicleUsageBalanceFreezes)
        .insertOnConflictUpdate(
          VehicleUsageBalanceFreezesCompanion.insert(
            id: id,
            sharingLinkId: sharingLinkId,
            vehicleId: vehicleId,
            status: status,
            initiatedByContactId: initiatedByContactId,
            proposedAt: proposedAt.toUtc(),
            confirmedAt: drift.Value(confirmedAt?.toUtc()),
            balanceMinor: balanceMinor,
            windowStart: windowStart.toUtc(),
            windowEnd: windowEnd.toUtc(),
            breakdownJson: breakdownJson,
            lastKnownPurchaseId: drift.Value(lastKnownPurchaseId),
          ),
        );
  }

  Future<void> updateUsageBalanceFreezeStatus({
    required String id,
    required String status,
    DateTime? confirmedAt,
  }) {
    return (_db.update(
      _db.vehicleUsageBalanceFreezes,
    )..where((t) => t.id.equals(id))).write(
      VehicleUsageBalanceFreezesCompanion(
        status: drift.Value(status),
        confirmedAt: confirmedAt == null
            ? const drift.Value.absent()
            : drift.Value(confirmedAt.toUtc()),
      ),
    );
  }

  Future<VehicleUsageTransfer?> getUsageTransfer(String id) {
    return (_db.select(
      _db.vehicleUsageTransfers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<VehicleUsageTransfer>> listUsageTransfersForLink(
    String sharingLinkId,
  ) {
    return (_db.select(_db.vehicleUsageTransfers)
          ..where((t) => t.sharingLinkId.equals(sharingLinkId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.proposedAt)]))
        .get();
  }

  Future<VehicleUsageTransfer?> pendingUsageTransferForLink(
    String sharingLinkId,
  ) {
    return (_db.select(_db.vehicleUsageTransfers)..where(
          (t) =>
              t.sharingLinkId.equals(sharingLinkId) &
              t.status.equals('pending'),
        ))
        .getSingleOrNull();
  }

  Future<void> upsertUsageTransfer({
    required String id,
    required String sharingLinkId,
    required String vehicleId,
    required int amountMinor,
    required String initiatedByContactId,
    required String status,
    required DateTime proposedAt,
    DateTime? confirmedAt,
  }) {
    return _db
        .into(_db.vehicleUsageTransfers)
        .insertOnConflictUpdate(
          VehicleUsageTransfersCompanion.insert(
            id: id,
            sharingLinkId: sharingLinkId,
            vehicleId: vehicleId,
            amountMinor: amountMinor,
            initiatedByContactId: drift.Value(initiatedByContactId),
            status: status,
            proposedAt: proposedAt.toUtc(),
            confirmedAt: drift.Value(confirmedAt?.toUtc()),
          ),
        );
  }

  Future<void> updateUsageTransferStatus({
    required String id,
    required String status,
    DateTime? confirmedAt,
  }) {
    return (_db.update(
      _db.vehicleUsageTransfers,
    )..where((t) => t.id.equals(id))).write(
      VehicleUsageTransfersCompanion(
        status: drift.Value(status),
        confirmedAt: confirmedAt == null
            ? const drift.Value.absent()
            : drift.Value(confirmedAt.toUtc()),
      ),
    );
  }

  String newUsageBalanceFreezeId() => _newVehicleId('ubfreeze:');

  String newUsageTransferId() => _newVehicleId('ubxfer:');
}
