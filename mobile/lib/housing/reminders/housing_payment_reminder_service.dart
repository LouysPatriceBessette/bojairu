import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/supported_time_zones.dart';
import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../notifications/push_notification_service.dart';
import '../../prefs/app_preferences.dart';
import '../../prefs/time_zone_policy_field.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../relay/relay_client.dart';
import '../../relay/relay_scheduling.dart';
import '../../relay/routing.dart';
import '../../contacts/invitation_expiry_reminder_service.dart';
import '../../scheduling/client_scheduled_fire_times.dart';
import '../amendment/housing_active_agreement_service.dart';
import '../realized_expense/realized_expense_ledger_service.dart';
import '../realized_expense/realized_expense_participants.dart';
import 'payment_period_coverage.dart';
import 'proposal_deadline_reminder_service.dart';

/// Reconciles housing payment reminders with the relay and delivers fired rows.
class HousingPaymentReminderService {
  HousingPaymentReminderService({
    required AppDatabase db,
    required RelayClient relay,
    required AppPreferences prefs,
    required HandshakeOrchestrator orchestrator,
    required ContactsRepository contacts,
  }) : _db = db,
       _relay = relay,
       _prefs = prefs,
       _orchestrator = orchestrator,
       _contacts = contacts,
       _agreements = HousingActiveAgreementService(db);

  final AppDatabase _db;
  final RelayClient _relay;
  final AppPreferences _prefs;
  final HandshakeOrchestrator _orchestrator;
  final ContactsRepository _contacts;
  final HousingActiveAgreementService _agreements;

  static String resolveIanaTimeZone(AppPreferences prefs) {
    if (prefs.timeZonePolicy == kTimeZonePolicyExplicit &&
        isKnownIanaTimeZoneId(prefs.timeZoneId)) {
      return prefs.timeZoneId;
    }
    return kDefaultExplicitTimeZoneId;
  }

  /// Upserts this device's timezone for every wake routing id.
  Future<void> upsertSelfTimezoneOnRelay() async {
    final tz = resolveIanaTimeZone(_prefs);
    final recipients = await _orchestrator.routingWakeRecipientIdentities();
    for (final r in recipients) {
      try {
        await _relay.upsertSchedulingTimezone(
          recipientIdentity: r,
          ianaTimezone: tz,
        );
      } on RelayClientError {
        // Best-effort per routing tuple.
      }
    }
  }

  /// Task 2.2b — Settings timezone change with an open agreement period.
  Future<void> onTimeZonePreferenceChanged() async {
    if (kIsWeb) {
      if (kDebugMode) {
        debugPrint(
          'housingPaymentReminder: timezone upsert skipped (web out of scope)',
        );
      }
      return;
    }
    if (!await _hasAnyOpenAgreementPeriodPlan()) {
      if (kDebugMode) {
        debugPrint(
          'housingPaymentReminder: timezone upsert skipped (no open agreement period)',
        );
      }
      return;
    }
    final tz = resolveIanaTimeZone(_prefs);
    if (kDebugMode) {
      debugPrint('housingPaymentReminder: upserting timezone $tz on relay');
    }
    await upsertSelfTimezoneOnRelay();
    if (kDebugMode) {
      debugPrint('housingPaymentReminder: timezone upsert finished ($tz)');
    }
  }

  Future<bool> _hasAnyOpenAgreementPeriodPlan() async {
    final housing = await (_db.select(_db.plans)
          ..where((t) => t.type.equals('housing')))
        .get();
    for (final plan in housing) {
      if (await _agreements.isPlanAgreementPeriodOpen(plan.id)) {
        return true;
      }
    }
    return false;
  }

