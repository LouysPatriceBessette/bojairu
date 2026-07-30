import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/screen_body_padding.dart';

/// Stub form after contact selection — content TBD (no DB write).
class VehicleSharingInviteFormScreen extends StatelessWidget {
  const VehicleSharingInviteFormScreen({
    super.key,
    required this.vehicleId,
    required this.contactId,
  });

  final String vehicleId;
  final String contactId;

  @override
  Widget build(BuildContext context) {
    assert(vehicleId.isNotEmpty);
    assert(contactId.isNotEmpty);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicleSharingNewShareTitle)),
      body: ListView(
        padding: screenBodyScrollPadding(context),
        children: [
          Text(l10n.vehicleSharingInviteFormStubBody),
        ],
      ),
    );
  }
}
