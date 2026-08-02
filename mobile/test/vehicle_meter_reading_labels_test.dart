import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
import 'package:compartarenta/vehicle/vehicle_meter_photo_path.dart';
import 'package:compartarenta/vehicle/vehicle_meter_reading_labels.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VehiclesRepository repo;
  late AppPreferences prefs;
  late AppLocalizations l10n;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.load();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = VehiclesRepository(db);
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  tearDown(() async {
    await db.close();
  });

  test('borrower self session start uses vehicle display label', () async {
    const vehicleId = 'vehicle:civic';
    await db.into(db.vehicles).insert(
          VehiclesCompanion.insert(
            id: vehicleId,
            ownerContactId: 'contact:owner',
            vehicleKind: VehicleKind.car.wire,
            displayLabel: 'QA Civic',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    final reading = await repo.saveMeterReading(
      vehicleId: vehicleId,
      value: 500500,
      unit: 'odometer_km',
      photoPath: kVehicleMeterPhotoKnownUnchangedSentinel,
      recordedByContactId: kVehicleBorrowerSelfContactId,
      role: MeterReadingRole.sessionStart,
      recordedAt: DateTime.utc(2026, 8, 2, 9, 5),
    );

    final label = await meterReadingRoleLabel(
      l10n: l10n,
      prefs: prefs,
      reading: reading,
      repo: repo,
    );
    expect(label, 'QA Civic - Début');
  });

  test('resolveVehicleContactDisplayName maps borrower self to vehicle name',
      () async {
    final name = await resolveVehicleContactDisplayName(
      kVehicleBorrowerSelfContactId,
      prefs: prefs,
      l10n: l10n,
      vehicleDisplayLabel: 'QA Civic',
    );
    expect(name, 'QA Civic');
  });
}
