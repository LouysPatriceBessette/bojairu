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
import '../../vehicle/vehicle_gap_correction.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../util/format_money.dart';
import '../../vehicle/vehicle_fuel_log_display.dart';
import '../../vehicle/vehicle_meter_reading_labels.dart';
import '../../vehicle/vehicle_meter_photo_path.dart';
import '../../vehicle/vehicle_stored_image.dart';
import '../../widgets/screen_body_padding.dart';

class VehicleMeterLogScreen extends StatelessWidget {
  const VehicleMeterLogScreen({
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
      appBar: AppBar(title: Text(l10n.vehicleLogMeterTitle)),
      body: FutureBuilder<(Vehicle?, List<VehicleMeterReading>)>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final vehicle = snap.data!.$1;
          final rows = snap.data!.$2;
          if (rows.isEmpty) {
            return Center(child: Text(l10n.vehicleJournalEmpty));
          }
          final kind = VehicleKind.fromWire(vehicle?.vehicleKind);
          final usesHorometer = kind?.usesHorometer ?? false;
          return ListView.separated(
            padding: screenBodyScrollPadding(context),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              final date = formatPreferenceDateTime(row.recordedAt, dateFmt);
              final meter = formatStoredMeterForDisplay(
                context,
                row.value,
                usesHorometer: usesHorometer,
                distanceUnit: distanceUnit,
              );
              return ListTile(
                title: Text(meter),
                subtitle: Text(date),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '/vehicle/$vehicleId/meter-log/${row.id}',
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<(Vehicle?, List<VehicleMeterReading>)> _load() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final vehicle = await repo.getVehicle(vehicleId);
    final rows = (await repo.listMeterReadings(vehicleId))
        .where(isMeterReadingShownInJournal)
        .toList();
    return (vehicle, rows);
  }
}

class VehicleMeterReadingDetailScreen extends StatelessWidget {
  const VehicleMeterReadingDetailScreen({
    super.key,
    required this.vehicleId,
    required this.readingId,
    required this.prefs,
  });

  final String vehicleId;
  final String readingId;
  final AppPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<_MeterReadingDetailData?>(
      future: _load(l10n),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.vehicleLogMeterDetailTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.vehicleLogMeterDetailTitle)),
            body: Center(child: Text(l10n.vehicleUsageBlockedVehicleNotFound)),
          );
        }
        final dateFmt = effectiveDateFormat(prefs);
        final distanceUnit = resolveDistanceUnit(prefs);
        final meterLabel = data.usesHorometer
            ? l10n.vehicleHorometerLabel
            : l10n.vehicleOdometerLabel;
        final date = formatPreferenceDateTime(data.reading.recordedAt, dateFmt);
        final meter = formatStoredMeterForDisplay(
          context,
          data.reading.value,
          usesHorometer: data.usesHorometer,
          distanceUnit: distanceUnit,
        );
        final applied = decodeAppliedGapCorrectionNote(data.reading.correctionNote);
        final isApplied = applied != null;
        final correctionLabel = data.correctionGapTenths == null
            ? null
            : data.appliedSplit
                ? l10n.vehicleLogCorrectionAppliedSplitSummary(
                    formatStoredMeterDeltaForDisplay(
                      context,
                      data.correctionGapTenths!,
                      usesHorometer: data.usesHorometer,
                      distanceUnit: distanceUnit,
                    ),
                  )
                : data.appliedAttributionName != null
                    ? l10n.vehicleLogCorrectionAppliedSummary(
                        formatStoredMeterDeltaForDisplay(
                          context,
                          data.correctionGapTenths!,
                          usesHorometer: data.usesHorometer,
                          distanceUnit: distanceUnit,
                        ),
                        data.appliedAttributionName!,
                      )
                    : data.isPendingVerification
                        ? pendingGapCorrectionSummaryLabel(
                            l10n: l10n,
                            gapDisplay: formatStoredMeterDeltaForDisplay(
                              context,
                              data.correctionGapTenths!,
                              usesHorometer: data.usesHorometer,
                              distanceUnit: distanceUnit,
                            ),
                            gapTenths: data.correctionGapTenths!,
                          )
                        : null;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.vehicleLogMeterDetailTitle)),
          body: ListView(
            padding: screenBodyScrollPadding(context),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  date,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                title: Text(l10n.vehicleLogReadingRole),
                subtitle: Text(data.roleLabel),
              ),
              if (correctionLabel != null)
                ListTile(
                  title: Text(l10n.vehicleLogCorrectionLabel),
                  subtitle: Text(correctionLabel),
                ),
              if (isApplied &&
                  data.appliedDivergenceTenths != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.vehicleLogCorrectionAppliedDivergence(
                      formatStoredMeterDeltaForDisplay(
                        context,
                        data.appliedDivergenceTenths!,
                        usesHorometer: data.usesHorometer,
                        distanceUnit: distanceUnit,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (!isApplied) ...[
                ListTile(
                  title: Text(meterLabel),
                  subtitle: Text(meter),
                ),
                if (formatMeterReadingTankStateLabel(data.reading).isNotEmpty)
                  ListTile(
                    title: Text(l10n.vehicleFuelTankState),
                    subtitle:
                        Text(formatMeterReadingTankStateLabel(data.reading)),
                  ),
                ..._meterReadingPhotoSection(
                  context: context,
                  l10n: l10n,
                  reading: data.reading,
                  usesHorometer: data.usesHorometer,
                ),
              ],
              if (isApplied && data.appliedPreviousReading != null) ...[
                const Divider(height: 24),
                _appliedContextReadingSection(
                  context: context,
                  l10n: l10n,
                  title: l10n.vehicleGapResolutionPreviousReading,
                  roleLabel: data.appliedPreviousRoleLabel ?? '—',
                  reading: data.appliedPreviousReading!,
                  usesHorometer: data.usesHorometer,
                  distanceUnit: distanceUnit,
                  dateFmt: dateFmt,
                ),
              ],
              if (isApplied && data.appliedTriggerReading != null) ...[
                const Divider(height: 24),
                _appliedContextReadingSection(
                  context: context,
                  l10n: l10n,
                  title: l10n.vehicleGapResolutionTriggerReading,
                  roleLabel: data.appliedTriggerRoleLabel ?? '—',
                  reading: data.appliedTriggerReading!,
                  usesHorometer: data.usesHorometer,
                  distanceUnit: distanceUnit,
                  dateFmt: dateFmt,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<_MeterReadingDetailData?> _load(AppLocalizations l10n) async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final vehicle = await repo.getVehicle(vehicleId);
    final reading = await repo.getMeterReading(readingId);
    if (vehicle == null || reading == null) return null;
    final kind = VehicleKind.fromWire(vehicle.vehicleKind);
    final usesHorometer = kind?.usesHorometer ?? false;
    final roleLabel = await meterReadingRoleLabel(
      l10n: l10n,
      prefs: prefs,
      reading: reading,
      repo: repo,
    );
    final decoded = decodeGapCorrectionNote(reading.correctionNote);
    final applied = decodeAppliedGapCorrectionNote(reading.correctionNote);
    int? verificationGapTenths;
    if (isGapVerificationCorrectionReading(reading)) {
      final gap = await repo.getOdometerGapByCorrectionReadingId(reading.id);
      verificationGapTenths = gap?.gapAmount ?? decoded?.gapTenths;
    }
    String? appliedAttributionName;
    VehicleMeterReading? appliedPrevious;
    VehicleMeterReading? appliedTrigger;
    String? appliedPreviousRoleLabel;
    String? appliedTriggerRoleLabel;
    int? appliedDivergenceTenths;
    if (applied != null &&
        applied.attributedContactId != 'split' &&
        applied.attributedContactId.isNotEmpty) {
      appliedAttributionName = await resolveVehicleContactDisplayName(
        applied.attributedContactId,
        prefs: prefs,
        l10n: l10n,
      );
    }
    if (applied != null) {
      appliedPrevious = await repo.getMeterReading(applied.previousReadingId);
      appliedTrigger = await repo.getMeterReading(applied.triggerReadingId);
      if (appliedPrevious != null && appliedTrigger != null) {
        appliedDivergenceTenths = appliedTrigger.value - appliedPrevious.value;
        appliedPreviousRoleLabel = await meterReadingRoleLabel(
          l10n: l10n,
          prefs: prefs,
          reading: appliedPrevious,
          repo: repo,
        );
        appliedTriggerRoleLabel = await meterReadingRoleLabel(
          l10n: l10n,
          prefs: prefs,
          reading: appliedTrigger,
          repo: repo,
        );
      }
    }
    return _MeterReadingDetailData(
      reading: reading,
      roleLabel: roleLabel,
      usesHorometer: usesHorometer,
      correctionGapTenths: applied?.kmAppliedTenths ?? verificationGapTenths,
      appliedAttributionName: appliedAttributionName,
      appliedSplit: applied?.attributedContactId == 'split',
      isPendingVerification: isGapVerificationCorrectionReading(reading),
      appliedPreviousReading: appliedPrevious,
      appliedTriggerReading: appliedTrigger,
      appliedPreviousRoleLabel: appliedPreviousRoleLabel,
      appliedTriggerRoleLabel: appliedTriggerRoleLabel,
      appliedDivergenceTenths: appliedDivergenceTenths,
    );
  }
}

List<Widget> _meterReadingPhotoSection({
  required BuildContext context,
  required AppLocalizations l10n,
  required VehicleMeterReading reading,
  required bool usesHorometer,
}) {
  if (isKnownUnchangedMeterPhotoPath(reading.photoPath)) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          l10n.vehicleOdometerPhotoLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text(
          usesHorometer
              ? l10n.vehicleMeterKnownUnchangedNoPhotoHorometer
              : l10n.vehicleMeterKnownUnchangedNoPhotoOdometer,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ];
  }
  if (!meterReadingHasDisplayablePhoto(reading.photoPath)) {
    return [];
  }
  return [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        l10n.vehicleOdometerPhotoLabel,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
    Padding(
      padding: const EdgeInsets.all(16),
      child: VehicleStoredImage(path: reading.photoPath),
    ),
  ];
}

Widget _appliedContextReadingSection({
  required BuildContext context,
  required AppLocalizations l10n,
  required String title,
  required String roleLabel,
  required VehicleMeterReading reading,
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
  required String dateFmt,
}) {
  final meter = formatStoredMeterForDisplay(
    context,
    reading.value,
    usesHorometer: usesHorometer,
    distanceUnit: distanceUnit,
  );
  final date = formatPreferenceDateTime(reading.recordedAt, dateFmt);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      ListTile(
        title: Text(roleLabel),
        subtitle: Text('$meter · $date'),
      ),
      ..._meterReadingPhotoSection(
        context: context,
        l10n: l10n,
        reading: reading,
        usesHorometer: usesHorometer,
      ),
    ],
  );
}

