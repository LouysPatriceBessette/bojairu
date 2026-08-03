import 'dart:convert';

import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_maintenance_transport_service.dart';
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

  test('import maintenance records borrower on owned vehicle', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleMaintenanceTransportService(db);

    final eventJson = jsonEncode({
      'kind': VehicleMaintenanceTransportService.eventKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'remoteEventId': 'maint:remote-1',
      'servicedAt': '2026-08-01T18:30:00.000Z',
      'category': 'oil',
      'costMinor': 12000,
      'currency': 'CAD',
      'notes': 'Oil change',
      'meterAtService': 501000,
      'photoBase64': null,
      'photoIsSentinel': true,
    });

    final imported = await transport.importReceivedEvent(
      eventJson: eventJson,
      borrowerContactId: borrowerContactId,
    );

    expect(imported.category, 'oil');
    expect(imported.costMinor, 12000);
    expect(imported.meterAtService, 501000);
    expect(imported.notes, 'Oil change');
    expect(imported.recordedByContactId, borrowerContactId);
    expect(
      imported.attachmentPath,
      kVehicleMeterPhotoKnownUnchangedSentinel,
    );
  });

  test('export then import round-trips maintenance fields', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleMaintenanceTransportService(db);
    final repo = VehiclesRepository(db);

    final local = await repo.saveMaintenanceEvent(
      vehicleId: vehicleId,
      servicedAt: DateTime.utc(2026, 8, 1, 18, 30),
      category: 'tires',
      costMinor: 45000,
      currency: 'CAD',
      recordedByContactId: borrowerContactId,
      notes: 'Rotated',
      meterAtService: 502000,
      attachmentPath: kVehicleMeterPhotoKnownUnchangedSentinel,
    );

    final exported = await transport.exportEventJson(
      linkId: linkId,
      vehicleId: vehicleId,
      remoteEventId: local.id,
    );
    final root = jsonDecode(exported) as Map<String, dynamic>;
    expect(root['kind'], VehicleMaintenanceTransportService.eventKind);
    expect(root['category'], 'tires');
    expect(root['costMinor'], 45000);
    expect(root['meterAtService'], 502000);
    expect(root['notes'], 'Rotated');
    expect(root['photoIsSentinel'], isTrue);
    expect(root['photoBase64'], isNull);

    final imported = await transport.importReceivedEvent(
      eventJson: exported,
      borrowerContactId: borrowerContactId,
    );
    expect(
      imported.attachmentPath,
      kVehicleMeterPhotoKnownUnchangedSentinel,
    );
  });
}
