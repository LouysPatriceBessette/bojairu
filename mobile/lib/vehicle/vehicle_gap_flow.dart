import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../debug/qa_vehicle_semantics.dart';
import '../db/app_database.dart';
import '../db/repositories/vehicles_repository.dart';
import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import '../util/vehicle_meter_display.dart';
import '../vehicle/vehicle_consumption_metrics.dart';
import '../vehicle/vehicle_gap_correction.dart';
import '../vehicle/vehicle_odometer_gap_plausibility.dart';
import '../widgets/app_dialog.dart';

/// Result of gap prompts before persisting a new meter value.
class MeterGapConfirmResult {
  const MeterGapConfirmResult.cancel() : proceed = false, divergenceTenths = null;

  const MeterGapConfirmResult.ok({this.divergenceTenths}) : proceed = true;

  final bool proceed;
  /// Signed odometer delta (positive or negative) when readings diverge.
  final int? divergenceTenths;
}

/// Confirms a positive odometer gap before saving the reading.
Future<bool> showPositiveGapConfirmDialog(
  BuildContext context, {
  required String gapDisplay,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showAppDialog<bool>(
    context: context,
    guardKey: 'vehiclePositiveGap',
    builder: (ctx) {
      return AlertDialog(
        content: Text(l10n.vehiclePositiveGapConfirmPrompt(gapDisplay)),
        actions: [
          Semantics(
            identifier: kDebugMode ? kQaVehicleGapConfirmNo : null,
            container: true,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.vehiclePositiveGapConfirmNo),
            ),
          ),
          Semantics(
            identifier: kDebugMode ? kQaVehicleGapConfirmYes : null,
            container: true,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.vehiclePositiveGapConfirmYes),
            ),
          ),
        ],
      );
    },
  );
  return choice ?? false;
}

/// Confirms a positive odometer gap that exceeds one-tank plausibility.
Future<bool> showSuspiciousPositiveGapDialog(
  BuildContext context, {
  required String gapDisplay,
  required String maxGapDisplay,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showAppDialog<bool>(
    context: context,
    guardKey: 'vehicleSuspiciousGap',
    builder: (ctx) {
      return AlertDialog(
        title: Text(l10n.vehicleSuspiciousGapTitle),
        content: Text(
          l10n.vehicleSuspiciousGapBody(gapDisplay, maxGapDisplay),
        ),
        actions: [
          Semantics(
            identifier: kDebugMode ? kQaVehicleGapSuspiciousCancel : null,
            container: true,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.vehicleSuspiciousGapCancel),
            ),
          ),
          Semantics(
            identifier: kDebugMode ? kQaVehicleGapSuspiciousConfirm : null,
            container: true,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.vehicleSuspiciousGapConfirm),
            ),
          ),
        ],
      );
    },
  );
  return choice ?? false;
}

