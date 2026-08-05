import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../debug/qa_vehicle_semantics.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../util/display_date.dart';
import '../../util/display_units.dart';
import '../../util/format_money.dart';
import '../../vehicle/sharing/vehicle_usage_balance.dart';
import '../../vehicle/sharing/vehicle_usage_balance_service.dart';
import '../../vehicle/vehicle_owner_contact.dart';
import '../../widgets/screen_body_padding.dart';

/// Shared breakdown (or unavailable explanation) for owner and borrower.
class VehicleUsageBalanceDetailBody extends StatefulWidget {
  const VehicleUsageBalanceDetailBody({
    super.key,
    required this.link,
    required this.prefs,
  });

  final VehicleSharingLink link;
  final AppPreferences prefs;

  @override
  State<VehicleUsageBalanceDetailBody> createState() =>
      _VehicleUsageBalanceDetailBodyState();
}

class _VehicleUsageBalanceDetailBodyState
    extends State<VehicleUsageBalanceDetailBody> {
  VehicleUsageBalanceResult? _result;
  bool _loading = true;
  _UsageBalanceSection? _expandedSection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VehicleUsageBalanceDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link.id != widget.link.id) {
      _expandedSection = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await VehicleUsageBalanceService(
      VehiclesRepository(AppDatabase.processScope),
    ).computeForLink(link: widget.link);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  void _onSectionExpansionChanged(_UsageBalanceSection section, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedSection = section;
      } else if (_expandedSection == section) {
        _expandedSection = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading || _result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final result = _result!;
    if (!result.isAvailable) {
      final message =
          result.unavailableReason ==
                  VehicleUsageBalanceUnavailableReason.noAverageFuelPrice
              ? l10n.vehicleUsageBalanceUnavailableFuelPrice
              : l10n.vehicleUsageBalanceUnavailableConsumption;
      return ListView(
        padding: screenBodyScrollPadding(context),
        children: [Text(message)],
      );
    }

    final b = result.breakdown!;
    final currency = widget.prefs.currency;
    final localeName = Localizations.localeOf(context).toString();
    final dateFmt = effectiveDateFormat(widget.prefs);
    final distanceUnit = resolveDistanceUnit(widget.prefs);
    final liquidUnit = resolveLiquidVolumeUnit(widget.prefs);
    final useMiles = distanceUnit == DistanceUnit.miles;
    String money(int minor) => formatMinorAsMoney(context, minor, currency);
    String calcNumber(double value, {int? fractionDigits}) {
      final digits = fractionDigits ??
          (value == value.roundToDouble() ? 0 : 1);
      return NumberFormat.decimalPatternDigits(
        locale: localeName,
        decimalDigits: digits,
      ).format(value);
    }

    String calcMoneyMajor(double major) => NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 2,
        ).format(major);

    String calcMinorAsMajor(int minor) => calcMoneyMajor(minor / 100.0);

    final distanceDisplayKm = kmToDisplayDistance(b.distanceKm, distanceUnit);
    final distanceDisplay = calcNumber(distanceDisplayKm, fractionDigits: 1);
    final unitAbbrev = distanceUnitAbbrev(distanceUnit).toLowerCase();
    final volumeAbbrev = liquidVolumeUnitAbbrev(liquidUnit);
    final rateUnitAbbrev = distanceUnitShort(distanceUnit);
    final unitPlural = useMiles
        ? l10n.vehicleDistanceUnitMiles
        : l10n.vehicleDistanceUnitKilometres;
    final mileageTitle = useMiles
        ? l10n.vehicleUsageBalanceMyMileageMiles
        : l10n.vehicleUsageBalanceMyMileage;

    final priceDisplayMinor = pricePerLiterMinorToDisplayMinor(
      b.pricePerLiterMinor,
      volumeUnit: liquidUnit,
    );
    final priceMajor = priceDisplayMinor / 100.0;
    final ratePerDisplayUnitMinor = ratePerKmMinorToDisplay(
      b.ratePerKmMinor.toDouble(),
      distanceUnit: distanceUnit,
    );
    final rateMajor = ratePerDisplayUnitMinor / 100.0;
    final consumptionDisplay = litersPer100KmToDisplay(
      b.litersPer100Km,
      volumeUnit: liquidUnit,
      distanceUnit: distanceUnit,
    );
    final consumptionPerDisplayUnit = consumptionDisplay / 100.0;
    final rateMajorDisplay = calcMoneyMajor(rateMajor);
    final priceMoneyLabel = formatMinorAsMoney(
      context,
      priceDisplayMinor.round(),
      currency,
    );
    final signLabel = b.balanceMinor < 0
        ? l10n.vehicleUsageBalanceCreditForBorrower
        : l10n.vehicleUsageBalanceOwedToOwner;

    return ListView(
      padding: screenBodyScrollPadding(context),
      children: [
        Text(
          l10n.vehicleUsageBalanceNetLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          money(b.balanceMinor),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          signLabel,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _UsageBalanceAccordion(
          section: _UsageBalanceSection.mileage,
          expandedSection: _expandedSection,
          onExpansionChanged: _onSectionExpansionChanged,
          title: mileageTitle,
          amountLabel: l10n.vehicleUsageBalanceDistanceAmount(
            distanceDisplay,
            unitAbbrev,
          ),
          canExpand: b.distanceKm > 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.vehicleUsageBalanceMileageSessionDatesBlurb),
              const SizedBox(height: 16),
              _UsageBalanceVerticalCalc(
                lines: [
                  for (var i = 0; i < b.distanceLineItems.length; i++)
                    _CalcLine(
                      sideLabel: formatPreferenceDate(
                        b.distanceLineItems[i].at,
                        dateFmt,
                      ),
                      operator: i == 0 ? null : '+',
                      value: calcNumber(
                        kmToDisplayDistance(
                          b.distanceLineItems[i].distanceTenths / 10.0,
                          distanceUnit,
                        ),
                        fractionDigits: 1,
                      ),
                    ),
                ],
                total: distanceDisplay,
              ),
            ],
          ),
        ),
        const Divider(height: 24),
        _UsageBalanceAccordion(
          section: _UsageBalanceSection.compensation,
          expandedSection: _expandedSection,
          onExpansionChanged: _onSectionExpansionChanged,
          title: l10n.vehicleUsageBalanceCompensation,
          amountLabel: money(b.compensationMinor),
          canExpand: b.compensationMinor != 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.vehicleUsageBalanceCompensationDistanceBlurb(
                  distanceDisplay,
                  unitPlural,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.vehicleUsageBalanceCompensationRateBlurb(
                  rateMajorDisplay,
                  rateUnitAbbrev,
                ),
              ),
              const SizedBox(height: 16),
              _UsageBalanceVerticalCalc(
                lines: [
                  _CalcLine(
                    value: distanceDisplay,
                  ),
                  _CalcLine(
                    operator: '×',
                    value: rateMajorDisplay,
                  ),
                ],
                total: calcMinorAsMajor(b.compensationMinor),
              ),
            ],
          ),
        ),
        _UsageBalanceAccordion(
          section: _UsageBalanceSection.fuelUsed,
          expandedSection: _expandedSection,
          onExpansionChanged: _onSectionExpansionChanged,
          title: l10n.vehicleUsageBalanceEstimatedFuel,
          amountLabel: money(b.estimatedFuelCostMinor),
          canExpand: b.estimatedFuelCostMinor != 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.vehicleUsageBalanceFuelPriceBlurb(
                  priceMoneyLabel,
                  volumeAbbrev,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.vehicleUsageBalanceFuelConsumptionBlurb(
                  calcNumber(consumptionDisplay, fractionDigits: 1),
                  volumeAbbrev,
                  unitAbbrev,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.vehicleUsageBalanceFuelDistanceBlurb(
                  distanceDisplay,
                  unitPlural,
                ),
              ),
              const SizedBox(height: 16),
              _UsageBalanceVerticalCalc(
                lines: [
                  _CalcLine(value: calcMoneyMajor(priceMajor)),
                  _CalcLine(
                    operator: '×',
                    value: calcNumber(
                      consumptionPerDisplayUnit,
                      fractionDigits: 3,
                    ),
                  ),
                  _CalcLine(
                    operator: '×',
                    value: distanceDisplay,
                  ),
                ],
                total: calcMinorAsMajor(b.estimatedFuelCostMinor),
              ),
            ],
          ),
        ),
        _UsageBalanceAccordion(
          section: _UsageBalanceSection.fuelPurchases,
          expandedSection: _expandedSection,
          onExpansionChanged: _onSectionExpansionChanged,
          title: l10n.vehicleUsageBalanceBorrowerFuel,
          amountLabel: money(-b.borrowerFuelCostMinor),
          canExpand: b.borrowerFuelCostMinor != 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.vehicleUsageBalanceFuelPurchasesDeductedBlurb),
              const SizedBox(height: 16),
              _UsageBalanceVerticalCalc(
                lines: [
                  for (var i = 0; i < b.borrowerFuelLineItems.length; i++)
                    _CalcLine(
                      sideLabel: formatPreferenceDate(
                        b.borrowerFuelLineItems[i].at,
                        dateFmt,
                      ),
                      operator: i == 0 ? null : '+',
                      value: calcMinorAsMajor(
                        b.borrowerFuelLineItems[i].costMinor,
                      ),
                    ),
                ],
                total: calcMinorAsMajor(b.borrowerFuelCostMinor),
              ),
            ],
          ),
        ),
        _UsageBalanceAccordion(
          section: _UsageBalanceSection.maintenance,
          expandedSection: _expandedSection,
          onExpansionChanged: _onSectionExpansionChanged,
          title: l10n.vehicleUsageBalanceBorrowerMaintenance,
          amountLabel: money(-b.borrowerMaintenanceCostMinor),
          canExpand: b.borrowerMaintenanceCostMinor != 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.vehicleUsageBalanceMaintenanceDeductedBlurb),
              const SizedBox(height: 16),
              _UsageBalanceVerticalCalc(
                lines: [
                  for (var i = 0;
                      i < b.borrowerMaintenanceLineItems.length;
                      i++)
                    _CalcLine(
                      sideLabel: formatPreferenceDate(
                        b.borrowerMaintenanceLineItems[i].at,
                        dateFmt,
                      ),
                      operator: i == 0 ? null : '+',
                      value: calcMinorAsMajor(
                        b.borrowerMaintenanceLineItems[i].costMinor,
                      ),
                    ),
                ],
                total: calcMinorAsMajor(b.borrowerMaintenanceCostMinor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _UsageBalanceSection {
  mileage,
  compensation,
  fuelUsed,
  fuelPurchases,
  maintenance,
}

class _UsageBalanceAccordion extends StatelessWidget {
  const _UsageBalanceAccordion({
    required this.section,
    required this.expandedSection,
    required this.onExpansionChanged,
    required this.title,
    required this.amountLabel,
    required this.canExpand,
    required this.child,
  });

  final _UsageBalanceSection section;
  final _UsageBalanceSection? expandedSection;
  final void Function(_UsageBalanceSection section, bool expanded)
      onExpansionChanged;
  final String title;
  final String amountLabel;
  final bool canExpand;
  final Widget child;

  Widget _header(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall;
    return Row(
      children: [
        Expanded(child: Text(title, style: style)),
        const SizedBox(width: 12),
        Text(amountLabel, style: style, textAlign: TextAlign.end),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = canExpand && expandedSection == section;
    // Keep a trailing expand icon footprint when locked so amounts align.
    final trailing = canExpand
        ? null
        : Icon(
            Icons.expand_more,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0),
          );

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: IgnorePointer(
        ignoring: !canExpand,
        child: ExpansionTile(
          // Rebuild only when this tile's open state flips so siblings can
          // collapse without wiping the newly opened section.
          key: ValueKey<String>(
            'usage-balance-$section-$isExpanded',
          ),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          title: _header(context),
          trailing: trailing,
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            if (!canExpand) return;
            onExpansionChanged(section, expanded);
          },
          children: canExpand ? [child] : const <Widget>[],
        ),
      ),
    );
  }
}

class _CalcLine {
  const _CalcLine({
    this.sideLabel,
    this.operator,
    required this.value,
  });

  final String? sideLabel;
  final String? operator;
  final String value;
}

/// Centered vertical ledger: aligned operators, decimals, and separator.
class _UsageBalanceVerticalCalc extends StatelessWidget {
  const _UsageBalanceVerticalCalc({
    required this.lines,
    required this.total,
  });

  final List<_CalcLine> lines;
  final String total;

  static const double _operatorWidth = 20;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final numberStyle = theme.textTheme.bodyLarge?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontFamilyFallback: const ['Roboto Mono', 'Courier New', 'monospace'],
    );
    final operatorStyle = numberStyle?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final hasSideLabels = lines.any((l) => l.sideLabel != null);
    final maxValueLen = [
      ...lines.map((l) => l.value.length),
      total.length,
    ].reduce((a, b) => a > b ? a : b);
    // Approximate monospace width from bodyLarge size.
    final digitWidth = (numberStyle?.fontSize ?? 16) * 0.62;
    final valueWidth = maxValueLen * digitWidth + 4;

    double? labelWidth;
    if (hasSideLabels) {
      final maxLabelLen = lines
          .map((l) => l.sideLabel?.length ?? 0)
          .reduce((a, b) => a > b ? a : b);
      labelWidth = maxLabelLen * ((labelStyle?.fontSize ?? 12) * 0.55) + 8;
    }

    Widget valueCell(String text, {TextStyle? style}) {
      return SizedBox(
        width: valueWidth,
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: style ?? numberStyle,
        ),
      );
    }

    Widget operatorCell(String? op) {
      return SizedBox(
        width: _operatorWidth,
        child: Text(
          op ?? '',
          textAlign: TextAlign.center,
          style: operatorStyle,
        ),
      );
    }

    Widget row({
      required String? sideLabel,
      required String? operator,
      required String value,
      TextStyle? valueStyle,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (hasSideLabels)
              SizedBox(
                width: labelWidth,
                child: Text(
                  sideLabel ?? '',
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (hasSideLabels) const SizedBox(width: _gap),
            operatorCell(operator),
            const SizedBox(width: 4),
            valueCell(value, style: valueStyle),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            row(
              sideLabel: line.sideLabel,
              operator: line.operator,
              value: line.value,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSideLabels) SizedBox(width: labelWidth),
                if (hasSideLabels) const SizedBox(width: _gap),
                const SizedBox(width: _operatorWidth + 4),
                SizedBox(
                  width: valueWidth,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          row(
            sideLabel: null,
            operator: null,
            value: total,
            valueStyle: numberStyle?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Propriétaire: list of Emprunteurs (active + revoked) for balance drill-down.
class VehicleBorrowerBalancesScreen extends StatefulWidget {
  const VehicleBorrowerBalancesScreen({
    super.key,
    required this.vehicleId,
    required this.prefs,
  });

  final String vehicleId;
  final AppPreferences prefs;

  @override
  State<VehicleBorrowerBalancesScreen> createState() =>
      _VehicleBorrowerBalancesScreenState();
}

class _VehicleBorrowerBalancesScreenState
    extends State<VehicleBorrowerBalancesScreen> {
  List<VehicleSharingLink> _links = const [];
  Map<String, String> _names = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final links = await repo.listSharingLinksForVehicle(widget.vehicleId);
    final accepted = links.where((l) {
      final status = VehicleSharingLinkStatus.fromWire(l.status);
      return status == VehicleSharingLinkStatus.active ||
          status == VehicleSharingLinkStatus.revoked ||
          l.acceptedAt != null;
    }).toList();

    final names = <String, String>{};
    for (final link in accepted) {
      if (vehicleContactIsBorrowerSelf(link.borrowerContactId)) {
        names[link.borrowerContactId] = link.borrowerContactId;
        continue;
      }
      final contact = await ContactsRepository(AppDatabase.processScope)
          .get(link.borrowerContactId);
      names[link.borrowerContactId] =
          contact?.displayName.trim().isNotEmpty == true
              ? contact!.displayName.trim()
              : link.borrowerContactId;
    }

    if (!mounted) return;
    setState(() {
      _links = accepted;
      _names = names;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleBorrowerBalancesTitle)),
      body: qaVehicleSemantics(
        identifier: kQaVehicleBorrowerBalancesScreen,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _links.isEmpty
                ? ListView(
                    padding: screenBodyScrollPadding(context),
                    children: [Text(l10n.vehicleBorrowerBalancesEmpty)],
                  )
                : ListView.separated(
                    padding: screenBodyScrollPadding(context),
                    itemCount: _links.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final link = _links[index];
                      final revoked =
                          VehicleSharingLinkStatus.fromWire(link.status) ==
                              VehicleSharingLinkStatus.revoked;
                      final name = _names[link.borrowerContactId] ??
                          link.borrowerContactId;
                      final title = revoked
                          ? '$name${l10n.vehicleUsageBalanceRevokedSuffix}'
                          : name;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(title),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/vehicle/${widget.vehicleId}/borrower-balances/${link.id}',
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// Detail for one sharing link (owner or borrower route).
class VehicleUsageBalanceScreen extends StatefulWidget {
  const VehicleUsageBalanceScreen({
    super.key,
    required this.vehicleId,
    required this.linkId,
    required this.prefs,
  });

  final String vehicleId;
  final String linkId;
  final AppPreferences prefs;

  @override
  State<VehicleUsageBalanceScreen> createState() =>
      _VehicleUsageBalanceScreenState();
}

class _VehicleUsageBalanceScreenState extends State<VehicleUsageBalanceScreen> {
  VehicleSharingLink? _link;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final link = await VehiclesRepository(AppDatabase.processScope)
        .getSharingLink(widget.linkId);
    if (!mounted) return;
    setState(() {
      _link = link;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleUsageBalanceTitle)),
      body: qaVehicleSemantics(
        identifier: kQaVehicleUsageBalanceScreen,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _link == null || _link!.vehicleId != widget.vehicleId
                ? const Center(child: Text('—'))
                : VehicleUsageBalanceDetailBody(
                    link: _link!,
                    prefs: widget.prefs,
                  ),
      ),
    );
  }
}

/// Emprunteur entry: resolve local sharing link then show the same breakdown.
class VehicleBorrowerUsageBalanceScreen extends StatefulWidget {
  const VehicleBorrowerUsageBalanceScreen({
    super.key,
    required this.vehicleId,
    required this.borrowerContactId,
    required this.prefs,
  });

  final String vehicleId;
  final String borrowerContactId;
  final AppPreferences prefs;

  @override
  State<VehicleBorrowerUsageBalanceScreen> createState() =>
      _VehicleBorrowerUsageBalanceScreenState();
}

class _VehicleBorrowerUsageBalanceScreenState
    extends State<VehicleBorrowerUsageBalanceScreen> {
  VehicleSharingLink? _link;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final links = await VehiclesRepository(AppDatabase.processScope)
        .listSharingLinksForVehicle(widget.vehicleId);
    VehicleSharingLink? match;
    for (final link in links) {
      if (link.borrowerContactId != widget.borrowerContactId) continue;
      final status = VehicleSharingLinkStatus.fromWire(link.status);
      if (status == VehicleSharingLinkStatus.active ||
          status == VehicleSharingLinkStatus.revoked ||
          link.acceptedAt != null) {
        match = link;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _link = match;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleUsageBalanceTitle)),
      body: qaVehicleSemantics(
        identifier: kQaVehicleUsageBalanceScreen,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _link == null
                ? ListView(
                    padding: screenBodyScrollPadding(context),
                    children: [Text(l10n.vehicleBorrowerBalancesEmpty)],
                  )
                : VehicleUsageBalanceDetailBody(
                    link: _link!,
                    prefs: widget.prefs,
                  ),
      ),
    );
  }
}