class _MeterReadingDetailData {
  const _MeterReadingDetailData({
    required this.reading,
    required this.roleLabel,
    required this.usesHorometer,
    this.correctionGapTenths,
    this.appliedAttributionName,
    this.appliedSplit = false,
    this.isPendingVerification = false,
    this.appliedPreviousReading,
    this.appliedTriggerReading,
    this.appliedPreviousRoleLabel,
    this.appliedTriggerRoleLabel,
    this.appliedDivergenceTenths,
  });

  final VehicleMeterReading reading;
  final String roleLabel;
  final bool usesHorometer;
  final int? correctionGapTenths;
  final String? appliedAttributionName;
  final bool appliedSplit;
  final bool isPendingVerification;
  final VehicleMeterReading? appliedPreviousReading;
  final VehicleMeterReading? appliedTriggerReading;
  final String? appliedPreviousRoleLabel;
  final String? appliedTriggerRoleLabel;
  final int? appliedDivergenceTenths;
}

class VehicleFuelLogScreen extends StatelessWidget {
  const VehicleFuelLogScreen({
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleLogFuelTitle)),
      body: FutureBuilder<List<FuelPurchase>>(
        future: VehiclesRepository(AppDatabase.processScope)
            .listFuelPurchases(vehicleId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return Center(child: Text(l10n.vehicleJournalEmpty));
          }
          return ListView.separated(
            padding: screenBodyScrollPadding(context),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              final date = formatPreferenceDateTime(row.purchasedAt, dateFmt);
              final cost = formatMinorAsMoney(context, row.costMinor, row.currency);
              return ListTile(
                title: Text(cost),
                subtitle: Text(date),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '/vehicle/$vehicleId/fuel-log/${row.id}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VehicleFuelPurchaseDetailScreen extends StatelessWidget {
  const VehicleFuelPurchaseDetailScreen({
    super.key,
    required this.vehicleId,
    required this.purchaseId,
    required this.prefs,
  });

  final String vehicleId;
  final String purchaseId;
  final AppPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<_FuelPurchaseDetailData?>(
      future: _load(l10n),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.vehicleLogFuelDetailTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data;
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.vehicleLogFuelDetailTitle)),
            body: Center(child: Text(l10n.vehicleUsageBlockedVehicleNotFound)),
          );
        }
        final row = data.purchase;
        final dateFmt = effectiveDateFormat(prefs);
        final distanceUnit = resolveDistanceUnit(prefs);
        final liquidUnit = resolveLiquidVolumeUnit(prefs);
        final locale = Localizations.localeOf(context).toString();
        final date = formatPreferenceDateTime(row.purchasedAt, dateFmt);
        final cost = formatMinorAsMoney(context, row.costMinor, row.currency);
        final tankState = formatFuelTankStateLabel(row);
        final meterLabel = data.usesHorometer
            ? l10n.vehicleHorometerLabel
            : l10n.vehicleOdometerLabel;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.vehicleLogFuelDetailTitle)),
          body: ListView(
            padding: screenBodyScrollPadding(context),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.vehicleFuelPurchaseMadeBy(data.recordedByName),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ListTile(
                title: Text(l10n.vehicleFuelCost),
                subtitle: Text(cost),
              ),
              if (row.volumeLiters != null)
                ListTile(
                  title: Text(l10n.vehicleFuelVolume),
                  subtitle: Text(
                    formatLiquidVolumeForDisplay(
                      row.volumeLiters!,
                      unit: liquidUnit,
                      locale: locale,
                    ),
                  ),
                ),
              ListTile(
                title: Text(l10n.vehicleFuelTankState),
                subtitle: Text(tankState),
              ),
              if (row.meterReadingValue != null)
                ListTile(
                  title: Text(meterLabel),
                  subtitle: Text(
                    formatStoredMeterForDisplay(
                      context,
                      row.meterReadingValue!,
                      usesHorometer: data.usesHorometer,
                      distanceUnit: distanceUnit,
                    ),
                  ),
                ),
              if (row.meterPhotoPath != null && row.meterPhotoPath!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.vehicleOdometerPhotoLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: VehicleStoredImage(path: row.meterPhotoPath!),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<_FuelPurchaseDetailData?> _load(AppLocalizations l10n) async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final vehicle = await repo.getVehicle(vehicleId);
    final purchase = await repo.getFuelPurchase(purchaseId);
    if (vehicle == null || purchase == null) return null;
    final kind = VehicleKind.fromWire(vehicle.vehicleKind);
    final recordedByName = await resolveVehicleContactDisplayName(
      purchase.recordedByContactId,
      prefs: prefs,
      l10n: l10n,
    );
    return _FuelPurchaseDetailData(
      purchase: purchase,
      usesHorometer: kind?.usesHorometer ?? false,
      recordedByName: recordedByName,
    );
  }
}

