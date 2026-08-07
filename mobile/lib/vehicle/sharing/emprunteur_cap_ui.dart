import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../db/repositories/vehicles_repository.dart';
import '../../l10n/app_localizations.dart';
import '../vehicle_emprunteur_cap.dart';

/// Cap gate before offer / reactivation send.
///
/// Returns false if blocked or the user cancels the last-slot warning.
Future<bool> ensureEmprunteurCapAllowsInvite({
  required BuildContext context,
  required String borrowerContactId,
}) async {
  final l10n = AppLocalizations.of(context);
  final counting = await VehiclesRepository(AppDatabase.processScope)
      .distinctEmprunteurContactIdsCountingTowardCap();
  if (!context.mounted) return false;

  if (EmprunteurCapLogic.wouldExceedCap(
    countingContactIds: counting,
    borrowerContactId: borrowerContactId,
  )) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.vehicleEmprunteurCapLimitReached)),
    );
    return false;
  }

  if (!EmprunteurCapLogic.wouldOccupyLastSlot(
    countingContactIds: counting,
    borrowerContactId: borrowerContactId,
  )) {
    return true;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.vehicleEmprunteurCapLastSlotTitle),
      content: Text(l10n.vehicleEmprunteurCapLastSlotBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.housingPlanCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.commonContinue),
        ),
      ],
    ),
  );
  return ok == true;
}
