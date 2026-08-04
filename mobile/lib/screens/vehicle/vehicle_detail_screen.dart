import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../debug/qa_vehicle_sale_portability_io.dart';
import '../../debug/qa_vehicle_semantics.dart';
import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../util/display_date.dart';
import '../../vehicle/portability/vehicle_sale_export_service.dart';
import '../../vehicle/portability/vehicle_sale_import_confirm.dart';
import '../../vehicle/portability/vehicle_sale_import_undo_service.dart';
import '../../vehicle/portability/vehicle_sale_portability_dialogs.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../vehicle/vehicle_owned_active_cap.dart';
import '../../widgets/screen_body_padding.dart';
import 'vehicle_detail_gallery.dart';

class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
    required this.prefs,
  });

  final String vehicleId;
  final AppPreferences prefs;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  Vehicle? _vehicle;
  bool _loading = true;
  bool _undoingImport = false;
  int _galleryReloadToken = 0;
  int _pendingCorrections = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final v = await repo.getVehicle(widget.vehicleId);
    final pending = v == null
        ? 0
        : await repo.countPendingGapVerifications(widget.vehicleId);
    if (!mounted) return;
    setState(() {
      _vehicle = v;
      _pendingCorrections = pending;
      _loading = false;
    });
  }

  Future<void> _openEdit() async {
    final updated = await context.push<bool>(
      '/vehicle/${widget.vehicleId}/edit',
    );
    if (updated == true) {
      await _load();
      setState(() => _galleryReloadToken++);
    }
  }

  Future<void> _confirmUndoImport() async {
    final target = _vehicle;
    if (target == null ||
        !target.saleImportUndoAvailable ||
        _undoingImport) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          l10n.vehicleSaleImportUndoConfirmBody(target.displayLabel),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                identifier: kDebugMode ? kQaVehicleImportUndoCancel : null,
                button: true,
                onTap: () => Navigator.of(ctx).pop(false),
                excludeSemantics: true,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.commonCancel),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                identifier: kDebugMode ? kQaVehicleImportUndoConfirm : null,
                button: true,
                onTap: () => Navigator.of(ctx).pop(true),
                excludeSemantics: true,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l10n.vehicleSaleImportUndoAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _undoingImport = true);
    try {
      await VehicleSaleImportUndoService(AppDatabase.processScope)
          .undoImport(target.id);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleImportFailOther)),
      );
    } finally {
      if (mounted) setState(() => _undoingImport = false);
    }
  }

  Future<void> _confirmDeactivate() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.vehicleDeactivateDialogTitle),
        content: Text(l10n.vehicleDeactivateDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.vehicleDeactivateConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final importOk = await confirmSaleImportCommitmentIfNeeded(
      context,
      vehicleId: widget.vehicleId,
    );
    if (!importOk || !mounted) return;
    final repo = VehiclesRepository(AppDatabase.processScope);
    try {
      await repo.deactivateOwnedVehicle(widget.vehicleId);
    } on VehicleHasOpenUseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleDeactivateBlockedOpenSession)),
      );
      return;
    }
    if (!mounted) return;
    await _load();
  }

  Future<void> _confirmExport() async {
    final l10n = AppLocalizations.of(context);
    if (!vehicleSalePortabilitySupportedOnPlatform()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleExportFailed)),
      );
      return;
    }
    final confirmed = await showVehicleSaleExportConfirmDialog(context);
    if (!confirmed || !mounted) return;
    try {
      final result = await VehicleSaleExportService(AppDatabase.processScope)
          .exportToDocuments(
        vehicleId: widget.vehicleId,
        dataOfSegment: l10n.vehicleExportFileDataOfSegment,
      );
      await qaWriteVehicleSaleExportZip(result.zipBytes);
      if (!mounted) return;
      await showVehicleSaleExportSuccessDialog(
        context,
        zipFileName: result.zipFileName,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleExportFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = _vehicle;
    if (_loading || v == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final summary = vehicleModelColorSummary(l10n, v);
    final dateFmt = effectiveDateFormat(widget.prefs);
    final usesHorometer =
        VehicleKind.fromWire(v.vehicleKind)?.usesHorometer ?? false;
    final active = vehicleIsActive(v);
    final showUndo = active && v.saleImportUndoAvailable;
    final bodyPadding = screenBodyScrollPadding(context);
    final headerPadding = EdgeInsets.fromLTRB(
      bodyPadding.left,
      bodyPadding.top,
      bodyPadding.right,
      0,
    );
    final listPadding = bodyPadding.copyWith(top: 8);
    Widget? editButton;
    if (active) {
      // Outside ListView/ScrollView: Semantics under a scrollable often report
      // max cross-axis bounds so Maestro tapOn COMPLETED without onPressed
      // (hierarchy 20260715T005535Z: qa-vehicle-detail-edit full row width).
      editButton = Semantics(
        identifier: kDebugMode ? kQaVehicleDetailEdit : null,
        button: true,
        onTap: _openEdit,
        excludeSemantics: true,
        child: IconButton(
          onPressed: _openEdit,
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.vehicleEditDetailsTitle,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(v.displayLabel)),
      body: qaVehicleSemantics(
        identifier: kQaVehicleDetail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: headerPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!active)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l10n.vehicleDeactivatedLabel(
                          formatPreferenceDate(v.deactivatedAt, dateFmt),
                        ),
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                      ),
                    ),
                  if (summary.isNotEmpty || showUndo || active)
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (summary.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    summary,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ?editButton,
                            ],
                          ),
                        ),
                        if (showUndo)
                          Semantics(
                            identifier:
                                kDebugMode ? kQaVehicleImportUndo : null,
                            button: true,
                            onTap:
                                _undoingImport ? null : _confirmUndoImport,
                            excludeSemantics: true,
                            child: TextButton(
                              onPressed: _undoingImport
                                  ? null
                                  : _confirmUndoImport,
                              child: Text(l10n.vehicleSaleImportUndoAction),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: listPadding,
                children: [
                  if (active) ...[
                    qaVehicleSemantics(
                      identifier: kQaVehicleDetailOdometerReading,
                      child: ListTile(
                        leading: const Icon(Icons.speed_outlined),
                        title: Text(l10n.vehicleQuickActionOdometer),
                        onTap: () =>
                            context.push('/vehicle/${v.id}/meter-reading'),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.build_outlined),
                      title: Text(l10n.vehicleQuickActionMaintenance),
                      onTap: () =>
                          context.push('/vehicle/${v.id}/maintenance'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.report_outlined),
                      title: Text(l10n.vehicleQuickActionViolation),
                      onTap: () =>
                          context.push('/vehicle/${v.id}/violation'),
                    ),
                    const Divider(),
                    qaVehicleSemantics(
                      identifier: kQaVehicleDetailBorrowerBalances,
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_wallet_outlined),
                        title: Text(l10n.vehicleUsageBalanceTileOwner),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/vehicle/${v.id}/borrower-balances',
                        ),
                      ),
                    ),
                    const Divider(),
                  ],
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(l10n.vehicleJournalsTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/vehicle/${v.id}/journals'),
                  ),
                  if (active && !usesHorometer)
                    ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text(l10n.vehiclePendingCorrectionsTitle),
                      trailing: _pendingCorrections > 0
                          ? Badge.count(
                              count: _pendingCorrections,
                              child: const Icon(Icons.chevron_right),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () async {
                        await context
                            .push('/vehicle/${v.id}/pending-corrections');
                        if (mounted) await _load();
                      },
                    ),
                  const Divider(),
                  VehicleDetailGalleryView(
                    key: ValueKey('gallery-$_galleryReloadToken'),
                    vehicleId: v.id,
                    dateFormat: dateFmt,
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    identifier: kDebugMode ? kQaVehicleDetailExport : null,
                    button: true,
                    onTap: _confirmExport,
                    excludeSemantics: true,
                    child: OutlinedButton(
                      onPressed: _confirmExport,
                      child: Text(l10n.vehicleExportDataAction),
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _confirmDeactivate,
                      child: Text(l10n.vehicleDeactivateAction),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
