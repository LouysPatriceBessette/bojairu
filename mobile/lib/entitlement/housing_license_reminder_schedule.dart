import 'housing_lifecycle_source.dart';

/// Local reminder kinds for housing trial and product grace (OpenSpec 2.1 / 2.2).
enum HousingLicenseReminderKind {
  trialStart,
  trialWeekLeft,
  trialDaysLeft,
  trialEnded,
  graceDaily,
}

/// One local notification fire time derived from trial / grace clocks.
class HousingLicenseReminderSlot {
  const HousingLicenseReminderSlot({
    required this.kind,
    required this.fireAtUtc,
    required this.sequence,
    this.daysRemaining,
    this.trialEndsAt,
    this.graceEndsAt,
  });

  final HousingLicenseReminderKind kind;
  final DateTime fireAtUtc;
  final int sequence;
  final int? daysRemaining;
  final DateTime? trialEndsAt;
  final DateTime? graceEndsAt;
}

/// Stable Android/iOS notification id for a plan + slot.
int housingLicenseReminderNotificationId({
  required String planId,
  required HousingLicenseReminderKind kind,
  required int sequence,
}) {
  final hashed = Object.hash(planId, kind.index, sequence);
  return 0x484C0000 | (hashed.abs() & 0xFFFF);
}

/// Builds the trial + grace reminder timetable (no plugin I/O).
List<HousingLicenseReminderSlot> housingLicenseReminderSlots({
  required DateTime activeUseStartedAt,
  required bool trialEligible,
}) {
  final started = activeUseStartedAt.toUtc();
  if (!trialEligible) return const [];

  final trialEnds = started.add(kHousingTrialDuration);
  return [
    HousingLicenseReminderSlot(
      kind: HousingLicenseReminderKind.trialStart,
      fireAtUtc: started,
      sequence: 0,
      daysRemaining: kHousingTrialDuration.inDays,
      trialEndsAt: trialEnds,
    ),
    HousingLicenseReminderSlot(
      kind: HousingLicenseReminderKind.trialWeekLeft,
      fireAtUtc: trialEnds.subtract(const Duration(days: 7)),
      sequence: 1,
      daysRemaining: 7,
      trialEndsAt: trialEnds,
    ),
    for (var daysLeft = 3; daysLeft >= 1; daysLeft--)
      HousingLicenseReminderSlot(
        kind: HousingLicenseReminderKind.trialDaysLeft,
        fireAtUtc: trialEnds.subtract(Duration(days: daysLeft)),
        sequence: 4 - daysLeft,
        daysRemaining: daysLeft,
        trialEndsAt: trialEnds,
      ),
    HousingLicenseReminderSlot(
      kind: HousingLicenseReminderKind.trialEnded,
      fireAtUtc: trialEnds,
      sequence: 5,
      daysRemaining: 0,
      trialEndsAt: trialEnds,
    ),
  ];
}

/// Daily grace reminders after a **paid** store receipt expires.
List<HousingLicenseReminderSlot> housingLicenseReceiptGraceSlots({
  required DateTime receiptExpiredAt,
}) {
  final started = receiptExpiredAt.toUtc();
  return _graceDailySlots(
    graceStartedAt: started,
    graceEndsAt: started.add(kHousingGraceDuration),
  );
}

/// Ids previously used for trial-chained grace (cancel leftovers).
List<HousingLicenseReminderSlot> housingLicenseLegacyGraceCancelSlots({
  required DateTime activeUseStartedAt,
}) {
  final started = activeUseStartedAt.toUtc();
  final trialEnds = started.add(kHousingTrialDuration);
  return _graceDailySlots(
    graceStartedAt: trialEnds,
    graceEndsAt: trialEnds.add(kHousingGraceDuration),
  );
}

List<HousingLicenseReminderSlot> _graceDailySlots({
  required DateTime graceStartedAt,
  required DateTime graceEndsAt,
}) {
  final days = kHousingGraceDuration.inDays;
  return [
    for (var i = 0; i < days; i++)
      HousingLicenseReminderSlot(
        kind: HousingLicenseReminderKind.graceDaily,
        fireAtUtc: graceStartedAt.add(Duration(days: i)),
        sequence: 10 + i,
        daysRemaining: days - i,
        graceEndsAt: graceEndsAt,
      ),
  ];
}
