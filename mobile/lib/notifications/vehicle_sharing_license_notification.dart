import '../prefs/app_preferences.dart';
import 'notification_localizations.dart';
import 'push_notification_service.dart';

const int _kVehicleSharingDisabledNotificationId = 0x56534844; // VSHD

/// Owner-side "sharing disabled" local notification (entry or first held packet).
Future<void> showVehicleSharingDisabledNotification() async {
  final prefs = await AppPreferences.load();
  if (!prefs.notificationsEnabled) return;
  final l10n = l10nForNotificationLocale(prefs: prefs);
  await PushNotificationService.showHousingLicenseReminderNow(
    id: _kVehicleSharingDisabledNotificationId,
    title: l10n.pushNotificationVehicleSharingDisabledTitle,
    body: l10n.pushNotificationVehicleSharingDisabledBody,
    playSound: prefs.notificationSoundEnabled,
  );
}

Future<void> notifyHeldBorrowerPacketOnce() async {
  final prefs = await AppPreferences.load();
  if (prefs.vehicleSharingHoldInboundNotified()) return;
  await prefs.setVehicleSharingHoldInboundNotified(true);
  await showVehicleSharingDisabledNotification();
}
