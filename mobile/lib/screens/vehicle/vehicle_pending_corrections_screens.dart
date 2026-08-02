import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../util/display_date.dart';
import '../../util/display_units.dart';
import '../../util/vehicle_meter_display.dart';
import '../../util/week_start_calendar.dart';
import '../../vehicle/portability/vehicle_sale_import_confirm.dart';
import '../../vehicle/vehicle_fuel_log_display.dart';
import '../../vehicle/vehicle_gap_correction.dart';
import '../../vehicle/vehicle_gap_resolution_service.dart';
import '../../vehicle/vehicle_gap_tank_levels.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../vehicle/vehicle_meter_photo_path.dart';
import '../../vehicle/vehicle_meter_reading_labels.dart';
import '../../vehicle/vehicle_stored_image.dart';
import '../../vehicle/vehicle_tank_fill_levels.dart';
import '../../widgets/screen_body_padding.dart';
import '../../widgets/vehicle_narrow_unit_field.dart';
import '../../widgets/vehicle_tank_fill_fields.dart';

class VehiclePendingCorrectionsListScreen extends StatelessWidget {
  const VehiclePendingCorrectionsListScreen({
    super.key,
    required this.vehicleId,
    required this.prefs,
  });

  final String vehicleId;
  final AppPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFmt = effectiveDateFormat(prefs);
    final distanceUnit = resolveDistanceUnit(prefs);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehiclePendingCorrectionsTitle)),
      body: FutureBuilder<(Vehicle?, List<({VehicleMeterReading reading, int gapTenths})>)>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final vehicle = snap.data!.$1;
          final rows = snap.data!.$2;
          if (vehicle == null) {
            return Center(child: Text(l10n.vehicleUsageBlockedVehicleNotFound));
          }
          if (rows.isEmpty) {
            return Center(child: Text(l10n.vehiclePendingCorrectionsEmpty));
          }
          final usesHorometer =
              VehicleKind.fromWire(vehicle.vehicleKind)?.usesHorometer ?? false;
          return ListView.separated(
            padding: screenBodyScrollPadding(context),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              final gapTenths = row.gapTenths;
              final gapDisplay = formatStoredMeterDeltaForDisplay(
                context,
                gapTenths,
                usesHorometer: usesHorometer,
                distanceUnit: distanceUnit,
              );
              return ListTile(
                title: Text(l10n.vehicleLogCorrectionJournalSubtitle),
                subtitle: Text(
                  '${pendingGapCorrectionSummaryLabel(
                    l10n: l10n,
                    gapDisplay: gapDisplay,
                    gapTenths: gapTenths,
                  )}\n'
                  '${formatPreferenceDateTime(row.reading.recordedAt, dateFmt)}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '/vehicle/$vehicleId/pending-corrections/${row.reading.id}',
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<(Vehicle?, List<({VehicleMeterReading reading, int gapTenths})>)> _load() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final vehicle = await repo.getVehicle(vehicleId);
    final pending = await repo.listPendingGapVerifications(vehicleId);
    final rows = <({VehicleMeterReading reading, int gapTenths})>[];
    for (final reading in pending) {
      final decoded = decodeGapCorrectionNote(reading.correctionNote);
      final gap = await repo.getOdometerGapByCorrectionReadingId(reading.id);
      final signed = gap?.gapAmount ?? decoded?.gapTenths ?? 0;
      rows.add((reading: reading, gapTenths: signed));
    }
    return (vehicle, rows);
  }
}

class VehiclePendingCorrectionDetailScreen extends StatefulWidget {
  const VehiclePendingCorrectionDetailScreen({
    super.key,
    required this.vehicleId,
    required this.correctionReadingId,
    required this.prefs,
  });

  final String vehicleId;
  final String correctionReadingId;
  final AppPreferences prefs;

  @override
  State<VehiclePendingCorrectionDetailScreen> createState() =>
      _VehiclePendingCorrectionDetailScreenState();
}

