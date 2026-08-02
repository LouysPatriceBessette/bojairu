import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../debug/qa_vehicle_semantics.dart';
import '../db/repositories/vehicles_repository.dart';
import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import '../util/vehicle_meter_display.dart';
import '../widgets/app_dialog.dart';
import 'vehicle_tank_fill_levels.dart';

/// Minimum road distance since the last fuel purchase that triggers a
/// confirmation when the session-end tank level is at the highest choice.
const int kSessionEndHighTankConfirmMinKm = 350;

bool sessionEndTankLevelNeedsConfirmation({
  required int declaredTankPercent,
  required int? distanceTenthsSinceLastFuelPurchase,
  required bool usesHorometer,
}) {
  if (usesHorometer) return false;
  // Highest approximate choice (7/8) or full tank after a long drive.
  if (declaredTankPercent < VehicleTankFillLevel.highestPercent) {
    return false;
  }
  final tenths = distanceTenthsSinceLastFuelPurchase;
  if (tenths == null) return false;
  return tenths >= kSessionEndHighTankConfirmMinKm * 10;
}

/// Prompts when a high tank level is declared after a long drive since the
/// last fuel purchase. Returns `false` if the user cancels.
Future<bool> confirmSessionEndTankLevelIfNeeded({
  required BuildContext context,
  required AppLocalizations l10n,
  required VehiclesRepository repo,
  required String vehicleId,
  required int parsedMeterTenths,
  required int declaredTankPercent,
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) async {
  final distanceTenths = await repo.distanceTenthsSinceLastFuelPurchase(
    vehicleId,
    currentMeterTenths: parsedMeterTenths,
  );
  if (!sessionEndTankLevelNeedsConfirmation(
    declaredTankPercent: declaredTankPercent,
    distanceTenthsSinceLastFuelPurchase: distanceTenths,
    usesHorometer: usesHorometer,
  )) {
    return true;
  }
  if (!context.mounted) return false;

  final distanceDisplay = formatStoredMeterDeltaForDisplay(
    context,
    distanceTenths!,
    usesHorometer: false,
    distanceUnit: distanceUnit,
  );

  final confirmed = await showAppDialog<bool>(
    context: context,
    guardKey: 'vehicleSessionEndTankConfirm',
    builder: (ctx) {
      return AlertDialog(
        title: Text(l10n.vehicleSessionEndTankConfirmTitle),
        content: Text(
          l10n.vehicleSessionEndTankConfirmBody(
            distanceDisplay,
            declaredTankPercent,
          ),
        ),
        actions: [
          Semantics(
            identifier: kDebugMode ? kQaVehicleSessionEndTankReview : null,
            container: true,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.vehicleSessionEndTankConfirmReview),
            ),
          ),
          Semantics(
            identifier: kDebugMode ? kQaVehicleSessionEndTankConfirm : null,
            container: true,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.vehicleSessionEndTankConfirmProceed),
            ),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
