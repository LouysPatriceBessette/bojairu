import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../widgets/app_text_field.dart';
import 'package:go_router/go_router.dart';

import '../../db/app_database.dart';
import '../../housing/agreement_rules_json.dart';
import '../../housing/housing_response_deadline_display.dart';
import 'housing_amendment_detail_screen.dart';
import 'housing_plan_missing_contacts_screen.dart';
import '../../housing/amendment/housing_amendment_summary.dart';
import '../../housing/housing_plan_peer_contacts.dart';
import '../../housing/proposals/housing_proposal_revision_state.dart';
import '../../housing/proposals/housing_proposal_transport_service.dart';
import '../../housing/proposals/plan_agreement_proposal_service.dart';
import 'housing_agreement_rules_read_only.dart';
import 'housing_invite_sunburst.dart';
import 'housing_proposal_expenses_detail_screen.dart';
import '../../housing/housing_module_exit.dart';
import '../../l10n/app_localizations.dart';
import '../../debug/qa_housing_proposal_semantics.dart';
import '../../notifications/notification_flow_permission_trigger.dart';
import '../../notifications/push_notification_service.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../util/display_date.dart';
import '../../util/format_money.dart';
import '../../widgets/screen_body_padding.dart';
import 'housing_active_plan_screen.dart';
import 'housing_invitation_status_dialog.dart';
import 'package:compartarenta/navigation/app_navigation.dart';

/// Per-participant response to a housing proposal (local UI state until relay exists).
enum HousingInviteParticipantUiStatus {
  accepted,
  pending,
  negotiating,
  rejected,
}

class _ProposalUiState {
  const _ProposalUiState({
    required this.revisionId,
    required this.activeRevisionId,
    required this.proposerParticipantId,
    required this.responsesByParticipantId,
    required this.payload,
  });

  final String? revisionId;
  final String? activeRevisionId;
  final String proposerParticipantId;
  final Map<String, ProposalResponse> responsesByParticipantId;
  final Map<String, dynamic> payload;
}

/// Full-scroll proposal preview for the plan author, or read-only + response UI for an invitee.
class HousingInviteProposalScreen extends StatefulWidget {
  const HousingInviteProposalScreen({
    super.key,
    required this.db,
    required this.planId,
    required this.prefs,
    this.revisionId,
    this.onSendProposal,

    /// When non-null, this screen simulates that participant’s view (chips locked, response buttons).
    this.viewerParticipantIndex,
  });

  final AppDatabase db;
  final String planId;
  final AppPreferences prefs;
  final String? revisionId;
  final Future<bool> Function(BuildContext context)? onSendProposal;

  /// Roster index (0 = plan author on device). Null = author preview / invitation prep.
  final int? viewerParticipantIndex;

  @override
  State<HousingInviteProposalScreen> createState() =>
      _HousingInviteProposalScreenState();
}

