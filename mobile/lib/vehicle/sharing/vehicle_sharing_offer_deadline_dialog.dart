import 'package:flutter/material.dart';

import '../../debug/qa_vehicle_sharing_semantics.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/dialog_tap_guard.dart';
import '../../widgets/standard_validity_duration_bar.dart';

/// Propriétaire picks how long the Emprunteur may accept before the offer
/// (or reactivation proposal) expires.
Future<Duration?> showVehicleSharingOfferDeadlineDialog(
  BuildContext context, {
  String? title,
  String? body,
}) async {
  return DialogTapGuard.run<Duration?>(
    'vehicleSharingOfferDeadline',
    () async {
      final l10n = AppLocalizations.of(context);
      var selected = StandardValidityDurations.values[2];

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: qaVehicleSharingSemantics(
              identifier: kQaVehicleSharingOfferDeadlineDialog,
              child: Text(title ?? l10n.vehicleSharingOfferDeadlineTitle),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(body ?? l10n.vehicleSharingOfferDeadlineBody),
                  const SizedBox(height: 16),
                  StandardValidityDurationSegmented(
                    selected: selected,
                    onChanged: (d) => setLocal(() => selected = d),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.housingPlanCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: qaVehicleSharingSemantics(
                  identifier: kQaVehicleSharingOfferDeadlineContinue,
                  button: true,
                  onTap: () => Navigator.pop(ctx, true),
                  child: Text(l10n.commonContinue),
                ),
              ),
            ],
          ),
        ),
      );

      if (proceed != true) return null;
      return selected;
    },
  );
}
