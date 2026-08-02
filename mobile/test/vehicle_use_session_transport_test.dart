import 'dart:convert';

import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_use_session_transport_service.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
import 'package:compartarenta/vehicle/vehicle_meter_photo_path.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vehicleId = 'vehicle:civic';
  const borrowerContactId = 'contact:monica';
  const linkId = 'vshare:link-1';

  Future<void> seedOwnedVehicle(AppDatabase db) async {
    await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'QA Civic',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  String startPayload({
    required int meterTenths,
    required String remoteUseId,
    String startedAt = '2026-08-01T18:00:00.000Z',
  }) =>
      jsonEncode({
        'kind': VehicleUseSessionTransportService.startKind,
        'linkId': linkId,
        'vehicleId': vehicleId,
        'remoteUseId': remoteUseId,
        'startedAt': startedAt,
        'meterTenths': meterTenths,
        'unit': 'odometer_km',
        'isFullTank': true,
        'photoBase64': null,
        'photoIsSentinel': true,
      });

  String endPayload({
    required int meterTenths,
    required String remoteUseId,
    String endedAt = '2026-08-01T20:00:00.000Z',
    bool isFullTank = false,
    int? tankFillFraction,
  }) =>
      jsonEncode({
        'kind': VehicleUseSessionTransportService.endKind,
        'linkId': linkId,
        'vehicleId': vehicleId,
        'remoteUseId': remoteUseId,
        'endedAt': endedAt,
        'meterTenths': meterTenths,
        'unit': 'odometer_km',
        'isFullTank': isFullTank,
        'tankFillFraction': ?tankFillFraction,
        'photoBase64': null,
        'photoIsSentinel': true,
      });

  test('import start with no open session opens borrower-attributed use',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleUseSessionTransportService(db);
    final repo = VehiclesRepository(db);

    final result = await transport.importReceivedSessionStart(
      sessionJson: startPayload(meterTenths: 120000, remoteUseId: 'use:remote-1'),
      borrowerContactId: borrowerContactId,
    );

    expect(result.conflictWithOpenSession, isFalse);
    expect(result.localUseId, isNotNull);
    final open = await repo.openUseForVehicle(vehicleId);
    expect(open, isNotNull);
    expect(open!.attributedContactId, borrowerContactId);
    expect(open.id, result.localUseId);

    final start = await repo.getMeterReading(open.startReadingId);
    expect(start, isNotNull);
    expect(start!.value, 120000);
    expect(start.photoPath, kVehicleMeterPhotoKnownUnchangedSentinel);
  });

  test('import start with open session creates pending gap and keeps one open use',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleUseSessionTransportService(db);
    final repo = VehiclesRepository(db);

    final baseline = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: 100000,
      unit: 'odometer_km',
      photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      recordedByContactId: kVehicleOwnerSelfContactId,
      role: MeterReadingRole.sessionStart,
      recordedAt: DateTime.utc(2026, 7, 1, 12),
    );
    await repo.openUseSession(
      vehicleId: vehicleId,
      attributedContactId: kVehicleOwnerSelfContactId,
      startReadingId: baseline.id,
    );

    final result = await transport.importReceivedSessionStart(
      sessionJson: startPayload(meterTenths: 120500, remoteUseId: 'use:remote-2'),
      borrowerContactId: borrowerContactId,
    );

    expect(result.conflictWithOpenSession, isTrue);
    expect(result.correctionReadingId, isNotNull);
    final open = await repo.openUseForVehicle(vehicleId);
    expect(open, isNotNull);
    expect(open!.attributedContactId, kVehicleOwnerSelfContactId);

    final pending = await repo.listPendingGapVerifications(vehicleId);
    expect(pending, isNotEmpty);
    expect(await repo.countPendingGapVerifications(vehicleId), greaterThan(0));
  });

  test('import end closes open session attributed to borrower', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleUseSessionTransportService(db);
    final repo = VehiclesRepository(db);

    await transport.importReceivedSessionStart(
      sessionJson: startPayload(meterTenths: 120000, remoteUseId: 'use:remote-3'),
      borrowerContactId: borrowerContactId,
    );
    expect(await repo.openUseForVehicle(vehicleId), isNotNull);

    final closed = await transport.importReceivedSessionEnd(
      sessionJson: endPayload(
        meterTenths: 120400,
        remoteUseId: 'use:remote-3',
        tankFillFraction: 87,
      ),
      borrowerContactId: borrowerContactId,
    );
    expect(closed, isTrue);
    expect(await repo.openUseForVehicle(vehicleId), isNull);

    final endReadings = await db.select(db.vehicleMeterReadings).get();
    final end = endReadings.where((r) => r.readingRole == 'sessionEnd').single;
    expect(end.isFullTank, isFalse);
    expect(end.tankFillFraction, 87);
  });

  test('export end json includes tank fill state', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleUseSessionTransportService(db);
    final repo = VehiclesRepository(db);

    final start = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: 120000,
      unit: 'odometer_km',
      photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      recordedByContactId: borrowerContactId,
      role: MeterReadingRole.sessionStart,
      isFullTank: true,
      recordedAt: DateTime.utc(2026, 8, 1, 10),
    );
    final use = await repo.openUseSession(
      vehicleId: vehicleId,
      attributedContactId: borrowerContactId,
      startReadingId: start.id,
    );
    final end = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: 120400,
      unit: 'odometer_km',
      photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      recordedByContactId: borrowerContactId,
      role: MeterReadingRole.sessionEnd,
      vehicleUseId: use.id,
      isFullTank: false,
      tankFillFraction: 87,
      recordedAt: DateTime.utc(2026, 8, 1, 12),
    );

    final json = await transport.exportSessionEndJson(
      linkId: linkId,
      vehicleId: vehicleId,
      remoteUseId: use.id,
      endReadingId: end.id,
    );
    final root = jsonDecode(json) as Map<String, dynamic>;
    expect(root['isFullTank'], isFalse);
    expect(root['tankFillFraction'], 87);
  });

  test('import end returns false when open session belongs to another actor',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleUseSessionTransportService(db);
    final repo = VehiclesRepository(db);

    final baseline = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: 100000,
      unit: 'odometer_km',
      photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      recordedByContactId: kVehicleOwnerSelfContactId,
      role: MeterReadingRole.sessionStart,
      recordedAt: DateTime.utc(2026, 7, 1, 12),
    );
    await repo.openUseSession(
      vehicleId: vehicleId,
      attributedContactId: kVehicleOwnerSelfContactId,
      startReadingId: baseline.id,
    );

    final closed = await transport.importReceivedSessionEnd(
      sessionJson: endPayload(meterTenths: 100200, remoteUseId: 'use:remote-x'),
      borrowerContactId: borrowerContactId,
    );
    expect(closed, isFalse);
    expect(await repo.openUseForVehicle(vehicleId), isNotNull);
  });

  test('export start json includes meter and sentinel photo flag', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleUseSessionTransportService(db);
    final repo = VehiclesRepository(db);

    final reading = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: 111000,
      unit: repo.meterUnitForVehicle((await repo.getVehicle(vehicleId))!),
      photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      recordedByContactId: borrowerContactId,
      role: MeterReadingRole.sessionStart,
      isFullTank: true,
      recordedAt: DateTime.utc(2026, 8, 1, 10),
    );
    final use = await repo.openUseSession(
      vehicleId: vehicleId,
      attributedContactId: borrowerContactId,
      startReadingId: reading.id,
    );

    final json = await transport.exportSessionStartJson(
      linkId: linkId,
      vehicleId: vehicleId,
      remoteUseId: use.id,
      startReadingId: reading.id,
    );
    final root = jsonDecode(json) as Map<String, dynamic>;
    expect(root['kind'], VehicleUseSessionTransportService.startKind);
    expect(root['meterTenths'], 111000);
    expect(root['photoIsSentinel'], isTrue);
    expect(root['remoteUseId'], use.id);
  });
}
