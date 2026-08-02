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
import '../../util/vehicle_meter_display.dart';
import '../../vehicle/vehicle_meter_photo_path.dart';
import '../../vehicle/vehicle_known_tank_state.dart';
import '../../vehicle/vehicle_consumption_mode_policy.dart';
import '../../vehicle/vehicle_tank_session_flow.dart';
import '../../vehicle/vehicle_gap_correction.dart';
import '../../vehicle/portability/vehicle_sale_import_confirm.dart';
import '../../vehicle/vehicle_gap_flow.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../vehicle/vehicle_meter_photo_picker.dart';
import '../../vehicle/vehicle_usage_context.dart';
import '../../vehicle/vehicle_usage_denial_ui.dart';
import '../../widgets/vehicle_meter_photo_button.dart';
import '../../widgets/screen_body_padding.dart';
import '../../widgets/vehicle_driving_condition_mix_fields.dart';
import '../../widgets/vehicle_narrow_unit_field.dart';
import '../../widgets/vehicle_tank_fill_fields.dart';
import '../../vehicle/vehicle_tank_fill_levels.dart';
import 'vehicle_form_vehicle_selector.dart';

/// Owner or borrower vehicle use session (start/end meter readings).
class VehicleUseSessionScreen extends StatefulWidget {
  const VehicleUseSessionScreen({
    super.key,
    this.initialVehicleId,
    this.prefs,
    this.usageContext = const VehicleUsageContext.owner(),
  });

  final String? initialVehicleId;
  final AppPreferences? prefs;
  final VehicleUsageContext usageContext;

  @override
  State<VehicleUseSessionScreen> createState() =>
      _VehicleUseSessionScreenState();
}

