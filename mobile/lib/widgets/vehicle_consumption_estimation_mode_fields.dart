import 'package:flutter/material.dart';

import '../debug/qa_vehicle_semantics.dart';
import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import '../util/display_units.dart';
import '../vehicle/vehicle_consumption_estimation_mode.dart';

/// Consumption estimation mode radios (simple vs detailed).
class VehicleConsumptionEstimationModeFields extends StatelessWidget {
  const VehicleConsumptionEstimationModeFields({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.prefs,
    this.simpleModeSemanticsId,
  });

  final VehicleConsumptionEstimationMode mode;
  final ValueChanged<VehicleConsumptionEstimationMode> onModeChanged;
  final AppPreferences prefs;
  final String? simpleModeSemanticsId;

  String _distanceUnitWord(AppLocalizations l10n) {
    return switch (resolveDistanceUnit(prefs)) {
      DistanceUnit.km => l10n.vehicleDistanceUnitKilometres,
      DistanceUnit.miles => l10n.vehicleDistanceUnitMiles,
    };
  }

  (String word, String wordCap) _volumeUnitWords(AppLocalizations l10n) {
    return switch (resolveLiquidVolumeUnit(prefs)) {
      LiquidVolumeUnit.liter => (
          l10n.vehicleLiquidVolumeUnitLitres,
          l10n.vehicleLiquidVolumeUnitLitresCap,
        ),
      LiquidVolumeUnit.usGallon => (
          l10n.vehicleLiquidVolumeUnitUsGallons,
          l10n.vehicleLiquidVolumeUnitUsGallonsCap,
        ),
      LiquidVolumeUnit.imperialGallon => (
          l10n.vehicleLiquidVolumeUnitImperialGallons,
          l10n.vehicleLiquidVolumeUnitImperialGallonsCap,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distanceUnit = _distanceUnitWord(l10n);
    final volumeWords = _volumeUnitWords(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.vehicleConsumptionEstimationModeTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        RadioGroup<VehicleConsumptionEstimationMode>(
          groupValue: mode,
          onChanged: (value) {
            if (value != null) onModeChanged(value);
          },
          child: Column(
            children: [
              _consumptionModeTile(
                semanticsId: simpleModeSemanticsId,
                child: RadioListTile<VehicleConsumptionEstimationMode>(
                  value: VehicleConsumptionEstimationMode.simple,
                  title: Text(l10n.vehicleConsumptionEstimationModeSimpleTitle),
                  subtitle: Text(
                    l10n.vehicleConsumptionEstimationModeSimpleDescription(
                      volumeWords.$1,
                      distanceUnit,
                    ),
                  ),
                  isThreeLine: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              RadioListTile<VehicleConsumptionEstimationMode>(
                value: VehicleConsumptionEstimationMode.detailed,
                title: Text(l10n.vehicleConsumptionEstimationModeDetailedTitle),
                subtitle: Text(
                  l10n.vehicleConsumptionEstimationModeDetailedDescription(
                    volumeWords.$2,
                    distanceUnit,
                  ),
                ),
                isThreeLine: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _consumptionModeTile({
    required String? semanticsId,
    required Widget child,
  }) {
    if (semanticsId == null) return child;
    return qaVehicleSemantics(identifier: semanticsId, child: child);
  }
}