  /// Full plan reconciliation after E.1–E.4 (unanimity-establishing client only).
  Future<void> reconcilePlanSchedule({
    required String planId,
    required String revisionId,
    required Uint8List senderRoutingId,
  }) async {
    if (!await _agreements.isPlanAgreementPeriodOpen(planId)) return;

    final planRow = await (_db.select(_db.plans)
          ..where((t) => t.id.equals(planId)))
        .getSingleOrNull();
    if (planRow == null) return;

    final agreement = await _db.getAgreementForPlan(planId);
    final agreementEnd = agreement?.periodEnd.toUtc();
    final packageId = await _packageIdForPlan(planId);
    if (packageId == null) return;

    final ledger = RealizedExpenseLedgerService(_db);
    final lines = await _db.listPlanLines(planId);
    final roster = await participantsForPlan(_db, planId);
    final now = DateTime.now().toUtc();
    final targets = <HousingReminderScheduleTarget>[];

    for (final line in lines) {
      if (!line.isRecurring || line.amountIsBudgetCap) continue;
      final period = slidingPeriodContaining(line: line, atUtc: now);
      if (period == null) continue;
      if (agreementEnd != null && period.dueAtUtc.isAfter(agreementEnd)) {
        continue;
      }

      final previous = slidingPeriodContaining(
        line: line,
        atUtc: period.startUtc.subtract(const Duration(seconds: 1)),
      );
      final coverage = await paymentPeriodCoverage(
        ledger: ledger,
        packageId: packageId,
        planId: planId,
        line: line,
        period: period,
        previousPeriod: previous,
      );

      final scopeKey = Uint8List.fromList(
        housingReminderScopeKeyBytes(planId, line.id),
      );
      final periodKey = Uint8List.fromList(utf8.encode(period.periodKey));
      final boundAt = agreementEnd;

      if (!coverage.isFullyCovered) {
        targets.addAll(
          await _targetsForLinePeriod(
            planId: planId,
            line: line,
            roster: roster,
            scopeKey: scopeKey,
            periodKey: periodKey,
            period: period,
            boundAt: boundAt,
          ),
        );
      } else {
        final next = nextSlidingPeriod(
          line: line,
          period: period,
          agreementEnd: agreementEnd,
        );
        if (next != null) {
          targets.addAll(
            await _targetsForLinePeriod(
              planId: planId,
              line: line,
              roster: roster,
              scopeKey: scopeKey,
              periodKey: Uint8List.fromList(utf8.encode(next.periodKey)),
              period: next,
              boundAt: boundAt,
            ),
          );
        }
      }
    }

    await _relay.reconcileHousingPaymentSchedule(
      senderIdentity: senderRoutingId,
      planIdBytes: Uint8List.fromList(utf8.encode(planId)),
      generation: revisionId.hashCode,
      targets: targets,
    );
    if (kDebugMode) {
      debugPrint(
        'housingPaymentReminder: reconcile posted ${targets.length} target(s) '
        'for planId=$planId revisionId=$revisionId',
      );
    }
  }

  /// Cancels before/overdue targets for a covered period (coverage update B).
  Future<void> cancelRemindersForCoveredPeriod({
    required String planId,
    required String lineId,
    required String periodKey,
    required Uint8List senderRoutingId,
  }) async {
    final scopeKey = Uint8List.fromList(
      housingReminderScopeKeyBytes(planId, lineId),
    );
    final periodKeyBytes = Uint8List.fromList(utf8.encode(periodKey));
    for (final kind in ['before_due', 'overdue']) {
      await _relay.cancelHousingPaymentSchedule(
        senderIdentity: senderRoutingId,
        scopeKeyBytes: [scopeKey],
        reminderKind: kind,
        periodKeyBytes: periodKeyBytes,
      );
    }
  }

  /// Polls relay for fired reminders and shows notifications (native only).
  Future<void> pollAndDeliverPendingReminders() async {
    if (kIsWeb) return;
    final recipients = await _orchestrator.routingWakeRecipientIdentities();
    for (final recipient in recipients) {
      List<RelayPendingReminderDelivery> pending;
      try {
        pending = await _relay.fetchPendingReminderDeliveries(
          recipientIdentity: recipient,
        );
      } on RelayClientError {
        continue;
      }
      for (final d in pending) {
        if (d.domain == 'housing_payment') {
          final handled = await _deliverHousingPaymentReminder(d);
          if (handled) {
            await _safeAck(recipient, d.fireId);
          }
          continue;
        }
        if (d.domain ==
            ClientScheduledFireTimes.domainContactsInvitationExpiry) {
          final inviteSvc = InvitationExpiryReminderService(
            relay: _relay,
            orchestrator: _orchestrator,
            prefs: _prefs,
          );
          final handled = await inviteSvc.deliverIfApplicable(d);
          if (handled) await _safeAck(recipient, d.fireId);
          continue;
        }
        if (d.domain ==
            ClientScheduledFireTimes.domainHousingProposalDeadline) {
          final propSvc = ProposalDeadlineReminderService(
            relay: _relay,
            prefs: _prefs,
          );
          final handled = await propSvc.deliverIfApplicable(d);
          if (handled) await _safeAck(recipient, d.fireId);
          continue;
        }
        await _safeAck(recipient, d.fireId);
      }
    }
  }

  Future<void> _safeAck(Uint8List recipient, Uint8List fireId) async {
    try {
      await _relay.ackReminderDelivery(
        recipientIdentity: recipient,
        fireId: fireId,
      );
    } on RelayClientError {
      // Retry on next poll.
    }
  }

