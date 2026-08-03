import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/db/repositories/vehicles_repository.dart';
import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/vehicle/vehicle_gap_flow.dart';
import 'package:compartarenta/vehicle/vehicle_kind.dart';
import 'package:compartarenta/vehicle/vehicle_owner_contact.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('borrower meter recheck confirm returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showBorrowerMeterRecheckDialog(
                  context,
                  gapDisplay: '12.0 km',
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Check this reading'), findsOneWidget);
    await tester.tap(find.text('I confirm'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('borrower meter recheck correct returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showBorrowerMeterRecheckDialog(
                  context,
                  gapDisplay: '12.0 km',
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'll correct it"));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets(
    'confirmOneTankSuspiciousPositiveGap skips horometer',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      AppDatabase.bindProcessScope(db);

      final t0 = DateTime.utc(2026, 8, 1);
      await db.into(db.vehicles).insert(
            VehiclesCompanion.insert(
              id: 'vehicle:boat',
              ownerContactId: kVehicleOwnerSelfContactId,
              vehicleKind: VehicleKind.boat.wire,
              displayLabel: 'Boat',
              createdAt: t0,
              updatedAt: t0,
              fuelTankCapacityLiters: const Value(60),
            ),
          );
      final vehicle = await VehiclesRepository(db).getVehicle('vehicle:boat');
      expect(vehicle, isNotNull);

      bool? ok;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  final check = await confirmOneTankSuspiciousPositiveGap(
                    context: context,
                    vehicle: vehicle!,
                    gapTenths: 9000,
                    usesHorometer: true,
                    distanceUnit: DistanceUnit.km,
                  );
                  ok = check == OneTankSuspiciousGapCheck.notApplicable;
                },
                child: const Text('run'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();
      expect(ok, isTrue);
      expect(find.text('Unusually large difference'), findsNothing);
    },
  );

  testWidgets(
    'confirmMeterGapsBeforeSave borrower lower reading asks recheck',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      AppDatabase.bindProcessScope(db);

      final repo = VehiclesRepository(db);
      const vehicleId = 'vehicle:borrower-gap';
      final t0 = DateTime.utc(2026, 8, 1);
      await db.into(db.vehicles).insert(
            VehiclesCompanion.insert(
              id: vehicleId,
              ownerContactId: kVehicleOwnerSelfContactId,
              vehicleKind: VehicleKind.car.wire,
              displayLabel: 'Car',
              createdAt: t0,
              updatedAt: t0,
              fuelTankCapacityLiters: const Value(60),
            ),
          );
      await db.into(db.vehicleMeterReadings).insert(
            VehicleMeterReadingsCompanion.insert(
              id: 'meter:known',
              vehicleId: vehicleId,
              value: 100000,
              unit: 'odometer_km',
              photoPath: 'a.jpg',
              recordedAt: t0,
              recordedByContactId: kVehicleOwnerSelfContactId,
              readingRole: MeterReadingRole.standalone.wire,
            ),
          );
      final vehicle = await repo.getVehicle(vehicleId);
      expect(vehicle, isNotNull);

      MeterGapConfirmResult? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return TextButton(
                onPressed: () async {
                  result = await confirmMeterGapsBeforeSave(
                    context: context,
                    l10n: l10n,
                    repo: repo,
                    vehicle: vehicle!,
                    parsedMeter: 90000,
                    actingContactId: 'contact:borrower',
                    isOwnerContext: false,
                    usesHorometer: false,
                    distanceUnit: DistanceUnit.km,
                    attributePositiveGap: true,
                  );
                },
                child: const Text('save'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(find.text('Check this reading'), findsOneWidget);
      await tester.tap(find.text("I'll correct it"));
      await tester.pumpAndSettle();
      expect(result?.proceed, isFalse);

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I confirm'));
      await tester.pumpAndSettle();
      expect(result?.proceed, isTrue);
      expect(result?.divergenceTenths, -10000);
    },
  );

  testWidgets(
    'confirmMeterGapsBeforeSave shows suspicious when gap exceeds one tank',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      AppDatabase.bindProcessScope(db);

      final repo = VehiclesRepository(db);
      const vehicleId = 'vehicle:sus-gap';
      final t0 = DateTime.utc(2026, 8, 1);
      await db.into(db.vehicles).insert(
            VehiclesCompanion.insert(
              id: vehicleId,
              ownerContactId: kVehicleOwnerSelfContactId,
              vehicleKind: VehicleKind.car.wire,
              displayLabel: 'Car',
              createdAt: t0,
              updatedAt: t0,
              fuelTankCapacityLiters: const Value(60),
            ),
          );
      await db.into(db.vehicleMeterReadings).insert(
            VehicleMeterReadingsCompanion.insert(
              id: 'meter:known',
              vehicleId: vehicleId,
              value: 100000,
              unit: 'odometer_km',
              photoPath: 'a.jpg',
              recordedAt: t0,
              recordedByContactId: kVehicleOwnerSelfContactId,
              readingRole: MeterReadingRole.standalone.wire,
            ),
          );
      final vehicle = await repo.getVehicle(vehicleId);
      expect(vehicle, isNotNull);

      MeterGapConfirmResult? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return TextButton(
                onPressed: () async {
                  result = await confirmMeterGapsBeforeSave(
                    context: context,
                    l10n: l10n,
                    repo: repo,
                    vehicle: vehicle!,
                    // +900 km vs 800 km one-tank max at 7.5 L/100 with 60 L.
                    parsedMeter: 109000,
                    actingContactId: 'contact:borrower',
                    isOwnerContext: false,
                    usesHorometer: false,
                    distanceUnit: DistanceUnit.km,
                    attributePositiveGap: false,
                    confirmOneTankSuspiciousGap: true,
                  );
                },
                child: const Text('save'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(find.text('Unusually large difference'), findsOneWidget);
      await tester.tap(find.text('Review entry'));
      await tester.pumpAndSettle();
      expect(result?.proceed, isFalse);

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this reading anyway'));
      await tester.pumpAndSettle();
      expect(result?.proceed, isTrue);
      expect(result?.divergenceTenths, 9000);
    },
  );

  testWidgets(
    'borrower small positive gap does not show any-difference dialog',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      AppDatabase.bindProcessScope(db);

      final repo = VehiclesRepository(db);
      const vehicleId = 'vehicle:small-gap';
      final t0 = DateTime.utc(2026, 8, 1);
      await db.into(db.vehicles).insert(
            VehiclesCompanion.insert(
              id: vehicleId,
              ownerContactId: kVehicleOwnerSelfContactId,
              vehicleKind: VehicleKind.car.wire,
              displayLabel: 'Car',
              createdAt: t0,
              updatedAt: t0,
              fuelTankCapacityLiters: const Value(60),
            ),
          );
      await db.into(db.vehicleMeterReadings).insert(
            VehicleMeterReadingsCompanion.insert(
              id: 'meter:known',
              vehicleId: vehicleId,
              value: 500050,
              unit: 'odometer_km',
              photoPath: 'a.jpg',
              recordedAt: t0,
              recordedByContactId: kVehicleOwnerSelfContactId,
              readingRole: MeterReadingRole.standalone.wire,
            ),
          );
      final vehicle = await repo.getVehicle(vehicleId);
      expect(vehicle, isNotNull);

      MeterGapConfirmResult? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return TextButton(
                onPressed: () async {
                  result = await confirmMeterGapsBeforeSave(
                    context: context,
                    l10n: l10n,
                    repo: repo,
                    vehicle: vehicle!,
                    // +5 km — within one tank; Emprunteur should not be prompted.
                    parsedMeter: 500100,
                    actingContactId: 'contact:borrower',
                    isOwnerContext: false,
                    usesHorometer: false,
                    distanceUnit: DistanceUnit.km,
                    attributePositiveGap: true,
                    confirmOneTankSuspiciousGap: true,
                  );
                },
                child: const Text('save'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('difference of'), findsNothing);
      expect(find.text('Unusually large difference'), findsNothing);
      expect(result?.proceed, isTrue);
      expect(result?.divergenceTenths, isNull);
    },
  );
}
