import 'package:compartarenta/activity/relay_activity_log_service.dart';
import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('matchesEmitterFilter distinguishes system, self, and contact', () async {
    final service = RelayActivityLogService(db);
    await service.append(
      kind: 'test',
      initiatorKind: RelayActivityLogService.initiatorSystem,
    );
    await service.append(
      kind: 'test',
      initiatorKind: RelayActivityLogService.initiatorSelf,
      initiatorDisplayName: 'Alice',
    );
    await service.append(
      kind: 'test',
      initiatorKind: RelayActivityLogService.initiatorContact,
      initiatorContactId: 'c1',
      initiatorDisplayName: 'Bob',
    );

    final rows = await db.select(db.relayActivityLogEntries).get();
    final system = rows.firstWhere(
      (r) => r.initiatorKind == RelayActivityLogService.initiatorSystem,
    );
    final self = rows.firstWhere(
      (r) => r.initiatorKind == RelayActivityLogService.initiatorSelf,
    );
    final contact = rows.firstWhere((r) => r.initiatorContactId == 'c1');

    expect(
      RelayActivityLogService.matchesEmitterFilter(
        system,
        RelayActivityLogService.emitterFilterSystem,
      ),
      isTrue,
    );
    expect(
      RelayActivityLogService.matchesEmitterFilter(
        self,
        RelayActivityLogService.emitterFilterSelf,
      ),
      isTrue,
    );
    expect(
      RelayActivityLogService.matchesEmitterFilter(
        contact,
        RelayActivityLogService.emitterFilterContact('c1'),
      ),
      isTrue,
    );
    expect(
      RelayActivityLogService.matchesEmitterFilter(
        contact,
        RelayActivityLogService.emitterFilterSystem,
      ),
      isFalse,
    );
  });

  test('emitterFilterOptions lists system, self name, and contacts', () async {
    final service = RelayActivityLogService(db);
    await service.append(
      kind: 'test',
      initiatorKind: RelayActivityLogService.initiatorSystem,
    );
    await service.append(
      kind: 'test',
      initiatorKind: RelayActivityLogService.initiatorSelf,
      initiatorDisplayName: 'Alice',
    );
    await service.append(
      kind: 'test',
      initiatorKind: RelayActivityLogService.initiatorContact,
      initiatorContactId: 'c1',
      initiatorDisplayName: 'Bob',
    );

    final options = await service.emitterFilterOptions(
      selfDisplayName: 'Alice',
      allLabel: 'All',
      systemLabel: 'System',
      selfFallbackLabel: 'Me',
    );

    expect(options.first.key, RelayActivityLogService.emitterFilterAll);
    expect(
      options.map((o) => o.label),
      containsAll(['All', 'System', 'Alice', 'Bob']),
    );
  });

  test('contactDeleted is stored with self initiator', () async {
    final service = RelayActivityLogService(db);
    await service.append(
      kind: RelayActivityLogKinds.contactDeleted,
      initiatorKind: RelayActivityLogService.initiatorSelf,
      initiatorDisplayName: 'Monica',
      details: {'contactId': 'contact:1'},
    );

    final rows = await db.select(db.relayActivityLogEntries).get();
    expect(rows.single.kind, RelayActivityLogKinds.contactDeleted);
    expect(rows.single.initiatorKind, RelayActivityLogService.initiatorSelf);
    expect(rows.single.initiatorDisplayName, 'Monica');
  });

  test('listFiltered excludes vehicle-related kinds', () async {
    final service = RelayActivityLogService(db);
    await service.append(
      kind: RelayActivityLogKinds.contactDeleted,
      initiatorKind: RelayActivityLogService.initiatorSelf,
    );
    await service.append(
      kind: RelayActivityLogKinds.vehicleSharingOfferSent,
      initiatorKind: RelayActivityLogService.initiatorSelf,
      details: {'vehicleId': 'vehicle:1'},
    );
    await service.append(
      kind: RelayActivityLogKinds.vehicleFuelPurchaseReceived,
      initiatorKind: RelayActivityLogService.initiatorContact,
      initiatorContactId: 'c1',
      details: {'vehicleId': 'vehicle:1'},
    );

    final rows = await service.listFiltered();
    expect(rows, hasLength(1));
    expect(rows.single.kind, RelayActivityLogKinds.contactDeleted);
  });

  test('listVehicleSharingSessionEvents filters by vehicleId', () async {
    final service = RelayActivityLogService(db);
    await service.append(
      kind: RelayActivityLogKinds.vehicleSharingOfferSent,
      initiatorKind: RelayActivityLogService.initiatorSelf,
      details: {'vehicleId': 'vehicle:a', 'linkId': 'link:a'},
    );
    await service.append(
      kind: RelayActivityLogKinds.vehicleUseSessionStartReceived,
      initiatorKind: RelayActivityLogService.initiatorContact,
      initiatorContactId: 'c1',
      details: {'vehicleId': 'vehicle:b'},
    );
    await service.append(
      kind: RelayActivityLogKinds.vehicleFuelPurchaseSent,
      initiatorKind: RelayActivityLogService.initiatorSelf,
      details: {'vehicleId': 'vehicle:a'},
    );
    await service.append(
      kind: RelayActivityLogKinds.contactDeleted,
      initiatorKind: RelayActivityLogService.initiatorSelf,
    );

    final forA = await service.listVehicleSharingSessionEvents('vehicle:a');
    expect(forA, hasLength(1));
    expect(forA.single.kind, RelayActivityLogKinds.vehicleSharingOfferSent);

    final forB = await service.listVehicleSharingSessionEvents('vehicle:b');
    expect(forB, hasLength(1));
    expect(
      forB.single.kind,
      RelayActivityLogKinds.vehicleUseSessionStartReceived,
    );
  });

  test('listVehicleSharingSessionEvents resolves vehicleId via linkId',
      () async {
    final now = DateTime.utc(2026, 8, 1);
    await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: 'vehicle:via-link',
            ownerContactId: kVehicleOwnerSelfContactId,
            vehicleKind: 'car',
            displayLabel: 'Via Link',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.vehicleSharingLinks).insert(
          VehicleSharingLinksCompanion.insert(
            id: 'link:resolve',
            vehicleId: 'vehicle:via-link',
            borrowerContactId: 'contact:b',
            ownerContactId: kVehicleOwnerSelfContactId,
            status: 'pending',
            createdAt: now,
          ),
        );

    final service = RelayActivityLogService(db);
    await service.append(
      kind: RelayActivityLogKinds.vehicleSharingOfferReceived,
      initiatorKind: RelayActivityLogService.initiatorContact,
      initiatorContactId: 'contact:owner',
      details: {'linkId': 'link:resolve'},
    );

    final rows =
        await service.listVehicleSharingSessionEvents('vehicle:via-link');
    expect(rows, hasLength(1));
    expect(rows.single.kind, RelayActivityLogKinds.vehicleSharingOfferReceived);
  });
}
