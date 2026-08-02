import '../../activity/relay_activity_log_service.dart';
import '../../l10n/app_localizations.dart';

/// Localized title for a vehicle sharing / session activity-log kind.
String vehicleSharingActivityKindLabel(AppLocalizations l10n, String kind) {
  return switch (kind) {
    RelayActivityLogKinds.vehicleSharingOfferSent =>
      l10n.activityLogKindVehicleSharingOfferSent,
    RelayActivityLogKinds.vehicleSharingOfferReceived =>
      l10n.activityLogKindVehicleSharingOfferReceived,
    RelayActivityLogKinds.vehicleSharingOfferResponse =>
      l10n.activityLogKindVehicleSharingOfferResponse,
    RelayActivityLogKinds.vehicleSharingOfferExpired =>
      l10n.activityLogKindVehicleSharingOfferExpired,
    RelayActivityLogKinds.vehicleUseSessionStartSent =>
      l10n.activityLogKindVehicleUseSessionStartSent,
    RelayActivityLogKinds.vehicleUseSessionStartReceived =>
      l10n.activityLogKindVehicleUseSessionStartReceived,
    RelayActivityLogKinds.vehicleUseSessionEndSent =>
      l10n.activityLogKindVehicleUseSessionEndSent,
    RelayActivityLogKinds.vehicleUseSessionEndReceived =>
      l10n.activityLogKindVehicleUseSessionEndReceived,
    _ => kind,
  };
}
