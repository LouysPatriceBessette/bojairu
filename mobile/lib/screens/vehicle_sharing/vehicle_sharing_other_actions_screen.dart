import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        title: qaVehicleSharingSemantics(
          identifier: kQaVehicleSharingOtherActionsScreen,
          child: Text(l10n.vehicleSharingOtherActionsTitle),
        ),
      ),
      body: ListView(
        padding: screenBodyScrollPadding(context),
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
        ],
      ),
    );
  }
}
