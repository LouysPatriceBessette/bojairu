import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/debug/qa_fcm_wake_push_seed.dart';
import 'package:compartarenta/debug/qa_scenario_seed_helpers.dart';
import 'package:compartarenta/debug/qa_vehicle_sharing_active_seed.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local-data helpers only (full seed restores identity via secure storage).
void main() {
  test('active owner local data: fixed vehicle + active outbound link', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await qaSeedFcmWakeConnectedContact(
      db: db,
      contactId: kQaFcmWakeMonicaContactId,
      displayName: 'Monica QA',
      avatarId: 'a01',
      peerPublicMaterialB64: 'dGVzdA',
      now: kQaSeedCreatedAt,
    );
    await seedQaVehicleSharingActiveOwnerLocalData(db);

    final repo = VehiclesRepository(db);
    final vehicle = await repo.getVehicle(kQaVehicleSharingActiveVehicleId);
    expect(vehicle, isNotNull);
    expect(vehicle!.ownerContactId, kVehicleOwnerSelfContactId);
    expect(vehicle.displayLabel, 'QA Civic');

    final link = await repo.getSharingLink(kQaVehicleSharingActiveLinkId);
    expect(link, isNotNull);
    expect(link!.status, VehicleSharingLinkStatus.active.wire);
    expect(link.borrowerContactId, kQaFcmWakeMonicaContactId);
    expect(link.createdAt.toUtc(), kQaVehicleSharingActiveLinkAt);
    expect(link.acceptedAt!.toUtc(), kQaVehicleSharingActiveLinkAt);
    expect(link.ratePerKmMinor, kQaVehicleSharingActiveRatePerKmMinor);
    // Must stay before usage-history baseline (unix 1785853111).
    expect(
      link.acceptedAt!.toUtc().isBefore(
        DateTime.fromMillisecondsSinceEpoch(1785853111 * 1000, isUtc: true),
      ),
      isTrue,
    );

    final active = await repo.listActiveLinksAsOwner();
    expect(active.map((e) => e.id), contains(kQaVehicleSharingActiveLinkId));
  });

  test('active borrower local data: accessible fixed vehicle', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await qaSeedFcmWakeConnectedContact(
      db: db,
      contactId: kQaFcmWakeLouysContactId,
      displayName: 'Louys QA',
      avatarId: 'a02',
      peerPublicMaterialB64: 'dGVzdA',
      now: kQaSeedCreatedAt,
    );
    await seedQaVehicleSharingActiveBorrowerLocalData(db);

    final repo = VehiclesRepository(db);
    final accessible = await repo.listBorrowerAccessibleEntries();
    expect(accessible, hasLength(1));
    expect(accessible.first.vehicle.id, kQaVehicleSharingActiveVehicleId);
    expect(
      accessible.first.link.status,
      VehicleSharingLinkStatus.active.wire,
    );
    expect(
      accessible.first.link.borrowerContactId,
      kVehicleBorrowerSelfContactId,
    );
  });
}
