import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'qa_vehicle_semantics.dart';

/// Vehicle sharing hub (debug Maestro).
const kQaVehicleSharingHub = 'qa-vehicle-sharing-hub';

/// Add share CTA on shares detail screen.
const kQaVehicleSharingAddShare = 'qa-vehicle-sharing-add-share';

/// Invite form primary send button.
const kQaVehicleSharingInviteSend = 'qa-vehicle-sharing-invite-send';

/// Disclaimer dialog Ok.
const kQaVehicleSharingInviteDisclaimerOk =
    'qa-vehicle-sharing-invite-disclaimer-ok';

/// Response-deadline dialog before sending an offer.
const kQaVehicleSharingOfferDeadlineDialog =
    'qa-vehicle-sharing-offer-deadline-dialog';

/// Continue on the response-deadline dialog.
const kQaVehicleSharingOfferDeadlineContinue =
    'qa-vehicle-sharing-offer-deadline-continue';

/// Pending outbound invitation row on shares detail (owner).
const kQaVehicleSharingOutboundPendingInvite =
    'qa-vehicle-sharing-outbound-pending-invite';

/// Pending offer Accept on hub.
const kQaVehicleSharingPendingAccept = 'qa-vehicle-sharing-pending-accept';

/// Shareable owned-vehicle row on hub (slug from display label).
String qaVehicleSharingShareableRowSemanticsId(String displayLabel) =>
    'qa-vehicle-sharing-shareable-${qaVehicleCardSemanticsId(displayLabel).replaceFirst('qa-vehicle-card-', '')}';

/// Known QA Civic shareable row.
const kQaVehicleSharingShareableQaCivic =
    'qa-vehicle-sharing-shareable-qa-civic';

/// Green check on a shareable row when the owner has an active outbound share.
String qaVehicleSharingShareableActiveSemanticsId(String displayLabel) =>
    'qa-vehicle-sharing-shareable-active-${qaVehicleCardSemanticsId(displayLabel).replaceFirst('qa-vehicle-card-', '')}';

const kQaVehicleSharingShareableActiveQaCivic =
    'qa-vehicle-sharing-shareable-active-qa-civic';

/// Pending offer row title container (vehicle label).
String qaVehicleSharingPendingRowSemanticsId(String displayLabel) =>
    'qa-vehicle-sharing-pending-${qaVehicleCardSemanticsId(displayLabel).replaceFirst('qa-vehicle-card-', '')}';

const kQaVehicleSharingPendingQaCivic = 'qa-vehicle-sharing-pending-qa-civic';

/// Accessible (active) vehicle card on hub.
String qaVehicleSharingAccessibleCardSemanticsId(String displayLabel) =>
    'qa-vehicle-sharing-accessible-${qaVehicleCardSemanticsId(displayLabel).replaceFirst('qa-vehicle-card-', '')}';

const kQaVehicleSharingAccessibleQaCivic =
    'qa-vehicle-sharing-accessible-qa-civic';

Widget qaVehicleSharingSemantics({
  required String identifier,
  required Widget child,
  String? label,
  bool button = false,
  VoidCallback? onTap,
}) {
  if (!kDebugMode) return child;
  return Semantics(
    identifier: identifier,
    label: label,
    button: button,
    excludeSemantics: button,
    onTap: button ? onTap : null,
    container: !button,
    child: child,
  );
}
