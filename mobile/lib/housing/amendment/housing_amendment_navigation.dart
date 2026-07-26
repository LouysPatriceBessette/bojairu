import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../prefs/app_preferences.dart';
import '../../screens/housing/housing_amendment_detail_screen.dart';
import '../../screens/housing/housing_amendment_journal_screen.dart';
import '../../screens/housing/housing_invite_proposal_screen.dart';
import '../proposals/housing_proposal_transport_service.dart';
import 'housing_amendment_summary.dart';
import 'package:compartarenta/navigation/app_navigation.dart';

/// Returns to the housing module hub when [planId] is in force.
///
/// When overlay routes sit above the housing module entry (e.g. Modifier le plan
/// → détail), pops back to that entry instead of [pushReplacement] a second hub
/// (which forced an extra Back through the amendment menu).
///
/// Returns true when the plan is active (navigation or already at root).
Future<bool> openHousingActivePlanHubIfActive(
  BuildContext context, {
  required AppDatabase db,
  required String planId,
  required AppPreferences prefs,
}) async {
  final transport = HousingProposalTransportService(db);
  if (!await transport.hasActiveRevision(planId)) return false;
  if (!context.mounted) return false;

  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.popUntil((route) => route.isFirst);
    return true;
  }

  // Housing root already shows the active hub as entry body — do not stack
  // another [HousingActivePlanScreen] via pushReplacement.
  return true;
}

/// Opens amendment detail after the proposer submitted, clearing the wizard
/// stack (Modifier le plan → form → aperçu) so Back returns to the housing hub.
///
/// Do **not** [navigateToRoute] (pushReplacement) from aperçu alone: that only
/// removes the preview and leaves the expense form underneath — Back lands on
/// « Editar gasto » instead of the hub (2026-07-26).
Future<void> openHousingAmendmentDetailAfterSubmit(
  BuildContext context, {
  required AppDatabase db,
  required String planId,
  required AppPreferences prefs,
  String? revisionId,
}) async {
  final transport = HousingProposalTransportService(db);
  final pendingId =
      revisionId ?? await transport.pendingRevisionIdForPlan(planId);
  if (!context.mounted) return;

  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.popUntil((route) => route.isFirst);
  }

  await nav.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => HousingAmendmentDetailScreen(
        db: db,
        planId: planId,
        prefs: prefs,
        revisionId: pendingId,
      ),
    ),
  );
}

/// Opens the amendment detail screen or the full-plan proposal screen.
Future<void> openHousingPendingProposalOrAmendment(
  BuildContext context, {
  required AppDatabase db,
  required String planId,
  required AppPreferences prefs,
  String? revisionId,
  bool isAmendment = false,
}) async {
  final transport = HousingProposalTransportService(db);
  await transport.reconcileStalePackagePending(planId);
  final pendingId =
      revisionId ?? await transport.pendingRevisionIdForPlan(planId);
  if (pendingId == null) {
    if (!context.mounted) return;
    await openHousingActivePlanHubIfActive(
      context,
      db: db,
      planId: planId,
      prefs: prefs,
    );
    return;
  }
  final openAmendment =
      isAmendment ||
      await pendingRevisionIsAmendment(
        db,
        planId,
        revisionId: pendingId,
      );
  if (!context.mounted) return;
  await navigateToChildRoute<void>(context, 
    MaterialPageRoute<void>(
      builder: (_) => openAmendment
          ? HousingAmendmentDetailScreen(
              db: db,
              planId: planId,
              prefs: prefs,
              revisionId: pendingId,
            )
          : HousingInviteProposalScreen(
              db: db,
              planId: planId,
              prefs: prefs,
              revisionId: pendingId,
            ),
    ),
  );
}

/// Opens a settled (archived) amendment in read-only detail.
Future<void> openHousingSettledAmendmentDetail(
  BuildContext context, {
  required AppDatabase db,
  required String planId,
  required AppPreferences prefs,
  required String revisionId,
}) {
  return navigateToChildRoute<void>(context, 
    MaterialPageRoute<void>(
      builder: (_) => HousingAmendmentDetailScreen(
        db: db,
        planId: planId,
        prefs: prefs,
        revisionId: revisionId,
        readOnlySettled: true,
      ),
    ),
  );
}

/// Opens the settled-amendment journal (no pending-request banner).
Future<void> openHousingAmendmentJournal(
  BuildContext context, {
  required String planId,
  required AppPreferences prefs,
}) {
  return navigateToChildRoute<void>(context, 
    MaterialPageRoute<void>(
      builder: (_) => HousingAmendmentJournalScreen(
        planId: planId,
        prefs: prefs,
      ),
    ),
  );
}
