import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../vehicle/vehicle_module_access.dart';
import '../../widgets/screen_body_padding.dart';

/// Picks a connected contact to invite; continues to the offer form stub.
class VehicleSharingOfferScreen extends StatefulWidget {
  const VehicleSharingOfferScreen({
    super.key,
    required this.vehicleId,
  });

  final String vehicleId;

  @override
  State<VehicleSharingOfferScreen> createState() =>
      _VehicleSharingOfferScreenState();
}

class _VehicleSharingOfferScreenState extends State<VehicleSharingOfferScreen> {
  List<Contact> _contacts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = VehiclesRepository(AppDatabase.processScope);
    final links = await repo.listSharingLinksForVehicle(widget.vehicleId);
    final activeBorrowerIds = {
      for (final l in links)
        if (l.status == VehicleSharingLinkStatus.active.wire) l.borrowerContactId,
    };
    final contacts = await ContactsRepository(AppDatabase.processScope).list();
    final connected = contacts
        .where(
          (c) =>
              c.kind == 'connected' && !activeBorrowerIds.contains(c.id),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _contacts = connected;
      _loading = false;
    });
  }

  void _select(String contactId) {
    final access = const VehicleModuleAccess();
    final l10n = AppLocalizations.of(context);
    if (!access.canOfferSharing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.vehicleSharingOfferBlocked)),
      );
      return;
    }
    final encoded = Uri.encodeComponent(contactId);
    context.push(
      '/vehicle-sharing/${widget.vehicleId}/invite-form?contactId=$encoded',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleSharingOffer)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: screenBodyScrollPadding(context),
              children: [
                Text(l10n.vehicleSharingOfferPickContact),
                const SizedBox(height: 8),
                if (_contacts.isEmpty)
                  Text(l10n.vehicleSharingNoContacts)
                else
                  ..._contacts.map(
                    (c) => ListTile(
                      title: Text(c.displayName),
                      onTap: () => _select(c.id),
                    ),
                  ),
              ],
            ),
    );
  }
}
