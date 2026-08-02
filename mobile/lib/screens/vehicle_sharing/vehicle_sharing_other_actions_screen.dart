import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../debug/qa_vehicle_sharing_semantics.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../widgets/screen_body_padding.dart';

/// Secondary borrower actions for an accessible shared vehicle.
class VehicleSharingOtherActionsScreen extends StatelessWidget {
  const VehicleSharingOtherActionsScreen({
    super.key,
    required this.vehicleId,
    required this.borrowerContactId,
    required this.prefs,
  });

  final String vehicleId;
  final String borrowerContactId;
  final AppPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final borrower = Uri.encodeComponent(borrowerContactId);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vehicleSharingOtherActionsTitle),
      ),
      body: qaVehicleSharingSemantics(
        identifier: kQaVehicleSharingOtherActionsScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FutureBuilder<String>(
                future: _vehicleLabel(),
                builder: (context, snap) {
                  final label = (snap.data ?? '').trim().isNotEmpty
                      ? snap.data!.trim()
                      : vehicleId;
                  return DropdownButtonFormField<String>(
                    key: ValueKey(label),
                    isExpanded: true,
                    initialValue: vehicleId,
                    decoration: InputDecoration(
                      labelText: l10n.vehicleFormVehicleLabel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: vehicleId,
                        child: Text(label),
                      ),
                    ],
                    onChanged: (_) {},
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: screenBodyScrollPadding(
                  context,
                  content: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: qaVehicleSharingSemantics(
                      identifier: kQaVehicleSharingOtherActionsFuel,
                      button: true,
                      onTap: () => context.push(
                        '/vehicle-sharing/$vehicleId/fuel?borrower=$borrower',
                      ),
                      child: Text(l10n.vehicleQuickActionFuel),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/vehicle-sharing/$vehicleId/fuel?borrower=$borrower',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: qaVehicleSharingSemantics(
                      identifier: kQaVehicleSharingOtherActionsJournals,
                      button: true,
                      onTap: () => context.push(
                        '/vehicle-sharing/$vehicleId/journals',
                      ),
                      child: Text(l10n.vehicleJournalsTitle),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/vehicle-sharing/$vehicleId/journals',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _vehicleLabel() async {
    final vehicle =
        await VehiclesRepository(AppDatabase.processScope).getVehicle(vehicleId);
    return vehicle?.displayLabel ?? '';
  }
}