/// Session-end distance guard vs fuel available since the last full tank.
///
/// Distance is `end − lastFullTankMeter` when a full-tank purchase with a meter
/// exists; otherwise `end − sessionStart`. The ceiling uses tank capacity plus
/// volumes of fuel purchases recorded **after** that last full tank (partial
/// top-ups count). Gap attribution vs the prior known meter still happens at
/// session **start**.
Future<bool> confirmSuspiciousSessionEndDistanceBeforeSave({
  required BuildContext context,
  required VehiclesRepository repo,
  required Vehicle vehicle,
  required int sessionStartMeterTenths,
  required int parsedEndMeterTenths,
  required double fuelLitersDuringSession,
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
  /// When false, Emprunteur is still awaiting fuel catch-up — skip this guard.
  bool fuelCatchUpResponseReceived = true,
}) async {
  if (usesHorometer) {
    return true;
  }
  if (!fuelCatchUpResponseReceived) {
    return true;
  }
  final tankCapacity = vehicle.fuelTankCapacityLiters;
  if (tankCapacity == null || tankCapacity <= 0) {
    return true;
  }

  final lastFull = await repo.latestFullTankFuelPurchase(vehicle.id);
  final lastFullMeter = lastFull?.meterReadingValue;
  late final int distanceTenths;
  late final double additionalFuelLiters;
  if (lastFull != null && lastFullMeter != null) {
    distanceTenths = parsedEndMeterTenths - lastFullMeter;
    additionalFuelLiters = await repo.fuelVolumeLitersPurchasedAfter(
      vehicle.id,
      afterPurchasedAt: lastFull.purchasedAt,
    );
  } else {
    distanceTenths = parsedEndMeterTenths - sessionStartMeterTenths;
    additionalFuelLiters = fuelLitersDuringSession;
  }
  if (distanceTenths <= 0) {
    return true;
  }

  final snapshot = await VehicleConsumptionMetrics(AppDatabase.processScope)
      .forVehicle(vehicle.id);
  final guardL100 = guardConsumptionLitersPer100Km(snapshot);
  final maxDistanceTenths = maxPlausibleDistanceTenthsFromFuel(
    tankCapacityLiters: tankCapacity,
    additionalFuelLitersAfterLastFullTank: additionalFuelLiters,
    guardLitersPer100Km: guardL100,
  );
  if (!isSuspiciousPositiveGap(
    gapTenths: distanceTenths,
    maxGapTenths: maxDistanceTenths,
  )) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  return showSuspiciousPositiveGapDialog(
    context,
    gapDisplay: formatStoredMeterDeltaForDisplay(
      context,
      distanceTenths,
      usesHorometer: usesHorometer,
      distanceUnit: distanceUnit,
    ),
    maxGapDisplay: formatStoredMeterDeltaForDisplay(
      context,
      maxDistanceTenths!,
      usesHorometer: usesHorometer,
      distanceUnit: distanceUnit,
    ),
  );
}

enum NegativeGapChoice { maintain, cancel }

/// Propriétaire negative-gap dialog per `vehicle-odometer-gap-attribution`.
Future<NegativeGapChoice?> showNegativeGapDialog(
  BuildContext context, {
  required String gapDisplay,
}) async {
  final l10n = AppLocalizations.of(context);
  return showAppDialog<NegativeGapChoice>(
    context: context,
    guardKey: 'vehicleNegativeGap',
    builder: (ctx) {
      return AlertDialog(
        title: Text(l10n.vehicleNegativeGapTitle),
        content: Text(
          l10n.vehicleNegativeGapBody(gapDisplay),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, NegativeGapChoice.cancel),
            child: Text(l10n.vehicleNegativeGapCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, NegativeGapChoice.maintain),
            child: Text(l10n.vehicleNegativeGapMaintain),
          ),
        ],
      );
    },
  );
}

/// Emprunteur typo recheck when the new reading is below the last known meter.
Future<bool> showBorrowerMeterRecheckDialog(
  BuildContext context, {
  required String gapDisplay,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showAppDialog<bool>(
    context: context,
    guardKey: 'vehicleBorrowerMeterRecheck',
    builder: (ctx) {
      return AlertDialog(
        title: Text(l10n.vehicleBorrowerMeterRecheckTitle),
        content: Text(l10n.vehicleBorrowerMeterRecheckBody(gapDisplay)),
        actions: [
          Semantics(
            identifier: kDebugMode ? kQaVehicleBorrowerMeterRecheckCorrect : null,
            container: true,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.vehicleBorrowerMeterRecheckCorrect),
            ),
          ),
          Semantics(
            identifier: kDebugMode ? kQaVehicleBorrowerMeterRecheckConfirm : null,
            container: true,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.vehicleBorrowerMeterRecheckConfirm),
            ),
          ),
        ],
      );
    },
  );
  return choice ?? false;
}

/// Result of the one-tank plausibility prompt.
enum OneTankSuspiciousGapCheck {
  /// Gap is within the one-tank guard (or not applicable); no dialog shown.
  notApplicable,

  /// User cancelled the suspicious-gap dialog.
  cancelled,

  /// User confirmed an implausibly large gap.
  confirmed,
}

