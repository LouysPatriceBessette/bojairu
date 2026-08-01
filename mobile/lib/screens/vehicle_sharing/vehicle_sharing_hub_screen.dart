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

    if (!mounted || gen != _reloadGeneration) return;
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

                        final hasActiveShare =
                            _vehicleIdsWithActiveShare.contains(vehicle.id);
                        // Maestro id on the row (button + excludeSemantics). A
                        // nested leading Semantics is invisible to Maestro.
                        return qaVehicleSharingSemantics(
                          identifier: hasActiveShare
                              ? qaVehicleSharingShareableActiveSemanticsId(
                                  vehicle.displayLabel,
                                )
                              : qaVehicleSharingShareableRowSemanticsId(
                                  vehicle.displayLabel,
                                ),
                          button: true,
                          onTap: openShares,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: hasActiveShare
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

class _AccessibleCard extends StatefulWidget {
  const _AccessibleCard({
    required this.vehicle,
    required this.link,
    required this.ownerLabel,
  });

  final Vehicle vehicle;
  final VehicleSharingLink link;
  final String ownerLabel;

  @override
  State<_AccessibleCard> createState() => _AccessibleCardState();
}

class _AccessibleCardState extends State<_AccessibleCard> {
  bool _sessionOpen = false;
  bool _loadingSession = true;

  @override
  void initState() {
    super.initState();
    _loadOpenSession();
  }

  @override
  void didUpdateWidget(covariant _AccessibleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicle.id != widget.vehicle.id) {
      _loadOpenSession();
    }
  }

  Future<void> _loadOpenSession() async {
    final open = await VehiclesRepository(AppDatabase.processScope)
        .openUseForVehicle(widget.vehicle.id);
    if (!mounted) return;
    setState(() {
      _sessionOpen = open != null;
      _loadingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usageContext = VehicleUsageContext.borrower(
      actingContactId: widget.link.borrowerContactId,
    );
    final sessionLabel = _sessionOpen
        ? l10n.vehicleSharingSessionEndAction
        : l10n.vehicleSharingSessionStartAction;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: qaVehicleSharingSemantics(
        identifier: qaVehicleSharingAccessibleCardSemanticsId(
          widget.vehicle.displayLabel,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.vehicle.displayLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(l10n.vehicleSharingOwnerLabel(widget.ownerLabel)),
              const SizedBox(height: 8),
              if (_loadingSession)
                const SizedBox(
                  height: 32,
                  width: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: qaVehicleSharingSemantics(
                        identifier: kQaVehicleSharingSessionAction,
                        button: true,
                        onTap: () => _openSession(context, usageContext),
                        child: Text(sessionLabel),
                      ),
                      onPressed: () => _openSession(context, usageContext),
                    ),
                    ActionChip(
                      label: qaVehicleSharingSemantics(
                        identifier: kQaVehicleSharingOtherActions,
                        button: true,
                        onTap: () => _openOtherActions(context, usageContext),
                        child: Text(l10n.vehicleSharingOtherActions),
                      ),
                      onPressed: () => _openOtherActions(context, usageContext),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSession(
    BuildContext context,
    VehicleUsageContext usageContext,
  ) async {
    final borrower = Uri.encodeComponent(usageContext.actingContactId);
    await context.push(
      '/vehicle-sharing/${widget.vehicle.id}/use?borrower=$borrower',
    );
    await _loadOpenSession();
  }

  Future<void> _openOtherActions(
    BuildContext context,
    VehicleUsageContext usageContext,
  ) async {
    final borrower = Uri.encodeComponent(usageContext.actingContactId);
    await context.push(
      '/vehicle-sharing/${widget.vehicle.id}/other-actions?borrower=$borrower',
    );
    await _loadOpenSession();
  }
}
