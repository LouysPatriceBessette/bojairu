import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../debug/qa_vehicle_sharing_semantics.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../relay/relay_client.dart';
import '../../vehicle/vehicle_module_access.dart';
import '../../vehicle/vehicle_module_exit.dart';
import '../../vehicle/vehicle_owner_contact.dart';
import '../../vehicle/vehicle_usage_context.dart';
import '../../widgets/screen_body_padding.dart';

class VehicleSharingHubScreen extends StatefulWidget {
  const VehicleSharingHubScreen({super.key, required this.prefs});

  final AppPreferences prefs;

  @override
  State<VehicleSharingHubScreen> createState() =>
      _VehicleSharingHubScreenState();
}

class _VehicleSharingHubScreenState extends State<VehicleSharingHubScreen> {
  final _access = const VehicleModuleAccess();
  List<Vehicle> _shareable = const [];
  Set<String> _vehicleIdsWithActiveShare = const {};
  List<({Vehicle vehicle, VehicleSharingLink link})> _accessible = const [];
  List<({VehicleSharingLink link, String vehicleLabel})> _pendingOffers =
      const [];
  Map<String, String> _contactLabels = const {};
  bool _loading = true;
  HandshakeOrchestrator? _steadyOrch;

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
    final repo = VehiclesRepository(AppDatabase.processScope);
    final contacts = await ContactsRepository(AppDatabase.processScope).list();
    final labels = {for (final c in contacts) c.id: c.displayName};

    final shareable = await repo.listActiveOwnedVehicles();
    final ownerActiveLinks = await repo.listActiveLinksAsOwner();
    final sharedIds = {
      for (final link in ownerActiveLinks) link.vehicleId,
    };
    final accessible = await repo.listBorrowerAccessibleEntries();
    final pendingLinks = await repo.listPendingBorrowerOffers();
    final pending = <({VehicleSharingLink link, String vehicleLabel})>[];
    for (final link in pendingLinks) {
      final v = await repo.getVehicle(link.vehicleId);
      pending.add((
        link: link,
        vehicleLabel: v?.displayLabel.trim().isNotEmpty == true
            ? v!.displayLabel
            : link.vehicleId,
      ));
    }

