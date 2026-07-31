import '../db/app_database.dart';
import 'qa_fcm_wake_push_seed.dart';
import 'qa_scenario_seed_helpers.dart';
import 'qa_vehicle_seed_helpers.dart';

/// Louys (owner): fixed identity + connected Monica + QA Civic.
///
/// Reuses the FCM-wake debug keypair so both emulators share predictable
/// long-term keys without a Maestro handshake.
Future<void> seedQaVehicleSharingOfferOwner(AppDatabase db) async {
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
  await qaSeedE2eVehicle(db);
}

/// Monica (borrower): fixed identity + connected Louys (no owned vehicle).
Future<void> seedQaVehicleSharingOfferBorrower(AppDatabase db) async {
  final now = kQaSeedCreatedAt;
  await qaRestoreFcmWakeIdentity(kQaFcmWakeMonicaPrivateKeySeed);
  final louysPubB64 =
      await qaFcmWakePublicKeyB64ForSeed(kQaFcmWakeLouysPrivateKeySeed);
  await qaSeedFcmWakeConnectedContact(
    db: db,
    contactId: kQaFcmWakeLouysContactId,
    displayName: 'Louys QA',
    avatarId: 'a02',
    peerPublicMaterialB64: louysPubB64,
    now: now,
  );
}
