import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../debug/qa_vehicle_semantics.dart';
import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../util/display_date.dart';
import '../../util/display_units.dart';
import '../../util/product_legal_urls.dart';
import '../../util/vehicle_meter_display.dart';
import '../../vehicle/vehicle_consumption_metrics.dart';
import '../../vehicle/vehicle_consumption_estimation_mode.dart';
import '../../vehicle/vehicle_consumption_reliability.dart';
import '../../vehicle/vehicle_consumption_reliability_l10n.dart';
import '../../vehicle/vehicle_fuel_tank_estimate.dart';
import '../../vehicle/vehicle_kind.dart';
import '../../vehicle/vehicle_maintenance_categories.dart';
import '../../vehicle/vehicle_maintenance_alerts.dart';
import '../../vehicle/vehicle_module_access.dart';
import '../../vehicle/vehicle_module_exit.dart';
import '../../vehicle/vehicle_owned_active_cap.dart';
import '../../vehicle/vehicle_usage_context.dart';
import '../../widgets/screen_body_padding.dart';

class VehicleModuleHubScreen extends StatefulWidget {
  const VehicleModuleHubScreen({super.key, required this.prefs});

  final AppPreferences prefs;

  @override
  State<VehicleModuleHubScreen> createState() =>
      _VehicleModuleHubScreenState();
}

class _VehicleModuleHubScreenState extends State<VehicleModuleHubScreen> {
  final _access = const VehicleModuleAccess();
  late final VehiclesRepository _repo =
      VehiclesRepository(AppDatabase.processScope);
  List<Vehicle> _vehicles = const [];
  VehicleUse? _openUse;
  bool _loading = true;
  bool _entitled = false;
  int _cardReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    final entitled = await _access.refreshAndHasVehicleEntitlement();
    if (!mounted) return;
    if (!entitled) {
      setState(() {
        _entitled = false;
        _loading = false;
      });
      return;
    }
    final vehicles = await _repo.listOwnedVehicles();
    final anyOpen = await _repo.findAnyOpenUse();
    // Propriétaire hub: only an open use attributed to self is "mine to end".
    // An Emprunteur session must not switch the chip to Terminer.
    final ownOpen = canEndUseSessionAsActor(
      openUse: anyOpen,
      context: const VehicleUsageContext.owner(),
    )
        ? anyOpen
        : null;
    if (!mounted) return;
    setState(() {
      _entitled = true;
      _vehicles = vehicles;
      _openUse = ownOpen;
      _loading = false;
      _cardReloadToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.homeModuleVehicle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_entitled) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.homeModuleVehicle)),
        body: Center(child: Text(l10n.vehicleLicensingRequired)),
      );
    }
    final dateFmt = effectiveDateFormat(widget.prefs);
    final sessionStartedLine = _openUse == null
        ? null
        : l10n.vehicleUseSessionStartedOn(
            formatPreferenceDateTime(_openUse!.startedAt, dateFmt),
          );
    final activeCount =
        _vehicles.where(vehicleIsActive).length;
    final atActiveCap = activeCount >= kMaxActiveOwnedVehicles;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => exitVehicleModule(context)),
        title: Text(l10n.homeModuleVehicle),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: l10n.vehicleStatisticsTitle,
            onPressed: () => context.push('/vehicle/statistics'),
          ),
        ],
      ),
      floatingActionButton: atActiveCap
          ? null
          : qaVehicleSemantics(
              identifier: kQaVehicleAddFab,
              child: FloatingActionButton.extended(
                onPressed: () async {
                  final created = await context.push<bool>('/vehicle/add');
                  if (created == true) _reload();
                },
                icon: const Icon(Icons.add),
                label: Text(l10n.vehicleAddVehicle),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: qaVehicleSemantics(
                identifier: kQaVehicleHub,
                child: ListView(
                  padding: screenBodyScrollPadding(context),
                  children: [
                  Text(
                    l10n.vehicleQuickActionsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _QuickActionsRow(
                    sessionOpen: _openUse != null,
                    sessionPrimaryLabel: _openUse == null
                        ? l10n.vehicleUseSessionStartAction
                        : l10n.vehicleUseSessionEndAction,
                    sessionSecondaryLine: sessionStartedLine,
                    onSession: () => _launchQuickAction('odometer'),
                    onFuel: () => _launchQuickAction('fuel'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.vehicleMyVehiclesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_vehicles.isEmpty)
                    Text(
                      l10n.vehicleMyVehiclesEmpty,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ..._vehicles.map(
                      (v) => _VehicleCard(
                        key: ValueKey('${v.id}-$_cardReloadToken'),
                        vehicle: v,
                        repo: _repo,
                        prefs: widget.prefs,
                        onTap: () async {
                          await context.push('/vehicle/${v.id}');
                          _reload();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _launchQuickAction(String kind) async {
    final active = _vehicles.where(vehicleIsActive).toList();
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).vehicleAddFirst)),
      );
      return;
    }
    final path = switch (kind) {
      'odometer' => _openUse == null
          ? '/vehicle/use-session'
          : '/vehicle/use-session?vehicleId=${Uri.encodeComponent(_openUse!.vehicleId)}',
      'fuel' => '/vehicle/fuel-purchase',
      _ => '/vehicle',
    };
    await context.push(path);
    _reload();
  }
}
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.sessionOpen,
    required this.sessionPrimaryLabel,
    required this.sessionSecondaryLine,
    required this.onSession,
    required this.onFuel,
  });

  final bool sessionOpen;
  final String sessionPrimaryLabel;
  final String? sessionSecondaryLine;
  final VoidCallback onSession;
  final VoidCallback onFuel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.speed_outlined, size: 18),
          label: qaVehicleSemantics(
            identifier: sessionOpen
                ? kQaVehicleQuickActionSessionEnd
                : kQaVehicleQuickActionSessionStart,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sessionPrimaryLabel),
                if (sessionSecondaryLine != null)
                  Text(
                    sessionSecondaryLine!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          onPressed: onSession,
        ),
        ActionChip(
          avatar: const Icon(Icons.local_gas_station_outlined, size: 18),
          label: qaVehicleSemantics(
            identifier: kQaVehicleQuickActionFuel,
            child: Text(l10n.vehicleQuickActionFuel),
          ),
          onPressed: onFuel,
        ),
      ],
    );
  }
}

