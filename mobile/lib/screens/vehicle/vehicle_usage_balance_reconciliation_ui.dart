import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../util/display_date.dart';
import '../../util/format_money.dart';
import '../../vehicle/sharing/vehicle_usage_balance.dart';
import '../../vehicle/sharing/vehicle_usage_balance_reconciliation.dart';
import '../../vehicle/sharing/vehicle_usage_balance_service.dart';
import '../../vehicle/vehicle_owner_contact.dart';
import '../../widgets/app_decimal_text_field.dart';

/// Where to render the reconciliation controls on the usage-balance page.
enum VehicleUsageBalanceReconciliationPlacement {
  actions,
  carried,
}

/// Actions + carried-forward accordion for the live usage-balance page.
class VehicleUsageBalanceReconciliationPanel extends StatefulWidget {
  const VehicleUsageBalanceReconciliationPanel({
    super.key,
    required this.link,
    required this.prefs,
    required this.breakdown,
    required this.onChanged,
    required this.placement,
  });

  final VehicleSharingLink link;
  final AppPreferences prefs;
  final VehicleUsageBalanceBreakdown breakdown;
  final VoidCallback onChanged;
  final VehicleUsageBalanceReconciliationPlacement placement;

  @override
  State<VehicleUsageBalanceReconciliationPanel> createState() =>
      _VehicleUsageBalanceReconciliationPanelState();
}

