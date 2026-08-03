import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../debug/qa_e2e_meter_photo.dart';
import '../../debug/qa_vehicle_semantics.dart';
import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../relay/relay_client.dart';
import '../../util/display_units.dart';
import '../../util/format_money.dart';
import '../../util/vehicle_meter_display.dart';
import '../../vehicle/portability/vehicle_sale_import_confirm.dart';
import '../../vehicle/vehicle_gap_correction.dart';
import '../../vehicle/vehicle_gap_flow.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../vehicle/vehicle_maintenance_categories.dart';
import '../../vehicle/vehicle_meter_photo_picker.dart';
import '../../vehicle/vehicle_tank_fill_levels.dart';
import '../../vehicle/vehicle_usage_context.dart';
import '../../vehicle/vehicle_usage_denial_ui.dart';
import '../../widgets/app_decimal_text_field.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/screen_body_padding.dart';
import '../../widgets/vehicle_meter_photo_button.dart';
import '../../widgets/vehicle_narrow_unit_field.dart';
import '../../widgets/vehicle_tank_fill_fields.dart';
import 'vehicle_form_vehicle_selector.dart';

class VehicleFuelPurchaseScreen extends StatefulWidget {
  const VehicleFuelPurchaseScreen({
    super.key,
    this.initialVehicleId,
    required this.prefs,
    this.usageContext = const VehicleUsageContext.owner(),
  });

  final String? initialVehicleId;
  final AppPreferences prefs;
  final VehicleUsageContext usageContext;

  @override
  State<VehicleFuelPurchaseScreen> createState() =>
      _VehicleFuelPurchaseScreenState();
}