class _VehicleCard extends StatefulWidget {
  const _VehicleCard({
    super.key,
    required this.vehicle,
    required this.repo,
    required this.prefs,
    required this.onTap,
  });

  final Vehicle vehicle;
  final VehiclesRepository repo;
  final AppPreferences prefs;
  final VoidCallback onTap;

  @override
  State<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<_VehicleCard> {
  late Future<_VehicleCardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  @override
  void didUpdateWidget(covariant _VehicleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicle.id != widget.vehicle.id ||
        oldWidget.repo != widget.repo) {
      _dataFuture = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_VehicleCardData>(
      future: _dataFuture,
      builder: (context, snap) {
        final data = snap.data;
        final l10n = AppLocalizations.of(context);
        final kind = VehicleKind.fromWire(widget.vehicle.vehicleKind);
        final usesHorometer = kind?.usesHorometer ?? false;
        final distanceUnit = resolveDistanceUnit(widget.prefs);
        final liquidUnit = resolveLiquidVolumeUnit(widget.prefs);
        final locale = Localizations.localeOf(context).toString();
        return qaVehicleSemantics(
          identifier: qaVehicleCardSemanticsId(widget.vehicle.displayLabel),
          child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.vehicle.displayLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!vehicleIsActive(widget.vehicle)) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.vehicleDeactivatedLabel(
                        formatPreferenceDate(
                          widget.vehicle.deactivatedAt!,
                          effectiveDateFormat(widget.prefs),
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (snap.hasError)
                    const SizedBox.shrink()
                  else if (data != null) ...[
                    Builder(
                      builder: (context) {
                        final meterDisplay = formatStoredMeterForDisplay(
                          context,
                          data.meterValue,
                          usesHorometer: usesHorometer,
                          distanceUnit: distanceUnit,
                        );
                        return qaVehicleSemantics(
                          identifier: qaVehicleCardMeterSemanticsId(
                            widget.vehicle.displayLabel,
                          ),
                          label: meterDisplay,
                          child: Text(
                            meterDisplay,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        );
                      },
                    ),
                    if (data.fuelTankLabel(l10n, locale, liquidUnit).isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final fuelTankLabel = data.fuelTankLabel(
                                  l10n,
                                  locale,
                                  liquidUnit,
                                );
                                return qaVehicleSemantics(
                                  identifier: qaVehicleCardFuelTankSemanticsId(
                                    widget.vehicle.displayLabel,
                                  ),
                                  label: fuelTankLabel,
                                  child: Text(
                                    fuelTankLabel,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            tooltip: l10n.vehicleFuelTankInfoTooltip,
                            onPressed: () {
                              final locale = Localizations.localeOf(context);
                              unawaited(
                                launchUrl(
                                  vehicleModuleFaqUrlForLocale(
                                    locale,
                                    fragment: ProductFaqAnchors.vehicleFuelTank,
                                  ),
                                  mode: LaunchMode.externalApplication,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    if (data.consumptionReliabilityMessage(l10n).isNotEmpty)
                      Builder(
                        builder: (context) {
                          final reliabilityMessage =
                              data.consumptionReliabilityMessage(l10n);
                          return qaVehicleSemantics(
                            identifier:
                                kQaVehicleCardQaCivicConsumptionReliability,
                            label: reliabilityMessage,
                            child: Text(
                              reliabilityMessage,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontStyle: data.consumption.reliability ==
                                            VehicleConsumptionReliability
                                                .preliminary
                                        ? FontStyle.italic
                                        : null,
                                  ),
                            ),
                          );
                        },
                      ),
                    if (data
                        .consumptionLabel(
                          l10n,
                          liquidUnit: liquidUnit,
                          distanceUnit: distanceUnit,
                        )
                        .isNotEmpty)
                      Builder(
                        builder: (context) {
                          final consumptionLabel = data.consumptionLabel(
                            l10n,
                            liquidUnit: liquidUnit,
                            distanceUnit: distanceUnit,
                          );
                          return qaVehicleSemantics(
                            identifier: kQaVehicleCardQaCivicConsumption,
                            label: consumptionLabel,
                            child: Text(
                              consumptionLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    if (data.alerts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: data.alerts
                            .map(
                              (a) => Chip(
                                backgroundColor: a.isDueNow
                                    ? Theme.of(context)
                                        .colorScheme
                                        .errorContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                label: Text(
                                  l10n.vehicleMaintenanceAlertTile(
                                    vehicleMaintenanceCategoryLabel(
                                      l10n,
                                      a.category,
                                    ),
                                    formatStoredMeterForDisplay(
                                      context,
                                      a.remainingAmount,
                                      usesHorometer: usesHorometer,
                                      distanceUnit: distanceUnit,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ] else
                    const SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }

  Future<_VehicleCardData> _load() async {
    final kind = VehicleKind.fromWire(widget.vehicle.vehicleKind);
    final meter =
        await widget.repo.latestMeterValue(widget.vehicle.id) ?? 0;
    try {
      final metrics = VehicleConsumptionMetrics(AppDatabase.processScope);
      final consumption = await metrics.forVehicle(widget.vehicle.id);
      final alerts = await VehicleMaintenanceAlerts(AppDatabase.processScope)
          .alertsForVehicle(widget.vehicle.id, currentMeter: meter);
      final fuelTank = await VehicleFuelTankEstimate(AppDatabase.processScope)
          .forVehicle(widget.vehicle.id);
      return _VehicleCardData(
        meterValue: meter,
        consumption: consumption,
        alerts: alerts,
        fuelTank: fuelTank,
        kind: kind,
        estimationMode: VehicleConsumptionEstimationMode.fromWire(
          widget.vehicle.consumptionEstimationMode,
        ),
      );
    } catch (_) {
      return _VehicleCardData(
        meterValue: meter,
        consumption: const VehicleConsumptionSnapshot(hasSufficientData: false),
        alerts: const [],
        fuelTank: null,
        kind: kind,
        estimationMode: VehicleConsumptionEstimationMode.fromWire(
          widget.vehicle.consumptionEstimationMode,
        ),
      );
    }
  }
}

class _VehicleCardData {
  const _VehicleCardData({
    required this.meterValue,
    required this.consumption,
    required this.alerts,
    required this.fuelTank,
    required this.kind,
    required this.estimationMode,
  });

  final int meterValue;
  final VehicleConsumptionSnapshot consumption;
  final List<VehicleMaintenanceAlert> alerts;
  final VehicleFuelTankSnapshot? fuelTank;
  final VehicleKind? kind;
  final VehicleConsumptionEstimationMode estimationMode;

  String fuelTankLabel(
    AppLocalizations l10n,
    String locale,
    LiquidVolumeUnit liquidUnit,
  ) {
    final snapshot = fuelTank;
    if (snapshot == null) return '';
    final volume = formatLiquidVolumeForDisplay(
      snapshot.volumeLiters,
      unit: liquidUnit,
      locale: locale,
    );
    return l10n.vehicleFuelTankInTank(volume);
  }

  String consumptionReliabilityMessage(AppLocalizations l10n) {
    if (kind?.usesHorometer ?? false) return '';
    if (consumption.showInsufficientDetailedDataMessage) {
      return l10n.vehicleConsumptionInsufficientDetailedData;
    }
    if (consumption.isCarriedFromOtherMode) {
      return l10n.vehicleConsumptionCarriedFromDetailedMode;
    }
    return consumption.reliability.message(l10n);
  }

  String consumptionLabel(
    AppLocalizations l10n, {
    required LiquidVolumeUnit liquidUnit,
    required DistanceUnit distanceUnit,
  }) {
    final volumeAbbrev = liquidVolumeUnitAbbrev(liquidUnit);
    final distanceAbbrev = distanceUnitAbbrev(distanceUnit).toLowerCase();
    if (!consumption.hasSufficientData) {
      return '';
    }
    if (kind?.usesHorometer ?? false) {
      final v = consumption.litersPerHour;
      if (v == null) return '';
      final display = litersPerHourToDisplay(v, volumeUnit: liquidUnit);
      return l10n.vehicleConsumptionPerHour(
        display.toStringAsFixed(2),
        volumeAbbrev,
      );
    }
    if (consumption.hasModeBreakdown &&
        estimationMode == VehicleConsumptionEstimationMode.detailed) {
      final route = consumption.litersPer100KmRoute;
      final city = consumption.litersPer100KmCity;
      final traffic = consumption.litersPer100KmTraffic;
      if (route == null || city == null || traffic == null) return '';
      String per100(double litersPer100Km) {
        final display = litersPer100KmToDisplay(
          litersPer100Km,
          volumeUnit: liquidUnit,
          distanceUnit: distanceUnit,
        );
        return l10n.vehicleConsumptionPer100Km(
          display.toStringAsFixed(1),
          volumeAbbrev,
          distanceAbbrev,
        );
      }

      return '${l10n.vehicleDrivingConditionRoute}: ${per100(route)}\n'
          '${l10n.vehicleDrivingConditionCity}: ${per100(city)}\n'
          '${l10n.vehicleDrivingConditionTraffic}: ${per100(traffic)}';
    }
    final v = consumption.litersPer100Km;
    if (v == null) return '';
    final display = litersPer100KmToDisplay(
      v,
      volumeUnit: liquidUnit,
      distanceUnit: distanceUnit,
    );
    return l10n.vehicleConsumptionSimpleEstimate(
      display.toStringAsFixed(1),
      volumeAbbrev,
      distanceAbbrev,
    );
  }
}