class _FuelPurchaseDetailData {
  const _FuelPurchaseDetailData({
    required this.purchase,
    required this.usesHorometer,
    required this.recordedByName,
  });

  final FuelPurchase purchase;
  final bool usesHorometer;
  final String recordedByName;
}

class VehicleMaintenanceLogScreen extends StatelessWidget {
  const VehicleMaintenanceLogScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleLogMaintenanceTitle)),
      body: FutureBuilder<List<MaintenanceEvent>>(
        future: VehiclesRepository(AppDatabase.processScope)
            .listMaintenanceEvents(vehicleId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return Center(child: Text(l10n.vehicleJournalEmpty));
          }
          return ListView.separated(
            padding: screenBodyScrollPadding(context),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              final date = DateFormat.yMMMd().add_Hm().format(
                    row.servicedAt.toLocal(),
                  );
              return ListTile(
                title: Text(row.category),
                subtitle: Text(date),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '/vehicle/$vehicleId/maintenance-log/${row.id}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VehicleMaintenanceDetailScreen extends StatelessWidget {
  const VehicleMaintenanceDetailScreen({
    super.key,
    required this.vehicleId,
    required this.eventId,
  });

  final String vehicleId;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<MaintenanceEvent?>(
      future: VehiclesRepository(AppDatabase.processScope)
          .getMaintenanceEvent(eventId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.vehicleLogMaintenanceDetailTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final row = snap.data;
        if (row == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.vehicleLogMaintenanceDetailTitle)),
            body: Center(child: Text(l10n.vehicleUsageBlockedVehicleNotFound)),
          );
        }
        final date = DateFormat.yMMMd().add_Hm().format(row.servicedAt.toLocal());
        return Scaffold(
          appBar: AppBar(title: Text(l10n.vehicleLogMaintenanceDetailTitle)),
          body: ListView(
            padding: screenBodyScrollPadding(context),
            children: [
              ListTile(
                title: Text(l10n.vehicleMaintenanceCategory),
                subtitle: Text(row.category),
              ),
              ListTile(
                title: Text(l10n.vehicleMaintenanceCost),
                subtitle: Text('${row.costMinor / 100} ${row.currency}'),
              ),
              ListTile(
                title: Text(l10n.vehicleLogRecordedAt),
                subtitle: Text(date),
              ),
              if (row.meterAtService != null)
                ListTile(
                  title: Text(l10n.vehicleFuelMeter),
                  subtitle: Text('${row.meterAtService}'),
                ),
              if (row.notes.isNotEmpty)
                ListTile(
                  title: Text(l10n.vehicleMaintenanceNotes),
                  subtitle: Text(row.notes),
                ),
            ],
          ),
        );
      },
    );
  }
}

