import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/vehicle/vehicle_emprunteur_cap.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
import 'package:compartarenta/vehicle/vehicle_meter_photo_path.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Vehicle> _createSample(
  VehiclesRepository repo, {
  required String label,
}) {
  return repo.createVehicle(
    kind: VehicleKind.car,
    displayLabel: label,
    make: 'Make',
    model: 'Model',
    color: 'Blue',
    modelYear: 2020,
    oilChangeIntervalAmount: 50000,
    initialMeterValue: 100000,
    initialMeterPhotoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
  );
}

Future<VehicleSharingLink> _offer(
  VehiclesRepository repo, {
  required String vehicleId,
  required String borrowerContactId,
  DateTime? expiresAt,
  String status = 'pending',
}) async {
  if (status == 'pending') {
    return repo.createSharingOffer(
      vehicleId: vehicleId,
      borrowerContactId: borrowerContactId,
      expiresAt: expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 24)),
    );
  }
  final link = await repo.createSharingOffer(
    vehicleId: vehicleId,
    borrowerContactId: borrowerContactId,
    expiresAt: expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 24)),
  );
  if (status == 'active') {
    await repo.acceptSharingLink(link.id);
  }
  return (await repo.getSharingLink(link.id))!;
}

void main() {
  group('EmprunteurCapLogic', () {
    test('last slot and exceed helpers', () {
      final four = {'a', 'b', 'c', 'd'};
      expect(
        EmprunteurCapLogic.wouldOccupyLastSlot(
          countingContactIds: four,
          borrowerContactId: 'e',
        ),
        isTrue,
      );
      expect(
        EmprunteurCapLogic.wouldExceedCap(
          countingContactIds: four,
          borrowerContactId: 'e',
        ),
        isFalse,
      );
      final five = {...four, 'e'};
      expect(
        EmprunteurCapLogic.wouldExceedCap(
          countingContactIds: five,
          borrowerContactId: 'f',
        ),
        isTrue,
      );
      expect(
        EmprunteurCapLogic.wouldExceedCap(
          countingContactIds: five,
          borrowerContactId: 'a',
        ),
        isFalse,
      );
    });
  });

  test('five distinct OK; sixth new contact blocked; same contact two vehicles counts once',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.bindProcessScope(db);
    addTearDown(() {
      AppDatabase.clearProcessScopeIfReferencing(db);
      db.close();
    });

    final repo = VehiclesRepository(db);
    final v1 = await _createSample(repo, label: 'V1');
    final v2 = await _createSample(repo, label: 'V2');

    for (var i = 0; i < 5; i++) {
      await _offer(
        repo,
        vehicleId: v1.id,
        borrowerContactId: 'contact:$i',
        status: 'active',
      );
    }
    expect(
      (await repo.distinctEmprunteurContactIdsCountingTowardCap()).length,
      kMaxDistinctEmprunteurs,
    );

    await expectLater(
      repo.createSharingOffer(
        vehicleId: v1.id,
        borrowerContactId: 'contact:sixth',
      ),
      throwsA(isA<EmprunteurCapExceededException>()),
    );

    // Same Emprunteur on a second owned vehicle is allowed.
    final second = await repo.createSharingOffer(
      vehicleId: v2.id,
      borrowerContactId: 'contact:0',
    );
    expect(second.borrowerContactId, 'contact:0');
    expect(
      (await repo.distinctEmprunteurContactIdsCountingTowardCap()).length,
      kMaxDistinctEmprunteurs,
    );
  });

  test('pending invitation counts toward cap until expiry', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.bindProcessScope(db);
    addTearDown(() {
      AppDatabase.clearProcessScopeIfReferencing(db);
      db.close();
    });

    final repo = VehiclesRepository(db);
    final v = await _createSample(repo, label: 'V');
    final now = DateTime.now().toUtc();
    final pendingExpires = now.add(const Duration(hours: 2));

    for (var i = 0; i < 4; i++) {
      await _offer(
        repo,
        vehicleId: v.id,
        borrowerContactId: 'contact:$i',
        status: 'active',
      );
    }
    await repo.createSharingOffer(
      vehicleId: v.id,
      borrowerContactId: 'contact:pending',
      expiresAt: pendingExpires,
    );
    expect(
      (await repo.distinctEmprunteurContactIdsCountingTowardCap()).length,
      5,
    );
    await expectLater(
      repo.createSharingOffer(
        vehicleId: v.id,
        borrowerContactId: 'contact:sixth',
        expiresAt: now.add(const Duration(days: 1)),
      ),
      throwsA(isA<EmprunteurCapExceededException>()),
    );

    await repo.expirePendingOffersPastDeadline(
      nowUtc: pendingExpires.add(const Duration(seconds: 1)),
    );
    expect(
      (await repo.distinctEmprunteurContactIdsCountingTowardCap(
        nowUtc: pendingExpires.add(const Duration(seconds: 1)),
      ))
          .length,
      4,
    );
    final freed = await repo.createSharingOffer(
      vehicleId: v.id,
      borrowerContactId: 'contact:sixth',
      expiresAt: now.add(const Duration(days: 1)),
    );
    expect(freed.borrowerContactId, 'contact:sixth');
  });

  test('reactivate pending expires back to revoked and frees the slot', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.bindProcessScope(db);
    addTearDown(() {
      AppDatabase.clearProcessScopeIfReferencing(db);
      db.close();
    });

    final repo = VehiclesRepository(db);
    final v = await _createSample(repo, label: 'V');
    final now = DateTime.now().toUtc();
    final reactivateExpires = now.add(const Duration(hours: 2));

    for (var i = 0; i < 4; i++) {
      await _offer(
        repo,
        vehicleId: v.id,
        borrowerContactId: 'contact:$i',
        status: 'active',
      );
    }
    final link = await _offer(
      repo,
      vehicleId: v.id,
      borrowerContactId: 'contact:revoked',
      status: 'active',
    );
    await repo.revokeSharingLink(link.id);
    expect(
      (await repo.distinctEmprunteurContactIdsCountingTowardCap()).length,
      4,
    );

    await repo.markSharingLinkReactivatePending(
      link.id,
      expiresAt: reactivateExpires,
    );
    expect(
      (await repo.distinctEmprunteurContactIdsCountingTowardCap()).length,
      5,
    );

    await repo.expirePendingOffersPastDeadline(
      nowUtc: reactivateExpires.add(const Duration(seconds: 1)),
    );
    final after = await repo.getSharingLink(link.id);
    expect(after!.status, VehicleSharingLinkStatus.revoked.wire);
    expect(after.expiresAt, isNull);
    expect(
      (await repo.distinctEmprunteurContactIdsCountingTowardCap(
        nowUtc: reactivateExpires.add(const Duration(seconds: 1)),
      ))
          .length,
      4,
    );
  });

  test('createSharingOffer refuses self-borrow ids', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.bindProcessScope(db);
    addTearDown(() {
      AppDatabase.clearProcessScopeIfReferencing(db);
      db.close();
    });

    final repo = VehiclesRepository(db);
    final v = await _createSample(repo, label: 'Own');

    await expectLater(
      repo.createSharingOffer(
        vehicleId: v.id,
        borrowerContactId: kVehicleOwnerSelfContactId,
      ),
      throwsA(isA<SelfBorrowForbiddenException>()),
    );
    await expectLater(
      repo.createSharingOffer(
        vehicleId: v.id,
        borrowerContactId: kVehicleBorrowerSelfContactId,
      ),
      throwsA(isA<SelfBorrowForbiddenException>()),
    );
  });
}