class _VehiclePendingCorrectionDetailScreenState
    extends State<VehiclePendingCorrectionDetailScreen> {
  _PendingCorrectionDetailData? _data;
  bool _loading = true;
  bool _saving = false;

  bool _showCorrectPrevious = false;
  bool _showCorrectTrigger = false;
  bool _showAddSessions = false;

  final _correctPreviousMeter = TextEditingController();
  final _correctTriggerMeter = TextEditingController();
  VehicleTankFillLevel? _correctPreviousTank;
  VehicleTankFillLevel? _correctTriggerTank;

  final List<_SessionSegmentForm> _sessionSegments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _correctPreviousMeter.dispose();
    _correctTriggerMeter.dispose();
    for (final s in _sessionSegments) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final vehicle = await repo.getVehicle(widget.vehicleId);
    final verification =
        await repo.getMeterReading(widget.correctionReadingId);
    if (vehicle == null || verification == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final gap =
        await repo.getOdometerGapByCorrectionReadingId(verification.id);
    if (gap == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final previous = await _resolveReading(
      repo: repo,
      vehicleId: widget.vehicleId,
      id: gap.previousReadingId,
      fallbackValue: gap.latestReadingBeforeGap,
    );
    final trigger = await _resolveReading(
      repo: repo,
      vehicleId: widget.vehicleId,
      id: gap.triggerReadingId,
      fallbackValue: gap.startReadingAfterGap,
    );
    if (previous == null || trigger == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final participants =
        await repo.listVehicleParticipantContactIds(widget.vehicleId);
    final minDate = await repo.previousSessionEndDateForReading(previous);
    final data = _PendingCorrectionDetailData(
      vehicle: vehicle,
      gap: gap,
      verificationReading: verification,
      previousReading: previous,
      triggerReading: trigger,
      participantIds: participants,
      minDate: minDate ?? previous.recordedAt,
      maxDate: trigger.recordedAt,
    );
    _sessionSegments
      ..clear()
      ..add(
        _SessionSegmentForm(
          startMeterTenths: gap.latestReadingBeforeGap,
          endMeterTenths: gap.startReadingAfterGap,
          participantIds: participants,
          defaultParticipant: participants.first,
          usesHorometer:
              VehicleKind.fromWire(vehicle.vehicleKind)?.usesHorometer ?? false,
          distanceUnit: resolveDistanceUnit(widget.prefs),
        ),
      );
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  Future<VehicleMeterReading?> _resolveReading({
    required VehiclesRepository repo,
    required String vehicleId,
    required String? id,
    required int fallbackValue,
  }) async {
    if (id != null && id.isNotEmpty) {
      return repo.getMeterReading(id);
    }
    final rows = await repo.listMeterReadings(vehicleId);
    for (final row in rows) {
      if (row.value == fallbackValue && !isGapVerificationCorrectionReading(row)) {
        return row;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vehiclePendingCorrectionDetailTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final data = _data;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.vehiclePendingCorrectionDetailTitle)),
        body: Center(child: Text(l10n.vehicleUsageBlockedVehicleNotFound)),
      );
    }
    final dateFmt = effectiveDateFormat(widget.prefs);
    final distanceUnit = resolveDistanceUnit(widget.prefs);
    final usesHorometer =
        VehicleKind.fromWire(data.vehicle.vehicleKind)?.usesHorometer ?? false;
    final gapDisplay = formatStoredMeterDeltaForDisplay(
      context,
      data.gap.gapAmount,
      usesHorometer: usesHorometer,
      distanceUnit: distanceUnit,
    );
    final previousDate =
        formatPreferenceDateTime(data.previousReading.recordedAt, dateFmt);
    final triggerDate =
        formatPreferenceDateTime(data.triggerReading.recordedAt, dateFmt);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehiclePendingCorrectionDetailTitle)),
      body: ListView(
        padding: screenBodyScrollPadding(context),
        children: [
          ListTile(
            title: Text(l10n.vehicleLogCorrectionLabel),
            subtitle: Text(
              pendingGapCorrectionSummaryLabel(
                l10n: l10n,
                gapDisplay: gapDisplay,
                gapTenths: data.gap.gapAmount,
              ),
            ),
          ),
          _readingSection(
            context: context,
            l10n: l10n,
            title: l10n.vehicleGapResolutionPreviousReading,
            reading: data.previousReading,
            usesHorometer: usesHorometer,
            distanceUnit: distanceUnit,
            prefs: widget.prefs,
          ),
          _readingSection(
            context: context,
            l10n: l10n,
            title: l10n.vehicleGapResolutionTriggerReading,
            reading: data.triggerReading,
            usesHorometer: usesHorometer,
            distanceUnit: distanceUnit,
            prefs: widget.prefs,
          ),
          const Divider(height: 32),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                      _showCorrectPrevious = !_showCorrectPrevious;
                      _showCorrectTrigger = false;
                      _showAddSessions = false;
                      if (_showCorrectPrevious) {
                        _correctPreviousMeter.text =
                            formatStoredMeterForInput(
                          data.previousReading.value,
                          usesHorometer: usesHorometer,
                          distanceUnit: distanceUnit,
                        );
                        _initTankForReading(
                          reading: data.previousReading,
                          other: data.triggerReading,
                          target: _TankTarget.previous,
                        );
                      }
                    }),
            child: Text(l10n.vehicleCorrectReadingButton(previousDate)),
          ),
          if (_showCorrectPrevious) ...[
            const SizedBox(height: 8),
            _buildCorrectReadingForm(
              context: context,
              l10n: l10n,
              meterController: _correctPreviousMeter,
              tankLevel: _correctPreviousTank,
              tankLevels: tankFillLevelsBetween(
                previousPercent: data.previousReading.tankFillFraction ??
                    (data.previousReading.isFullTank == true ? 100 : null),
                triggerPercent: data.triggerReading.tankFillFraction ??
                    (data.triggerReading.isFullTank == true ? 100 : null),
              ),
              onTankChanged: (v) => setState(() => _correctPreviousTank = v),
              usesHorometer: usesHorometer,
              distanceUnit: distanceUnit,
              onSubmit: () => _submitCorrectReading(
                reading: data.previousReading,
                kind: GapResolutionKind.correctPrevious,
                meterController: _correctPreviousMeter,
                tankLevel: _correctPreviousTank,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                      _showCorrectTrigger = !_showCorrectTrigger;
                      _showCorrectPrevious = false;
                      _showAddSessions = false;
                      if (_showCorrectTrigger) {
                        _correctTriggerMeter.text = formatStoredMeterForInput(
                          data.triggerReading.value,
                          usesHorometer: usesHorometer,
                          distanceUnit: distanceUnit,
                        );
                        _initTankForReading(
                          reading: data.triggerReading,
                          other: data.previousReading,
                          target: _TankTarget.trigger,
                        );
                      }
                    }),
            child: Text(l10n.vehicleCorrectReadingButton(triggerDate)),
          ),
          if (_showCorrectTrigger) ...[
            const SizedBox(height: 8),
            _buildCorrectReadingForm(
              context: context,
              l10n: l10n,
              meterController: _correctTriggerMeter,
              tankLevel: _correctTriggerTank,
              tankLevels: tankFillLevelsBetween(
                previousPercent: data.previousReading.tankFillFraction ??
                    (data.previousReading.isFullTank == true ? 100 : null),
                triggerPercent: data.triggerReading.tankFillFraction ??
                    (data.triggerReading.isFullTank == true ? 100 : null),
              ),
              onTankChanged: (v) => setState(() => _correctTriggerTank = v),
              usesHorometer: usesHorometer,
              distanceUnit: distanceUnit,
              onSubmit: () => _submitCorrectReading(
                reading: data.triggerReading,
                kind: GapResolutionKind.correctTrigger,
                meterController: _correctTriggerMeter,
                tankLevel: _correctTriggerTank,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () => setState(() {
                      _showAddSessions = !_showAddSessions;
                      _showCorrectPrevious = false;
                      _showCorrectTrigger = false;
                    }),
            child: Text(l10n.vehicleAddMissingSessionButton),
          ),
          if (_showAddSessions) ...[
            const SizedBox(height: 8),
            ..._sessionSegments.asMap().entries.map((entry) {
              final segment = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildSessionSegmentForm(
                  context: context,
                  l10n: l10n,
                  segment: segment,
                  data: data,
                  usesHorometer: usesHorometer,
                  distanceUnit: distanceUnit,
                ),
              );
            }),
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        final last = _sessionSegments.last;
                        final parsedEnd = parseMeterInputToStoredTenths(
                          last.endMeter.text,
                          usesHorometer: usesHorometer,
                          distanceUnit: distanceUnit,
                        );
                        _sessionSegments.add(
                          _SessionSegmentForm(
                            startMeterTenths: parsedEnd ??
                                data.gap.startReadingAfterGap,
                            endMeterTenths: data.gap.startReadingAfterGap,
                            participantIds: data.participantIds,
                            defaultParticipant: last.selectedParticipant,
                            usesHorometer: usesHorometer,
                            distanceUnit: distanceUnit,
                          ),
                        );
                      }),
              child: Text(l10n.vehicleSplitSessionButton),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _submitSessions,
              child: Text(l10n.vehicleGapResolutionSubmit),
            ),
          ],
        ],
      ),
    );
  }

  void _initTankForReading({
    required VehicleMeterReading reading,
    required VehicleMeterReading other,
    required _TankTarget target,
  }) {
    final levels = tankFillLevelsBetween(
      previousPercent: reading.tankFillFraction ??
          (reading.isFullTank == true ? 100 : null),
      triggerPercent: other.tankFillFraction ??
          (other.isFullTank == true ? 100 : null),
    );
    final level = levels.length == 1
        ? levels.first
        : VehicleTankFillLevel.fromPercent(
            reading.tankFillFraction ??
                (reading.isFullTank == true ? 100 : null),
          );
    if (target == _TankTarget.previous) {
      _correctPreviousTank = level ?? levels.firstOrNull;
    } else {
      _correctTriggerTank = level ?? levels.firstOrNull;
    }
  }

  Widget _buildCorrectReadingForm({
    required BuildContext context,
    required AppLocalizations l10n,
    required TextEditingController meterController,
    required VehicleTankFillLevel? tankLevel,
    required List<VehicleTankFillLevel> tankLevels,
    required ValueChanged<VehicleTankFillLevel?> onTankChanged,
    required bool usesHorometer,
    required DistanceUnit distanceUnit,
    required VoidCallback onSubmit,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VehicleNarrowUnitField(
              controller: meterController,
              label: usesHorometer
                  ? l10n.vehicleHorometerLabel
                  : l10n.vehicleOdometerLabel,
              unitSuffix: usesHorometer ? 'h' : distanceUnitAbbrev(distanceUnit),
              decimal: true,
            ),
            if (tankLevels.isNotEmpty) ...[
              const SizedBox(height: 12),
              VehicleTankFillFields(
                fullTank: tankLevel?.percent == 100,
                onFullTankChanged: (full) {
                  if (full) {
                    onTankChanged(VehicleTankFillLevel.full);
                    return;
                  }
                  final approx = tankLevels
                      .where((l) => l.percent < 100)
                      .firstOrNull;
                  onTankChanged(approx ?? VehicleTankFillLevel.defaultChoice);
                },
                tankFillLevel: tankLevel?.percent == 100
                    ? (tankLevels
                            .where((l) => l.percent < 100)
                            .firstOrNull ??
                        VehicleTankFillLevel.defaultChoice)
                    : (tankLevel ?? VehicleTankFillLevel.defaultChoice),
                onTankFillLevelChanged: tankLevels.length == 1
                    ? (_) {}
                    : (v) => onTankChanged(v),
                showFullTankSwitch:
                    tankLevels.any((l) => l.percent >= 100),
                levels: tankLevels,
                sectionTitle: l10n.vehicleFuelTankState,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : onSubmit,
              child: Text(l10n.vehicleGapResolutionSubmit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionSegmentForm({
    required BuildContext context,
    required AppLocalizations l10n,
    required _SessionSegmentForm segment,
    required _PendingCorrectionDetailData data,
    required bool usesHorometer,
    required DistanceUnit distanceUnit,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownMenu<String>(
              label: Text(l10n.vehicleGapResolutionAssignTo),
              initialSelection: segment.selectedParticipant,
              dropdownMenuEntries: [
                for (final id in segment.participantIds)
                  DropdownMenuEntry(value: id, label: id),
              ],
              onSelected: (v) {
                if (v != null) setState(() => segment.selectedParticipant = v);
              },
            ),
            const SizedBox(height: 8),
            VehicleNarrowUnitField(
              controller: segment.startMeter,
              label: l10n.vehicleGapResolutionStartMeter,
              unitSuffix: usesHorometer ? 'h' : distanceUnitAbbrev(distanceUnit),
              decimal: true,
            ),
            const SizedBox(height: 8),
            VehicleNarrowUnitField(
              controller: segment.endMeter,
              label: l10n.vehicleGapResolutionEndMeter,
              unitSuffix: usesHorometer ? 'h' : distanceUnitAbbrev(distanceUnit),
              decimal: true,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.vehicleGapResolutionDates),
              subtitle: Text(
                segment.dateLabel ??
                    DateFormat.yMMMd().format(data.minDate.toLocal()),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _saving
                  ? null
                  : () => _pickSegmentDates(segment: segment, data: data),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSegmentDates({
    required _SessionSegmentForm segment,
    required _PendingCorrectionDetailData data,
  }) async {
    final range = await showAppDateRangePicker(
      context: context,
      prefs: widget.prefs,
      firstDate: data.minDate,
      lastDate: data.maxDate,
    );
    if (range == null) return;
    setState(() {
      segment.startDate = range.start;
      segment.endDate = range.end;
      segment.dateLabel =
          '${DateFormat.yMMMd().format(range.start.toLocal())} – '
          '${DateFormat.yMMMd().format(range.end.toLocal())}';
    });
  }

  Future<void> _submitCorrectReading({
    required VehicleMeterReading reading,
    required GapResolutionKind kind,
    required TextEditingController meterController,
    required VehicleTankFillLevel? tankLevel,
  }) async {
    final data = _data;
    if (data == null) return;
    final usesHorometer =
        VehicleKind.fromWire(data.vehicle.vehicleKind)?.usesHorometer ?? false;
    final distanceUnit = resolveDistanceUnit(widget.prefs);
    final parsed = parseMeterInputToStoredTenths(
      meterController.text,
      usesHorometer: usesHorometer,
      distanceUnit: distanceUnit,
    );
    if (parsed == null) return;
    setState(() => _saving = true);
    try {
      final ok = await confirmSaleImportCommitmentIfNeeded(
        context,
        vehicleId: widget.vehicleId,
      );
      if (!ok) return;
      final service = VehicleGapResolutionService(
        VehiclesRepository(AppDatabase.processScope),
      );
      await service.correctMeterReading(
        gap: data.gap,
        verificationReading: data.verificationReading,
        readingToCorrect: reading,
        previousReadingId: data.previousReading.id,
        triggerReadingId: data.triggerReading.id,
        newMeterTenths: parsed,
        isFullTank: tankLevel?.percent == 100,
        tankFillFraction:
            tankLevel?.percent == 100 ? null : tankLevel?.percent,
        kind: kind,
      );
      if (!mounted) return;
      context.pop();
    } on GapResolutionValidationException catch (e) {
      if (!mounted) return;
      _showValidationError(e.code);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitSessions() async {
    final data = _data;
    if (data == null) return;
    final usesHorometer =
        VehicleKind.fromWire(data.vehicle.vehicleKind)?.usesHorometer ?? false;
    final distanceUnit = resolveDistanceUnit(widget.prefs);
    final segments = <GapMissingSessionSegment>[];
    for (final form in _sessionSegments) {
      final start = parseMeterInputToStoredTenths(
        form.startMeter.text,
        usesHorometer: usesHorometer,
        distanceUnit: distanceUnit,
      );
      final end = parseMeterInputToStoredTenths(
        form.endMeter.text,
        usesHorometer: usesHorometer,
        distanceUnit: distanceUnit,
      );
      final startDate = form.startDate ?? data.minDate;
      final endDate = form.endDate ?? startDate;
      if (start == null || end == null) return;
      segments.add(
        GapMissingSessionSegment(
          attributedContactId: form.selectedParticipant,
          startMeterTenths: start,
          endMeterTenths: end,
          startDate: startDate,
          endDate: endDate,
        ),
      );
    }
    setState(() => _saving = true);
    try {
      final ok = await confirmSaleImportCommitmentIfNeeded(
        context,
        vehicleId: widget.vehicleId,
      );
      if (!ok) return;
      final service = VehicleGapResolutionService(
        VehiclesRepository(AppDatabase.processScope),
      );
      await service.addMissingUseSessions(
        vehicle: data.vehicle,
        gap: data.gap,
        verificationReading: data.verificationReading,
        previousReading: data.previousReading,
        triggerReading: data.triggerReading,
        segments: segments,
      );
      if (!mounted) return;
      context.pop();
    } on GapResolutionValidationException catch (e) {
      if (!mounted) return;
      _showValidationError(e.code);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showValidationError(GapResolutionValidationCode code) {
    final l10n = AppLocalizations.of(context);
    final message = switch (code) {
      GapResolutionValidationCode.monotonicity =>
        l10n.vehicleGapResolutionValidationMonotonicity,
      GapResolutionValidationCode.segmentSum ||
      GapResolutionValidationCode.segmentOdometer =>
        l10n.vehicleGapResolutionValidationSegment,
      GapResolutionValidationCode.dateOverlap =>
        l10n.vehicleGapResolutionValidationDateOverlap,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _TankTarget { previous, trigger }

class _PendingCorrectionDetailData {
  const _PendingCorrectionDetailData({
    required this.vehicle,
    required this.gap,
    required this.verificationReading,
    required this.previousReading,
    required this.triggerReading,
    required this.participantIds,
    required this.minDate,
    required this.maxDate,
  });

  final Vehicle vehicle;
  final VehicleOdometerGap gap;
  final VehicleMeterReading verificationReading;
  final VehicleMeterReading previousReading;
  final VehicleMeterReading triggerReading;
  final List<String> participantIds;
  final DateTime minDate;
  final DateTime maxDate;
}

class _SessionSegmentForm {
  _SessionSegmentForm({
    required int startMeterTenths,
    required int endMeterTenths,
    required this.participantIds,
    required String defaultParticipant,
    required bool usesHorometer,
    required DistanceUnit distanceUnit,
  })  : selectedParticipant = defaultParticipant,
        startMeter = TextEditingController(
          text: formatStoredMeterForInput(
            startMeterTenths,
            usesHorometer: usesHorometer,
            distanceUnit: distanceUnit,
          ),
        ),
        endMeter = TextEditingController(
          text: formatStoredMeterForInput(
            endMeterTenths,
            usesHorometer: usesHorometer,
            distanceUnit: distanceUnit,
          ),
        );

  final List<String> participantIds;
  String selectedParticipant;
  final TextEditingController startMeter;
  final TextEditingController endMeter;
  DateTime? startDate;
  DateTime? endDate;
  String? dateLabel;

  void dispose() {
    startMeter.dispose();
    endMeter.dispose();
  }
}

Widget _readingSection({
  required BuildContext context,
  required AppLocalizations l10n,
  required String title,
  required VehicleMeterReading reading,
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
  required AppPreferences prefs,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      ListTile(
        title: Text(
          formatStoredMeterForDisplay(
            context,
            reading.value,
            usesHorometer: usesHorometer,
            distanceUnit: distanceUnit,
          ),
        ),
        subtitle: FutureBuilder<String>(
          future: meterReadingRoleLabel(
            l10n: l10n,
            prefs: prefs,
            reading: reading,
            repo: VehiclesRepository(AppDatabase.processScope),
          ),
          builder: (context, snap) => Text(snap.data ?? ''),
        ),
      ),
      if (formatMeterReadingTankStateLabel(reading).isNotEmpty)
        ListTile(
          title: Text(l10n.vehicleFuelTankState),
          subtitle: Text(formatMeterReadingTankStateLabel(reading)),
        ),
      if (meterReadingHasDisplayablePhoto(reading.photoPath))
        Padding(
          padding: const EdgeInsets.all(16),
          child: VehicleStoredImage(path: reading.photoPath),
        ),
    ],
  );
}