class VehicleViolationLogScreen extends StatelessWidget {
  const VehicleViolationLogScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleLogViolationTitle)),
      body: FutureBuilder<List<TrafficViolation>>(
        future: VehiclesRepository(AppDatabase.processScope)
            .listViolations(vehicleId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return Center(child: Text(l10n.vehicleJournalEmpty));
          }
          return ListView.separated(
            padding: screenBodyScrollPadding(context),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = rows[index];
              final date = DateFormat.yMMMd().add_Hm().format(
                    row.violatedAt.toLocal(),
                  );
              return ListTile(
                title: Text(row.violationType),
                subtitle: Text(date),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  '/vehicle/$vehicleId/violation-log/${row.id}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VehicleViolationDetailScreen extends StatelessWidget {
  const VehicleViolationDetailScreen({
    super.key,
    required this.vehicleId,
    required this.violationId,
  });

  final String vehicleId;
  final String violationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<TrafficViolation?>(
      future: VehiclesRepository(AppDatabase.processScope)
          .getTrafficViolation(violationId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.vehicleLogViolationDetailTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final row = snap.data;
        if (row == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.vehicleLogViolationDetailTitle)),
            body: Center(child: Text(l10n.vehicleUsageBlockedVehicleNotFound)),
          );
        }
        final date = DateFormat.yMMMd().add_Hm().format(row.violatedAt.toLocal());
        return Scaffold(
          appBar: AppBar(title: Text(l10n.vehicleLogViolationDetailTitle)),
          body: ListView(
            padding: screenBodyScrollPadding(context),
            children: [
              ListTile(
                title: Text(l10n.vehicleViolationType),
                subtitle: Text(row.violationType),
              ),
              ListTile(
                title: Text(l10n.vehicleViolationAmount),
                subtitle: Text('${row.amountMinor / 100} ${row.currency}'),
              ),
              ListTile(
                title: Text(l10n.vehicleLogRecordedAt),
                subtitle: Text(date),
              ),
              if (row.notes.isNotEmpty)
                ListTile(
                  title: Text(l10n.vehicleMaintenanceNotes),
                  subtitle: Text(row.notes),
                ),
            ],
          ),
        );
      },
    );
  }
}
