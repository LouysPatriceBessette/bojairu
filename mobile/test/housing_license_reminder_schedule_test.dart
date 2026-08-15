import 'package:compartarenta/entitlement/housing_license_reminder_schedule.dart';
import 'package:compartarenta/entitlement/housing_lifecycle_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final started = DateTime.utc(2026, 8, 1, 12);

  test('eligible trial schedules start, week-left, last 3 days, then 7 grace days', () {
    final slots = housingLicenseReminderSlots(
      activeUseStartedAt: started,
      trialEligible: true,
    );
    final trialEnds = started.add(kHousingTrialDuration);

    expect(
      slots.where((s) => s.kind == HousingLicenseReminderKind.trialStart),
      hasLength(1),
    );
    expect(
      slots.where((s) => s.kind == HousingLicenseReminderKind.trialWeekLeft).single.fireAtUtc,
      trialEnds.subtract(const Duration(days: 7)),
    );
    expect(
      slots
          .where((s) => s.kind == HousingLicenseReminderKind.trialDaysLeft)
          .map((s) => s.daysRemaining)
          .toList(),
      [3, 2, 1],
    );
    expect(
      slots.where((s) => s.kind == HousingLicenseReminderKind.graceDaily),
      hasLength(7),
    );
    expect(slots.first.fireAtUtc, started);
    expect(slots.last.daysRemaining, 1);
  });

  test('consumed trial schedules only daily grace', () {
    final slots = housingLicenseReminderSlots(
      activeUseStartedAt: started,
      trialEligible: false,
    );
    expect(slots, hasLength(7));
    expect(
      slots.every((s) => s.kind == HousingLicenseReminderKind.graceDaily),
      isTrue,
    );
    expect(slots.first.fireAtUtc, started);
    expect(slots.first.daysRemaining, 7);
  });

  test('notification ids are stable for the same plan slot', () {
    final a = housingLicenseReminderNotificationId(
      planId: 'housing:p1',
      kind: HousingLicenseReminderKind.trialStart,
      sequence: 0,
    );
    final b = housingLicenseReminderNotificationId(
      planId: 'housing:p1',
      kind: HousingLicenseReminderKind.trialStart,
      sequence: 0,
    );
    final c = housingLicenseReminderNotificationId(
      planId: 'housing:p2',
      kind: HousingLicenseReminderKind.trialStart,
      sequence: 0,
    );
    expect(a, b);
    expect(a, isNot(c));
  });
}
