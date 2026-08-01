import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../db/repositories/vehicles_repository.dart';
import '../vehicle/vehicle_consumption_estimation_mode.dart';
import '../vehicle/vehicle_kind.dart';
import '../vehicle/vehicle_maintenance_categories.dart';
import '../vehicle/vehicle_meter_photo_path.dart';
import '../vehicle/vehicle_owner_contact.dart';
import 'qa_fcm_wake_push_seed.dart';
import 'qa_scenario_seed_helpers.dart';
import 'qa_vehicle_seed_helpers.dart';
import 'qa_vehicle_sharing_offer_seed.dart';

/// Fixed ids so Louys and Monica share the same vehicle/link after seed
/// (end state of `vehicle_sharing_offer_happy_path` without offer/accept UI).
const kQaVehicleSharingActiveVehicleId = 'vehicle:qa-civic-sharing';
const kQaVehicleSharingActiveLinkId = 'vshare:qa-civic-monica';

/// Louys: connected Monica + owned QA Civic + **active** share to Monica.
Future<void> seedQaVehicleSharingActiveOwner(AppDatabase db) async {
  final now = kQaSeedCreatedAt;
  await qaRestoreFcmWakeIdentity(kQaFcmWakeLouysPrivateKeySeed);
  final monicaPubB64 =
      await qaFcmWakePublicKeyB64ForSeed(kQaFcmWakeMonicaPrivateKeySeed);
  await qaSeedFcmWakeConnectedContact(
    db: db,
    contactId: kQaFcmWakeMonicaContactId,
    displayName: 'Monica QA',
    avatarId: 'a01',
    peerPublicMaterialB64: monicaPubB64,
    now: now,
  );
  await seedQaVehicleSharingActiveOwnerLocalData(db);
}

/// Monica: connected Louys + external QA Civic + **active** accessible share.
Future<void> seedQaVehicleSharingActiveBorrower(AppDatabase db) async {
  await seedQaVehicleSharingOfferBorrower(db);
  await seedQaVehicleSharingActiveBorrowerLocalData(db);
}

/// Vehicle + active outbound link (no identity). Used by seed and unit tests.
@visibleForTesting
Future<void> seedQaVehicleSharingActiveOwnerLocalData(AppDatabase db) async {
  final repo = VehiclesRepository(db);
  final now = DateTime.now().toUtc();
  await db.into(db.vehicles).insert(
        VehiclesCompanion.insert(
          id: kQaVehicleSharingActiveVehicleId,
          ownerContactId: kVehicleOwnerSelfContactId,
          vehicleKind: VehicleKind.car.wire,
          displayLabel: kQaVehicleE2eDisplayLabel,
          make: const drift.Value('Honda'),
          model: const drift.Value('Civic'),
          color: const drift.Value('Bleu'),
          modelYear: const drift.Value(2020),
          fuelTankCapacityLiters: const drift.Value(60),
          consumptionEstimationMode: drift.Value(
            VehicleConsumptionEstimationMode.simple.wire,
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );
  final preview = (kQaVehicleE2eOilChangeIntervalTenths ~/ 10)
      .clamp(1, kQaVehicleE2eOilChangeIntervalTenths);
  await db.into(db.vehicleMaintenanceRules).insert(
        VehicleMaintenanceRulesCompanion.insert(
          id: '$kQaVehicleSharingActiveVehicleId:rule:oil',
          vehicleId: kQaVehicleSharingActiveVehicleId,
          category: VehicleMaintenanceCategoryWire.oil.wire,
          intervalAmount: kQaVehicleE2eOilChangeIntervalTenths,
          previewWindowAmount: drift.Value(preview),
        ),
      );
  await repo.saveMeterReading(
    vehicleId: kQaVehicleSharingActiveVehicleId,
    value: kQaVehicleE2eInitialMeterTenths,
    unit: repo.meterUnitForKind(VehicleKind.car),
    photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
    recordedByContactId: kVehicleOwnerSelfContactId,
    role: MeterReadingRole.standalone,
  );
  final linkAt = kQaSeedCreatedAt;
  await db.into(db.vehicleSharingLinks).insert(
        VehicleSharingLinksCompanion.insert(
          id: kQaVehicleSharingActiveLinkId,
          vehicleId: kQaVehicleSharingActiveVehicleId,
          ownerContactId: kVehicleOwnerSelfContactId,
          borrowerContactId: kQaFcmWakeMonicaContactId,
          status: VehicleSharingLinkStatus.active.wire,
          createdAt: linkAt,
          acceptedAt: drift.Value(linkAt),
          ratePerKmMinor: const drift.Value(25),
          rateCurrency: const drift.Value('CAD'),
          availabilityWeekJson: const drift.Value(''),
          ownerRulesText: const drift.Value(''),
        ),
      );
}

/// External vehicle + active inbound link (no identity). Used by seed and tests.
@visibleForTesting
Future<void> seedQaVehicleSharingActiveBorrowerLocalData(AppDatabase db) async {
  final repo = VehiclesRepository(db);
  await repo.upsertExternalOwnedVehicle(
    vehicleId: kQaVehicleSharingActiveVehicleId,
    ownerContactId: kQaFcmWakeLouysContactId,
    vehicleKind: VehicleKind.car.wire,
    displayLabel: kQaVehicleE2eDisplayLabel,
    make: 'Honda',
    model: 'Civic',
    color: 'Bleu',
    modelYear: 2020,
    fuelTankCapacityLiters: 60,
    consumptionEstimationMode: VehicleConsumptionEstimationMode.simple.wire,
  );
  final now = kQaSeedCreatedAt;
  await db.into(db.vehicleSharingLinks).insert(
        VehicleSharingLinksCompanion.insert(
          id: kQaVehicleSharingActiveLinkId,
          vehicleId: kQaVehicleSharingActiveVehicleId,
          ownerContactId: kQaFcmWakeLouysContactId,
          borrowerContactId: kVehicleBorrowerSelfContactId,
          status: VehicleSharingLinkStatus.active.wire,
          createdAt: now,
          acceptedAt: drift.Value(now),
          ratePerKmMinor: const drift.Value(25),
          rateCurrency: const drift.Value('CAD'),
          availabilityWeekJson: const drift.Value(''),
          ownerRulesText: const drift.Value(''),
        ),
      );
}
