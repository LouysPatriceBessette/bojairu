import 'dart:convert';

import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_violation_transport_service.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
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

  test('import traffic violation records borrower on owned vehicle', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleViolationTransportService(db);

    final violationJson = jsonEncode({
      'kind': VehicleViolationTransportService.violationKind,
      'linkId': linkId,
      'vehicleId': vehicleId,
      'remoteViolationId': 'violation:remote-1',
      'violatedAt': '2026-08-01T18:30:00.000Z',
      'violationType': 'Speeding',
      'amountMinor': 25000,
      'currency': 'CAD',
      'notes': 'Highway',
    });

    final imported = await transport.importReceivedViolation(
      violationJson: violationJson,
      borrowerContactId: borrowerContactId,
    );

    expect(imported.violationType, 'Speeding');
    expect(imported.amountMinor, 25000);
    expect(imported.notes, 'Highway');
    expect(imported.recordedByContactId, borrowerContactId);
  });

  test('export then import round-trips traffic violation fields', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedOwnedVehicle(db);
    final transport = VehicleViolationTransportService(db);
    final repo = VehiclesRepository(db);

    final local = await repo.saveTrafficViolation(
      vehicleId: vehicleId,
      violatedAt: DateTime.utc(2026, 8, 1, 18, 30),
      violationType: 'Parking',
      amountMinor: 8000,
      currency: 'CAD',
      recordedByContactId: borrowerContactId,
      notes: 'Downtown',
    );

    final exported = await transport.exportViolationJson(
      linkId: linkId,
      vehicleId: vehicleId,
      remoteViolationId: local.id,
    );
    final root = jsonDecode(exported) as Map<String, dynamic>;
    expect(root['kind'], VehicleViolationTransportService.violationKind);
    expect(root['violationType'], 'Parking');
    expect(root['amountMinor'], 8000);
    expect(root['notes'], 'Downtown');
  });
}