/// One-tank plausibility prompt when [gapTenths] exceeds the max plausible gap.
Future<OneTankSuspiciousGapCheck> confirmOneTankSuspiciousPositiveGap({
  required BuildContext context,
  required Vehicle vehicle,
  required int gapTenths,
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) async {
  if (usesHorometer || gapTenths <= 0) {
    return OneTankSuspiciousGapCheck.notApplicable;
  }
  final tankCapacity = vehicle.fuelTankCapacityLiters;
  if (tankCapacity == null || tankCapacity <= 0) {
    return OneTankSuspiciousGapCheck.notApplicable;
  }
  final snapshot = await VehicleConsumptionMetrics(AppDatabase.processScope)
      .forVehicle(vehicle.id);
  final maxGapTenths = maxPlausiblePositiveGapTenths(
    tankCapacityLiters: tankCapacity,
    guardLitersPer100Km: guardConsumptionLitersPer100Km(snapshot),
  );
  if (!isSuspiciousPositiveGap(
    gapTenths: gapTenths,
    maxGapTenths: maxGapTenths,
  )) {
    return OneTankSuspiciousGapCheck.notApplicable;
  }
  if (!context.mounted) {
    return OneTankSuspiciousGapCheck.cancelled;
  }
  final confirmed = await showSuspiciousPositiveGapDialog(
    context,
    gapDisplay: formatStoredMeterDeltaForDisplay(
      context,
      gapTenths,
      usesHorometer: usesHorometer,
      distanceUnit: distanceUnit,
    ),
    maxGapDisplay: formatStoredMeterDeltaForDisplay(
      context,
      maxGapTenths!,
      usesHorometer: usesHorometer,
      distanceUnit: distanceUnit,
    ),
  );
  return confirmed
      ? OneTankSuspiciousGapCheck.confirmed
      : OneTankSuspiciousGapCheck.cancelled;
}

/// Negative- and positive-gap prompts before persisting a new meter value.
///
/// When [attributePositiveGap] is false (e.g. fuel purchase during an open use
/// session), Propriétaire positive-gap confirmation is skipped.
/// Emprunteur never sees the any-positive "are you sure?" dialog — only the
/// lower-than-known recheck and (when enabled) one-tank suspicious prompt.
///
/// When [confirmOneTankSuspiciousGap] is false (e.g. session end, which uses
/// [confirmSuspiciousSessionEndDistanceBeforeSave]), the one-tank vs-latest
/// plausibility prompt is skipped to avoid a duplicate dialog.
Future<MeterGapConfirmResult> confirmMeterGapsBeforeSave({
  required BuildContext context,
  required AppLocalizations l10n,
  required VehiclesRepository repo,
  required Vehicle vehicle,
  required int parsedMeter,
  required String actingContactId,
  required bool isOwnerContext,
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
  required bool attributePositiveGap,
  bool confirmOneTankSuspiciousGap = true,
}) async {
  final latest = await repo.latestMeterValue(vehicle.id);

  if (latest != null && parsedMeter < latest) {
    if (!context.mounted) return const MeterGapConfirmResult.cancel();
    final gapDisplay = formatStoredMeterDeltaForDisplay(
      context,
      parsedMeter - latest,
      usesHorometer: usesHorometer,
      distanceUnit: distanceUnit,
    );
    if (isOwnerContext) {
      final choice = await showNegativeGapDialog(
        context,
        gapDisplay: gapDisplay,
      );
      if (!context.mounted) return const MeterGapConfirmResult.cancel();
      if (choice != NegativeGapChoice.maintain) {
        return const MeterGapConfirmResult.cancel();
      }
      return MeterGapConfirmResult.ok(divergenceTenths: parsedMeter - latest);
    }
    final confirmed = await showBorrowerMeterRecheckDialog(
      context,
      gapDisplay: gapDisplay,
    );
    if (!context.mounted || !confirmed) {
      return const MeterGapConfirmResult.cancel();
    }
    return MeterGapConfirmResult.ok(divergenceTenths: parsedMeter - latest);
  }

  int? divergenceTenths;
  // Positive-gap "are you sure?" is for Propriétaire attribution flows only.
  // Emprunteur typo guards are negative recheck + one-tank suspicious below.
  if (attributePositiveGap &&
      isOwnerContext &&
      latest != null &&
      parsedMeter > latest) {
    if (!context.mounted) return const MeterGapConfirmResult.cancel();
    final confirmed = await showPositiveGapConfirmDialog(
      context,
      gapDisplay: formatStoredMeterDeltaForDisplay(
        context,
        parsedMeter - latest,
        usesHorometer: usesHorometer,
        distanceUnit: distanceUnit,
      ),
    );
    if (!context.mounted || !confirmed) {
      return const MeterGapConfirmResult.cancel();
    }
    divergenceTenths = parsedMeter - latest;
  }

  if (confirmOneTankSuspiciousGap &&
      latest != null &&
      parsedMeter > latest) {
    if (!context.mounted) return const MeterGapConfirmResult.cancel();
    final gapTenths = parsedMeter - latest;
    final check = await confirmOneTankSuspiciousPositiveGap(
      context: context,
      vehicle: vehicle,
      gapTenths: gapTenths,
      usesHorometer: usesHorometer,
      distanceUnit: distanceUnit,
    );
    if (check == OneTankSuspiciousGapCheck.cancelled) {
      return const MeterGapConfirmResult.cancel();
    }
    if (check == OneTankSuspiciousGapCheck.confirmed) {
      divergenceTenths ??= gapTenths;
    }
  }

  if (divergenceTenths != null) {
    return MeterGapConfirmResult.ok(divergenceTenths: divergenceTenths);
  }
  return const MeterGapConfirmResult.ok();
}

/// Persists verification journal entry and gap record after user confirmation.
Future<({
  VehicleMeterReading correctionReading,
  VehicleOdometerGap gap,
})> persistConfirmedMeterDivergence({
  required VehiclesRepository repo,
  required Vehicle vehicle,
  required VehicleMeterReading previousReading,
  required int parsedMeter,
  required int divergenceTenths,
  required String photoPath,
  required String actingContactId,
  required GapCorrectionContext correctionContext,
  String? vehicleUseId,
  DateTime? correctionRecordedAt,
}) async {
  final correctionReading = await repo.saveGapCorrectionReading(
    vehicle: vehicle,
    meterValue: parsedMeter,
    gapTenths: divergenceTenths,
    photoPath: photoPath,
    recordedByContactId: actingContactId,
    correctionContext: correctionContext,
    vehicleUseId: vehicleUseId,
    recordedAt: correctionRecordedAt,
  );
  final gap = await repo.recordPositiveGap(
    vehicleId: vehicle.id,
    latestBefore: previousReading.value,
    startAfter: parsedMeter,
    attributedContactId: kVehicleGapAttributionUnknown,
    recordedByContactId: actingContactId,
    vehicleUseId: vehicleUseId,
    correctionReadingId: correctionReading.id,
    previousReadingId: previousReading.id,
  );
  return (correctionReading: correctionReading, gap: gap);
}

Future<void> linkGapTriggerReading({
  required VehiclesRepository repo,
  required String gapId,
  required String correctionReadingId,
  required String previousReadingId,
  required String triggerReadingId,
}) =>
    repo.linkOdometerGapReadings(
      gapId: gapId,
      correctionReadingId: correctionReadingId,
      previousReadingId: previousReadingId,
      triggerReadingId: triggerReadingId,
    );

/// @deprecated Use [persistConfirmedMeterDivergence].
Future<void> persistConfirmedPositiveGap({
  required VehiclesRepository repo,
  required Vehicle vehicle,
  required int latestBefore,
  required int parsedMeter,
  required int gapTenths,
  required String photoPath,
  required String actingContactId,
  required GapCorrectionContext correctionContext,
  String? vehicleUseId,
  DateTime? correctionRecordedAt,
}) async {
  await repo.saveGapCorrectionReading(
    vehicle: vehicle,
    meterValue: parsedMeter,
    gapTenths: gapTenths,
    photoPath: photoPath,
    recordedByContactId: actingContactId,
    correctionContext: correctionContext,
    vehicleUseId: vehicleUseId,
    recordedAt: correctionRecordedAt,
  );
  await repo.recordPositiveGap(
    vehicleId: vehicle.id,
    latestBefore: latestBefore,
    startAfter: parsedMeter,
    attributedContactId: kVehicleGapAttributionUnknown,
    recordedByContactId: actingContactId,
    vehicleUseId: vehicleUseId,
  );
}
