import 'dart:typed_data';

import 'package:compartarenta/relay/envelopes.dart';
import 'package:compartarenta/relay/identity_keystore.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_sharing_lifecycle_transport_service.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_usage_balance.dart';
import 'package:compartarenta/vehicle/sharing/vehicle_usage_balance_reconciliation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vehicle_sharing_revoke round-trips payload_json', () async {
    final aliceKeystore = InMemoryIdentityKeystore(
      seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
    );
    final bobKeystore = InMemoryIdentityKeystore(
      seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x40 + i)),
    );
    final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
    final alicePub = await aliceKeystore.publicKey();
    final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
    final bobPub = await bobKeystore.publicKey();

    const payload = '{"kind":"vehicleSharingRevoke","linkId":"vshare:1"}';
    final frame = await EnvelopeCodec.encryptVehicleSharingRevoke(
      envelope: VehicleSharingLifecycleEnvelope(
        senderLongTermPublicKey: alicePub,
        payloadJson: payload,
      ),
      senderLongTermPrivateKey: alicePriv,
      peerLongTermPublicKey: bobPub,
    );
    expect(frame[1], EnvelopeKind.vehicleSharingRevoke);
    final decoded = await EnvelopeCodec.decryptVehicleSharingRevoke(
      frame: frame,
      receiverLongTermPrivateKey: bobPriv,
    );
    expect(decoded.payloadJson, payload);
    expect(decoded.senderLongTermPublicKey, equals(alicePub));
  });

  test('vehicle_sharing_reactivate propose/accept round-trip', () async {
    final aliceKeystore = InMemoryIdentityKeystore(
      seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 2)),
    );
    final bobKeystore = InMemoryIdentityKeystore(
      seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x50 + i)),
    );
    final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
    final alicePub = await aliceKeystore.publicKey();
    final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
    final bobPub = await bobKeystore.publicKey();

    const propose = '{"kind":"vehicleSharingReactivatePropose","linkId":"x"}';
    final proposeFrame =
        await EnvelopeCodec.encryptVehicleSharingReactivatePropose(
      envelope: VehicleSharingLifecycleEnvelope(
        senderLongTermPublicKey: alicePub,
        payloadJson: propose,
      ),
      senderLongTermPrivateKey: alicePriv,
      peerLongTermPublicKey: bobPub,
    );
    expect(proposeFrame[1], EnvelopeKind.vehicleSharingReactivatePropose);
    final proposeDecoded =
        await EnvelopeCodec.decryptVehicleSharingReactivatePropose(
      frame: proposeFrame,
      receiverLongTermPrivateKey: bobPriv,
    );
    expect(proposeDecoded.payloadJson, propose);

    const accept = '{"kind":"vehicleSharingReactivateAccept","linkId":"x"}';
    final acceptFrame =
        await EnvelopeCodec.encryptVehicleSharingReactivateAccept(
      envelope: VehicleSharingLifecycleEnvelope(
        senderLongTermPublicKey: bobPub,
        payloadJson: accept,
      ),
      senderLongTermPrivateKey: bobPriv,
      peerLongTermPublicKey: alicePub,
    );
    expect(acceptFrame[1], EnvelopeKind.vehicleSharingReactivateAccept);
    final acceptDecoded =
        await EnvelopeCodec.decryptVehicleSharingReactivateAccept(
      frame: acceptFrame,
      receiverLongTermPrivateKey: alicePriv,
    );
    expect(acceptDecoded.payloadJson, accept);
  });

  test('vehicle_use_session_end_by_owner round-trips session_json', () async {
    final aliceKeystore = InMemoryIdentityKeystore(
      seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 3)),
    );
    final bobKeystore = InMemoryIdentityKeystore(
      seed: Uint8List.fromList(List<int>.generate(32, (i) => 0x60 + i)),
    );
    final alicePriv = await aliceKeystore.loadOrCreatePrivateKey();
    final alicePub = await aliceKeystore.publicKey();
    final bobPriv = await bobKeystore.loadOrCreatePrivateKey();
    final bobPub = await bobKeystore.publicKey();

    const session = '{"kind":"vehicleUseSessionEndByOwner","linkId":"vshare:1"}';
    final frame = await EnvelopeCodec.encryptVehicleUseSessionEndByOwner(
      envelope: VehicleUseSessionEndEnvelope(
        senderLongTermPublicKey: alicePub,
        sessionJson: session,
      ),
      senderLongTermPrivateKey: alicePriv,
      peerLongTermPublicKey: bobPub,
    );
    expect(frame[1], EnvelopeKind.vehicleUseSessionEndByOwner);
    final decoded = await EnvelopeCodec.decryptVehicleUseSessionEndByOwner(
      frame: frame,
      receiverLongTermPrivateKey: bobPriv,
    );
    expect(decoded.sessionJson, session);
  });

  test('parseRevoke validates kind and freeze map', () {
    final now = DateTime.utc(2026, 8, 7, 12);
    final breakdown = VehicleUsageBalanceBreakdown(
      litersPer100Km: 8,
      distanceKm: 10,
      pricePerLiterMinor: 150,
      fuelPurchasesInAverage: 1,
      borrowerFuelCostMinor: 0,
      borrowerMaintenanceCostMinor: 0,
      ratePerKmMinor: 10,
      estimatedFuelCostMinor: 100,
      compensationMinor: 100,
      balanceMinor: 310,
      windowStart: now.subtract(const Duration(days: 7)),
      windowEnd: now,
      distanceLineItems: const [],
      borrowerFuelLineItems: const [],
      borrowerMaintenanceLineItems: const [],
    );
    // exportRevokeJson does not touch AppDatabase fields.
    final raw = _exportRevokeWithoutDb(
      linkId: 'vshare:1',
      vehicleId: 'vehicle:1',
      revokedAt: now,
      freezeId: 'ubfreeze:1',
      breakdown: breakdown,
    );
    final parsed = VehicleSharingLifecycleTransportService.parseRevokeStatic(
      raw,
    );
    expect(parsed['kind'], VehicleSharingLifecycleTransportService.revokeKind);
    expect(parsed['linkId'], 'vshare:1');
    final freeze = parsed['freeze'] as Map<String, dynamic>;
    expect(freeze['freezeId'], 'ubfreeze:1');
    expect(freeze['balanceMinor'], 310);
  });

  test('carried forward zero is settlement complete', () {
    expect(
      usageBalanceCarriedForwardMinor(
        confirmedFreezeBalanceMinors: const [6810],
        confirmedTransferLedgerDeltas: const [-6500, -310],
      ),
      0,
    );
  });
}

String _exportRevokeWithoutDb({
  required String linkId,
  required String vehicleId,
  required DateTime revokedAt,
  required String freezeId,
  required VehicleUsageBalanceBreakdown breakdown,
}) {
  return VehicleSharingLifecycleTransportService.exportRevokeJsonStatic(
    linkId: linkId,
    vehicleId: vehicleId,
    revokedAt: revokedAt,
    freezeId: freezeId,
    breakdown: breakdown,
  );
}
