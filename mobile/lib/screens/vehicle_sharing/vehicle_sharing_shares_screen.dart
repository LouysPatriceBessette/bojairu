import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../debug/qa_vehicle_sharing_semantics.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../sandbox/sandbox_mode.dart';
import '../../util/display_date.dart';
import '../../vehicle/vehicle_module_access.dart';
import '../../widgets/screen_body_padding.dart';
import '../contacts/contact_picker_sheet.dart';

/// Active and pending sharing links for one owned vehicle (Propriétaire view).
class VehicleSharingSharesScreen extends StatefulWidget {
  const VehicleSharingSharesScreen({
    super.key,
    required this.vehicleId,
    required this.prefs,
  });

  final String vehicleId;
  final AppPreferences prefs;

  @override
  State<VehicleSharingSharesScreen> createState() =>
      _VehicleSharingSharesScreenState();
}

class _VehicleSharingSharesScreenState
    extends State<VehicleSharingSharesScreen> {
  final _access = const VehicleModuleAccess();
  Vehicle? _vehicle;
  List<VehicleSharingLink> _activeLinks = const [];
  List<VehicleSharingLink> _pendingLinks = const [];
  Map<String, String> _contactLabels = const {};
  bool _loading = true;
  HandshakeOrchestrator? _steadyOrch;
  int _reloadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _steadyOrch = HandshakeOrchestrator.maybeInstance;
    _steadyOrch?.steadyStateInboxTick.addListener(_onSteadyInboxTick);
    _reload();
  }

  @override
  void dispose() {
    _steadyOrch?.steadyStateInboxTick.removeListener(_onSteadyInboxTick);
    super.dispose();
  }

  void _onSteadyInboxTick() {
    if (!mounted) return;
    _reload();
  }

  Future<void> _reload() async {
    final gen = ++_reloadGeneration;
    final repo = VehiclesRepository(AppDatabase.processScope);
    final vehicle = await repo.getVehicle(widget.vehicleId);
    final links = await repo.listSharingLinksForVehicle(widget.vehicleId);
    final active = links
        .where((l) => l.status == VehicleSharingLinkStatus.active.wire)
        .toList();
    final pending = links
        .where((l) => l.status == VehicleSharingLinkStatus.pending.wire)
        .toList();
    final contacts = await ContactsRepository(AppDatabase.processScope).list();
    final labels = {for (final c in contacts) c.id: c.displayName};

    if (!mounted || gen != _reloadGeneration) return;
    setState(() {
      _vehicle = vehicle;
      _activeLinks = active;
      _pendingLinks = pending;
      _contactLabels = labels;
      _loading = false;
    });
  }

  Future<void> _onAddShare() async {
    final l10n = AppLocalizations.of(context);
    if (!_access.canOfferSharing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleSharingOfferBlocked)),
      );
      return;
    }
    final excluded = await VehiclesRepository(AppDatabase.processScope)
        .borrowerContactIdsBlockingNewOffer(widget.vehicleId);
    if (!mounted) return;
    final selected = await showContactPickerSheet(
      context: context,
      db: AppDatabase.processScope,
      excludeContactIds: excluded,
      allowInvite: !SandboxMode.isActive(widget.prefs),
    );
    if (selected == null || !mounted) return;
    final encoded = Uri.encodeComponent(selected.id);
    await context.push(
      '/vehicle-sharing/${widget.vehicleId}/invite-form?contactId=$encoded',
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _vehicle?.displayLabel ?? l10n.vehicleSharingSharesDetailTitle;
    final dateFmt = widget.prefs.dateFormat;
    final hasAny = _activeLinks.isNotEmpty || _pendingLinks.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: screenBodyScrollPadding(context),
              children: [
                Text(
                  l10n.vehicleSharingSharesDetailTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (!hasAny)
                  Text(l10n.vehicleSharingEmptyNone)
                else ...[
                  ..._pendingLinks.map((link) {
                    final name = _contactLabels[link.borrowerContactId] ??
                        link.borrowerContactId;
                    final when = formatPreferenceDateTime(
                      link.createdAt.toUtc(),
                      dateFmt,
                    );
                    return qaVehicleSharingSemantics(
                      identifier: kQaVehicleSharingOutboundPendingInvite,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.vehicleSharingInvitationSentToAt(name, when),
                        ),
                      ),
                    );
                  }),
                  ..._activeLinks.map(
                    (link) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _contactLabels[link.borrowerContactId] ??
                            link.borrowerContactId,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                qaVehicleSharingSemantics(
                  identifier: kQaVehicleSharingAddShare,
                  button: true,
                  onTap: _onAddShare,
                  child: FilledButton(
                    onPressed: _onAddShare,
                    child: Text(l10n.vehicleSharingAddShare),
                  ),
                ),
              ],
            ),
    );
  }
}
