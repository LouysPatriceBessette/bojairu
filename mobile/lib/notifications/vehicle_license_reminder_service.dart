import 'package:flutter/foundation.dart';

import '../entitlement/housing_license_reminder_schedule.dart';
import '../entitlement/vehicle_license_lifecycle_sync.dart';
import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import '../util/display_date.dart';
import 'notification_localizations.dart';
import 'notification_permission_gate.dart';
import 'notification_qa_prefix.dart';
import 'push_notification_service.dart';

/// Schedules / cancels local vehicle trial and payment-default grace reminders.
abstract final class VehicleLicenseReminderService {
  static const int qaListNumber = 21;

  static Future<void> sync({
    required List<HousingLicenseReminderSlot> slots,
    List<HousingLicenseReminderSlot> extraCancelSlots = const [],
    required DateTime now,
    required bool showDueImmediately,
    required bool paid,
  }) async {
    const planId = kVehicleLicenseReminderPlanId;
    final toCancel = <HousingLicenseReminderSlot>[
      ...slots,
      ...extraCancelSlots,
    ];
    final seen = <int>{};
    for (final slot in toCancel) {
      final id = housingLicenseReminderNotificationId(
        planId: planId,
        kind: slot.kind,
        sequence: slot.sequence,
      );
      if (!seen.add(id)) continue;
      await PushNotificationService.cancelLocalNotification(id);
    }
    if (paid || kIsWeb) return;

    final prefs = await AppPreferences.load();
    if (!prefs.notificationsEnabled) return;
    final status = await NotificationPermissionGate.instance.status();
    if (status != NotificationSystemPermissionStatus.granted &&
        status != NotificationSystemPermissionStatus.provisional) {
      return;
    }

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final dateFormat = effectiveDateFormat(prefs);
    final utc = now.toUtc();
    final playSound = prefs.notificationSoundEnabled;

    for (final slot in slots) {
      final id = housingLicenseReminderNotificationId(
        planId: planId,
        kind: slot.kind,
        sequence: slot.sequence,
      );
      final copy = _copyFor(slot, l10n, dateFormat);
      if (!slot.fireAtUtc.toUtc().isAfter(utc)) {
        if (showDueImmediately && _justDue(slot.fireAtUtc, utc)) {
          await PushNotificationService.showHousingLicenseReminderNow(
            id: id,
            title: copy.title,
            body: copy.body,
            playSound: playSound,
          );
        }
        continue;
      }
      await PushNotificationService.scheduleHousingLicenseReminder(
        id: id,
        fireAtUtc: slot.fireAtUtc.toUtc(),
        title: copy.title,
        body: copy.body,
        playSound: playSound,
      );
    }
  }

  static ({String title, String body}) _copyFor(
    HousingLicenseReminderSlot slot,
    AppLocalizations l10n,
    String dateFormat,
  ) {
    final title = notificationQaPrefix(
      qaListNumber,
      switch (slot.kind) {
        HousingLicenseReminderKind.trialStart =>
          l10n.pushNotificationVehicleTrialStartedTitle,
        HousingLicenseReminderKind.trialWeekLeft ||
        HousingLicenseReminderKind.trialDaysLeft =>
          l10n.pushNotificationVehicleTrialReminderTitle,
        HousingLicenseReminderKind.trialEnded =>
          l10n.pushNotificationTrialEndedTitle,
        HousingLicenseReminderKind.graceDaily =>
          l10n.pushNotificationVehicleGraceReminderTitle,
      },
    );
    final trialDate = formatPreferenceDate(slot.trialEndsAt, dateFormat);
    final graceDate = formatPreferenceDate(slot.graceEndsAt, dateFormat);
    final days = slot.daysRemaining ?? 0;
    final bodyRaw = switch (slot.kind) {
      HousingLicenseReminderKind.trialStart =>
        l10n.pushNotificationVehicleTrialStartedBody(trialDate),
      HousingLicenseReminderKind.trialWeekLeft =>
        l10n.pushNotificationVehicleTrialWeekLeftBody(trialDate),
      HousingLicenseReminderKind.trialDaysLeft =>
        l10n.pushNotificationVehicleTrialDaysLeftBody(days, trialDate),
      HousingLicenseReminderKind.trialEnded =>
        l10n.pushNotificationVehicleTrialEndedBody,
      HousingLicenseReminderKind.graceDaily =>
        l10n.pushNotificationVehicleGraceReminderBody(days, graceDate),
    };
    return (title: title, body: notificationQaPrefix(qaListNumber, bodyRaw));
  }

  static bool _justDue(DateTime fireAtUtc, DateTime nowUtc) {
    final fire = fireAtUtc.toUtc();
    return !fire.isBefore(nowUtc.subtract(const Duration(minutes: 5)));
  }
}
