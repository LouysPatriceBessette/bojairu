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

/// Active, revoked, and pending sharing links for one owned vehicle.
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
  List<VehicleSharingLink> _revokedLinks = const [];
  List<VehicleSharingLink> _pendingLinks = const [];
  List<VehicleSharingLink> _reactivatePendingLinks = const [];
  Map<String, String> _contactLabels = const {};
  Map<String, bool> _pendingDecisionByLink = const {};
  Map<String, VehicleUse?> _openUseByVehicle = const {};
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
    final revoked = links
        .where((l) => l.status == VehicleSharingLinkStatus.revoked.wire)
        .toList();
    final pending = links
        .where((l) => l.status == VehicleSharingLinkStatus.pending.wire)
        .toList();
    final reactivatePending = links
        .where(
          (l) => l.status == VehicleSharingLinkStatus.reactivatePending.wire,
        )
        .toList();
    final contacts = await ContactsRepository(AppDatabase.processScope).list();
    final labels = {for (final c in contacts) c.id: c.displayName};

    final pendingDecision = <String, bool>{};
    for (final link in active) {
      pendingDecision[link.id] =
          await repo.hasPendingUsageBalanceDecision(link.id);
    }
    final openUse = await repo.openUseForVehicle(widget.vehicleId);

    if (!mounted || gen != _reloadGeneration) return;
    setState(() {
      _vehicle = vehicle;
      _activeLinks = active;
      _revokedLinks = revoked;
      _pendingLinks = pending;
      _reactivatePendingLinks = reactivatePending;
      _contactLabels = labels;
      _pendingDecisionByLink = pendingDecision;
      _openUseByVehicle = {widget.vehicleId: openUse};
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

  Future<void> _onRevoke(VehicleSharingLink link) async {
    final l10n = AppLocalizations.of(context);
    final name = _contactLabels[link.borrowerContactId] ?? link.borrowerContactId;
    final openUse = _openUseByVehicle[widget.vehicleId];
    final borrowerOpen = openUse != null &&
        openUse.attributedContactId == link.borrowerContactId;

    if (borrowerOpen) {
      final when = formatPreferenceDateTime(
        openUse.startedAt.toUtc(),
        widget.prefs.dateFormat,
      );
      final force = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(
            l10n.vehicleSharingRevokeForceSessionBody(name, when),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.vehicleUsageBalanceCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.vehicleSharingRevokeForceSessionYes),
            ),
          ],
        ),
      );
      if (force != true || !mounted) return;
      final ended = await context.push<bool>(
        '/vehicle/${widget.vehicleId}/use'
        '?forceEndBorrowerSession=1&linkId=${Uri.encodeComponent(link.id)}',
      );
      if (ended != true || !mounted) {
        await _reload();
        return;
      }
    }

    final vehicleName = _vehicle?.displayLabel.trim().isNotEmpty == true
        ? _vehicle!.displayLabel
        : widget.vehicleId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          l10n.vehicleSharingRevokeConfirmBody(name, vehicleName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.vehicleUsageBalanceCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.vehicleUsageBalanceDecisionConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return;
    try {
      await orch.sendVehicleSharingRevoke(linkId: link.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorSomethingWentWrongBody)),
      );
    }
    if (mounted) await _reload();
  }

  Future<void> _onReactivate(VehicleSharingLink link) async {
    final l10n = AppLocalizations.of(context);
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return;
    try {
      await orch.sendVehicleSharingReactivatePropose(linkId: link.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorSomethingWentWrongBody)),
      );
    }
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _vehicle?.displayLabel ?? l10n.vehicleSharingSharesDetailTitle;
    final dateFmt = widget.prefs.dateFormat;
    final hasAny = _activeLinks.isNotEmpty ||
        _revokedLinks.isNotEmpty ||
        _pendingLinks.isNotEmpty ||
        _reactivatePendingLinks.isNotEmpty;
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
                  ..._reactivatePendingLinks.map((link) {
                    final name = _contactLabels[link.borrowerContactId] ??
                        link.borrowerContactId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      trailing: Text(l10n.vehicleSharingReactivatePendingSent),
                    );
                  }),
                  ..._activeLinks.map((link) {
                    final name = _contactLabels[link.borrowerContactId] ??
                        link.borrowerContactId;
                    final revokeBlocked =
                        _pendingDecisionByLink[link.id] == true;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      title: Text(name),
                      trailing: TextButton(
                        onPressed:
                            revokeBlocked ? null : () => _onRevoke(link),
                        child: Text(l10n.vehicleSharingRevoke),
                      ),
                    );
                  }),
                  ..._revokedLinks.map((link) {
                    final name = _contactLabels[link.borrowerContactId] ??
                        link.borrowerContactId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const SizedBox(width: 24),
                      title: Text(name),
                      trailing: TextButton(
                        onPressed: () => _onReactivate(link),
                        child: Text(l10n.vehicleSharingReactivate),
                      ),
                    );
                  }),
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
