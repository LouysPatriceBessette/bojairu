import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../debug/qa_vehicle_sharing_semantics.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../vehicle/vehicle_owner_contact.dart';
import '../../widgets/screen_body_padding.dart';

/// Secondary borrower actions for an accessible shared vehicle.
class VehicleSharingOtherActionsScreen extends StatefulWidget {
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
  State<VehicleSharingOtherActionsScreen> createState() =>
      _VehicleSharingOtherActionsScreenState();
}

class _VehicleSharingOtherActionsScreenState
    extends State<VehicleSharingOtherActionsScreen> {
  bool _revoked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final links = await repo.listSharingLinksForVehicle(widget.vehicleId);
    VehicleSharingLink? match;
    for (final link in links) {
      if (link.borrowerContactId == widget.borrowerContactId ||
          link.borrowerContactId == kVehicleBorrowerSelfContactId) {
        match = link;
        if (link.status == VehicleSharingLinkStatus.active.wire ||
            link.status == VehicleSharingLinkStatus.revoked.wire) {
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _revoked =
          match?.status == VehicleSharingLinkStatus.revoked.wire;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final borrower = Uri.encodeComponent(widget.borrowerContactId);
    final vehicleId = widget.vehicleId;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vehicleSharingOtherActionsTitle),
      ),
      body: qaVehicleSharingSemantics(
        identifier: kQaVehicleSharingOtherActionsScreen,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
                        _actionTile(
                          context,
                          enabled: !_revoked,
                          semanticsId: kQaVehicleSharingOtherActionsFuel,
                          title: l10n.vehicleQuickActionFuel,
                          onTap: () => context.push(
                            '/vehicle-sharing/$vehicleId/fuel?borrower=$borrower',
                          ),
                        ),
                        _actionTile(
                          context,
                          enabled: !_revoked,
                          semanticsId: kQaVehicleSharingOtherActionsMaintenance,
                          title: l10n.vehicleQuickActionMaintenance,
                          onTap: () => context.push(
                            '/vehicle-sharing/$vehicleId/maintenance?borrower=$borrower',
                          ),
                        ),
                        _actionTile(
                          context,
                          enabled: !_revoked,
                          semanticsId: kQaVehicleSharingOtherActionsViolation,
                          title: l10n.vehicleQuickActionViolation,
                          onTap: () => context.push(
                            '/vehicle-sharing/$vehicleId/violation?borrower=$borrower',
                          ),
                        ),
                        const Divider(),
                        _actionTile(
                          context,
                          enabled: true,
                          semanticsId:
                              kQaVehicleSharingOtherActionsUsageBalance,
                          title: l10n.vehicleUsageBalanceTileBorrower,
                          onTap: () => context.push(
                            '/vehicle-sharing/$vehicleId/usage-balance?borrower=$borrower',
                          ),
                        ),
                        const Divider(),
                        _actionTile(
                          context,
                          enabled: true,
                          semanticsId: kQaVehicleSharingOtherActionsJournals,
                          title: l10n.vehicleJournalsTitle,
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

  Widget _actionTile(
    BuildContext context, {
    required bool enabled,
    required String semanticsId,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      title: qaVehicleSharingSemantics(
        identifier: semanticsId,
        button: enabled,
        onTap: enabled ? onTap : null,
        child: Text(title),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled ? onTap : null,
    );
  }

  Future<String> _vehicleLabel() async {
    final vehicle = await VehiclesRepository(AppDatabase.processScope)
        .getVehicle(widget.vehicleId);
    return vehicle?.displayLabel ?? '';
  }
}