    if (!mounted) return;
    setState(() {
      _shareable = shareable;
      _vehicleIdsWithActiveShare = sharedIds;
      _accessible = accessible;
      _pendingOffers = pending;
      _contactLabels = labels;
      _loading = false;
    });
  }

  Future<void> _acceptOffer(VehicleSharingLink link) async {
    final l10n = AppLocalizations.of(context);
    final repo = VehiclesRepository(AppDatabase.processScope);
    await repo.acceptSharingLink(link.id);
    // Refresh immediately so Maestro / user see accessible before relay RTT.
    await _reload();
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      try {
        await orch.sendVehicleSharingOfferAccept(linkId: link.id);
      } on HandshakeOrchestratorError {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vehicleSharingAcceptRelayFailed)),
        );
      } on RelayClientError {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vehicleSharingAcceptRelayFailed)),
        );
      } on RelayUnreachableException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vehicleSharingAcceptRelayFailed)),
        );
      } on TimeoutException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vehicleSharingAcceptRelayFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_access.hasVehicleSharingEntitlement) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => exitVehicleSharingModule(context),
          ),
          title: Text(l10n.homeModuleVehicleSharing),
        ),
        body: Center(child: Text(l10n.vehicleSharingLicensingRequired)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => exitVehicleSharingModule(context),
        ),
        title: qaVehicleSharingSemantics(
          identifier: kQaVehicleSharingHub,
          child: Text(l10n.homeModuleVehicleSharing),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: screenBodyScrollPadding(context),
                children: [
                  _sectionTitle(
                    context,
                    _countTitle(
                      _shareable.length,
                      l10n.vehicleSharingShareableTitle,
                      l10n.vehicleSharingShareableTitlePlural,
                    ),
                  ),
                  if (_shareable.isEmpty)
                    Text(l10n.vehicleSharingEmptyNone)
                  else
                    ..._shareable.map(
                      (vehicle) {
                        Future<void> openShares() async {
                          await context.push(
                            '/vehicle-sharing/${vehicle.id}/shares',
                          );
                          _reload();
                        }

                        return qaVehicleSharingSemantics(
                          identifier: qaVehicleSharingShareableRowSemanticsId(
                            vehicle.displayLabel,
                          ),
                          button: true,
                          onTap: openShares,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading:
                                _vehicleIdsWithActiveShare.contains(vehicle.id)
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : const SizedBox(width: 24),
                            title: Text(vehicle.displayLabel),
                            onTap: openShares,
                          ),
                        );
                      },
                    ),
                  const Divider(height: 32),
                  _sectionTitle(
                    context,
                    _countTitle(
                      _accessible.length,
                      l10n.vehicleSharingAccessibleTitle,
                      l10n.vehicleSharingAccessibleTitlePlural,
                    ),
                  ),
                  if (_accessible.isEmpty)
                    Text(l10n.vehicleSharingEmptyNone)
                  else
                    ..._accessible.map(
                      (entry) => _AccessibleCard(
                        vehicle: entry.vehicle,
                        link: entry.link,
                        ownerLabel: _ownerLabel(
                          entry.vehicle,
                          _contactLabels,
                          l10n,
                        ),
                        prefs: widget.prefs,
                      ),
                    ),
                  const Divider(height: 32),
                  _sectionTitle(
                    context,
                    _countTitle(
                      _pendingOffers.length,
                      l10n.vehicleSharingPendingOfferTitle,
                      l10n.vehicleSharingPendingOfferTitlePlural,
                    ),
                  ),
                  if (_pendingOffers.isEmpty)
                    Text(l10n.vehicleSharingEmptyNoneFeminine)
                  else
                    ..._pendingOffers.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: qaVehicleSharingSemantics(
                                identifier:
                                    qaVehicleSharingPendingRowSemanticsId(
                                  entry.vehicleLabel,
                                ),
                                child: Text(entry.vehicleLabel),
                              ),
                            ),
                            // Put qa-* on the label *inside* FilledButton so
                            // Maestro bounds stay button-sized. A Semantics
                            // wrapping the whole Row/trailing under ListView
                            // reports full-width bounds; tapOn COMPLETED then
                            // hits the title, not Accepter (hierarchy
                            // 20260731T225710Z: accept [42,850][1038,997]).
                            FilledButton(
                              onPressed: () => _acceptOffer(entry.link),
                              child: qaVehicleSharingSemantics(
                                identifier: kQaVehicleSharingPendingAccept,
                                button: true,
                                onTap: () => _acceptOffer(entry.link),
                                child: Text(l10n.vehicleSharingAccept),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  String _countTitle(int count, String singular, String plural) {
    return count <= 1 ? singular : plural;
  }

  String _ownerLabel(
    Vehicle vehicle,
    Map<String, String> labels,
    AppLocalizations l10n,
  ) {
    final id = vehicle.ownerContactId;
    if (id == kVehicleOwnerSelfContactId) {
      return l10n.vehicleRoleOwner;
    }
    return labels[id] ?? id;
  }
}

class _AccessibleCard extends StatelessWidget {
  const _AccessibleCard({
    required this.vehicle,
    required this.link,
    required this.ownerLabel,
    required this.prefs,
  });

  final Vehicle vehicle;
  final VehicleSharingLink link;
  final String ownerLabel;
  final AppPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usageContext = VehicleUsageContext.borrower(
      actingContactId: link.borrowerContactId,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: qaVehicleSharingSemantics(
        identifier: qaVehicleSharingAccessibleCardSemanticsId(
          vehicle.displayLabel,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.displayLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(l10n.vehicleSharingOwnerLabel(ownerLabel)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: Text(l10n.vehicleQuickActionOdometer),
                    onPressed: () => _openForm(
                      context,
                      'use',
                      usageContext,
                    ),
                  ),
                  ActionChip(
                    label: Text(l10n.vehicleQuickActionFuel),
                    onPressed: () => _openForm(
                      context,
                      'fuel',
                      usageContext,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openForm(
    BuildContext context,
    String kind,
    VehicleUsageContext usageContext,
  ) {
    final borrower = Uri.encodeComponent(usageContext.actingContactId);
    final path = kind == 'use'
        ? '/vehicle-sharing/${vehicle.id}/use?borrower=$borrower'
        : '/vehicle-sharing/${vehicle.id}/fuel?borrower=$borrower';
    context.push(path);
  }
}