  Future<bool> _deliverHousingPaymentReminder(
    RelayPendingReminderDelivery d,
  ) async {
    if (!shouldDisplayHousingPaymentReminderNotification(_prefs)) {
      return true;
    }
    final parsed = parseHousingReminderScopeKey(d.scopeKeyBytes);
    if (parsed == null) return true;
    final (planId, lineId) = parsed;
    final lines = await _db.listPlanLines(planId);
    PlanLine? line;
    for (final l in lines) {
      if (l.id == lineId) {
        line = l;
        break;
      }
    }
    if (line == null) return true;

    if (d.reminderKind == 'overdue') {
      await _db.upsertHousingPaymentOverdueJournalEntry(
        id: '$planId:$lineId:${utf8.decode(d.periodKeyBytes)}:overdue',
        planId: planId,
        planLineId: lineId,
        periodKey: utf8.decode(d.periodKeyBytes),
        periodDueAt: d.periodDueAt ?? DateTime.now().toUtc(),
        recordedAt: DateTime.now().toUtc(),
        reminderKind: 'overdue',
      );
    }

    await PushNotificationService.showLocalHousingPaymentReminderNotification(
      lineTitle: line.title,
      reminderKind: d.reminderKind,
      planId: planId,
      planLineId: lineId,
      periodDueAt: d.periodDueAt ?? DateTime.now().toUtc(),
    );
    if (kDebugMode) {
      final qaNumber = d.reminderKind == 'overdue' ? 11 : 10;
      debugPrint(
        'housingPaymentReminder: delivered kind=${d.reminderKind} qa=#$qaNumber '
        'line=${line.title} planId=$planId',
      );
    }
    return true;
  }

  Future<List<HousingReminderScheduleTarget>> _targetsForLinePeriod({
    required String planId,
    required PlanLine line,
    required List<Participant> roster,
    required Uint8List scopeKey,
    required Uint8List periodKey,
    required SlidingPaymentPeriod period,
    required DateTime? boundAt,
  }) async {
    final out = <HousingReminderScheduleTarget>[];
    final designated = line.paymentResponsibleParticipantId;
    final beforeRecipients = designated == null || designated.isEmpty
        ? roster
        : roster.where((p) => p.id == designated);

    Future<void> addTarget(Participant p, String kind) async {
      final routing = await _routingIdForParticipant(planId, p.id);
      if (routing == null) return;
      out.add(
        HousingReminderScheduleTarget(
          scopeKeyBytes: scopeKey,
          recipientRoutingId: routing,
          reminderKind: kind,
          periodKeyBytes: periodKey,
          recurrencePeriodDays: period.windowDays,
          dueAt: period.dueAtUtc,
          boundAt: boundAt,
        ),
      );
    }

    for (final p in beforeRecipients) {
      await addTarget(p, 'before_due');
    }
    for (final p in roster) {
      await addTarget(p, 'overdue');
    }
    return out;
  }

  Future<Uint8List?> _routingIdForParticipant(
    String planId,
    String participantId,
  ) async {
    if (participantId == selfParticipantIdForPlan(planId)) {
      final selfPub = await _orchestrator.selfLongTermPublicKey();
      final peers = await participantsForPlan(_db, planId);
      for (final p in peers) {
        if (p.id == selfParticipantIdForPlan(planId)) continue;
        if (p.contactId == null) continue;
        final contact = await _contacts.get(p.contactId!);
        if (contact == null || contact.peerPublicMaterial == null) continue;
        try {
          final peerPub = RelayRouting.unb64(contact.peerPublicMaterial!);
          return RelayRouting.steadyStateAddress(
            firstPub: selfPub,
            secondPub: peerPub,
          );
        } catch (_) {
          continue;
        }
      }
      return null;
    }
    final peers = await participantsForPlan(_db, planId);
    Participant? participant;
    for (final p in peers) {
      if (p.id == participantId) {
        participant = p;
        break;
      }
    }
    if (participant?.contactId == null) return null;
    final contact = await _contacts.get(participant!.contactId!);
    final b64 = contact?.relayRoutingId;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return RelayRouting.unb64(b64);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _packageIdForPlan(String planId) async {
    final row = await (_db.select(_db.proposalPackages)
          ..where((t) => t.planId.equals(planId)))
        .getSingleOrNull();
    return row?.id;
  }
}

(String planId, String lineId)? parseHousingReminderScopeKey(Uint8List bytes) {
  final sep = bytes.indexOf(0x1f);
  if (sep < 0) return null;
  return (
    String.fromCharCodes(bytes.sublist(0, sep)),
    String.fromCharCodes(bytes.sublist(sep + 1)),
  );
}

bool shouldDisplayHousingPaymentReminderNotification(AppPreferences prefs) {
  if (!prefs.notificationsEnabled) return false;
  return prefs.notificationHousingPaymentReminders;
}