class _VehicleUsageBalanceReconciliationPanelState
    extends State<VehicleUsageBalanceReconciliationPanel> {
  List<VehicleUsageBalanceFreeze> _freezes = const [];
  List<VehicleUsageTransfer> _transfers = const [];
  bool _loading = true;
  bool _decisionDialogShown = false;
  bool _carriedExpanded = false;
  HandshakeOrchestrator? _steadyInboxOrchestrator;

  bool get _isOwner =>
      widget.link.ownerContactId == kVehicleOwnerSelfContactId;

  @override
  void initState() {
    super.initState();
    _steadyInboxOrchestrator = HandshakeOrchestrator.maybeInstance;
    _steadyInboxOrchestrator?.steadyStateInboxTick.addListener(
      _onSteadyInboxTick,
    );
    _reload();
  }

  @override
  void dispose() {
    _steadyInboxOrchestrator?.steadyStateInboxTick.removeListener(
      _onSteadyInboxTick,
    );
    super.dispose();
  }

  void _onSteadyInboxTick() {
    if (!mounted) return;
    _reload();
  }

  @override
  void didUpdateWidget(
    covariant VehicleUsageBalanceReconciliationPanel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link.id != widget.link.id) {
      _decisionDialogShown = false;
      _reload();
    }
  }

  Future<void> _reload() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final freezes = await repo.listUsageBalanceFreezesForLink(widget.link.id);
    final transfers = await repo.listUsageTransfersForLink(widget.link.id);
    if (!mounted) return;
    setState(() {
      _freezes = freezes;
      _transfers = transfers;
      _loading = false;
    });
    if (widget.placement ==
        VehicleUsageBalanceReconciliationPlacement.actions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeShowDecisionDialog();
      });
    }
  }

  VehicleUsageBalanceFreeze? get _pendingFreezeForLocalDecision {
    for (final f in _freezes) {
      if (f.status != UsageBalanceFreezeStatus.pending) continue;
      final localIsInitiator = _isOwner
          ? f.initiatedByContactId == kVehicleOwnerSelfContactId
          : f.initiatedByContactId == kVehicleBorrowerSelfContactId;
      if (!localIsInitiator) return f;
    }
    return null;
  }

  VehicleUsageTransfer? get _pendingTransferForLocalDecision {
    for (final t in _transfers) {
      if (t.status != UsageBalanceTransferStatus.pending) continue;
      final localIsInitiator = _isOwner
          ? t.initiatedByContactId == kVehicleOwnerSelfContactId
          : t.initiatedByContactId == kVehicleBorrowerSelfContactId;
      if (!localIsInitiator) return t;
    }
    return null;
  }

  /// True when this transfer was declared as a payment to the Propriétaire
  /// (borrower-initiated, or legacy rows with empty initiator).
  bool _transferPaidToOwner(VehicleUsageTransfer t) {
    final id = t.initiatedByContactId;
    if (id.isEmpty) return true;
    if (id == kVehicleBorrowerSelfContactId) return true;
    if (id == kVehicleOwnerSelfContactId) return false;
    if (id == widget.link.borrowerContactId) return true;
    if (id == widget.link.ownerContactId) return false;
    return true;
  }

  int _transferLedgerDelta(VehicleUsageTransfer t) {
    return usageBalanceTransferLedgerDeltaMinor(
      amountMinor: t.amountMinor,
      paidToOwner: _transferPaidToOwner(t),
    );
  }

  bool _localInitiatedTransfer(VehicleUsageTransfer t) {
    return _isOwner
        ? t.initiatedByContactId == kVehicleOwnerSelfContactId
        : t.initiatedByContactId == kVehicleBorrowerSelfContactId;
  }

  String _carriedRowLabel(AppLocalizations l10n, _CarriedRow row) {
    if (row.freeze != null) {
      return l10n.vehicleUsageBalanceCarriedFreezeLabel;
    }
    final transfer = row.transfer;
    if (transfer == null) return '';
    return _localInitiatedTransfer(transfer)
        ? l10n.vehicleUsageBalanceCarriedTransferSent
        : l10n.vehicleUsageBalanceCarriedTransferReceived;
  }

  bool get _hasOpenFreezeRequest {
    return _freezes.any(
      (f) =>
          f.status == UsageBalanceFreezeStatus.pending ||
          f.status == UsageBalanceFreezeStatus.acceptedAwaitingCatchUp,
    );
  }

  bool get _hasPendingTransfer {
    return _transfers.any(
      (t) => t.status == UsageBalanceTransferStatus.pending,
    );
  }

  /// Freeze is blocked while any freeze/transfer awaits a decision, or when
  /// the current-period net is zero (nothing to freeze).
  bool get _canProposeFreeze =>
      !_hasOpenFreezeRequest &&
      !_hasPendingTransfer &&
      widget.breakdown.balanceMinor != 0;

  Future<void> _maybeShowDecisionDialog() async {
    if (_decisionDialogShown || !mounted) return;
    final freeze = _pendingFreezeForLocalDecision;
    if (freeze != null) {
      _decisionDialogShown = true;
      await _showFreezeDecisionDialog(freeze);
      return;
    }
    final transfer = _pendingTransferForLocalDecision;
    if (transfer != null) {
      _decisionDialogShown = true;
      await _showTransferDecisionDialog(transfer);
    }
  }

  Future<void> _showFreezeProposeDialog() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.vehicleUsageBalanceFreezeProposeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.vehicleUsageBalanceCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.vehicleUsageBalanceSubmit),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return;
    await orch.sendUsageBalanceFreezePropose(
      linkId: widget.link.id,
      breakdown: widget.breakdown,
      initiatedByRole: _isOwner ? 'owner' : 'borrower',
    );
    await _reload();
    widget.onChanged();
  }

  Future<void> _showTransferProposeDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final proposeBody = _isOwner
        ? l10n.vehicleUsageBalanceTransferProposeBodyToBorrower
        : l10n.vehicleUsageBalanceTransferProposeBody;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(proposeBody),
            const SizedBox(height: 12),
            AppDecimalTextField(
              controller: controller,
              fractionDigits: 2,
              decoration: const InputDecoration(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.vehicleUsageBalanceCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.vehicleUsageBalanceSubmit),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final major = double.tryParse(
      controller.text.trim().replaceAll(',', '.'),
    );
    if (major == null || major <= 0) return;
    final amountMinor = (major * 100).round();
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return;
    await orch.sendUsageTransferPropose(
      linkId: widget.link.id,
      amountMinor: amountMinor,
      initiatedByRole: _isOwner ? 'owner' : 'borrower',
    );
    await _reload();
    widget.onChanged();
  }

  Future<void> _showFreezeDecisionDialog(VehicleUsageBalanceFreeze freeze) async {
    final l10n = AppLocalizations.of(context);
    final currency = widget.prefs.currency;
    final dateFmt = effectiveDateFormat(widget.prefs);
    final when = formatPreferenceDateTime(freeze.proposedAt, dateFmt);
    final amount = formatMinorAsMoney(context, freeze.balanceMinor, currency);
    final name = await _initiatorDisplayName(freeze.initiatedByContactId);
    if (!mounted) return;
    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.vehicleUsageBalanceFreezeConfirmTitle),
        content: Text(
          l10n.vehicleUsageBalanceFreezeConfirmBody(name, amount, when),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'later'),
            child: Text(l10n.vehicleUsageBalanceDecisionLater),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'reject'),
            child: Text(l10n.vehicleUsageBalanceDecisionReject),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'confirm'),
            child: Text(l10n.vehicleUsageBalanceDecisionConfirm),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (decision == 'later' || decision == null) return;
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return;
    await orch.sendUsageBalanceFreezeDecision(
      freezeId: freeze.id,
      accepted: decision == 'confirm',
    );
    await _reload();
    widget.onChanged();
  }

  Future<String> _initiatorDisplayName(String contactId) async {
    if (contactId.isEmpty ||
        contactId == kVehicleOwnerSelfContactId ||
        contactId == kVehicleBorrowerSelfContactId) {
      return contactId;
    }
    final contact =
        await ContactsRepository(AppDatabase.processScope).get(contactId);
    final name = contact?.displayName.trim() ?? '';
    return name.isNotEmpty ? name : contactId;
  }

  Future<void> _showTransferDecisionDialog(VehicleUsageTransfer transfer) async {
    final l10n = AppLocalizations.of(context);
    final currency = widget.prefs.currency;
    final amount = formatMinorAsMoney(context, transfer.amountMinor, currency);
    final decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.vehicleUsageBalanceTransferConfirmTitle),
        content: Text(amount),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'later'),
            child: Text(l10n.vehicleUsageBalanceDecisionLater),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'reject'),
            child: Text(l10n.vehicleUsageBalanceDecisionReject),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'confirm'),
            child: Text(l10n.vehicleUsageBalanceDecisionConfirm),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (decision == 'later' || decision == null) {
      _decisionDialogShown = false;
      return;
    }
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return;
    await orch.sendUsageTransferDecision(
      transferId: transfer.id,
      accepted: decision == 'confirm',
    );
    await _reload();
    widget.onChanged();
  }

  void _openHistorical(VehicleUsageBalanceFreeze freeze) {
    final path = _isOwner
        ? '/vehicle/${widget.link.vehicleId}/borrower-balances/${widget.link.id}'
        : '/vehicle-sharing/${widget.link.vehicleId}/usage-balance';
    final uri = Uri(
      path: path,
      queryParameters: {
        if (!_isOwner) 'borrower': widget.link.borrowerContactId,
        'freeze': freeze.id,
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final currency = widget.prefs.currency;
    final dateFmt = effectiveDateFormat(widget.prefs);

    final confirmedFreezes = _freezes
        .where((f) => f.status == UsageBalanceFreezeStatus.confirmed)
        .toList();
    final confirmedTransfers = _transfers
        .where((t) => t.status == UsageBalanceTransferStatus.confirmed)
        .toList();
    final pendingTransfersForLocal = _transfers
        .where((t) {
          if (t.status != UsageBalanceTransferStatus.pending) return false;
          final localIsInitiator = _isOwner
              ? t.initiatedByContactId == kVehicleOwnerSelfContactId
              : t.initiatedByContactId == kVehicleBorrowerSelfContactId;
          return !localIsInitiator;
        })
        .toList();

    final carried = usageBalanceCarriedForwardMinor(
      confirmedFreezeBalanceMinors: confirmedFreezes.map((f) => f.balanceMinor),
      confirmedTransferLedgerDeltas:
          confirmedTransfers.map(_transferLedgerDelta),
    );

    final ledger = <_CarriedRow>[
      for (final f in confirmedFreezes)
        _CarriedRow(
          at: f.confirmedAt ?? f.proposedAt,
          amountMinor: f.balanceMinor,
          freeze: f,
        ),
      for (final t in confirmedTransfers)
        _CarriedRow(
          at: t.confirmedAt ?? t.proposedAt,
          amountMinor: _transferLedgerDelta(t),
          transfer: t,
        ),
      for (final t in pendingTransfersForLocal)
        _CarriedRow(
          at: t.proposedAt,
          amountMinor: _transferLedgerDelta(t),
          transfer: t,
          pending: true,
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.placement ==
            VehicleUsageBalanceReconciliationPlacement.actions)
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed:
                      _canProposeFreeze ? _showFreezeProposeDialog : null,
                  child: Text(l10n.vehicleUsageBalanceFreezeButton),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _hasPendingTransfer ? null : _showTransferProposeDialog,
                  child: Text(l10n.vehicleUsageBalanceTransferButton),
                ),
              ),
            ],
          ),
        if (widget.placement ==
            VehicleUsageBalanceReconciliationPlacement.carried) ...[
          const Divider(),
          Text(
            l10n.vehicleUsageBalanceNotInCurrent,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Builder(
            builder: (context) {
              final canExpand = ledger.isNotEmpty;
              final trailing = canExpand
                  ? null
                  : Icon(
                      Icons.expand_more,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0),
                    );
              return Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: IgnorePointer(
                  ignoring: !canExpand,
                  child: ExpansionTile(
                    key: ValueKey<String>(
                      'usage-balance-carried-$canExpand-$_carriedExpanded',
                    ),
                    tilePadding: EdgeInsets.zero,
                    trailing: trailing,
                    initiallyExpanded: canExpand && _carriedExpanded,
                    onExpansionChanged: canExpand
                        ? (v) => setState(() => _carriedExpanded = v)
                        : null,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.vehicleUsageBalanceCarriedForward,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          formatMinorAsMoney(context, carried, currency),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    children: [
                      for (final row in ledger) ...[
                        if (row.pending && row.transfer != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                _decisionDialogShown = false;
                                _showTransferDecisionDialog(row.transfer!);
                              },
                              child: Text(
                                l10n.vehicleUsageBalancePendingDecision,
                              ),
                            ),
                          ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: row.freeze != null
                              ? InkWell(
                                  onTap: () => _openHistorical(row.freeze!),
                                  child: Text(
                                    '${formatPreferenceDate(row.at, dateFmt)}  ${_carriedRowLabel(l10n, row)}',
                                  ),
                                )
                              : Text(
                                  '${formatPreferenceDate(row.at, dateFmt)}  ${_carriedRowLabel(l10n, row)}',
                                ),
                          trailing: Text(
                            formatMinorAsMoney(
                              context,
                              row.amountMinor,
                              currency,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _CarriedRow {
  _CarriedRow({
    required this.at,
    required this.amountMinor,
    this.freeze,
    this.transfer,
    this.pending = false,
  });

  final DateTime at;
  final int amountMinor;
  final VehicleUsageBalanceFreeze? freeze;
  final VehicleUsageTransfer? transfer;
  final bool pending;
}

/// Loads a frozen snapshot for historical display.
Future<VehicleUsageBalanceBreakdown?> loadFrozenUsageBalanceBreakdown(
  String freezeId,
) async {
  final row = await VehiclesRepository(AppDatabase.processScope)
      .getUsageBalanceFreeze(freezeId);
  if (row == null || row.status != UsageBalanceFreezeStatus.confirmed) {
    return null;
  }
  return UsageBalanceBreakdownCodec.decode(row.breakdownJson);
}

/// Reloads live balance then returns result (for screens that need refresh).
Future<VehicleUsageBalanceResult> reloadUsageBalanceForLink(
  VehicleSharingLink link,
) {
  return VehicleUsageBalanceService(VehiclesRepository(AppDatabase.processScope))
      .computeForLink(link: link);
}