class _VehicleFuelPurchaseScreenState extends State<VehicleFuelPurchaseScreen> {
  final _cost = TextEditingController();
  final _volume = TextEditingController();
  final _meter = TextEditingController();
  bool _fullTank = true;
  VehicleTankFillLevel _tankFillLevel = VehicleTankFillLevel.defaultChoice;
  String? _photoPath;
  List<Vehicle> _vehicles = const [];
  String? _selectedVehicleId;
  Vehicle? _selectedVehicle;
  VehicleUsageAccessDenial? _denial;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_cost, _volume, _meter]) {
      c.addListener(_refresh);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_cost, _volume, _meter]) {
      c
        ..removeListener(_refresh)
        ..dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _load() async {
    final vehicles = await loadVehiclesForUsageForms(widget.usageContext);
    final selectedId = widget.initialVehicleId?.isNotEmpty == true
        ? widget.initialVehicleId
        : vehicles.firstOrNull?.id;
    VehicleUsageAccessDenial? denial;
    if (selectedId != null) {
      final v = await VehiclesRepository(AppDatabase.processScope)
          .getVehicle(selectedId);
      denial = denyVehicleUsageAccess(
        vehicle: v,
        context: widget.usageContext,
      );
    }
    Vehicle? selectedVehicle;
    if (selectedId != null) {
      selectedVehicle = vehicles.where((v) => v.id == selectedId).firstOrNull ??
          await VehiclesRepository(AppDatabase.processScope)
              .getVehicle(selectedId);
    }
    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _selectedVehicleId = selectedId;
      _selectedVehicle = selectedVehicle;
      _denial = denial;
      _loading = false;
    });
  }

  Future<void> _onVehicleSelected(String vehicleId) async {
    final v = await VehiclesRepository(AppDatabase.processScope)
        .getVehicle(vehicleId);
    if (!mounted) return;
    setState(() {
      _selectedVehicleId = vehicleId;
      _selectedVehicle = v;
      _denial = denyVehicleUsageAccess(
        vehicle: v,
        context: widget.usageContext,
      );
      _photoPath = null;
    });
  }

  int? _parsedMeter() {
    final vehicle = _selectedVehicle;
    if (vehicle == null) return null;
    final kind = VehicleKind.fromWire(vehicle.vehicleKind);
    return parseMeterInputToStoredTenths(
      _meter.text,
      usesHorometer: kind?.usesHorometer ?? false,
      distanceUnit: resolveDistanceUnit(widget.prefs),
    );
  }

  bool get _canSave {
    if (_denial != null || _selectedVehicleId == null) return false;
    if (double.tryParse(_cost.text.replaceAll(',', '.')) == null) return false;
    if (double.tryParse(_volume.text.replaceAll(',', '.')) == null) return false;
    if (_parsedMeter() == null) return false;
    if (qaE2eMeterPhotoRequired(otherwiseRequired: true)) {
      if (_photoPath == null || _photoPath!.isEmpty) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    final l10n = AppLocalizations.of(context);
    final costMajor = double.parse(_cost.text.replaceAll(',', '.'));
    final volume = double.parse(_volume.text.replaceAll(',', '.'));
    final meter = _parsedMeter()!;
    final vehicle = _selectedVehicle!;
    final vehicleId = _selectedVehicleId!;
    final repo = VehiclesRepository(AppDatabase.processScope);
    final kind = VehicleKind.fromWire(vehicle.vehicleKind);
    final usesHorometer = kind?.usesHorometer ?? false;
    final distanceUnit = resolveDistanceUnit(widget.prefs);

    setState(() => _saving = true);
    try {
      final ok = await confirmSaleImportCommitmentIfNeeded(
        context,
        vehicleId: vehicleId,
      );
      if (!ok || !mounted) return;
      final openUse = await repo.openUseForVehicle(vehicleId);
      if (!mounted) return;
      final gapResult = await confirmMeterGapsBeforeSave(
        context: context,
        l10n: l10n,
        repo: repo,
        vehicle: vehicle,
        parsedMeter: meter,
        actingContactId: widget.usageContext.actingContactId,
        isOwnerContext: widget.usageContext.isOwner,
        usesHorometer: usesHorometer,
        distanceUnit: distanceUnit,
        attributePositiveGap: openUse == null,
      );
      if (!gapResult.proceed || !mounted) return;

      final photoPath = qaE2eEffectiveMeterPhotoPath(_photoPath);
      if (photoPath == null) return;

      final purchase = await repo.saveFuelPurchase(
        vehicleId: vehicleId,
        purchasedAt: DateTime.now().toUtc(),
        costMinor: (costMajor * 100).round(),
        currency: widget.prefs.currency,
        isFullTank: _fullTank,
        recordedByContactId: widget.usageContext.actingContactId,
        volumeLiters: displayVolumeToLiters(
          volume,
          resolveLiquidVolumeUnit(widget.prefs),
        ),
        meterReadingValue: meter,
        meterPhotoPath: photoPath,
        tankFillFraction: _fullTank ? null : _tankFillLevel.percent,
      );

      if (!mounted) return;
      if (widget.usageContext.forwardsToOwner) {
        final relayOk = await _forwardFuelPurchaseToOwner(
          vehicleId: vehicleId,
          remotePurchaseId: purchase.id,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              relayOk
                  ? l10n.vehicleSharingForwarded
                  : l10n.vehicleSharingFuelRelayFailed,
            ),
          ),
        );
      }
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _activeBorrowerLinkId(String vehicleId) async {
    final links = await VehiclesRepository(AppDatabase.processScope)
        .listSharingLinksForVehicle(vehicleId);
    for (final link in links) {
      if (link.status == VehicleSharingLinkStatus.active.wire) {
        return link.id;
      }
    }
    return null;
  }

  Future<bool> _forwardFuelPurchaseToOwner({
    required String vehicleId,
    required String remotePurchaseId,
  }) async {
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return false;
    final linkId = await _activeBorrowerLinkId(vehicleId);
    if (linkId == null) return false;
    try {
      await orch.sendVehicleFuelPurchase(
        linkId: linkId,
        vehicleId: vehicleId,
        remotePurchaseId: remotePurchaseId,
      );
      return true;
    } on HandshakeOrchestratorError {
      return false;
    } on RelayClientError {
      return false;
    } on RelayUnreachableException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final volumeUnit =
        liquidVolumeUnitAbbrev(resolveLiquidVolumeUnit(widget.prefs));
    final distanceUnit =
        distanceUnitAbbrev(resolveDistanceUnit(widget.prefs));
    final selectedKind =
        VehicleKind.fromWire(_selectedVehicle?.vehicleKind);
    final usesHorometer = selectedKind?.usesHorometer ?? false;
    final meterUnitSuffix = usesHorometer ? 'h' : distanceUnit;
    final currencySymbol =
        currencyDisplaySymbol(context, widget.prefs.currency);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleQuickActionFuel)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denial != null
              ? vehicleUsageDenialBody(context, _denial!)
              : ListView(
                  padding: screenBodyScrollPadding(context),
                  children: [
                    VehicleFormVehicleSelector(
                      vehicles: _vehicles,
                      selectedId: _selectedVehicleId,
                      onSelected: _onVehicleSelected,
                      fixedDisplayLabel: widget.usageContext.isBorrower
                          ? _selectedVehicle?.displayLabel
                          : null,
                    ),
                    const SizedBox(height: 16),
                    qaVehicleSemantics(
                      identifier: kQaVehicleFieldCost,
                      child: VehicleNarrowUnitField(
                        controller: _cost,
                        label: l10n.vehicleFuelCost,
                        unitSuffix: currencySymbol,
                        decimal: true,
                        fractionDigits: 2,
                        onChanged: (_) => _refresh(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    qaVehicleSemantics(
                      identifier: kQaVehicleFieldVolume,
                      child: VehicleNarrowUnitField(
                        controller: _volume,
                        label: l10n.vehicleFuelVolume,
                        unitSuffix: volumeUnit,
                        decimal: true,
                        onChanged: (_) => _refresh(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    VehicleTankFillFields(
                      fullTank: _fullTank,
                      onFullTankChanged: (v) => setState(() => _fullTank = v),
                      tankFillLevel: _tankFillLevel,
                      onTankFillLevelChanged: (v) =>
                          setState(() => _tankFillLevel = v),
                    ),
                    const SizedBox(height: 12),
                    qaVehicleSemantics(
                      identifier: kQaVehicleFieldFuelMeter,
                      child: VehicleNarrowUnitField(
                        controller: _meter,
                        label: usesHorometer
                            ? l10n.vehicleHorometerLabel
                            : l10n.vehicleFuelMeter,
                        unitSuffix: meterUnitSuffix,
                        decimal: true,
                        meterUsesHorometer: usesHorometer,
                        meterDistanceUnit: resolveDistanceUnit(widget.prefs),
                        onChanged: (_) => _refresh(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    VehicleMeterPhotoButton(
                      attached: _photoPath != null && _photoPath!.isNotEmpty,
                      enabled: _selectedVehicleId != null,
                      onPressed: _selectedVehicleId == null
                          ? null
                          : () async {
                              final path = await pickAndStoreVehicleMeterPhoto(
                                context,
                                vehicleId: _selectedVehicleId!,
                              );
                              if (path != null && mounted) {
                                setState(() => _photoPath = path);
                              }
                            },
                      label: _photoPath == null
                          ? l10n.vehicleOdometerPhotoLabel
                          : l10n.vehicleMeterPhotoAttached,
                    ),
                    const SizedBox(height: 24),
                    qaVehicleSemantics(
                      identifier: kQaVehicleSave,
                      child: FilledButton(
                        onPressed: _saving || !_canSave ? null : _save,
                        child: Text(l10n.commonSave),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class VehicleStandaloneMeterReadingScreen extends StatefulWidget {
  const VehicleStandaloneMeterReadingScreen({
    super.key,
    required this.vehicleId,
    required this.prefs,
    this.usageContext = const VehicleUsageContext.owner(),
  });

  final String vehicleId;
  final AppPreferences prefs;
  final VehicleUsageContext usageContext;

  @override
  State<VehicleStandaloneMeterReadingScreen> createState() =>
      _VehicleStandaloneMeterReadingScreenState();
}

class _VehicleStandaloneMeterReadingScreenState
    extends State<VehicleStandaloneMeterReadingScreen> {
  final _reading = TextEditingController();
  String? _photoPath;
  Vehicle? _vehicle;
  VehicleUsageAccessDenial? _denial;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reading.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _reading.dispose();
    super.dispose();
  }

  bool get _formComplete {
    final v = _vehicle;
    if (v == null) return false;
    final parsed = parseMeterInputToStoredTenths(
      _reading.text,
      usesHorometer:
          VehicleKind.fromWire(v.vehicleKind)?.usesHorometer ?? false,
      distanceUnit: resolveDistanceUnit(widget.prefs),
    );
    if (parsed == null) return false;
    if (qaE2eMeterPhotoRequired(otherwiseRequired: true)) {
      final photo = _photoPath;
      if (photo == null || photo.isEmpty) return false;
    }
    return true;
  }

  Future<void> _load() async {
    final v = await VehiclesRepository(AppDatabase.processScope)
        .getVehicle(widget.vehicleId);
    if (!mounted) return;
    setState(() {
      _vehicle = v;
      _denial = denyVehicleUsageAccess(
        vehicle: v,
        context: widget.usageContext,
      );
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final path = await pickAndStoreVehicleMeterPhoto(
      context,
      vehicleId: widget.vehicleId,
    );
    if (path != null && mounted) setState(() => _photoPath = path);
  }

  Future<void> _save() async {
    if (_saving || !_formComplete) return;
    final l10n = AppLocalizations.of(context);
    final v = _vehicle;
    if (v == null || _denial != null) return;
    final parsed = parseMeterInputToStoredTenths(
      _reading.text,
      usesHorometer: VehicleKind.fromWire(v.vehicleKind)?.usesHorometer ?? false,
      distanceUnit: resolveDistanceUnit(widget.prefs),
    );
    if (parsed == null) return;
    final photoPath = qaE2eEffectiveMeterPhotoPath(_photoPath);
    if (photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleMeterPhotoRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = VehiclesRepository(AppDatabase.processScope);
    try {
      final ok = await confirmSaleImportCommitmentIfNeeded(
        context,
        vehicleId: v.id,
      );
      if (!ok || !mounted) return;
      final kind = VehicleKind.fromWire(v.vehicleKind);
      final usesHorometer = kind?.usesHorometer ?? false;
      final distanceUnit = resolveDistanceUnit(widget.prefs);
      final latest = await repo.latestMeterValue(v.id);
      if (!mounted) return;
      final actingId = widget.usageContext.actingContactId;

      final gapResult = await confirmMeterGapsBeforeSave(
        context: context,
        l10n: l10n,
        repo: repo,
        vehicle: v,
        parsedMeter: parsed,
        actingContactId: actingId,
        isOwnerContext: widget.usageContext.isOwner,
        usesHorometer: usesHorometer,
        distanceUnit: distanceUnit,
        attributePositiveGap: true,
      );
      if (!gapResult.proceed || !mounted) return;

      DateTime? followUpRecordedAt;
      VehicleOdometerGap? pendingGap;
      VehicleMeterReading? previousReading;

      if (gapResult.divergenceTenths != null) {
        previousReading = await repo.latestNonCorrectionMeterReading(v.id);
        if (previousReading != null) {
          final gapRecordedAt =
              await repo.reserveGapCorrectionTimestamp(v.id);
          final persisted = await persistConfirmedMeterDivergence(
            repo: repo,
            vehicle: v,
            previousReading: previousReading,
            parsedMeter: parsed,
            divergenceTenths: gapResult.divergenceTenths!,
            photoPath: photoPath,
            actingContactId: actingId,
            correctionContext: GapCorrectionContext.standalone,
            correctionRecordedAt: gapRecordedAt,
          );
          pendingGap = persisted.gap;
          followUpRecordedAt = gapRecordedAt;
        }
      }

      final triggerReading = await repo.saveMeterReading(
        vehicleId: v.id,
        value: parsed,
        unit: repo.meterUnitForVehicle(v),
        photoPath: photoPath,
        recordedByContactId: actingId,
        role: MeterReadingRole.standalone,
        negativeGapAcknowledged: latest != null && parsed < latest,
        recordedAt: followUpRecordedAt,
      );

      if (pendingGap != null && previousReading != null) {
        await linkGapTriggerReading(
          repo: repo,
          gapId: pendingGap.id,
          correctionReadingId: pendingGap.correctionReadingId!,
          previousReadingId: previousReading.id,
          triggerReadingId: triggerReading.id,
        );
      }

      if (!mounted) return;
      if (widget.usageContext.forwardsToOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vehicleSharingForwarded)),
        );
      }
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = _vehicle;
    final kind = VehicleKind.fromWire(v?.vehicleKind);
    final meterLabel = kind?.usesHorometer ?? false
        ? l10n.vehicleHorometerLabel
        : l10n.vehicleOdometerLabel;
    final distanceUnit =
        distanceUnitAbbrev(resolveDistanceUnit(widget.prefs));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleQuickActionOdometer)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denial != null
              ? vehicleUsageDenialBody(context, _denial!)
              : v == null
                  ? vehicleUsageDenialBody(
                      context,
                      VehicleUsageAccessDenial.vehicleNotFound,
                    )
                  : ListView(
                      padding: screenBodyScrollPadding(context),
                      children: [
                        qaVehicleSemantics(
                          identifier: kQaVehicleFieldStandaloneMeter,
                          child: VehicleNarrowUnitField(
                            controller: _reading,
                            label: meterLabel,
                            unitSuffix: kind?.usesHorometer ?? false
                                ? 'h'
                                : distanceUnit,
                            decimal: true,
                            meterUsesHorometer: kind?.usesHorometer ?? false,
                            meterDistanceUnit:
                                resolveDistanceUnit(widget.prefs),
                          ),
                        ),
                        const SizedBox(height: 12),
                        VehicleMeterPhotoButton(
                          attached: _photoPath != null && _photoPath!.isNotEmpty,
                          onPressed: _saving ? null : _pickPhoto,
                          label: _photoPath == null
                              ? l10n.vehicleOdometerPhotoLabel
                              : l10n.vehicleMeterPhotoAttached,
                        ),
                        const SizedBox(height: 24),
                        qaVehicleSemantics(
                          identifier: kQaVehicleSave,
                          child: FilledButton(
                            onPressed: _saving || !_formComplete ? null : _save,
                            child: Text(l10n.commonSave),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class VehicleMaintenanceFormScreen extends StatefulWidget {
  const VehicleMaintenanceFormScreen({
    super.key,
    required this.vehicleId,
    required this.prefs,
    this.usageContext = const VehicleUsageContext.owner(),
  });

  final String vehicleId;
  final AppPreferences prefs;
  final VehicleUsageContext usageContext;

  @override
  State<VehicleMaintenanceFormScreen> createState() =>
      _VehicleMaintenanceFormScreenState();
}

class _VehicleMaintenanceFormScreenState
    extends State<VehicleMaintenanceFormScreen> {
  VehicleMaintenanceCategoryWire _category =
      VehicleMaintenanceCategoryWire.oil;
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  final _meter = TextEditingController();
  String? _photoPath;
  Vehicle? _vehicle;
  VehicleUsageAccessDenial? _denial;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_cost, _meter]) {
      c.addListener(_refresh);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_cost, _meter]) {
      c.removeListener(_refresh);
    }
    _cost.dispose();
    _notes.dispose();
    _meter.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _load() async {
    final v = await VehiclesRepository(AppDatabase.processScope)
        .getVehicle(widget.vehicleId);
    if (!mounted) return;
    setState(() {
      _vehicle = v;
      _denial = denyVehicleUsageAccess(
        vehicle: v,
        context: widget.usageContext,
      );
      _loading = false;
    });
  }

  int? _parsedMeter() {
    if (!_category.requiresOdometer) return null;
    final kind = VehicleKind.fromWire(_vehicle?.vehicleKind);
    return parseMeterInputToStoredTenths(
      _meter.text,
      usesHorometer: kind?.usesHorometer ?? false,
      distanceUnit: resolveDistanceUnit(widget.prefs),
    );
  }

  bool get _canSave {
    if (_denial != null || _saving) return false;
    if (double.tryParse(_cost.text.replaceAll(',', '.')) == null) {
      return false;
    }
    if (_category.requiresOdometer) {
      if (_parsedMeter() == null) return false;
      if (qaE2eMeterPhotoRequired(otherwiseRequired: true)) {
        if (_photoPath == null || _photoPath!.isEmpty) return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final l10n = AppLocalizations.of(context);
    final costMajor = double.parse(_cost.text.replaceAll(',', '.'));
    final meterAtService = _category.requiresOdometer ? _parsedMeter() : null;
    final String? attachmentPath;
    if (_category.requiresOdometer) {
      attachmentPath = qaE2eEffectiveMeterPhotoPath(_photoPath);
      if (attachmentPath == null) return;
    } else {
      attachmentPath = null;
    }
    setState(() => _saving = true);
    try {
      final ok = await confirmSaleImportCommitmentIfNeeded(
        context,
        vehicleId: widget.vehicleId,
      );
      if (!ok || !mounted) return;
      final repo = VehiclesRepository(AppDatabase.processScope);
      final vehicle = _vehicle;
      if (meterAtService != null && vehicle != null) {
        final kind = VehicleKind.fromWire(vehicle.vehicleKind);
        final usesHorometer = kind?.usesHorometer ?? false;
        final distanceUnit = resolveDistanceUnit(widget.prefs);
        if (!mounted) return;
        final gapResult = await confirmMeterGapsBeforeSave(
          context: context,
          l10n: l10n,
          repo: repo,
          vehicle: vehicle,
          parsedMeter: meterAtService,
          actingContactId: widget.usageContext.actingContactId,
          isOwnerContext: widget.usageContext.isOwner,
          usesHorometer: usesHorometer,
          distanceUnit: distanceUnit,
          // Maintenance advances the meter; do not prompt for ordinary positive
          // gaps (owner attribution or borrower typo). Negative + one-tank only.
          attributePositiveGap: false,
        );
        if (!gapResult.proceed || !mounted) return;
      }
      final event = await repo.saveMaintenanceEvent(
        vehicleId: widget.vehicleId,
        servicedAt: DateTime.now().toUtc(),
        category: _category.wire,
        costMinor: (costMajor * 100).round(),
        currency: widget.prefs.currency,
        recordedByContactId: widget.usageContext.actingContactId,
        notes: _notes.text.trim(),
        meterAtService: meterAtService,
        attachmentPath: attachmentPath,
      );
      if (!mounted) return;
      if (widget.usageContext.forwardsToOwner) {
        final relayOk = await _forwardMaintenanceToOwner(
          vehicleId: widget.vehicleId,
          remoteEventId: event.id,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              relayOk
                  ? l10n.vehicleSharingForwarded
                  : l10n.vehicleSharingForwardRelayFailed,
            ),
          ),
        );
      }
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _activeBorrowerLinkId(String vehicleId) async {
    final links = await VehiclesRepository(AppDatabase.processScope)
        .listSharingLinksForVehicle(vehicleId);
    for (final link in links) {
      if (link.status == VehicleSharingLinkStatus.active.wire) {
        return link.id;
      }
    }
    return null;
  }

  Future<bool> _forwardMaintenanceToOwner({
    required String vehicleId,
    required String remoteEventId,
  }) async {
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return false;
    final linkId = await _activeBorrowerLinkId(vehicleId);
    if (linkId == null) return false;
    try {
      await orch.sendVehicleMaintenance(
        linkId: linkId,
        vehicleId: vehicleId,
        remoteEventId: remoteEventId,
      );
      return true;
    } on HandshakeOrchestratorError {
      return false;
    } on RelayClientError {
      return false;
    } on RelayUnreachableException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = VehicleKind.fromWire(_vehicle?.vehicleKind);
    final distanceUnit =
        distanceUnitAbbrev(resolveDistanceUnit(widget.prefs));
    final meterUnitSuffix =
        kind?.usesHorometer ?? false ? 'h' : distanceUnit;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleQuickActionMaintenance)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denial != null
              ? vehicleUsageDenialBody(context, _denial!)
              : ListView(
                  padding: screenBodyScrollPadding(context),
                  children: [
                    DropdownButtonFormField<VehicleMaintenanceCategoryWire>(
                      key: ValueKey(_category),
                      isExpanded: true,
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: l10n.vehicleMaintenanceCategory,
                      ),
                      items: [
                        for (final c in VehicleMaintenanceCategoryWire.values)
                          DropdownMenuItem(
                            value: c,
                            child: Text(vehicleMaintenanceCategoryLabel(l10n, c.wire)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _category = value;
                          if (!value.requiresOdometer) {
                            _meter.clear();
                            _photoPath = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    AppDecimalTextField(
                      controller: _cost,
                      fractionDigits: 2,
                      decoration:
                          InputDecoration(labelText: l10n.vehicleMaintenanceCost),
                      onChanged: (_) => _refresh(),
                    ),
                    if (_category.requiresOdometer) ...[
                      const SizedBox(height: 12),
                      VehicleNarrowUnitField(
                        controller: _meter,
                        label: kind?.usesHorometer ?? false
                            ? l10n.vehicleHorometerLabel
                            : l10n.vehicleFuelMeter,
                        unitSuffix: meterUnitSuffix,
                        decimal: true,
                        meterUsesHorometer: kind?.usesHorometer ?? false,
                        meterDistanceUnit: resolveDistanceUnit(widget.prefs),
                        onChanged: (_) => _refresh(),
                      ),
                      const SizedBox(height: 12),
                      VehicleMeterPhotoButton(
                        attached: _photoPath != null && _photoPath!.isNotEmpty,
                        onPressed: () async {
                          final path = await pickAndStoreVehicleMeterPhoto(
                            context,
                            vehicleId: widget.vehicleId,
                          );
                          if (path != null && mounted) {
                            setState(() => _photoPath = path);
                          }
                        },
                        label: _photoPath == null
                            ? l10n.vehicleOdometerPhotoLabel
                            : l10n.vehicleMeterPhotoAttached,
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration:
                          InputDecoration(labelText: l10n.vehicleMaintenanceNotes),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _canSave ? _save : null,
                      child: Text(l10n.commonSave),
                    ),
                  ],
                ),
    );
  }
}

class VehicleViolationFormScreen extends StatefulWidget {
  const VehicleViolationFormScreen({
    super.key,
    required this.vehicleId,
    required this.prefs,
    this.usageContext = const VehicleUsageContext.owner(),
  });

  final String vehicleId;
  final AppPreferences prefs;
  final VehicleUsageContext usageContext;

  @override
  State<VehicleViolationFormScreen> createState() =>
      _VehicleViolationFormScreenState();
}

class _VehicleViolationFormScreenState extends State<VehicleViolationFormScreen> {
  final _type = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  VehicleUsageAccessDenial? _denial;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_type, _amount]) {
      c.addListener(_refresh);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_type, _amount]) {
      c.removeListener(_refresh);
    }
    _type.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _load() async {
    final v = await VehiclesRepository(AppDatabase.processScope)
        .getVehicle(widget.vehicleId);
    if (!mounted) return;
    setState(() {
      _denial = denyVehicleUsageAccess(
        vehicle: v,
        context: widget.usageContext,
      );
      _loading = false;
    });
  }

  bool get _canSave {
    if (_denial != null || _saving) return false;
    if (_type.text.trim().isEmpty) return false;
    if (double.tryParse(_amount.text.replaceAll(',', '.')) == null) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final amountMajor = double.parse(_amount.text.replaceAll(',', '.'));
    setState(() => _saving = true);
    try {
      final ok = await confirmSaleImportCommitmentIfNeeded(
        context,
        vehicleId: widget.vehicleId,
      );
      if (!ok || !mounted) return;
      final repo = VehiclesRepository(AppDatabase.processScope);
      final violation = await repo.saveTrafficViolation(
        vehicleId: widget.vehicleId,
        violatedAt: DateTime.now().toUtc(),
        violationType: _type.text.trim(),
        amountMinor: (amountMajor * 100).round(),
        currency: widget.prefs.currency,
        recordedByContactId: widget.usageContext.actingContactId,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      if (widget.usageContext.forwardsToOwner) {
        final l10n = AppLocalizations.of(context);
        final relayOk = await _forwardViolationToOwner(
          vehicleId: widget.vehicleId,
          remoteViolationId: violation.id,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              relayOk
                  ? l10n.vehicleSharingForwarded
                  : l10n.vehicleSharingForwardRelayFailed,
            ),
          ),
        );
      }
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _activeBorrowerLinkId(String vehicleId) async {
    final links = await VehiclesRepository(AppDatabase.processScope)
        .listSharingLinksForVehicle(vehicleId);
    for (final link in links) {
      if (link.status == VehicleSharingLinkStatus.active.wire) {
        return link.id;
      }
    }
    return null;
  }

  Future<bool> _forwardViolationToOwner({
    required String vehicleId,
    required String remoteViolationId,
  }) async {
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return false;
    final linkId = await _activeBorrowerLinkId(vehicleId);
    if (linkId == null) return false;
    try {
      await orch.sendVehicleTrafficViolation(
        linkId: linkId,
        vehicleId: vehicleId,
        remoteViolationId: remoteViolationId,
      );
      return true;
    } on HandshakeOrchestratorError {
      return false;
    } on RelayClientError {
      return false;
    } on RelayUnreachableException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleQuickActionViolation)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denial != null
              ? vehicleUsageDenialBody(context, _denial!)
              : ListView(
                  padding: screenBodyScrollPadding(context),
                  children: [
                    AppTextField(
                      controller: _type,
                      decoration: InputDecoration(labelText: l10n.vehicleViolationType),
                      onChanged: (_) => _refresh(),
                    ),
                    const SizedBox(height: 12),
                    AppDecimalTextField(
                      controller: _amount,
                      fractionDigits: 2,
                      decoration:
                          InputDecoration(labelText: l10n.vehicleViolationAmount),
                      onChanged: (_) => _refresh(),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration:
                          InputDecoration(labelText: l10n.vehicleMaintenanceNotes),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _canSave ? _save : null,
                      child: Text(l10n.commonSave),
                    ),
                  ],
                ),
    );
  }
}
