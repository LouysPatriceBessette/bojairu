import 'package:drift/drift.dart';

class Vehicles extends Table {
  TextColumn get id => text()();
  TextColumn get ownerContactId => text()();
  TextColumn get vehicleKind => text()();
  TextColumn get displayLabel => text()();
  TextColumn get make => text().withDefault(const Constant(''))();
  TextColumn get model => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant(''))();
  IntColumn get modelYear => integer().nullable()();
  TextColumn get licensePlate => text().withDefault(const Constant(''))();
  TextColumn get vin => text().withDefault(const Constant(''))();
  RealColumn get fuelTankCapacityLiters => real().nullable()();
  /// `simple` or `detailed` — road fuel consumption estimation style.
  TextColumn get consumptionEstimationMode =>
      text().withDefault(const Constant('detailed'))();
  /// When owner uses detailed mode, optionally require borrowers to declare mix.
  BoolColumn get requireDetailedDrivingMixForBorrowers =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  /// When set, the vehicle is deactivated (read-only). Null = active.
  DateTimeColumn get deactivatedAt => dateTime().nullable()();
  /// Sale-import undo still available (rename/consult only so far).
  BoolColumn get saleImportUndoAvailable =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class VehicleMeterReadings extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  IntColumn get value => integer()();
  TextColumn get unit => text()();
  TextColumn get photoPath => text()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get recordedByContactId => text()();
  TextColumn get vehicleUseId => text().nullable()();
  TextColumn get readingRole => text()();
  BoolColumn get isCorrection =>
      boolean().withDefault(const Constant(false))();
  TextColumn get correctionNote =>
      text().withDefault(const Constant(''))();
  BoolColumn get negativeGapAcknowledged =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isFullTank => boolean().nullable()();
  IntColumn get tankFillFraction => integer().nullable()();
  /// Set when a gap-verification correction row is resolved by the owner.
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  /// When set, this reading replaces [supersedesReadingId] for usage metrics;
  /// the superseded row stays in the journal unchanged.
  TextColumn get supersedesReadingId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class VehicleUses extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  TextColumn get attributedContactId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get startReadingId => text()();
  TextColumn get endReadingId => text().nullable()();
  IntColumn get usageAmount => integer().nullable()();
  /// Integer percent (0–100) of session distance on each driving condition.
  /// Set when a road-vehicle use session ends; null for legacy rows and boats.
  IntColumn get drivingRoutePercent => integer().nullable()();
  IntColumn get drivingCityPercent => integer().nullable()();
  IntColumn get drivingTrafficPercent => integer().nullable()();
  /// `simple` or `detailed` at session end; null on legacy rows.
  TextColumn get sessionConsumptionMode => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class VehicleConsumptionEstimateHistory extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  DateTimeColumn get anchorEndAt => dateTime()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get reliability => text()();
  RealColumn get litersPer100Km => real()();
  RealColumn get litersPer100KmRoute => real().nullable()();
  RealColumn get litersPer100KmCity => real().nullable()();
  RealColumn get litersPer100KmTraffic => real().nullable()();
  IntColumn get periodsInWindow => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class VehicleOdometerGaps extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  IntColumn get latestReadingBeforeGap => integer()();
  IntColumn get startReadingAfterGap => integer()();
  IntColumn get gapAmount => integer()();
  TextColumn get attributedContactId => text()();
  TextColumn get recordedByContactId => text()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get vehicleUseId => text().nullable()();
  TextColumn get correctionReadingId => text().nullable()();
  TextColumn get previousReadingId => text().nullable()();
  TextColumn get triggerReadingId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class FuelPurchases extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  DateTimeColumn get purchasedAt => dateTime()();
  IntColumn get costMinor => integer()();
  TextColumn get currency => text()();
  RealColumn get volumeLiters => real().nullable()();
  IntColumn get meterReadingValue => integer().nullable()();
  TextColumn get meterPhotoPath => text().nullable()();
  BoolColumn get isFullTank => boolean()();
  IntColumn get tankFillFraction => integer().nullable()();
  TextColumn get recordedByContactId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class MaintenanceEvents extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  DateTimeColumn get servicedAt => dateTime()();
  TextColumn get category => text()();
  IntColumn get costMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get attachmentPath => text().nullable()();
  IntColumn get meterAtService => integer().nullable()();
  TextColumn get recordedByContactId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class VehicleMaintenanceRules extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  TextColumn get category => text()();
  IntColumn get intervalAmount => integer()();
  IntColumn get previewWindowAmount =>
      integer().withDefault(const Constant(500))();

  @override
  Set<Column> get primaryKey => {id};
}

class TrafficViolations extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  DateTimeColumn get violatedAt => dateTime()();
  TextColumn get violationType => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get responsibilityContactId => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get recordedByContactId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class VehicleSharingLinks extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  TextColumn get ownerContactId => text()();
  TextColumn get borrowerContactId => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get acceptedAt => dateTime().nullable()();
  DateTimeColumn get revokedAt => dateTime().nullable()();
  /// Usage compensation rate in minor currency units per km (0 = free).
  IntColumn get ratePerKmMinor => integer().withDefault(const Constant(0))();
  TextColumn get rateCurrency => text().withDefault(const Constant(''))();
  /// Legacy date-range columns (unused; week grid supersedes).
  DateTimeColumn get availabilityStart => dateTime().nullable()();
  DateTimeColumn get availabilityEnd => dateTime().nullable()();
  /// Half-hour week grid JSON (same shape as housing quiet hours), or empty.
  TextColumn get availabilityWeekJson =>
      text().withDefault(const Constant(''))();
  TextColumn get ownerRulesText => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class VehiclePhotoGalleries extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  IntColumn get galleryIndex => integer()();
  TextColumn get relativeDirectory => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class VehicleGalleryPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get galleryId => text()();
  TextColumn get relativeFilePath => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get capturedAt => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
