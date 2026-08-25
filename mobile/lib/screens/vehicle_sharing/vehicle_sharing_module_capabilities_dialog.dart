import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Explains what Vehicle sharing allows and shows paid license status.
class VehicleSharingModuleCapabilitiesDialog extends StatelessWidget {
  const VehicleSharingModuleCapabilitiesDialog({
    super.key,
    required this.vehiclePaid,
    required this.sharingPaid,
  });

  final bool vehiclePaid;
  final bool sharingPaid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.vehicleSharingModuleCapabilitiesBody1),
            const SizedBox(height: 16),
            Text(l10n.vehicleSharingModuleCapabilitiesBody2),
            const SizedBox(height: 16),
            Text(l10n.vehicleSharingModuleCapabilitiesLicensesHeading),
            const SizedBox(height: 8),
            _LicenseMarkRow(
              paid: vehiclePaid,
              label: l10n.licensesProductVehicle,
            ),
            _LicenseMarkRow(
              paid: sharingPaid,
              label: l10n.licensesProductSharing,
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}

class _LicenseMarkRow extends StatelessWidget {
  const _LicenseMarkRow({
    required this.paid,
    required this.label,
  });

  final bool paid;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = paid
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            paid ? Icons.check : Icons.close,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

Future<void> showVehicleSharingModuleCapabilitiesDialog({
  required BuildContext context,
  required bool vehiclePaid,
  required bool sharingPaid,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => VehicleSharingModuleCapabilitiesDialog(
      vehiclePaid: vehiclePaid,
      sharingPaid: sharingPaid,
    ),
  );
}
