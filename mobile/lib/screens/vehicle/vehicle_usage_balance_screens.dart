import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../debug/qa_vehicle_semantics.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VehicleUsageBalanceDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link.id != widget.link.id) {
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
        children: [
          Text(message),
          const SizedBox(height: 16),
          Text(
            l10n.vehicleUsageBalanceInformativeNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    final b = result.breakdown!;
    final currency = widget.prefs.currency;
    String money(int minor) => formatMinorAsMoney(context, minor, currency);
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
        const Divider(height: 32),
        _row(
          context,
          l10n.vehicleUsageBalanceEstimatedFuel,
          money(b.estimatedFuelCostMinor),
        ),
        _row(
          context,
          l10n.vehicleUsageBalanceBorrowerFuel,
          money(b.borrowerFuelCostMinor),
        ),
        _row(
          context,
          l10n.vehicleUsageBalanceBorrowerMaintenance,
          money(b.borrowerMaintenanceCostMinor),
        ),
        _row(
          context,
          l10n.vehicleUsageBalanceCompensation,
          money(b.compensationMinor),
        ),
        const Divider(height: 32),
        _row(
          context,
          l10n.vehicleUsageBalanceConsumption,
          '${b.litersPer100Km.toStringAsFixed(1)} L/100 km',
        ),
        _row(
          context,
          l10n.vehicleUsageBalanceDistance,
          '${b.distanceKm} km',
        ),
        _row(
          context,
          l10n.vehicleUsageBalanceFuelPrice,
          '${formatMinorAsMoney(context, b.pricePerLiterMinor.round(), currency)} / L',
        ),
        _row(
          context,
          l10n.vehicleUsageBalanceRatePerKm,
          money(b.ratePerKmMinor),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.vehicleUsageBalanceInformativeNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, textAlign: TextAlign.end),
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
                    separatorBuilder: (context, index) => const Divider(height: 1),
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

