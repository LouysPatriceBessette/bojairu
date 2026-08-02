import '../db/app_database.dart';
import '../db/repositories/contacts_repository.dart';
import '../db/repositories/vehicles_repository.dart';
import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import 'vehicle_gap_correction.dart';
import 'vehicle_owner_contact.dart';

/// Pending gap verification summary (signed gap; negative → removed, positive → added).
String pendingGapCorrectionSummaryLabel({
  required AppLocalizations l10n,
  required String gapDisplay,
  required int gapTenths,
}) {
  if (gapTenths < 0) {
    return l10n.vehicleLogCorrectionGapMustBeRemoved(gapDisplay);
  }
  return l10n.vehicleLogCorrectionGapMustBeAdded(gapDisplay);
}

Future<String> resolveVehicleContactDisplayName(
  String contactId, {
  required AppPreferences prefs,
  required AppLocalizations l10n,
  String? vehicleDisplayLabel,
}) async {
  if (vehicleContactIsOwnerSelf(contactId)) {
    final name = prefs.displayName.trim();
    return name.isNotEmpty ? name : l10n.vehicleGapAttributionSelf;
  }
  if (vehicleContactIsBorrowerSelf(contactId)) {
    final label = (vehicleDisplayLabel ?? '').trim();
    return label.isNotEmpty ? label : l10n.vehicleGapAttributionSelf;
  }
  final contact = await ContactsRepository(AppDatabase.processScope).get(contactId);
  final name = contact?.displayName.trim() ?? '';
  return name.isNotEmpty ? name : contactId;
}

Future<String> meterReadingRoleLabel({
  required AppLocalizations l10n,
  required AppPreferences prefs,
  required VehicleMeterReading reading,
  required VehiclesRepository repo,
}) async {
  final role = MeterReadingRole.fromWire(reading.readingRole);
  var userContactId = reading.recordedByContactId;
  if (reading.vehicleUseId != null) {
    final use = await repo.getVehicleUse(reading.vehicleUseId!);
    if (use != null) {
      userContactId = use.attributedContactId;
    }
  }
  final vehicle = await repo.getVehicle(reading.vehicleId);
  final userName = await resolveVehicleContactDisplayName(
    userContactId,
    prefs: prefs,
    l10n: l10n,
    vehicleDisplayLabel: vehicle?.displayLabel,
  );

  if (role == MeterReadingRole.correction || reading.isCorrection) {
    if (isGapAppliedCorrectionReading(reading)) {
      return l10n.vehicleLogReadingRoleCorrectionApplied;
    }
    if (isMeterReadingReplacement(reading)) {
      final superseded = reading.supersedesReadingId == null
          ? null
          : await repo.getMeterReading(reading.supersedesReadingId!);
      if (superseded != null) {
        final supersededLabel = await meterReadingRoleLabel(
          l10n: l10n,
          prefs: prefs,
          reading: superseded,
          repo: repo,
        );
        return l10n.vehicleLogReadingRoleCorrectionReplaces(supersededLabel);
      }
    }
    final decoded = decodeGapCorrectionNote(reading.correctionNote);
    return switch (decoded?.context) {
      GapCorrectionContext.sessionStart =>
        l10n.vehicleLogReadingRoleCorrectionSessionStart(userName),
      GapCorrectionContext.sessionEnd =>
        l10n.vehicleLogReadingRoleCorrectionSessionStart(userName),
      GapCorrectionContext.standalone =>
        l10n.vehicleLogReadingRoleCorrectionStandalone(userName),
      GapCorrectionContext.applied => l10n.vehicleLogReadingRoleCorrectionApplied,
      null => l10n.vehicleLogReadingRoleCorrectionBy(userName),
    };
  }

  return switch (role) {
    MeterReadingRole.sessionEnd =>
      l10n.vehicleLogReadingRoleSessionEnd(userName),
    MeterReadingRole.sessionStart =>
      l10n.vehicleLogReadingRoleSessionStart(userName),
    MeterReadingRole.standalone => l10n.vehicleLogReadingRoleStandalone,
    MeterReadingRole.fuelPurchase => l10n.vehicleLogReadingRoleFuelPurchase,
    MeterReadingRole.correction => l10n.vehicleLogReadingRoleCorrectionBy(userName),
    null => reading.readingRole,
  };
}
