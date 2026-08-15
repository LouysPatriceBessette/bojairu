import 'package:flutter/foundation.dart';

import '../entitlement/housing_license_reminder_schedule.dart';
import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import '../util/display_date.dart';
import 'notification_localizations.dart';
import 'notification_permission_gate.dart';
import 'notification_qa_prefix.dart';
import 'push_notification_service.dart';

/// Schedules / cancels local housing trial and grace reminders.
abstract final class HousingLicenseReminderService {
  static const int qaListNumber = 20;

  static Future<void> syncPlan({
    required String planId,
    required List<HousingLicenseReminderSlot> slots,
    required DateTime now,
    required bool showDueImmediately,
    required bool paid,
  }) async {
    for (final slot in slots) {
      await PushNotificationService.cancelLocalNotification(
        housingLicenseReminderNotificationId(
          planId: planId,
          kind: slot.kind,
          sequence: slot.sequence,
        ),
      );
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

  static bool _justDue(DateTime fireAtUtc, DateTime nowUtc) {
    final fire = fireAtUtc.toUtc();
    return !fire.isBefore(nowUtc.subtract(const Duration(minutes: 5)));
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
          l10n.pushNotificationHousingTrialStartedTitle,
        HousingLicenseReminderKind.trialWeekLeft ||
        HousingLicenseReminderKind.trialDaysLeft =>
          l10n.pushNotificationHousingTrialReminderTitle,
        HousingLicenseReminderKind.graceDaily =>
          l10n.pushNotificationHousingGraceReminderTitle,
      },
    );
    final trialDate = formatPreferenceDate(slot.trialEndsAt, dateFormat);
    final graceDate = formatPreferenceDate(slot.graceEndsAt, dateFormat);
    final days = slot.daysRemaining ?? 0;
    final bodyRaw = switch (slot.kind) {
      HousingLicenseReminderKind.trialStart =>
        l10n.pushNotificationHousingTrialStartedBody(trialDate),
      HousingLicenseReminderKind.trialWeekLeft =>
        l10n.pushNotificationHousingTrialWeekLeftBody(trialDate),
      HousingLicenseReminderKind.trialDaysLeft =>
        l10n.pushNotificationHousingTrialDaysLeftBody(days, trialDate),
      HousingLicenseReminderKind.graceDaily =>
        l10n.pushNotificationHousingGraceReminderBody(days, graceDate),
    };
    return (title: title, body: notificationQaPrefix(qaListNumber, bodyRaw));
  }
}
