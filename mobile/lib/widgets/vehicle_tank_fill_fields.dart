import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../debug/qa_vehicle_semantics.dart';
import '../vehicle/vehicle_tank_fill_levels.dart';
import 'vehicle_narrow_unit_field.dart';

/// Full-tank switch and approximate fill selector (fuel purchase, use session).
class VehicleTankFillFields extends StatelessWidget {
  const VehicleTankFillFields({
    super.key,
    required this.fullTank,
    required this.onFullTankChanged,
    required this.tankFillLevel,
    required this.onTankFillLevelChanged,
    this.showFullTankSwitch = true,
    this.sectionTitle,
    this.fullTankSemanticsId,
    this.tankLevelSemanticsId,
    this.levels,
  });

  final bool fullTank;
  final ValueChanged<bool> onFullTankChanged;
  final VehicleTankFillLevel tankFillLevel;
  final ValueChanged<VehicleTankFillLevel> onTankFillLevelChanged;
  final bool showFullTankSwitch;
  final String? sectionTitle;
  final String? fullTankSemanticsId;
  final String? tankLevelSemanticsId;

  /// When set, the approximate dropdown uses these levels instead of
  /// [VehicleTankFillLevel.dropdownChoices]. Full (100%) entries are omitted
  /// from the dropdown when [showFullTankSwitch] is true (switch covers that
  /// case). When the switch is hidden, full is included so session end can
  /// declare a full tank.
  final List<VehicleTankFillLevel>? levels;

  List<VehicleTankFillLevel> _dropdownLevels() {
    if (levels != null) {
      if (showFullTankSwitch) {
        return levels!.where((l) => l.percent < 100).toList();
      }
      return levels!;
    }
    return VehicleTankFillLevel.dropdownChoices(
      includeFull: !showFullTankSwitch,
    );
  }

  String _levelLabel(AppLocalizations l10n, VehicleTankFillLevel level) {
    if (level.percent >= 100) return l10n.vehicleFuelFullTank;
    return level.label();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dropdownLevels = _dropdownLevels();
    final showLevelSelector =
        (!showFullTankSwitch || !fullTank) && dropdownLevels.isNotEmpty;
    final dropdownValue = dropdownLevels.contains(tankFillLevel)
        ? tankFillLevel
        : (dropdownLevels.isNotEmpty ? dropdownLevels.first : tankFillLevel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFullTankSwitch)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: VehicleNarrowUnitField.fieldMaxWidth,
              ),
              child: Row(
                children: [
                  fullTankSemanticsId == null
                      ? Switch(
                          value: fullTank,
                          onChanged: onFullTankChanged,
                        )
                      : qaVehicleSemantics(
                          identifier: fullTankSemanticsId!,
                          child: Switch(
                            value: fullTank,
                            onChanged: onFullTankChanged,
                          ),
                        ),
                  Expanded(child: Text(l10n.vehicleFuelFullTank)),
                ],
              ),
            ),
          ),
        if (showLevelSelector) ...[
          if (showFullTankSwitch) const SizedBox(height: 12),
          if (sectionTitle != null) ...[
            Text(
              sectionTitle!,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
          ],
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: VehicleNarrowUnitField.fieldMaxWidth,
              ),
              child: tankLevelSemanticsId == null
                  ? DropdownButtonFormField<VehicleTankFillLevel>(
                      key: ValueKey(dropdownValue.percent),
                      isExpanded: true,
                      initialValue: dropdownValue,
                      decoration: InputDecoration(
                        labelText: l10n.vehicleFuelApproximateLevel,
                      ),
                      items: [
                        for (final level in dropdownLevels)
                          DropdownMenuItem(
                            value: level,
                            child: Text(_levelLabel(l10n, level)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) onTankFillLevelChanged(value);
                      },
                    )
                  : qaVehicleSemantics(
                      identifier: tankLevelSemanticsId!,
                      child: DropdownButtonFormField<VehicleTankFillLevel>(
                        key: ValueKey(dropdownValue.percent),
                        isExpanded: true,
                        initialValue: dropdownValue,
                        decoration: InputDecoration(
                          labelText: l10n.vehicleFuelApproximateLevel,
                        ),
                        items: [
                          for (final level in dropdownLevels)
                            DropdownMenuItem(
                              value: level,
                              child: Text(_levelLabel(l10n, level)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) onTankFillLevelChanged(value);
                        },
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
