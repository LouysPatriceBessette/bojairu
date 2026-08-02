import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../activity/relay_activity_log_service.dart';
import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../util/display_date.dart';
import '../../util/display_units.dart';
import '../../util/format_money.dart';
import '../../util/vehicle_meter_display.dart';
import '../../vehicle/sharing/vehicle_sharing_activity_labels.dart';
import '../../vehicle/vehicle_gap_correction.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../vehicle/vehicle_meter_journal_sort.dart';
import '../../vehicle/vehicle_meter_reading_labels.dart';
import '../../widgets/screen_body_padding.dart';

enum _VehicleJournalKind {
  meterAndFuel,
  sharingSessions,
  maintenance,
  violation,
}

class VehicleJournalsScreen extends StatefulWidget {
  const VehicleJournalsScreen({
    super.key,
    required this.vehicleId,
    required this.prefs,
  });

  final String vehicleId;
  final AppPreferences prefs;

  @override
  State<VehicleJournalsScreen> createState() => _VehicleJournalsScreenState();
}

class _VehicleJournalsScreenState extends State<VehicleJournalsScreen> {
  _VehicleJournalKind _kind = _VehicleJournalKind.meterAndFuel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleJournalsTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<_VehicleJournalKind>(
              key: ValueKey(_kind),
              isExpanded: true,
              initialValue: _kind,
              decoration: InputDecoration(
                labelText: l10n.vehicleJournalSelectorLabel,
              ),
              items: [
                DropdownMenuItem(
                  value: _VehicleJournalKind.meterAndFuel,
                  child: Text(l10n.vehicleLogMeterFuelTitle),
                ),
                DropdownMenuItem(
                  value: _VehicleJournalKind.sharingSessions,
                  child: Text(l10n.vehicleLogSharingSessionsTitle),
                ),
                DropdownMenuItem(
                  value: _VehicleJournalKind.maintenance,
                  child: Text(l10n.vehicleLogMaintenanceTitle),
                ),
                DropdownMenuItem(
                  value: _VehicleJournalKind.violation,
                  child: Text(l10n.vehicleLogViolationTitle),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _kind = value);
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: switch (_kind) {
              _VehicleJournalKind.meterAndFuel => _MeterFuelJournalList(
                  vehicleId: widget.vehicleId,
                  prefs: widget.prefs,
                ),
              _VehicleJournalKind.sharingSessions => _SharingSessionsJournalList(
                  vehicleId: widget.vehicleId,
                  prefs: widget.prefs,
                ),
              _VehicleJournalKind.maintenance => _MaintenanceJournalList(
                  vehicleId: widget.vehicleId,
                ),
              _VehicleJournalKind.violation => _ViolationJournalList(
                  vehicleId: widget.vehicleId,
                ),
            },
          ),
        ],
      ),
    );
  }
}

sealed class _MeterFuelJournalRow {
  const _MeterFuelJournalRow({required this.sortAt});

  final DateTime sortAt;
}

final class _MeterFuelJournalMeterRow extends _MeterFuelJournalRow {
  _MeterFuelJournalMeterRow({
    required this.reading,
    required this.roleLabel,
    required this.isCorrectionEntry,
    required super.sortAt,
  });

  final VehicleMeterReading reading;
  final String roleLabel;
  final bool isCorrectionEntry;
}

final class _MeterFuelJournalFuelRow extends _MeterFuelJournalRow {
  _MeterFuelJournalFuelRow({
    required this.purchase,
    required super.sortAt,
  });

  final FuelPurchase purchase;
}

class _MeterFuelJournalList extends StatelessWidget {
  const _MeterFuelJournalList({
    required this.vehicleId,
    required this.prefs,
  });

