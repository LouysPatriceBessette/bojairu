import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_sharing_offer_transport_service.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('import offer upserts external vehicle and pending borrower link',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final transport = VehicleSharingOfferTransportService(db);
    final repo = VehiclesRepository(db);

    const ownerContactId = 'contact:owner';
    const linkId = 'vshare:offer-1';
    const vehicleId = 'vehicle:civic';
    final payload = '''
{
  "kind": "vehicleSharingOffer",
  "linkId": "$linkId",
  "createdAt": "2026-07-31T12:00:00.000Z",
  "expiresAt": "2027-08-01T12:00:00.000Z",
  "ratePerKmMinor": 25,
  "rateCurrency": "CAD",
  "availabilityWeekJson": "",
  "ownerRulesText": "No pets",
  "vehicle": {
    "id": "$vehicleId",
    "vehicleKind": "${VehicleKind.car.wire}",
    "displayLabel": "Civic QA",
    "make": "Honda",
    "model": "Civic",
    "color": "Blue",
    "modelYear": 2018,
    "licensePlate": "QA-123",
    "fuelTankCapacityLiters": 47.0,
    "consumptionEstimationMode": "detailed",
    "requireDetailedDrivingMixForBorrowers": false
  }
}
''';

    final imported = await transport.importReceivedOffer(
      offerJson: payload,
      senderContactId: ownerContactId,
    );
    expect(imported.linkId, linkId);
    expect(imported.vehicleLabel, 'Civic QA');

    final vehicle = await repo.getVehicle(vehicleId);
    expect(vehicle, isNotNull);
    expect(vehicle!.ownerContactId, ownerContactId);
    expect(vehicle.displayLabel, 'Civic QA');

    final link = await repo.getSharingLink(linkId);
    expect(link, isNotNull);
    expect(link!.status, VehicleSharingLinkStatus.pending.wire);
    expect(link.borrowerContactId, kVehicleBorrowerSelfContactId);
    expect(link.ownerContactId, ownerContactId);
    expect(link.ratePerKmMinor, 25);
    expect(link.ownerRulesText, 'No pets');
    expect(link.expiresAt!.toUtc(), DateTime.utc(2027, 8, 1, 12));

    final pending = await repo.listPendingBorrowerOffers();
    expect(pending.map((e) => e.id), contains(linkId));

    await transport.importReceivedOffer(
      offerJson: payload,
      senderContactId: ownerContactId,
    );
    expect((await repo.listPendingBorrowerOffers()).length, 1);
  });

  test('import offer revokes older pending from same owner', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final transport = VehicleSharingOfferTransportService(db);
    final repo = VehiclesRepository(db);
    const ownerContactId = 'contact:owner';

    String payload({
      required String linkId,
      required String vehicleId,
      required String label,
    }) =>
        '''
{
  "kind": "vehicleSharingOffer",
  "linkId": "$linkId",
  "createdAt": "2026-07-31T12:00:00.000Z",
  "ratePerKmMinor": 25,
  "rateCurrency": "CAD",
  "availabilityWeekJson": "",
  "ownerRulesText": "",
  "vehicle": {
    "id": "$vehicleId",
    "vehicleKind": "${VehicleKind.car.wire}",
    "displayLabel": "$label",
    "make": "Honda",
    "model": "Civic",
    "color": "Blue",
    "modelYear": 2018,
    "licensePlate": "",
    "fuelTankCapacityLiters": 47.0,
    "consumptionEstimationMode": "detailed",
    "requireDetailedDrivingMixForBorrowers": false
  }
}
''';

    await transport.importReceivedOffer(
      offerJson: payload(
        linkId: 'vshare:old',
        vehicleId: 'vehicle:old',
        label: 'QA Civic',
      ),
      senderContactId: ownerContactId,
    );
    await transport.importReceivedOffer(
      offerJson: payload(
        linkId: 'vshare:new',
        vehicleId: 'vehicle:new',
        label: 'QA Civic',
      ),
      senderContactId: ownerContactId,
    );

    final pending = await repo.listPendingBorrowerOffers();
    expect(pending.map((e) => e.id), ['vshare:new']);
    expect(
      (await repo.getSharingLink('vshare:old'))!.status,
      VehicleSharingLinkStatus.revoked.wire,
    );
  });

  test('owner create + export + borrower import + accept round-trip fields',
      () async {
    final ownerDb = AppDatabase.forTesting(NativeDatabase.memory());
    final borrowerDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(ownerDb.close);
    addTearDown(borrowerDb.close);

    final ownerRepo = VehiclesRepository(ownerDb);
    const vehicleId = 'vehicle:owner-car';
    await ownerDb.into(ownerDb.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'Owner Car',
            make: const drift.Value('Toyota'),
            model: const drift.Value('Corolla'),
            color: const drift.Value('Red'),
            modelYear: const drift.Value(2020),
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    final link = await ownerRepo.createSharingOffer(
      vehicleId: vehicleId,
      borrowerContactId: 'contact:borrower',
      ratePerKmMinor: 10,
      rateCurrency: 'CAD',
      ownerRulesText: 'Be careful',
      expiresAt: DateTime.utc(2026, 8, 2, 12),
    );

    final offerJson =
        await VehicleSharingOfferTransportService(ownerDb).exportOfferJson(
      link.id,
    );

    const ownerAsContact = 'contact:owner-on-borrower';
    await VehicleSharingOfferTransportService(borrowerDb).importReceivedOffer(
      offerJson: offerJson,
      senderContactId: ownerAsContact,
    );

    final borrowerRepo = VehiclesRepository(borrowerDb);
    await borrowerRepo.acceptSharingLink(link.id);
    final acceptJson = VehicleSharingOfferTransportService(borrowerDb)
        .exportAcceptJson(
      linkId: link.id,
      acceptedAt: DateTime.utc(2026, 7, 31, 15),
    );

    final applied = await VehicleSharingOfferTransportService(ownerDb)
        .importReceivedAccept(acceptJson: acceptJson);
    expect(applied, isTrue);

    final ownerLink = await ownerRepo.getSharingLink(link.id);
    expect(ownerLink!.status, VehicleSharingLinkStatus.active.wire);
    expect(ownerLink.acceptedAt, isNotNull);
  });

  test('apply accept returns false when owner link already expired', () async {
    final ownerDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(ownerDb.close);
    final ownerRepo = VehiclesRepository(ownerDb);
    const vehicleId = 'vehicle:owner-car';
    await ownerDb.into(ownerDb.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'Owner Car',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    final link = await ownerRepo.createSharingOffer(
      vehicleId: vehicleId,
      borrowerContactId: 'contact:borrower',
      expiresAt: DateTime.utc(2026, 7, 1, 12),
    );
    await ownerRepo.expirePendingOffersPastDeadline(
      nowUtc: DateTime.utc(2026, 7, 2, 12),
    );
    expect(
      (await ownerRepo.getSharingLink(link.id))!.status,
      VehicleSharingLinkStatus.expired.wire,
    );

    final acceptJson = VehicleSharingOfferTransportService(ownerDb)
        .exportAcceptJson(
      linkId: link.id,
      acceptedAt: DateTime.utc(2026, 7, 2, 13),
    );
    final applied = await VehicleSharingOfferTransportService(ownerDb)
        .importReceivedAccept(acceptJson: acceptJson);
    expect(applied, isFalse);
  });
}
