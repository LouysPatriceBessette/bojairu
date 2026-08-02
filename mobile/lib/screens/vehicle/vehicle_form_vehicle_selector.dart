import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../vehicle/vehicle_usage_context.dart';

/// Vehicle picker for quick-action forms.
///
/// When [fixedDisplayLabel] is set (or only one vehicle is available), shows the
/// vehicle name like the session-end form — not an empty "tap +" hint.
class VehicleFormVehicleSelector extends StatelessWidget {
  const VehicleFormVehicleSelector({
    super.key,
    required this.vehicles,
    required this.selectedId,
    required this.onSelected,
    this.fixedDisplayLabel,
  });

  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  /// When non-null/non-empty, show a read-only vehicle name (no dropdown).
  final String? fixedDisplayLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locked = (fixedDisplayLabel ?? '').trim();
    if (locked.isNotEmpty) {
      return InputDecorator(
        decoration: InputDecoration(labelText: l10n.vehicleFormVehicleLabel),
        child: Text(
          locked,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    if (vehicles.length == 1) {
      final only = vehicles.first;
      return InputDecorator(
        decoration: InputDecoration(labelText: l10n.vehicleFormVehicleLabel),
        child: Text(
          only.displayLabel,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    if (vehicles.isEmpty) {
      // Owner-only empty copy (hub has "+"). Borrower forms must pass
      // [fixedDisplayLabel] or load accessible vehicles instead.
      return Text(l10n.vehicleMyVehiclesEmpty);
    }
    return DropdownButtonFormField<String>(
      key: ValueKey(selectedId),
      isExpanded: true,
      initialValue: selectedId,
      decoration: InputDecoration(labelText: l10n.vehicleFormVehicleLabel),
      items: [
        for (final v in vehicles)
          DropdownMenuItem(value: v.id, child: Text(v.displayLabel)),
      ],
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }
}

Future<List<Vehicle>> loadOwnedVehiclesForForms() =>
    VehiclesRepository(AppDatabase.processScope).listActiveOwnedVehicles();

/// Vehicles selectable in a usage form for the given role.
Future<List<Vehicle>> loadVehiclesForUsageForms(
  VehicleUsageContext context,
) {
  final repo = VehiclesRepository(AppDatabase.processScope);
  if (context.isBorrower) {
    return repo.listAccessibleVehiclesAsBorrower(context.actingContactId);
  }
  return repo.listActiveOwnedVehicles();
}