  final String vehicleId;
  final AppPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<_MeterFuelJournalData?>(
      future: _load(l10n),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data;
        if (data == null || data.rows.isEmpty) {
          return Center(child: Text(l10n.vehicleJournalEmpty));
        }
        final dateFmt = effectiveDateFormat(prefs);
        final distanceUnit = resolveDistanceUnit(prefs);
        final liquidUnit = resolveLiquidVolumeUnit(prefs);
        final locale = Localizations.localeOf(context).toString();
        final bodySmall = Theme.of(context).textTheme.bodySmall;
        return ListView.separated(
          padding: screenBodyScrollPadding(context),
          itemCount: data.rows.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = data.rows[index];
            return switch (row) {
              _MeterFuelJournalMeterRow(
                :final reading,
                :final roleLabel,
                :final isCorrectionEntry,
              ) =>
                _journalTile(
                  context: context,
                  line1: formatStoredMeterForDisplay(
                    context,
                    reading.value,
                    usesHorometer: data.usesHorometer,
                    distanceUnit: distanceUnit,
                  ),
                  line2: isCorrectionEntry
                      ? l10n.vehicleLogCorrectionJournalSubtitle
                      : roleLabel,
                  line3: formatPreferenceDateTime(reading.recordedAt, dateFmt),
                  bodySmall: bodySmall,
                  highlight: isCorrectionEntry,
                  onTap: () => context.push(
                    '/vehicle/$vehicleId/meter-log/${reading.id}',
                  ),
                ),
              _MeterFuelJournalFuelRow(:final purchase) => _journalTile(
                  context: context,
                  line1: formatMinorAsMoney(
                    context,
                    purchase.costMinor,
                    purchase.currency,
                  ),
                  line2: purchase.volumeLiters == null
                      ? '—'
                      : formatLiquidVolumeForDisplay(
                          purchase.volumeLiters!,
                          unit: liquidUnit,
                          locale: locale,
                        ),
                  line3: formatPreferenceDateTime(
                    purchase.purchasedAt,
                    dateFmt,
                  ),
                  bodySmall: bodySmall,
                  onTap: () => context.push(
                    '/vehicle/$vehicleId/fuel-log/${purchase.id}',
                  ),
                ),
            };
          },
        );
      },
    );
  }

  Widget _journalTile({
    required BuildContext context,
    required String line1,
    required String line2,
    required String line3,
    required TextStyle? bodySmall,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return ColoredBox(
      color: highlight
          ? Theme.of(context).colorScheme.secondaryContainer
          : Colors.transparent,
      child: ListTile(
        title: Text(line1),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line2),
            Text(line3, style: bodySmall),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<_MeterFuelJournalData?> _load(AppLocalizations l10n) async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final vehicle = await repo.getVehicle(vehicleId);
    if (vehicle == null) return null;
    final kind = VehicleKind.fromWire(vehicle.vehicleKind);
    final usesHorometer = kind?.usesHorometer ?? false;
    final readings = await repo.listMeterReadings(vehicleId);
    final purchases = await repo.listFuelPurchases(vehicleId);
    final rows = <_MeterFuelJournalRow>[];
    for (final reading in readings) {
      if (!isMeterReadingShownInJournal(reading)) continue;
      final roleLabel = await meterReadingRoleLabel(
        l10n: l10n,
        prefs: prefs,
        reading: reading,
        repo: repo,
      );
      rows.add(
        _MeterFuelJournalMeterRow(
          reading: reading,
          roleLabel: roleLabel,
          isCorrectionEntry: isGapVerificationCorrectionReading(reading),
          sortAt: reading.recordedAt,
        ),
      );
    }
    for (final purchase in purchases) {
      rows.add(
        _MeterFuelJournalFuelRow(
          purchase: purchase,
          sortAt: purchase.purchasedAt,
        ),
      );
    }
    rows.sort(_compareMeterFuelJournalRows);
    return _MeterFuelJournalData(usesHorometer: usesHorometer, rows: rows);
  }
}

int _compareMeterFuelJournalRows(_MeterFuelJournalRow a, _MeterFuelJournalRow b) {
  final byTime = b.sortAt.compareTo(a.sortAt);
  if (byTime != 0) return byTime;
  return _meterFuelJournalRank(b).compareTo(_meterFuelJournalRank(a));
}

int _meterFuelJournalRank(_MeterFuelJournalRow row) {
  return switch (row) {
    _MeterFuelJournalFuelRow() => 5,
    _MeterFuelJournalMeterRow(:final reading) =>
      meterReadingJournalRank(reading),
  };
}

class _MeterFuelJournalData {
  const _MeterFuelJournalData({
    required this.usesHorometer,
    required this.rows,
  });

  final bool usesHorometer;
  final List<_MeterFuelJournalRow> rows;
}

class _SharingSessionsJournalList extends StatelessWidget {
  const _SharingSessionsJournalList({
    required this.vehicleId,
    required this.prefs,
  });

  final String vehicleId;
  final AppPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<RelayActivityLogEntry>>(
      future: RelayActivityLogService(AppDatabase.processScope)
          .listVehicleSharingSessionEvents(vehicleId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return Center(child: Text(l10n.vehicleJournalEmpty));
        }
        final dateFmt = effectiveDateFormat(prefs);
        final bodySmall = Theme.of(context).textTheme.bodySmall;
        return ListView.separated(
          padding: screenBodyScrollPadding(context),
          itemCount: rows.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = rows[index];
            return ListTile(
              title: Text(vehicleSharingActivityKindLabel(l10n, row.kind)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_emitterLabel(l10n, row)),
                  Text(
                    formatPreferenceDateTime(row.occurredAt, dateFmt),
                    style: bodySmall,
                  ),
                ],
              ),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }

  String _emitterLabel(AppLocalizations l10n, RelayActivityLogEntry row) {
    return switch (row.initiatorKind) {
      RelayActivityLogService.initiatorSelf =>
        row.initiatorDisplayName.trim().isNotEmpty
            ? row.initiatorDisplayName.trim()
            : (prefs.displayName.trim().isNotEmpty
                ? prefs.displayName.trim()
                : l10n.activityLogFilterInitiatorSelf),
      RelayActivityLogService.initiatorSystem =>
        l10n.activityLogFilterEmitterSystem,
      RelayActivityLogService.initiatorContact =>
        row.initiatorDisplayName.trim().isNotEmpty
            ? row.initiatorDisplayName.trim()
            : (row.initiatorContactId ??
                l10n.activityLogFilterInitiatorContact),
      _ => row.initiatorDisplayName.trim().isNotEmpty
          ? row.initiatorDisplayName.trim()
          : row.initiatorKind,
    };
  }
}

class _MaintenanceJournalList extends StatelessWidget {
  const _MaintenanceJournalList({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<MaintenanceEvent>>(
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
    );
  }
}

class _ViolationJournalList extends StatelessWidget {
  const _ViolationJournalList({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<TrafficViolation>>(
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
    );
  }
}
