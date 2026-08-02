import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:compartarenta/vehicle/vehicle_usage_context.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleUse _use({required String attributedContactId}) {
  final now = DateTime.utc(2026, 8, 1, 12);
  return VehicleUse(
    id: 'use:test',
    vehicleId: 'vehicle:test',
    attributedContactId: attributedContactId,
    startedAt: now,
    startReadingId: 'reading:start',
    endedAt: null,
    endReadingId: null,
    usageAmount: null,
    drivingRoutePercent: null,
    drivingCityPercent: null,
    drivingTrafficPercent: null,
    sessionConsumptionMode: null,
  );
}

void main() {
  test('owner can end only a self-attributed open use', () {
    const owner = VehicleUsageContext.owner();
    expect(
      canEndUseSessionAsActor(
        openUse: _use(attributedContactId: kVehicleOwnerSelfContactId),
        context: owner,
      ),
      isTrue,
    );
    expect(
      canEndUseSessionAsActor(
        openUse: _use(attributedContactId: 'contact:monica'),
        context: owner,
      ),
      isFalse,
    );
    expect(
      canEndUseSessionAsActor(openUse: null, context: owner),
      isFalse,
    );
  });

  test('borrower can end only their attributed open use', () {
    const borrower = VehicleUsageContext.borrower(
      actingContactId: 'contact:monica',
    );
    expect(
      canEndUseSessionAsActor(
        openUse: _use(attributedContactId: 'contact:monica'),
        context: borrower,
      ),
      isTrue,
    );
    expect(
      canEndUseSessionAsActor(
        openUse: _use(attributedContactId: kVehicleOwnerSelfContactId),
        context: borrower,
      ),
      isFalse,
    );
  });
}