class _VehicleUseSessionScreenState extends State<VehicleUseSessionScreen> {
  final _reading = TextEditingController();
  final _routePercent = TextEditingController();
  final _cityPercent = TextEditingController();
  final _trafficPercent = TextEditingController();
  bool _fullTank = true;
  VehicleTankFillLevel _tankFillLevel = VehicleTankFillLevel.defaultChoice;
  String? _photoPath;
  int? _baselineMeterTenths;
  List<Vehicle> _vehicles = const [];
  String? _selectedVehicleId;
  Vehicle? _vehicle;
  VehicleUse? _openUse;
  VehicleUsageAccessDenial? _denial;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reading.addListener(_onReadingChanged);
    _routePercent.addListener(_onReadingChanged);
    _cityPercent.addListener(_onReadingChanged);
    _trafficPercent.addListener(_onReadingChanged);
    _load();
  }

  @override
  void dispose() {
    _reading.removeListener(_onReadingChanged);
    _routePercent.removeListener(_onReadingChanged);
    _cityPercent.removeListener(_onReadingChanged);
    _trafficPercent.removeListener(_onReadingChanged);
    _reading.dispose();
    _routePercent.dispose();
    _cityPercent.dispose();
    _trafficPercent.dispose();
    super.dispose();
  }

  void _onReadingChanged() {
    if (_openUse == null && _baselineMeterTenths != null) {
      final v = _vehicle;
      if (v != null) {
        final parsed = parseMeterInputToStoredTenths(
          _reading.text,
          usesHorometer:
              VehicleKind.fromWire(v.vehicleKind)?.usesHorometer ?? false,
          distanceUnit: widget.prefs == null
              ? DistanceUnit.km
              : resolveDistanceUnit(widget.prefs!),
        );
        if (parsed != _baselineMeterTenths &&
            _photoPath != null &&
            _photoPath!.isNotEmpty) {
          _photoPath = null;
        }
      }
    }
    setState(() {});
  }

  int? _parsedMeterTenths() {
    final v = _vehicle;
    if (v == null) return null;
    return parseMeterInputToStoredTenths(
      _reading.text,
      usesHorometer:
          VehicleKind.fromWire(v.vehicleKind)?.usesHorometer ?? false,
      distanceUnit: widget.prefs == null
          ? DistanceUnit.km
          : resolveDistanceUnit(widget.prefs!),
    );
  }

  bool get _startingSession => _openUse == null;

  bool get _meterChangedFromBaseline {
    if (!_startingSession || _baselineMeterTenths == null) return true;
    final parsed = _parsedMeterTenths();
    return parsed != null && parsed != _baselineMeterTenths;
  }

  bool get _photoRequired {
    if (QaE2eFlags.meterPhotoOptional) return false;
    if (!_startingSession) return true;
    return _meterChangedFromBaseline;
  }

  bool get _photoPickEnabled {
    if (_photoPath != null && _photoPath!.isNotEmpty) return false;
    if (!_startingSession) return true;
    return _meterChangedFromBaseline;
  }

  bool get _endingRoadSession {
    final v = _vehicle;
    if (v == null || _openUse == null) return false;
    return !(VehicleKind.fromWire(v.vehicleKind)?.usesHorometer ?? false);
  }

  bool get _requiresDetailedDrivingMix {
    final v = _vehicle;
    if (v == null || !_endingRoadSession) return false;
    return shouldCollectDetailedDrivingMix(
      vehicle: v,
      usageContext: widget.usageContext,
    );
  }

  bool get _formComplete {
    final v = _vehicle;
    if (v == null) return false;
    final parsed = _parsedMeterTenths();
    if (parsed == null) return false;
    if (_photoRequired) {
      final photo = _photoPath;
      if (photo == null || photo.isEmpty) return false;
    }
    if (_requiresDetailedDrivingMix &&
        !drivingMixFieldsCompleteAndValid(
          routeText: _routePercent.text,
          cityText: _cityPercent.text,
          trafficText: _trafficPercent.text,
        )) {
      return false;
    }
    return true;
  }

  Future<void> _load() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final vehicles = await loadVehiclesForUsageForms(widget.usageContext);
    final globalOpen = await repo.findAnyOpenUse();
    final selectedId = widget.initialVehicleId?.isNotEmpty == true
        ? widget.initialVehicleId
        : globalOpen?.vehicleId ?? vehicles.firstOrNull?.id;
    await _loadVehicleState(selectedId, vehicles: vehicles);
  }

  Future<void> _loadVehicleState(
    String? vehicleId, {
    List<Vehicle>? vehicles,
  }) async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final owned = vehicles ?? _vehicles;
    final v = vehicleId == null ? null : await repo.getVehicle(vehicleId);
    final denial = denyVehicleUsageAccess(
      vehicle: v,
      context: widget.usageContext,
    );
    VehicleUse? open;
    if (denial == null && v != null) {
      open = await repo.openUseForVehicle(v.id);
      // Propriétaire (or any actor) may only end a session attributed to them.
      // A peer/borrower open use must leave this form in "start" mode.
      if (!canEndUseSessionAsActor(
        openUse: open,
        context: widget.usageContext,
      )) {
        open = null;
      }
    }
    final endingSession = open != null;
    int? baselineMeter;
    VehicleTankFillLevel tankLevel = VehicleTankFillLevel.defaultChoice;
    var fullTank = !endingSession;
    if (denial == null && v != null && !endingSession) {
      final kind = VehicleKind.fromWire(v.vehicleKind);
      final usesHorometer = kind?.usesHorometer ?? false;
      final distanceUnit = widget.prefs == null
          ? DistanceUnit.km
          : resolveDistanceUnit(widget.prefs!);
      final anchor = await repo.latestMeterAnchorDetail(v.id);
      if (anchor != null) {
        baselineMeter = anchor.value;
        _reading.text = formatStoredMeterForInput(
          anchor.value,
          usesHorometer: usesHorometer,
          distanceUnit: distanceUnit,
        );
      }
      final tankState = await VehicleKnownTankState.latest(
        AppDatabase.processScope,
        v.id,
      );
      if (tankState != null) {
        fullTank = tankState.isFullTank;
        if (!tankState.isFullTank) {
          tankLevel = VehicleTankFillLevel.fromPercent(tankState.tankFillFraction) ??
              VehicleTankFillLevel.defaultChoice;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _vehicles = owned;
      _selectedVehicleId = vehicleId;
      _vehicle = v;
      _denial = denial;
      _openUse = open;
      _photoPath = null;
      _baselineMeterTenths = baselineMeter;
      if (endingSession) {
        _reading.clear();
        _routePercent.clear();
        _cityPercent.clear();
        _trafficPercent.clear();
        _fullTank = false;
        _tankFillLevel = VehicleTankFillLevel.defaultChoice;
      } else if (denial != null || v == null) {
        _reading.clear();
        _fullTank = true;
        _tankFillLevel = VehicleTankFillLevel.defaultChoice;
      } else {
        _fullTank = fullTank;
        _tankFillLevel = tankLevel;
      }
      _loading = false;
    });
  }

  Future<void> _onVehicleSelected(String vehicleId) async {
    setState(() => _loading = true);
    await _loadVehicleState(vehicleId);
  }

  Future<void> _pickPhoto() async {
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) return;
    final path = await pickAndStoreVehicleMeterPhoto(
      context,
      vehicleId: vehicleId,
    );
    if (path != null && mounted) setState(() => _photoPath = path);
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final v = _vehicle;
    if (v == null || _denial != null) return;
    final parsed = _parsedMeterTenths();
    if (parsed == null) return;

    setState(() => _saving = true);
    final repo = VehiclesRepository(AppDatabase.processScope);
    try {
      final existingOpen = await repo.openUseForVehicle(v.id);
      final ending = canEndUseSessionAsActor(
        openUse: existingOpen,
        context: widget.usageContext,
      );
      // Only the attributed actor may end; otherwise this submit is a start.
      final openUse = ending ? existingOpen : null;
      final blockingOpenUse = !ending ? existingOpen : null;
      if (!mounted) return;
      // Starting a session (or ending one with other writes) confirms import.
      final ok = await confirmSaleImportCommitmentIfNeeded(
        context,
        vehicleId: v.id,
      );
      if (!ok) return;
      if (!mounted) return;
      final unit = repo.meterUnitForVehicle(v);
      final kind = VehicleKind.fromWire(v.vehicleKind);
      final usesHorometer = kind?.usesHorometer ?? false;
      final distanceUnit = widget.prefs == null
          ? DistanceUnit.km
          : resolveDistanceUnit(widget.prefs!);
      final latest = await repo.latestMeterValue(v.id);
      if (!mounted) return;
      final actingId = widget.usageContext.actingContactId;

      String photoPath;
      if (_photoPath != null && _photoPath!.isNotEmpty) {
        photoPath = _photoPath!;
      } else if (_startingSession && !_meterChangedFromBaseline) {
        photoPath = kVehicleMeterPhotoKnownUnchangedSentinel;
      } else {
        final qaPath = qaE2eEffectiveMeterPhotoPath(_photoPath);
        if (qaPath != null) {
          photoPath = qaPath;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.vehicleMeterPhotoRequired)),
          );
          return;
        }
      }

      if (!mounted) return;
      // Peer open use absorbs the meter advance when we close it in good faith;
      // do not create a separate "unknown" positive gap for that span.
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
        attributePositiveGap: openUse == null && blockingOpenUse == null,
      );
      if (!gapResult.proceed) {
        return;
      }

      if (openUse != null || blockingOpenUse != null) {
        final sessionToClose = openUse ?? blockingOpenUse!;
        final startReading =
            await repo.getMeterReading(sessionToClose.startReadingId);
        if (startReading == null) {
          return;
        }
        final fuelDuringSession =
            await repo.fuelLitersPurchasedDuringOpenUse(sessionToClose);
        if (!mounted) return;
        final distanceOk = await confirmSuspiciousSessionEndDistanceBeforeSave(
          context: context,
          repo: repo,
          vehicle: v,
          sessionStartMeterTenths: startReading.value,
          parsedEndMeterTenths: parsed,
          fuelLitersDuringSession: fuelDuringSession,
          usesHorometer: usesHorometer,
          distanceUnit: distanceUnit,
        );
        if (!distanceOk) {
          return;
        }
      }

      if (openUse != null) {
        if (!mounted) return;
        final tankOk = await confirmSessionEndTankLevelIfNeeded(
          context: context,
          l10n: l10n,
          repo: repo,
          vehicleId: v.id,
          parsedMeterTenths: parsed,
          declaredTankPercent: _tankFillLevel.percent,
          usesHorometer: usesHorometer,
          distanceUnit: distanceUnit,
        );
        if (!tankOk) {
          return;
        }
      }

      // Good faith: owner's trusted start reading closes a peer/borrower session
      // that was left open, then opens the owner's own session.
      if (blockingOpenUse != null) {
        final endReading = await repo.saveMeterReading(
          vehicleId: v.id,
          value: parsed,
          unit: unit,
          photoPath: photoPath,
          recordedByContactId: actingId,
          role: MeterReadingRole.sessionEnd,
          vehicleUseId: blockingOpenUse.id,
          negativeGapAcknowledged: latest != null && parsed < latest,
        );
        await repo.closeUseSession(
          useId: blockingOpenUse.id,
          endReadingId: endReading.id,
        );
        final startReading = await repo.saveMeterReading(
          vehicleId: v.id,
          value: parsed,
          unit: unit,
          photoPath: photoPath,
          recordedByContactId: actingId,
          role: MeterReadingRole.sessionStart,
          isFullTank: _fullTank,
          tankFillFraction: _fullTank ? null : _tankFillLevel.percent,
        );
        await repo.openUseSession(
          vehicleId: v.id,
          attributedContactId: actingId,
          startReadingId: startReading.id,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vehicleUseSessionStarted)),
        );
        context.pop();
        return;
      }

      DateTime? readingRecordedAt;
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
            correctionContext: openUse == null
                ? GapCorrectionContext.sessionStart
                : GapCorrectionContext.sessionEnd,
            vehicleUseId: openUse?.id,
            correctionRecordedAt: gapRecordedAt,
          );
          pendingGap = persisted.gap;
          readingRecordedAt = gapRecordedAt;
        }
      }

      final reading = await repo.saveMeterReading(
        vehicleId: v.id,
        value: parsed,
        unit: unit,
        photoPath: photoPath,
        recordedByContactId: actingId,
        role: openUse == null
            ? MeterReadingRole.sessionStart
            : MeterReadingRole.sessionEnd,
        vehicleUseId: openUse?.id,
        negativeGapAcknowledged: latest != null && parsed < latest,
        isFullTank: openUse == null ? _fullTank : false,
        tankFillFraction: openUse == null && _fullTank
            ? null
            : _tankFillLevel.percent,
        recordedAt: readingRecordedAt,
      );

      if (pendingGap != null && previousReading != null) {
        await linkGapTriggerReading(
          repo: repo,
          gapId: pendingGap.id,
          correctionReadingId: pendingGap.correctionReadingId!,
          previousReadingId: previousReading.id,
          triggerReadingId: reading.id,
        );
      }

      if (openUse == null) {
        final opened = await repo.openUseSession(
          vehicleId: v.id,
          attributedContactId: actingId,
          startReadingId: reading.id,
        );
        if (widget.usageContext.forwardsToOwner) {
          final relayOk = await _forwardSessionStartToOwner(
            vehicleId: v.id,
            remoteUseId: opened.id,
            startReadingId: reading.id,
          );
          if (!mounted) return;
          if (!relayOk) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.vehicleSharingSessionRelayFailed)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.vehicleSharingForwarded)),
            );
          }
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.vehicleUseSessionStarted)),
        );
        context.pop();
        return;
      }

      final collectedDetailedMix = _requiresDetailedDrivingMix;
      final routePct = collectedDetailedMix
          ? parseDrivingMixPercent(_routePercent.text)
          : null;
      final cityPct = collectedDetailedMix
          ? parseDrivingMixPercent(_cityPercent.text)
          : null;
      final trafficPct = collectedDetailedMix
          ? parseDrivingMixPercent(_trafficPercent.text)
          : null;
      await repo.closeUseSession(
        useId: openUse.id,
        endReadingId: reading.id,
        drivingRoutePercent: routePct,
        drivingCityPercent: cityPct,
        drivingTrafficPercent: trafficPct,
        sessionConsumptionMode: sessionConsumptionModeForClose(
          collectedDetailedMix: collectedDetailedMix,
        ),
      );
      if (widget.usageContext.forwardsToOwner) {
        final relayOk = await _forwardSessionEndToOwner(
          vehicleId: v.id,
          remoteUseId: openUse.id,
          endReadingId: reading.id,
          drivingRoutePercent: routePct,
          drivingCityPercent: cityPct,
          drivingTrafficPercent: trafficPct,
        );
        if (!mounted) return;
        if (!relayOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.vehicleSharingSessionRelayFailed)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.vehicleSharingForwarded)),
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleUseSessionEnded)),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorSomethingWentWrongBody)),
      );
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

  Future<bool> _forwardSessionStartToOwner({
    required String vehicleId,
    required String remoteUseId,
    required String startReadingId,
  }) async {
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return false;
    final linkId = await _activeBorrowerLinkId(vehicleId);
    if (linkId == null) return false;
    try {
      await orch.sendVehicleUseSessionStart(
        linkId: linkId,
        vehicleId: vehicleId,
        remoteUseId: remoteUseId,
        startReadingId: startReadingId,
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

  Future<bool> _forwardSessionEndToOwner({
    required String vehicleId,
    required String remoteUseId,
    required String endReadingId,
    int? drivingRoutePercent,
    int? drivingCityPercent,
    int? drivingTrafficPercent,
  }) async {
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return false;
    final linkId = await _activeBorrowerLinkId(vehicleId);
    if (linkId == null) return false;
    try {
      await orch.sendVehicleUseSessionEnd(
        linkId: linkId,
        vehicleId: vehicleId,
        remoteUseId: remoteUseId,
        endReadingId: endReadingId,
        drivingRoutePercent: drivingRoutePercent,
        drivingCityPercent: drivingCityPercent,
        drivingTrafficPercent: drivingTrafficPercent,
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
    final v = _vehicle;
    final kind = VehicleKind.fromWire(v?.vehicleKind);
    final meterLabel = kind?.usesHorometer ?? false
        ? l10n.vehicleHorometerLabel
        : l10n.vehicleOdometerLabel;
    final distanceUnit = widget.prefs == null
        ? 'Km'
        : distanceUnitAbbrev(resolveDistanceUnit(widget.prefs!));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _openUse == null
              ? l10n.vehicleUseSessionStart
              : l10n.vehicleUseSessionEnd,
        ),
      ),
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
                        VehicleFormVehicleSelector(
                          vehicles: _vehicles,
                          selectedId: _selectedVehicleId,
                          onSelected: _onVehicleSelected,
                          fixedDisplayLabel:
                              _openUse != null || widget.usageContext.isBorrower
                                  ? v.displayLabel
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        VehicleTankFillFields(
                          fullTank: _fullTank,
                          onFullTankChanged: (v) => setState(() => _fullTank = v),
                          tankFillLevel: _tankFillLevel,
                          onTankFillLevelChanged: (v) =>
                              setState(() => _tankFillLevel = v),
                          showFullTankSwitch: _openUse == null,
                          sectionTitle: _openUse == null
                              ? null
                              : l10n.vehicleFuelTankState,
                          fullTankSemanticsId: _openUse == null
                              ? kQaVehicleFieldSessionFullTank
                              : null,
                          tankLevelSemanticsId: kQaVehicleFieldSessionTankLevel,
                        ),
                        const SizedBox(height: 12),
                        qaVehicleSemantics(
                          identifier: kQaVehicleFieldSessionMeter,
                          child: VehicleNarrowUnitField(
                            controller: _reading,
                            label: meterLabel,
                            unitSuffix: kind?.usesHorometer ?? false
                                ? 'h'
                                : distanceUnit,
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        VehicleMeterPhotoButton(
                          attached: _photoPath != null && _photoPath!.isNotEmpty,
                          enabled: _photoPickEnabled,
                          onPressed: _saving ? null : _pickPhoto,
                          label: _photoPath == null
                              ? l10n.vehicleOdometerPhotoLabel
                              : l10n.vehicleMeterPhotoAttached,
                        ),
                        if (_requiresDetailedDrivingMix) ...[
                          const SizedBox(height: 16),
                          VehicleDrivingConditionMixFields(
                            routeController: _routePercent,
                            cityController: _cityPercent,
                            trafficController: _trafficPercent,
                            onChanged: _onReadingChanged,
                          ),
                        ],
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