class _HousingInviteProposalScreenState
    extends State<HousingInviteProposalScreen> {
  late Future<List<dynamic>> _proposalFuture;

  int _focusedParticipantIndex = 0;

  final Map<int, HousingInviteParticipantUiStatus> _statusByRosterIndex = {};

  bool _negotiateExpanded = false;
  bool _sendingProposal = false;
  bool _redirectedToAmendment = false;
  String? _displayRevisionId;
  final TextEditingController _negotiateController = TextEditingController();

  bool get _isAuthorPreview => widget.viewerParticipantIndex == null;

  bool get _isDraftSendPreview => widget.onSendProposal != null;

  void _goBack() {
    if (_isDraftSendPreview && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    exitHousingModule(context);
  }

  @override
  void initState() {
    super.initState();
    _proposalFuture = _loadProposalScreenData();
    if (!_isAuthorPreview) {
      _focusedParticipantIndex = widget.viewerParticipantIndex!.clamp(0, 100);
    }
    if (!_isDraftSendPreview) {
      HandshakeOrchestrator.maybeInstance?.steadyStateInboxTick.addListener(
        _onSteadyInboxTick,
      );
    }
  }

  void _onSteadyInboxTick() {
    if (!mounted || _negotiateExpanded || _isDraftSendPreview) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _negotiateExpanded) return;
      setState(() {
        _proposalFuture = _loadProposalScreenData();
      });
    });
  }

  Future<List<dynamic>> _loadProposalScreenData() async {
    final proposal = await _loadProposalUiState();
    final routeAsAmendment =
        proposal.revisionId != null &&
        await pendingRevisionIsAmendment(
          widget.db,
          widget.planId,
          revisionId: proposal.revisionId,
        );
    final rest = await Future.wait<dynamic>([
      widget.db.listParticipants(),
      widget.db.listPlanLines(widget.planId),
      widget.db.getAgreementForPlan(widget.planId),
      widget.db.listPlanRatios(widget.planId),
      widget.db.listPlanGroups(widget.planId),
      Future<_ProposalUiState>.value(proposal),
      listMissingPlanPeerContacts(db: widget.db, planId: widget.planId),
    ]);
    return [...rest, routeAsAmendment];
  }

  void _openMissingContactsHub() {
    navigateToRoute<void>(context, 
          MaterialPageRoute<void>(
            builder: (_) => HousingPlanMissingContactsScreen(
              db: widget.db,
              planId: widget.planId,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          setState(() {
            _proposalFuture = _loadProposalScreenData();
          });
        });
  }

  @override
  void dispose() {
    if (!_isDraftSendPreview) {
      HandshakeOrchestrator.maybeInstance?.steadyStateInboxTick.removeListener(
        _onSteadyInboxTick,
      );
    }
    _negotiateController.dispose();
    super.dispose();
  }

  int _rosterOrder(String id) {
    if (id.endsWith(':self')) return -1;
    final tail = id.split(':p').last;
    return int.tryParse(tail) ?? 999;
  }

  List<Participant> _sortedRoster(List<Participant> all) {
    final roster =
        all
            .where(
              (p) =>
                  p.id == '${widget.planId}:self' ||
                  p.id.startsWith('${widget.planId}:p'),
            )
            .toList()
          ..sort((a, b) => _rosterOrder(a.id).compareTo(_rosterOrder(b.id)));
    return roster;
  }

  HousingInviteParticipantUiStatus _statusFor(int rosterIndex) {
    return _statusByRosterIndex[rosterIndex] ??
        HousingInviteParticipantUiStatus.pending;
  }

  HousingInviteParticipantUiStatus _statusForParticipant(
    Participant participant,
    _ProposalUiState proposal,
  ) {
    final status = proposal.responsesByParticipantId[participant.id]?.status;
    return switch (status) {
      'accepted' => HousingInviteParticipantUiStatus.accepted,
      'negotiate' => HousingInviteParticipantUiStatus.negotiating,
      'rejected' => HousingInviteParticipantUiStatus.rejected,
      _ => HousingInviteParticipantUiStatus.pending,
    };
  }

  bool _allRosterParticipantsAccepted(
    List<Participant> roster,
    _ProposalUiState proposal,
  ) {
    if (proposal.revisionId == null || roster.isEmpty) return false;
    for (final participant in roster) {
      final status = proposal.responsesByParticipantId[participant.id]?.status;
      if (status != ProposalResponseStatus.accepted.name) {
        return false;
      }
    }
    return true;
  }

  String? _settledRevisionId(_ProposalUiState proposal) {
    final active = proposal.activeRevisionId;
    if (active != null && active.isNotEmpty) return active;
    return proposal.revisionId;
  }

  Future<_ProposalUiState> _loadProposalUiState() async {
    final transport = HousingProposalTransportService(widget.db);
    final activeRevisionId = await transport.resolveActiveRevisionIdForPlan(
      widget.planId,
    );
    final pendingRevisionId = await transport.resolvePendingRevisionIdForPlan(
      widget.planId,
    );
    final revisionId =
        widget.revisionId ??
        activeRevisionId ??
        pendingRevisionId ??
        _displayRevisionId;
    if (revisionId == null) {
      return const _ProposalUiState(
        revisionId: null,
        activeRevisionId: null,
        proposerParticipantId: '',
        responsesByParticipantId: <String, ProposalResponse>{},
        payload: <String, dynamic>{},
      );
    }
    await HousingProposalTransportService(widget.db).expireRevisionIfNeeded(
      planId: widget.planId,
      revisionId: revisionId,
    );
    final revision = await (widget.db.select(
      widget.db.proposalRevisions,
    )..where((t) => t.id.equals(revisionId))).getSingle();
    _displayRevisionId = revisionId;
    final responses = await (widget.db.select(
      widget.db.proposalResponses,
    )..where((t) => t.revisionId.equals(revisionId))).get();
    return _ProposalUiState(
      revisionId: revisionId,
      activeRevisionId: activeRevisionId,
      proposerParticipantId: revision.proposerParticipantId,
      responsesByParticipantId: {
        for (final response in responses) response.participantId: response,
      },
      payload: jsonDecode(revision.payloadJson) as Map<String, dynamic>,
    );
  }

  Future<void> _submitResponse(
    ProposalResponseStatus status, {
    String message = '',
    String? revisionId,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (status == ProposalResponseStatus.accepted) {
      final missing = await listMissingPlanPeerContacts(
        db: widget.db,
        planId: widget.planId,
      );
      if (!mounted) return;
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.housingInviteMissingContactsBlocked)),
        );
        return;
      }
    }
    final orchestrator = HandshakeOrchestrator.maybeInstance;
    if (orchestrator == null) {
      if (status == ProposalResponseStatus.negotiate) {
        await PushNotificationService.showLocalHousingResponseFailureNotification(
          errorCode: 'relay_unavailable',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.housingPlanCouldNotContinue('relay'))),
      );
      return;
    }
    if (status == ProposalResponseStatus.negotiate) {
      final notificationResult = await const NotificationFlowPermissionTrigger()
          .ensure(
            context: context,
            prefs: widget.prefs,
            switches: const {
              NotificationFlowSwitch.housingDecisionChange,
              NotificationFlowSwitch.housingOfferExpiration,
            },
          );
      if (notificationResult == NotificationFlowPermissionResult.abortFlow ||
          !mounted) {
        return;
      }
    }
    try {
      final result = await orchestrator.sendHousingProposalResponse(
        planId: widget.planId,
        status: status,
        message: message,
        revisionId: revisionId,
      );
      final relayDelivered = result.sentCount > 0;
      if (!relayDelivered) {
        if (status == ProposalResponseStatus.negotiate) {
          await PushNotificationService.showLocalHousingResponseFailureNotification(
            errorCode: 'send_failed',
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.housingInviteTransportFailed)),
        );
        return;
      }
      if (status == ProposalResponseStatus.negotiate &&
          result.failedParticipantIds.isNotEmpty) {
        await PushNotificationService.showLocalHousingResponseFailureNotification(
          errorCode: 'send_failed',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.housingInviteResponseSent)));
      setState(() {
        _proposalFuture = _loadProposalScreenData();
        _negotiateExpanded = false;
        _negotiateController.clear();
      });
      if (status == ProposalResponseStatus.negotiate) {
        if (mounted) context.go('/');
      }
    } on HandshakeOrchestratorError catch (e) {
      if (status == ProposalResponseStatus.negotiate) {
        await PushNotificationService.showLocalHousingResponseFailureNotification(
          errorCode: e.code,
        );
      }
      if (!mounted) return;
      final message = e.code == 'plan_missing_peer_contacts'
          ? l10n.housingInviteMissingContactsBlocked
          : l10n.housingPlanCouldNotContinue(e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (status == ProposalResponseStatus.negotiate) {
        await PushNotificationService.showLocalHousingResponseFailureNotification(
          errorCode: 'local_error',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.housingPlanCouldNotContinue('$e'))),
      );
    }
  }

  Future<void> _sendFromPreview() async {
    final send = widget.onSendProposal;
    if (send == null || _sendingProposal) return;
    debugPrint('housing_proposal preview send tapped for ${widget.planId}');
    setState(() => _sendingProposal = true);
    final sent = await send(context);
    if (!mounted) return;
    setState(() => _sendingProposal = false);
    if (sent) _goBack();
  }

  void _cancelNegotiation() {
    setState(() {
      _negotiateExpanded = false;
      _negotiateController.clear();
    });
  }

  (Color bg, Color fg) _statusColors(
    ThemeData theme,
    HousingInviteParticipantUiStatus s,
  ) {
    switch (s) {
      case HousingInviteParticipantUiStatus.accepted:
        return (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        );
      case HousingInviteParticipantUiStatus.pending:
        return (
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        );
      case HousingInviteParticipantUiStatus.negotiating:
        return (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        );
      case HousingInviteParticipantUiStatus.rejected:
        return (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
        );
    }
  }

  Widget _participantChip(
    AppLocalizations l10n,
    ThemeData theme,
    int index,
    String label,
    bool enabled,
    bool showParticipantStatus,
  ) {
    final isAuthorRoster = index == 0;
    final selected = _focusedParticipantIndex == index;
    final status = _statusFor(index);
    final (chipBg, chipFg) = isAuthorRoster
        ? (theme.colorScheme.surface, theme.colorScheme.onSurface)
        : (!showParticipantStatus
              ? (
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.onSurface,
                )
              : _statusColors(theme, status));
    final statusLabel = switch (status) {
      HousingInviteParticipantUiStatus.accepted =>
        l10n.housingInviteStatusAccepted,
      HousingInviteParticipantUiStatus.pending =>
        l10n.housingInviteStatusPending,
      HousingInviteParticipantUiStatus.negotiating =>
        l10n.housingInviteStatusNegotiating,
      HousingInviteParticipantUiStatus.rejected =>
        l10n.housingInviteStatusRejected,
    };

    final chip = ChoiceChip(
      selected: selected,
      onSelected: enabled
          ? (v) {
              if (!v) return;
              setState(() => _focusedParticipantIndex = index);
            }
          : null,
      selectedColor: isAuthorRoster
          ? theme.colorScheme.surfaceContainerLowest
          : theme.colorScheme.primaryContainer,
      backgroundColor: chipBg,
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: chipFg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (showParticipantStatus && !isAuthorRoster)
              Text(
                statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: chipFg.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
      ),
    );

    if (showParticipantStatus &&
        !isAuthorRoster &&
        status == HousingInviteParticipantUiStatus.accepted) {
      return qaHousingProposalSemantics(
        identifier: qaHousingInviteParticipantAcceptedSemanticsId(label),
        child: chip,
      );
    }
    return chip;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return FutureBuilder<List<dynamic>>(
      future: _proposalFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(
                title: qaHousingProposalSemantics(
                  identifier: kQaHousingInviteProposalScreen,
                  header: true,
                  child: Text(l10n.housingInviteProposalAppBarTitle),
                ),
              ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
          final roster = _sortedRoster(snap.data![0] as List<Participant>);
          final lines = snap.data![1] as List<PlanLine>;
          final agr = snap.data![2] as Agreement?;
          final ratios = snap.data![3] as List<PlanRatio>;
          final groups = snap.data![4] as List<PlanGroup>;
          final proposal = snap.data![5] as _ProposalUiState;
          final missingPeerContacts = snap.data![6] as List<Participant>;
          final routeAsAmendment = snap.data![7] as bool;
          final hasMissingPeerContacts = missingPeerContacts.isNotEmpty;
          if (agr == null || roster.isEmpty) {
            return Scaffold(
              appBar: AppBar(
                title: qaHousingProposalSemantics(
                  identifier: kQaHousingInviteProposalScreen,
                  header: true,
                  child: Text(l10n.housingInviteProposalAppBarTitle),
                ),
              ),
              body: Center(
                child: Text(l10n.housingPlanSummaryMissingAgreement),
              ),
            );
          }
          final revisionForRoute = proposal.revisionId;
          if (routeAsAmendment && !_redirectedToAmendment) {
            _redirectedToAmendment = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              navigateToRoute<void>(context, 
                MaterialPageRoute<void>(
                  builder: (_) => HousingAmendmentDetailScreen(
                    db: widget.db,
                    planId: widget.planId,
                    prefs: widget.prefs,
                    revisionId: revisionForRoute,
                  ),
                ),
              );
            });
            return const Center(child: CircularProgressIndicator());
          }
          final proposalAgreement = proposal.payload['agreement'] is Map
              ? (proposal.payload['agreement'] as Map).cast<String, dynamic>()
              : const <String, dynamic>{};
          final proposalRulesJson = proposalAgreement['agreementRulesJson']
              ?.toString();
          final proposalClauses = proposalAgreement['clauses']?.toString();
          final rules = AgreementRulesDraft.parseStored(
            agreementRulesJson: proposalRulesJson ?? agr.agreementRulesJson,
            clausesFallback: proposalClauses ?? agr.clauses,
          );
          final pids = roster.map((p) => p.id).toList();
          final idx = pids.isEmpty
              ? 0
              : _focusedParticipantIndex.clamp(0, pids.length - 1);
          final selfParticipantId = '${widget.planId}:self';
          final isAuthor =
              _isDraftSendPreview ||
              proposal.proposerParticipantId == selfParticipantId;
          final selfStatus =
              proposal.responsesByParticipantId[selfParticipantId]?.status ??
              ProposalResponseStatus.pending.name;
          final revisionState = HousingProposalRevisionState.fromPayload(
            proposal.payload,
          );
          final canRespond = housingParticipantMayRespond(
            revision: revisionState,
            participantResponseStatus: selfStatus,
            proposerParticipantId: proposal.proposerParticipantId,
            participantId: selfParticipantId,
          );
          final expiresUtc = revisionState.responseExpiresAtUtc;
          final forkFromId = revisionState.forkedFromRevisionId;
          final showParticipantStatus = proposal.revisionId != null;
          final settledRevisionId = _settledRevisionId(proposal);
          final unanimousAccepted = _allRosterParticipantsAccepted(
            roster,
            proposal,
          );
          if (settledRevisionId != null &&
              (proposal.activeRevisionId != null || unanimousAccepted)) {
            return _HousingUnanimousActiveGate(
              db: widget.db,
              planId: widget.planId,
              prefs: widget.prefs,
              revisionId: settledRevisionId,
            );
          }
          _statusByRosterIndex
            ..clear()
            ..addEntries(
              roster.indexed.map(
                (entry) => MapEntry(
                  entry.$1,
                  _statusForParticipant(entry.$2, proposal),
                ),
              ),
            );
          final dateFmt = effectiveDateFormat(widget.prefs);
          final dateRangeLine =
              '${formatPreferenceDate(agr.periodStart, dateFmt)}${l10n.housingInviteDateRangeSeparator}${formatPreferenceDate(agr.periodEnd, dateFmt)}';
          final sunSlices = buildInviteSunburstSlices(
            lines: lines,
            groups: groups,
            ratios: ratios,
            participantIdsOrdered: pids,
            participantId: pids[idx],
            l10n: l10n,
            displayCurrency: displayCurrencyCodeForPlan(widget.prefs, lines),
          );

          return Scaffold(
            appBar: AppBar(
                title: qaHousingProposalSemantics(
                  identifier: kQaHousingInviteProposalScreen,
                  header: true,
                  child: Text(l10n.housingInviteProposalAppBarTitle),
                ),
              ),
            body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: screenBodyScrollPadding(context),
                  children: [
                    if (isAuthor) ...[
                      Text(
                        _isDraftSendPreview
                            ? l10n.housingInviteProposalIntroTitle
                            : l10n.housingInviteProposalSentIntroTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(height: 32),
                    ],
                    Center(
                      child: Text(
                        l10n.housingInviteHousingAgreementTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        dateRangeLine,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        formatContractCalendarDuration(
                          agr.periodStart,
                          agr.periodEnd,
                          l10n,
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (expiresUtc != null) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: HousingResponseDeadlineDisplay(
                          expiresUtc: expiresUtc,
                          dateFormat: dateFmt,
                          l10n: l10n,
                        ),
                      ),
                    ],
                    if (forkFromId != null && forkFromId.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          l10n.housingInviteForkedFromLabel(forkFromId),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    if (!isAuthor &&
                        !canRespond &&
                        selfStatus ==
                            ProposalResponseStatus.pending.name) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.housingInviteOfferClosedHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      l10n.housingInviteParticipantsSectionTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < roster.length; i++)
                          _participantChip(
                            l10n,
                            theme,
                            i,
                            roster[i].displayName,
                            true,
                            showParticipantStatus,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    HousingInviteSunburstChart(
                      l10n: l10n,
                      slices: sunSlices,
                      participantName: roster[idx].displayName,
                    ),
                    if (lines.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton.tonal(
                          onPressed: () {
                            final dateFmt = effectiveDateFormat(widget.prefs);
                            final currency = displayCurrencyCodeForPlan(
                              widget.prefs,
                              lines,
                            );
                            navigateToChildRoute<void>(context, 
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    HousingProposalExpensesDetailScreen(
                                  db: widget.db,
                                  planId: widget.planId,
                                  participantIds: pids,
                                  participantNames: [
                                    for (final p in roster) p.displayName,
                                  ],
                                  defaultCurrency: currency,
                                  dateFormat: dateFmt,
                                ),
                              ),
                            );
                          },
                          child: Text(l10n.housingInviteViewExpensesDetail),
                        ),
                      ),
                      if (sunburstSlicesHaveMonthlyNormalized(sunSlices))
                        HousingInviteSunburstMonthlyFootnote(l10n: l10n),
                    ],
                    const SizedBox(height: 20),
                    HousingAgreementRulesReadOnlyCard(
                      agr: agr,
                      rules: rules,
                      roster: roster,
                      displayCurrency: displayCurrencyCodeForPlan(
                        widget.prefs,
                        lines,
                      ),
                      firstDayOfWeekIndex: widget.prefs.resolvedFirstDayOfWeekIndex(
                        Localizations.localeOf(context),
                      ),
                    ),
                    if (!isAuthor && canRespond) ...[
                      const SizedBox(height: 24),
                      if (!_negotiateExpanded) ...[
                        Builder(
                          builder: (context) {
                            final acceptAction = canRespond
                                ? (hasMissingPeerContacts
                                      ? _openMissingContactsHub
                                      : () => _submitResponse(
                                          ProposalResponseStatus.accepted,
                                          revisionId: proposal.revisionId,
                                        ))
                                : null;
                            return qaHousingProposalSemantics(
                              identifier: kQaHousingInviteRecipientAccept,
                              button: true,
                              enabled: canRespond,
                              onTap: acceptAction,
                              child: FilledButton(
                                onPressed: acceptAction,
                                child: Text(
                                  hasMissingPeerContacts
                                      ? l10n.housingInviteMissingContactsAction
                                      : l10n.housingInviteAcceptFull,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: canRespond
                              ? () => setState(() => _negotiateExpanded = true)
                              : null,
                          child: Text(l10n.housingInviteNegotiate),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          onPressed: canRespond
                              ? () => _submitResponse(
                                  ProposalResponseStatus.rejected,
                                  revisionId: proposal.revisionId,
                                )
                              : null,
                          child: Text(l10n.housingInviteRejectBlock),
                        ),
                      ] else if (canRespond) ...[
                        AppTextField(
                          controller: _negotiateController,
                          minLines: 3,
                          maxLines: 8,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: l10n.housingInviteNegotiateMessageLabel,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () {
                            final t = _negotiateController.text.trim();
                            if (t.isEmpty) return;
                            _submitResponse(
                              ProposalResponseStatus.negotiate,
                              message: t,
                              revisionId: proposal.revisionId,
                            );
                          },
                          child: Text(l10n.commonSend),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _cancelNegotiation,
                          child: Text(l10n.commonCancel),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isAuthor) ...[
                        OutlinedButton(
                          onPressed: _goBack,
                          child: Text(l10n.housingPlanBack),
                        ),
                        const SizedBox(height: 8),
                        if (_isDraftSendPreview)
                          FilledButton(
                            onPressed: _sendingProposal
                                ? null
                                : _sendFromPreview,
                            child: Text(l10n.housingPlanSummaryInvite),
                          )
                        else
                          FilledButton(
                            onPressed: () => showHousingInvitationStatusDialog(
                              context,
                              db: widget.db,
                              planId: widget.planId,
                              prefs: widget.prefs,
                              revisionId: proposal.revisionId,
                            ),
                            child: Text(
                              l10n.housingInviteInvitationStatusAction,
                            ),
                          ),
                      ] else ...[
                        if (!_negotiateExpanded) ...[
                          OutlinedButton(
                            onPressed: _goBack,
                            child: Text(l10n.housingPlanBack),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => showHousingInvitationStatusDialog(
                              context,
                              db: widget.db,
                              planId: widget.planId,
                              prefs: widget.prefs,
                              revisionId: proposal.revisionId,
                            ),
                            child: Text(
                              l10n.housingInviteInvitationStatusAction,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
            ),
          );
      },
    );
  }
}

/// After unanimous acceptance, opens the operational hub (pass 1) or activates first.
class _HousingUnanimousActiveGate extends StatefulWidget {
  const _HousingUnanimousActiveGate({
    required this.db,
    required this.planId,
    required this.prefs,
    required this.revisionId,
  });

  final AppDatabase db;
  final String planId;
  final AppPreferences prefs;
  final String revisionId;

  @override
  State<_HousingUnanimousActiveGate> createState() =>
      _HousingUnanimousActiveGateState();
}

class _HousingUnanimousActiveGateState extends State<_HousingUnanimousActiveGate> {
  late Future<({String packageId, bool ready})> _readyFuture;

  @override
  void initState() {
    super.initState();
    _readyFuture = _resolveActivePackage();
    HandshakeOrchestrator.maybeInstance?.steadyStateInboxTick.addListener(
      _onSteadyInboxTick,
    );
  }

  @override
  void dispose() {
    HandshakeOrchestrator.maybeInstance?.steadyStateInboxTick.removeListener(
      _onSteadyInboxTick,
    );
    super.dispose();
  }

  void _onSteadyInboxTick() {
    if (!mounted) return;
    setState(() {
      _readyFuture = _resolveActivePackage();
    });
  }

  Future<({String packageId, bool ready})> _resolveActivePackage() async {
    final pkg = await (widget.db.select(widget.db.proposalPackages)
          ..where((t) => t.planId.equals(widget.planId)))
        .getSingleOrNull();
    if (pkg == null) return (packageId: '', ready: false);

    if (pkg.activeRevisionId != null) {
      return (packageId: pkg.id, ready: true);
    }

    final outcome = await HousingProposalTransportService(
      widget.db,
    ).tryActivatePlanIfUnanimous(
      planId: widget.planId,
      revisionId: widget.revisionId,
    );
    if (outcome == ProposalActivationOutcome.activated) {
      await HousingProposalTransportService(
        widget.db,
      ).notifyAgreementActivatedIfNeeded(
        planId: widget.planId,
        revisionId: widget.revisionId,
      );
      return (packageId: pkg.id, ready: true);
    }

    final again = await (widget.db.select(widget.db.proposalPackages)
          ..where((t) => t.planId.equals(widget.planId)))
        .getSingleOrNull();
    return (
      packageId: pkg.id,
      ready: again?.activeRevisionId != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<({String packageId, bool ready})>(
      future: _readyFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
                title: qaHousingProposalSemantics(
                  identifier: kQaHousingInviteProposalScreen,
                  header: true,
                  child: Text(l10n.housingInviteProposalAppBarTitle),
                ),
              ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data;
        if (data != null && data.ready && data.packageId.isNotEmpty) {
          return HousingActivePlanScreen(
            planId: widget.planId,
            packageId: data.packageId,
            prefs: widget.prefs,
          );
        }
        return Scaffold(
          appBar: AppBar(
                title: qaHousingProposalSemantics(
                  identifier: kQaHousingInviteProposalScreen,
                  header: true,
                  child: Text(l10n.housingInviteProposalAppBarTitle),
                ),
              ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.housingInvitePlanActivating,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
