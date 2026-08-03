import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const kQaVehicleHub = 'qa-vehicle-hub';
const kQaVehicleAddFab = 'qa-vehicle-add-fab';
const kQaVehicleQuickActionSessionStart = 'qa-vehicle-quick-action-session-start';
const kQaVehicleQuickActionSessionEnd = 'qa-vehicle-quick-action-session-end';
const kQaVehicleQuickActionFuel = 'qa-vehicle-quick-action-fuel';
const kQaVehicleSave = 'qa-vehicle-save';

const kQaVehicleFieldLabel = 'qa-vehicle-field-label';
const kQaVehicleFieldMake = 'qa-vehicle-field-make';
const kQaVehicleFieldModel = 'qa-vehicle-field-model';
const kQaVehicleFieldColor = 'qa-vehicle-field-color';
const kQaVehicleFieldYear = 'qa-vehicle-field-year';
const kQaVehicleFieldMeter = 'qa-vehicle-field-meter';
const kQaVehicleFieldTankCapacity = 'qa-vehicle-field-tank-capacity';
const kQaVehicleFieldOilInterval = 'qa-vehicle-field-oil-interval';
const kQaVehicleConsumptionModeSimple = 'qa-vehicle-consumption-mode-simple';

/// Card id for the [vehicle_add] Maestro flow (`displayLabel`: Mon QA).
const kQaVehicleCardMonQa = 'qa-vehicle-card-mon-qa';

/// Card id for seeded E2E vehicle [kQaVehicleE2eDisplayLabel].
const kQaVehicleCardQaCivic = 'qa-vehicle-card-qa-civic';

/// Hub card after rename in [vehicle_sale_import] (displayLabel: QA Maserati).
const kQaVehicleCardQaMaserati = 'qa-vehicle-card-qa-maserati';

/// Latest meter reading on [kQaVehicleCardQaCivic] (hub card body).
const kQaVehicleCardQaCivicMeter = 'qa-vehicle-card-qa-civic-meter';

/// Estimated fuel volume on [kQaVehicleCardQaCivic] (hub card body).
const kQaVehicleCardQaCivicFuelTank = 'qa-vehicle-card-qa-civic-fuel-tank';

/// Consumption estimate line on [kQaVehicleCardQaCivic] (hub card body).
const kQaVehicleCardQaCivicConsumption = 'qa-vehicle-card-qa-civic-consumption';

/// Consumption reliability / detailed-mode helper line on the hub card.
const kQaVehicleCardQaCivicConsumptionReliability =
    'qa-vehicle-card-qa-civic-consumption-reliability';

const kQaVehicleFieldCost = 'qa-vehicle-field-cost';
const kQaVehicleFieldVolume = 'qa-vehicle-field-volume';
const kQaVehicleFieldFuelMeter = 'qa-vehicle-field-fuel-meter';
const kQaVehicleFieldSessionMeter = 'qa-vehicle-field-session-meter';
const kQaVehicleFieldSessionFullTank = 'qa-vehicle-field-session-full-tank';
const kQaVehicleFieldSessionTankLevel = 'qa-vehicle-field-session-tank-level';
const kQaVehicleFieldStandaloneMeter = 'qa-vehicle-field-standalone-meter';

const kQaVehicleDetail = 'qa-vehicle-detail';
const kQaVehicleDetailOdometerReading = 'qa-vehicle-detail-odometer-reading';
const kQaVehicleDetailEdit = 'qa-vehicle-detail-edit';
const kQaVehicleDetailExport = 'qa-vehicle-detail-export';
const kQaVehicleExportConfirm = 'qa-vehicle-export-confirm';
const kQaVehicleExportCancel = 'qa-vehicle-export-cancel';
const kQaVehicleExportSuccessDone = 'qa-vehicle-export-success-done';
const kQaVehicleImportAction = 'qa-vehicle-import-action';
const kQaVehicleImportConfirm = 'qa-vehicle-import-confirm';
const kQaVehicleImportCancel = 'qa-vehicle-import-cancel';
const kQaVehicleImportUndo = 'qa-vehicle-import-undo';
const kQaVehicleImportUndoConfirm = 'qa-vehicle-import-undo-confirm';
const kQaVehicleImportUndoCancel = 'qa-vehicle-import-undo-cancel';
const kQaVehicleImportCommitConfirm = 'qa-vehicle-import-commit-confirm';
const kQaVehicleImportCommitCancel = 'qa-vehicle-import-commit-cancel';

/// Positive-gap dialog: confirm the differential.
const kQaVehicleGapConfirmYes = 'qa-vehicle-gap-confirm-yes';

/// Positive-gap dialog: cancel and review entry.
const kQaVehicleGapConfirmNo = 'qa-vehicle-gap-confirm-no';

/// Implausible-gap dialog: proceed with the entered reading.
const kQaVehicleGapSuspiciousConfirm = 'qa-vehicle-gap-suspicious-confirm';

/// Implausible-gap dialog: cancel and review entry.
const kQaVehicleGapSuspiciousCancel = 'qa-vehicle-gap-suspicious-cancel';

/// Borrower lower-than-known meter recheck: confirm the entered reading.
const kQaVehicleBorrowerMeterRecheckConfirm =
    'qa-vehicle-borrower-meter-recheck-confirm';

/// Borrower lower-than-known meter recheck: go back and correct entry.
const kQaVehicleBorrowerMeterRecheckCorrect =
    'qa-vehicle-borrower-meter-recheck-correct';

/// Session-end tank dialog: review the odometer / tank entry.
const kQaVehicleSessionEndTankReview = 'qa-vehicle-session-end-tank-review';

/// Session-end tank dialog: confirm the declared tank level.
const kQaVehicleSessionEndTankConfirm = 'qa-vehicle-session-end-tank-confirm';

/// Maestro id for a vehicle card on the hub (derived from [displayLabel]).
String qaVehicleCardSemanticsId(String displayLabel) {
  final slug = displayLabel
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'qa-vehicle-card-${slug.isEmpty ? 'unnamed' : slug}';
}

/// Maestro id for the latest meter line on a hub vehicle card.
String qaVehicleCardMeterSemanticsId(String displayLabel) =>
    '${qaVehicleCardSemanticsId(displayLabel)}-meter';

/// Maestro id for the fuel-tank estimate line on a hub vehicle card.
String qaVehicleCardFuelTankSemanticsId(String displayLabel) =>
    '${qaVehicleCardSemanticsId(displayLabel)}-fuel-tank';

/// Maestro-facing [Semantics.identifier] wrapper (debug builds only).
Widget qaVehicleSemantics({
  required String identifier,
  required Widget child,
  String? label,
}) {
  return Semantics(
    identifier: kDebugMode ? identifier : null,
    label: kDebugMode ? label : null,
    container: true,
    child: child,
  );
}
