import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../util/display_date.dart';
import '../../util/display_units.dart';
import '../../util/vehicle_meter_display.dart';
import '../../vehicle/vehicle_consumption_metrics.dart';
import '../../vehicle/vehicle_consumption_reliability.dart';
import '../../vehicle/vehicle_consumption_reliability_l10n.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../widgets/screen_body_padding.dart';

class VehicleStatisticsScreen extends StatefulWidget {
  const VehicleStatisticsScreen({super.key, required this.prefs});

  final AppPreferences prefs;

  @override
  State<VehicleStatisticsScreen> createState() =>
      _VehicleStatisticsScreenState();
}

class _VehicleStatisticsScreenState extends State<VehicleStatisticsScreen> {
  List<Vehicle> _vehicles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vehicles =
        await VehiclesRepository(AppDatabase.processScope).listOwnedVehicles();
    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFmt = widget.prefs.dateFormat;
    final metrics = VehicleConsumptionMetrics(AppDatabase.processScope);
    final repo = VehiclesRepository(AppDatabase.processScope);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleStatisticsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: screenBodyScrollPadding(context),
              children: [
                Text(
                  l10n.vehicleStatisticsMileageTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_vehicles.isEmpty)
                  Text(l10n.vehicleMyVehiclesEmpty)
                else
                  ..._vehicles.map((v) {
                    return FutureBuilder<int>(
                      future: metrics.totalLifetimeUsage(v.id),
                      builder: (context, snap) {
                        final kind = VehicleKind.fromWire(v.vehicleKind);
                        final total = snap.data;
                        final display = total == null
                            ? '…'
                            : formatStoredMeterDeltaForDisplay(
                                context,
                                total,
                                usesHorometer:
                                    kind?.usesHorometer ?? false,
                                distanceUnit: resolveDistanceUnit(
                                  widget.prefs,
                                ),
                              );
                        return ListTile(
                          title: Text(v.displayLabel),
                          subtitle: Text(display),
                        );
                      },
                    );
                  }),
                const Divider(height: 32),
                Text(
                  l10n.vehicleStatisticsConsumptionHistoryTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_vehicles.isEmpty)
                  Text(l10n.vehicleMyVehiclesEmpty)
                else
                  ..._vehicles.where((v) {
                    final kind = VehicleKind.fromWire(v.vehicleKind);
                    return !(kind?.usesHorometer ?? false);
                  }).map((v) {
                    return FutureBuilder<List<VehicleConsumptionEstimateHistoryData>>(
                      future: metrics.listReliableEstimateHistory(v.id),
                      builder: (context, snap) {
                        final entries = snap.data;
                        final distanceUnit =
                            resolveDistanceUnit(widget.prefs);
                        final liquidUnit =
                            resolveLiquidVolumeUnit(widget.prefs);
                        final volumeAbbrev =
                            liquidVolumeUnitAbbrev(liquidUnit);
                        final distanceAbbrev =
                            distanceUnitAbbrev(distanceUnit).toLowerCase();
                        String formatPer100(double litersPer100Km) {
                          final display = litersPer100KmToDisplay(
                            litersPer100Km,
                            volumeUnit: liquidUnit,
                            distanceUnit: distanceUnit,
                          );
                          return display.toStringAsFixed(1);
                        }

                        if (entries == null) {
                          return ListTile(title: Text(v.displayLabel));
                        }
                        if (entries.isEmpty) {
                          return ListTile(
                            title: Text(v.displayLabel),
                            subtitle: Text(
                              l10n.vehicleConsumptionReliabilityNone,
                            ),
                          );
                        }
                        return ExpansionTile(
                          title: Text(v.displayLabel),
                          children: entries.map((entry) {
                            final date = formatPreferenceDateTime(
                              entry.anchorEndAt,
                              dateFmt,
                            );
                            final blended = formatPer100(entry.litersPer100Km);
                            final lines = <String>[
                              l10n.vehicleConsumptionHistoryBlended(
                                date,
                                blended,
                                volumeAbbrev,
                                distanceAbbrev,
                              ),
                            ];
                            final route = entry.litersPer100KmRoute;
                            final city = entry.litersPer100KmCity;
                            final traffic = entry.litersPer100KmTraffic;
                            if (route != null &&
                                city != null &&
                                traffic != null) {
                              lines.add(
                                '${l10n.vehicleDrivingConditionRoute}: '
                                '${l10n.vehicleConsumptionPer100Km(formatPer100(route), volumeAbbrev, distanceAbbrev)}',
                              );
                              lines.add(
                                '${l10n.vehicleDrivingConditionCity}: '
                                '${l10n.vehicleConsumptionPer100Km(formatPer100(city), volumeAbbrev, distanceAbbrev)}',
                              );
                              lines.add(
                                '${l10n.vehicleDrivingConditionTraffic}: '
                                '${l10n.vehicleConsumptionPer100Km(formatPer100(traffic), volumeAbbrev, distanceAbbrev)}',
                              );
                            }
                            final reliability =
                                VehicleConsumptionReliability.fromWire(
                              entry.reliability,
                            );
                            if (reliability != null) {
                              lines.add(reliability.message(l10n));
                            }
                            return ListTile(
                              title: Text(lines.first),
                              subtitle: lines.length > 1
                                  ? Text(lines.sublist(1).join('\n'))
                                  : null,
                              isThreeLine: lines.length > 2,
                            );
                          }).toList(),
                        );
                      },
                    );
                  }),
                const Divider(height: 32),
                Text(
                  l10n.vehicleStatisticsExpensesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ..._vehicles.map((v) {
                  return FutureBuilder<_ExpenseTotals>(
                    future: _expenseTotals(repo, v.id),
                    builder: (context, snap) {
                      final t = snap.data;
                      if (t == null) {
                        return ListTile(title: Text(v.displayLabel));
                      }
                      return ListTile(
                        title: Text(v.displayLabel),
                        subtitle: Text(
                          '${l10n.vehicleExpenseFuel}: ${t.fuel}\n'
                          '${l10n.vehicleExpenseMaintenance}: ${t.maintenance}\n'
                          '${l10n.vehicleExpenseViolations}: ${t.violations}',
                        ),
                        isThreeLine: true,
                      );
                    },
                  );
                }),
              ],
            ),
    );
  }

  Future<_ExpenseTotals> _expenseTotals(
    VehiclesRepository repo,
    String vehicleId,
  ) async {
    final fuel = await repo.listFuelPurchases(vehicleId);
    final maint = await repo.listMaintenanceEvents(vehicleId);
    final viol = await repo.listViolations(vehicleId);
    var sumFuel = 0;
    for (final f in fuel) {
      sumFuel += f.costMinor;
    }
    var sumMaint = 0;
    for (final m in maint) {
      sumMaint += m.costMinor;
    }
    var sumViol = 0;
    for (final v in viol) {
      sumViol += v.amountMinor;
    }
    return _ExpenseTotals(
      fuel: (sumFuel / 100).toStringAsFixed(2),
      maintenance: (sumMaint / 100).toStringAsFixed(2),
      violations: (sumViol / 100).toStringAsFixed(2),
    );
  }
}

class _ExpenseTotals {
  const _ExpenseTotals({
    required this.fuel,
    required this.maintenance,
    required this.violations,
  });

  final String fuel;
  final String maintenance;
  final String violations;
}
