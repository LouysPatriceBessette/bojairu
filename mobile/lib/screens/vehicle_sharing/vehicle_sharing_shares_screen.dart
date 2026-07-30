import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/screen_body_padding.dart';

/// Active sharing links for one owned vehicle (Propriétaire view).
class VehicleSharingSharesScreen extends StatefulWidget {
  const VehicleSharingSharesScreen({
    super.key,
    required this.vehicleId,
  });

  final String vehicleId;

  @override
  State<VehicleSharingSharesScreen> createState() =>
      _VehicleSharingSharesScreenState();
}

class _VehicleSharingSharesScreenState
    extends State<VehicleSharingSharesScreen> {
  Vehicle? _vehicle;
  List<VehicleSharingLink> _activeLinks = const [];
  Map<String, String> _contactLabels = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final vehicle = await repo.getVehicle(widget.vehicleId);
    final links = await repo.listSharingLinksForVehicle(widget.vehicleId);
    final active = links
        .where((l) => l.status == VehicleSharingLinkStatus.active.wire)
        .toList();
    final contacts = await ContactsRepository(AppDatabase.processScope).list();
    final labels = {for (final c in contacts) c.id: c.displayName};

    if (!mounted) return;
    setState(() {
      _vehicle = vehicle;
      _activeLinks = active;
      _contactLabels = labels;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _vehicle?.displayLabel ?? l10n.vehicleSharingSharesDetailTitle;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: screenBodyScrollPadding(context),
              children: [
                Text(
                  l10n.vehicleSharingSharesDetailTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_activeLinks.isEmpty)
                  Text(l10n.vehicleSharingEmptyNone)
                else
                  ..._activeLinks.map(
                    (link) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _contactLabels[link.borrowerContactId] ??
                            link.borrowerContactId,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await context.push(
                      '/vehicle-sharing/${widget.vehicleId}/invite',
                    );
                    _reload();
                  },
                  child: Text(l10n.vehicleSharingAddShare),
                ),
              ],
            ),
    );
  }
}
