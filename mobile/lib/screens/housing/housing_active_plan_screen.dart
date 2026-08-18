import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../debug/qa_housing_proposal_semantics.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../housing/amendment/housing_amendment_ui_gates.dart';
import '../../housing/amendment/housing_amendment_navigation.dart';
import '../../housing/housing_module_exit.dart';
import '../../housing/housing_navigation_intent.dart';
import '../../housing/renewal/housing_renewal_fork_availability.dart';
import '../../housing/renewal/housing_renewal_fork_navigation.dart';
import '../../housing/reminders/payment_reminder_journal_month.dart';
import '../../housing/settlement/housing_hub_expense_entry.dart';
import '../../housing/settlement/housing_settlement_window.dart';
import '../../housing/participation/housing_participation_change_kind.dart';
import '../../housing/participation/housing_participation_hub_gates.dart';
import '../../housing/participation/housing_participation_membership_service.dart';
import '../../housing/proposals/housing_proposal_transport_service.dart';
import '../../housing/realized_expense/realized_expense_ledger_service.dart';
import '../../housing/realized_expense/realized_expense_participants.dart';
import '../../entitlement/housing_license_lifecycle_sync.dart';
import '../../entitlement/housing_plan_license_access.dart';
import '../../entitlement/module_entitlement_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../sandbox/sandbox_bot_expense.dart';
import '../../sandbox/sandbox_mode.dart';
import '../../util/display_date.dart';
import 'housing_active_plan_read_only_screen.dart';
import 'housing_agreement_renewal_screen.dart';
import 'housing_amendment_request_screen.dart';
import 'housing_participation_change_detail_screen.dart';
import 'housing_balances_screen.dart';
import 'housing_expense_payment_status_screen.dart';
import '../../widgets/balanced_text.dart';
import '../../widgets/screen_body_padding.dart';
import 'housing_journals_screen.dart';
import 'housing_monthly_expenses_screen.dart';
import 'housing_realized_expense_form_screen.dart';
import 'housing_settlement_due_form_screen.dart';
import 'housing_realized_expense_review_list_screen.dart';
import 'housing_realized_expense_review_screen.dart';
import 'widgets/housing_participation_change_banner.dart';
import 'widgets/housing_license_status_banner.dart';
import 'package:compartarenta/navigation/app_navigation.dart';

/// Operational hub for an active housing agreement (menu of actions).
class HousingActivePlanScreen extends StatefulWidget {
  const HousingActivePlanScreen({
    super.key,
    required this.planId,
    required this.packageId,
    this.prefs,
  });

  final String planId;
  final String packageId;
  final AppPreferences? prefs;

  @override
  State<HousingActivePlanScreen> createState() =>
      _HousingActivePlanScreenState();
}

class _HousingActivePlanScreenState extends State<HousingActivePlanScreen>
    with WidgetsBindingObserver {
  Future<_HubHeader?>? _headerFuture;
  _HubHeader? _cachedHeader;
  Future<RealizedExpensePendingSummary>? _pendingExpenseFuture;
  Future<bool>? _pendingAmendmentFuture;
  Future<HousingParticipationHubGates>? _hubGatesFuture;
  Future<HousingHubExpenseEntry>? _hubExpenseEntryFuture;
  Future<bool>? _hubRenewalForkFuture;
  HousingPlanLicenseView? _licenseView;
  bool _renewalForkInProgress = false;
  /// Last resolved banner value; only updated when [_amendmentBannerGeneration] matches.
  bool _hubShowsPendingAmendment = false;
  int _amendmentBannerGeneration = 0;
  bool _openingPendingReview = false;
  bool _openingPendingAmendment = false;
  bool _openingSettledAmendment = false;
  bool _openingParticipationChange = false;
  bool _openingAcceptedExpenses = false;
  HandshakeOrchestrator? _steadyInboxOrchestrator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPendingReviewIfAny();
      _openPendingAmendmentFromNotificationIfAny();
      _openSettledAmendmentFromNotificationIfAny();
      _openAcceptedExpensesFromNotificationIfAny();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _steadyInboxOrchestrator = HandshakeOrchestrator.maybeInstance;
      _steadyInboxOrchestrator?.steadyStateInboxTick.addListener(
        _onSteadyInboxTick,
      );
      HousingNavigationIntent.reviewRequestTick.addListener(
        _onPendingReviewIntent,
      );
      HousingNavigationIntent.openAmendmentTick.addListener(
        _onOpenAmendmentIntent,
      );
      HousingNavigationIntent.openSettledAmendmentTick.addListener(
        _onOpenSettledAmendmentIntent,
      );
      HousingNavigationIntent.openParticipationChangeTick.addListener(
        _onOpenParticipationChangeIntent,
      );
      HousingNavigationIntent.openAcceptedExpensesTick.addListener(
        _onOpenAcceptedExpensesIntent,
      );
      unawaited(_pollHubInboxOnce());
      unawaited(_syncPendingExpenseInboxOnce());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _steadyInboxOrchestrator?.steadyStateInboxTick.removeListener(
      _onSteadyInboxTick,
    );
    _steadyInboxOrchestrator = null;
    HousingNavigationIntent.reviewRequestTick.removeListener(
      _onPendingReviewIntent,
    );
    HousingNavigationIntent.openAmendmentTick.removeListener(
      _onOpenAmendmentIntent,
    );
    HousingNavigationIntent.openSettledAmendmentTick.removeListener(
      _onOpenSettledAmendmentIntent,
    );
    HousingNavigationIntent.openParticipationChangeTick.removeListener(
      _onOpenParticipationChangeIntent,
    );
    HousingNavigationIntent.openAcceptedExpensesTick.removeListener(
      _onOpenAcceptedExpensesIntent,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    ModuleEntitlementController.maybeInstance?.refreshClock();
    unawaited(
      HousingLicenseLifecycleSync.apply(db: AppDatabase.maybeProcessScope),
    );
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openPendingReviewIfAny();
      _openPendingAmendmentFromNotificationIfAny();
      _openSettledAmendmentFromNotificationIfAny();
      _openAcceptedExpensesFromNotificationIfAny();
    });
  }

  void _onOpenSettledAmendmentIntent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openSettledAmendmentFromNotificationIfAny();
      _openParticipationChangeFromNotificationIfAny();
    });
  }

  void _onOpenParticipationChangeIntent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openParticipationChangeFromNotificationIfAny();
    });
  }

  Future<void> _openParticipationChangeFromNotificationIfAny() async {
    if (_openingParticipationChange) return;
    final pending = HousingNavigationIntent.takePendingOpenParticipationChange();
    if (pending == null || pending.planId != widget.planId || !mounted) return;
    _openingParticipationChange = true;
    try {
      if (!mounted) return;
      await navigateToChildRoute<void>(context, 
        MaterialPageRoute<void>(
          builder:
              (_) => HousingParticipationChangeDetailScreen(
                changeId: pending.changeId,
                planId: widget.planId,
                packageId: widget.packageId,
                prefs: widget.prefs,
              ),
        ),
      );
    } finally {
      _openingParticipationChange = false;
      if (mounted) _reload();
    }
  }

  /// One-shot relay poll when the hub opens (web may throttle background delivery).
  Future<void> _pollHubInboxOnce() async {
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      await orch.pollSteadyStateInboxes().catchError((Object e, StackTrace st) {
        debugPrint('housing hub inbox poll: $e\n$st');
      });
    }
    if (mounted) _refreshPendingBanners();
  }

  /// One-shot inbox poll when there are pending realized expenses to settle.
  Future<void> _syncPendingExpenseInboxOnce() async {
    final ledger = RealizedExpenseLedgerService(AppDatabase.processScope);
    final pending = await ledger.pendingSummary(
      packageId: widget.packageId,
      planId: widget.planId,
    );
    if (!mounted) return;
    if (pending.totalPendingCount == 0) return;
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) return;
    await orch.pollSteadyStateInboxes().catchError((Object e, StackTrace st) {
      debugPrint('housing hub realized-expense poll: $e\n$st');
    });
  }

  void _onSteadyInboxTick() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshPendingBanners();
      unawaited(_syncPendingExpenseInboxOnce());
    });
  }

  void _onPendingReviewIntent() {
    if (!mounted) return;
    _refreshPendingBanners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openPendingReviewIfAny();
    });
  }

  void _onOpenAcceptedExpensesIntent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openAcceptedExpensesFromNotificationIfAny();
    });
  }

  void _onOpenAmendmentIntent() {
    if (!mounted) return;
    _refreshPendingBanners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openPendingAmendmentFromNotificationIfAny();
    });
  }

  void _reload() {
    setState(() {
      _headerFuture = _loadHeader().then((header) {
        _cachedHeader = header;
        return header;
      });
    });
    _refreshPendingBanners();
    unawaited(_pollHubInboxOnce());
    unawaited(_syncPendingExpenseInboxOnce());
  }

  /// Updates amendment / expense banners only — does not reset the hub header.
  void _refreshPendingBanners() {
    final db = AppDatabase.maybeProcessScope;
    if (db == null) return;
    setState(() {
      _pendingExpenseFuture = RealizedExpenseLedgerService(
        db,
      ).pendingSummary(packageId: widget.packageId, planId: widget.planId);
      final generation = ++_amendmentBannerGeneration;
      final amendmentBannerFuture = HousingProposalTransportService(
        db,
      ).shouldShowPendingAmendmentHubBanner(widget.planId);
      _pendingAmendmentFuture = amendmentBannerFuture;
      _hubShowsPendingAmendment = false;
      _hubGatesFuture = _loadHubGates();
      _hubExpenseEntryFuture = _loadHubExpenseEntry();
      _hubRenewalForkFuture = _loadRenewalForkAvailable();
      unawaited(_refreshLicenseView());
      unawaited(
        amendmentBannerFuture.then((show) {
          if (!mounted || generation != _amendmentBannerGeneration) return;
          setState(() => _hubShowsPendingAmendment = show);
        }),
      );
    });
  }

  Future<void> _refreshLicenseView() async {
    final view = await HousingLicenseLifecycleSync.viewForPlan(
      planId: widget.planId,
      prefs: widget.prefs,
    );
    if (!mounted) return;
    setState(() => _licenseView = view);
  }

  Future<HousingParticipationHubGates> _loadHubGates() async {
    final prefs = widget.prefs ?? await AppPreferences.load();
    final lang = prefs.languageCode ?? 'en';
    final l10n = lookupAppLocalizations(Locale(lang));
    final result = await HousingParticipationHubGates.compute(
      db: AppDatabase.processScope,
      planId: widget.planId,
      selfParticipantId: selfParticipantIdForPlan(widget.planId),
      ejectionCandidateSubtitle: l10n.housingParticipationChangeEjectionHubSubtitle,
      bannerTextBuilder:
          ({
            required String initiatorName,
            required String? targetName,
            required DateTime? departureDate,
          }) {
            final pending = targetName;
            if (departureDate != null) {
              return l10n.housingParticipationChangeBannerWithdrawal(
                initiatorName,
              );
            }
            if (pending != null && pending.isNotEmpty) {
              return l10n.housingParticipationChangeBannerEjection(
                initiatorName,
                pending,
              );
            }
            return l10n.pushNotificationHousingParticipationChangeBodyFrom(
              initiatorName,
            );
          },
    );
    final broadcastId = result.broadcastEffectiveChangeId;
    if (broadcastId != null) {
      final orch = HandshakeOrchestrator.maybeInstance;
      if (orch != null) {
        await orch.sendParticipationChangeNotify(
          changeId: broadcastId,
          statusWireOverride:
              HousingParticipationChangeStatus.effective.wireValue,
        );
      }
    }
    return result.gates;
  }

  Future<HousingHubExpenseEntry> _loadHubExpenseEntry() async {
    final gates = await (_hubGatesFuture ?? _loadHubGates());
    return resolveHubExpenseEntry(
      AppDatabase.processScope,
      widget.planId,
      participationEnterEnabled: gates.enterExpenseEnabled,
    );
  }

  Future<bool> _loadRenewalForkAvailable() async {
    final gates = await (_hubGatesFuture ?? _loadHubGates());
    if (gates.isPastAgreementForSelf) return false;
    return hubRenewalForkAvailable(AppDatabase.processScope, widget.planId);
  }

  Future<void> _openParticipationChangeDetail(
    BuildContext context,
    String changeId,
  ) async {
    await navigateToChildRoute<void>(context, 
      MaterialPageRoute<void>(
        builder:
            (_) => HousingParticipationChangeDetailScreen(
              changeId: changeId,
              planId: widget.planId,
              packageId: widget.packageId,
              prefs: widget.prefs,
            ),
      ),
    );
    if (mounted) _reload();
  }

  /// Resolves pending amendment at tap time (not from a cached [FutureBuilder]).
  Future<void> _openMajorChange(BuildContext context) async {
    final prefs = widget.prefs ?? await AppPreferences.load();
    if (!context.mounted) return;
    await navigateToChildRoute<void>(context, 
      MaterialPageRoute<void>(
        builder:
            (_) => HousingAgreementRenewalScreen(
              planId: widget.planId,
              packageId: widget.packageId,
              prefs: prefs,
            ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _onAmendmentHubTap(BuildContext context) async {
    final db = AppDatabase.processScope;
    final transport = HousingProposalTransportService(db);
    final prefs = widget.prefs ?? await AppPreferences.load();
    final hasPending =
        await transport.hasPendingAmendmentForUi(widget.planId);
    if (!context.mounted) return;

    if (hasPending) {
      final pendingId = await transport.pendingRevisionIdForPlan(widget.planId);
      if (!context.mounted) return;
      await openHousingPendingProposalOrAmendment(
        context,
        db: db,
        planId: widget.planId,
        prefs: prefs,
        revisionId: pendingId,
        isAmendment: true,
      );
    } else {
      await navigateToChildRoute<void>(context, 
        MaterialPageRoute<void>(
          builder: (_) => HousingAmendmentRequestScreen(
            planId: widget.planId,
            prefs: prefs,
          ),
        ),
      );
    }
    if (mounted) _reload();
  }

  Future<void> _openJournals(BuildContext context) async {
    final prefs = widget.prefs ?? await AppPreferences.load();
    if (!context.mounted) return;
    await navigateToChildRoute<void>(context, 
      MaterialPageRoute<void>(
        builder: (_) => HousingJournalsScreen(
          packageId: widget.packageId,
          planId: widget.planId,
          prefs: prefs,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<_HubHeader?> _loadHeader() async {
    final db = AppDatabase.processScope;
    final plan = await (db.select(
      db.plans,
    )..where((t) => t.id.equals(widget.planId))).getSingleOrNull();
    final agreement = await db.getAgreementForPlan(widget.planId);
    if (plan == null || agreement == null) return null;
    final prefs = widget.prefs ?? await AppPreferences.load();
    final lang = prefs.languageCode ?? 'en';
    final l10n = lookupAppLocalizations(Locale(lang));
    final dateFmt = effectiveDateFormat(prefs);
    final selfId = selfParticipantIdForPlan(widget.planId);
    final titleParts = await HousingParticipationMembershipService(
      db,
    ).hubTitleParts(
      planId: widget.planId,
      selfParticipantId: selfId,
      activeHubTitleL10n: l10n.housingActiveHubTitle,
      pastHubTitleL10n: l10n.housingPastHubTitle,
      formatDate: (d) => formatPreferenceDate(d, dateFmt),
    );
    return _HubHeader(
      titlePrefix: titleParts.titlePrefix,
      periodRange: titleParts.periodRange,
      currency: plan.currency.trim().isEmpty ? prefs.currency : plan.currency,
    );
  }

  Future<void> _openPendingAmendmentFromNotificationIfAny() async {
    if (_openingPendingAmendment) return;
    final planId = HousingNavigationIntent.takePendingOpenAmendmentPlanId();
    if (planId == null || planId != widget.planId || !mounted) return;
    _openingPendingAmendment = true;
    try {
      final db = AppDatabase.processScope;
      final prefs = widget.prefs ?? await AppPreferences.load();
      final transport = HousingProposalTransportService(db);
      if (!await transport.hasPendingAmendmentForUi(widget.planId)) {
        return;
      }
      if (!mounted) return;
      await openHousingPendingProposalOrAmendment(
        context,
        db: db,
        planId: widget.planId,
        prefs: prefs,
        isAmendment: true,
      );
    } finally {
      _openingPendingAmendment = false;
      if (mounted) _reload();
    }
  }

  Future<void> _openSettledAmendmentFromNotificationIfAny() async {
    if (_openingSettledAmendment) return;
    final pending = HousingNavigationIntent.takePendingOpenSettledAmendment();
    if (pending == null || pending.planId != widget.planId || !mounted) return;
    _openingSettledAmendment = true;
    try {
      final db = AppDatabase.processScope;
      final prefs = widget.prefs ?? await AppPreferences.load();
      if (!mounted) return;
      await openHousingSettledAmendmentDetail(
        context,
        db: db,
        planId: widget.planId,
        prefs: prefs,
        revisionId: pending.revisionId,
      );
    } finally {
      _openingSettledAmendment = false;
      if (mounted) _reload();
    }
  }

  void _openPendingReviewIfAny() {
    if (_openingPendingReview) return;
    final expenseId = HousingNavigationIntent.takePendingReview();
    if (expenseId == null || !mounted) return;
    _openingPendingReview = true;
    navigateToChildRoute<void>(context, 
          MaterialPageRoute<void>(
            builder: (_) => HousingRealizedExpenseReviewScreen(
              expenseId: expenseId,
              planId: widget.planId,
              packageId: widget.packageId,
              prefs: widget.prefs,
            ),
          ),
        )
        .then((_) {
          _openingPendingReview = false;
          if (mounted) _reload();
        })
        .catchError((_) {
          _openingPendingReview = false;
        });
  }

  Future<void> _openAcceptedExpensesFromNotificationIfAny() async {
    if (_openingAcceptedExpenses) return;
    final planId =
        HousingNavigationIntent.takePendingOpenAcceptedExpensesPlanId();
    if (planId == null || planId != widget.planId || !mounted) return;
    _openingAcceptedExpenses = true;
    try {
      final db = AppDatabase.processScope;
      final prefs = widget.prefs ?? await AppPreferences.load();
      final entries =
          await db.listHousingPaymentOverdueJournalForPlan(widget.planId);
      DateTime? focusMonth;
      if (entries.isNotEmpty) {
        focusMonth = journalMonthForHousingPaymentReminder(entries.first);
      }
      if (!mounted) return;
      await navigateToChildRoute<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => HousingMonthlyExpensesScreen(
            packageId: widget.packageId,
            planId: widget.planId,
            prefs: prefs,
            initialMonth: focusMonth,
          ),
        ),
      );
    } finally {
      _openingAcceptedExpenses = false;
      if (mounted) _reload();
    }
  }

  Future<void> _openReviewList(BuildContext context) async {
    await navigateToChildRoute<void>(context, 
      MaterialPageRoute<void>(
        builder: (_) => HousingRealizedExpenseReviewListScreen(
          planId: widget.planId,
          packageId: widget.packageId,
          prefs: widget.prefs,
        ),
      ),
    );
    if (mounted) _reload();
  }

  int _graceDaysRemaining(HousingPlanLicenseView view) {
    final end = view.graceEndsAt;
    if (end == null) return 1;
    final remaining = end.toUtc().difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 1;
    final days = remaining.inDays;
    return days < 1 ? 1 : days;
  }

  Future<void> _openEnterExpense(BuildContext context) async {
    if (_licenseView?.allowsNewRealizedExpense == false) return;
    final entry = await (_hubExpenseEntryFuture ?? _loadHubExpenseEntry());
    if (!context.mounted) return;
    switch (entry.mode) {
      case HousingHubExpenseEntryMode.enterExpense:
        await navigateToChildRoute<void>(context,
          MaterialPageRoute<void>(
            builder: (_) => HousingRealizedExpenseFormScreen(
              planId: widget.planId,
              packageId: widget.packageId,
              prefs: widget.prefs,
            ),
          ),
        );
      case HousingHubExpenseEntryMode.settlementDue:
        await navigateToChildRoute<void>(context,
          MaterialPageRoute<void>(
            builder: (_) => HousingSettlementDueFormScreen(
              planId: widget.planId,
              packageId: widget.packageId,
              prefs: widget.prefs,
            ),
          ),
        );
      case HousingHubExpenseEntryMode.disabled:
        return;
    }
    if (mounted) _reload();
  }

  Future<void> _startRenewalFork(BuildContext context) async {
    if (_renewalForkInProgress) return;
    setState(() => _renewalForkInProgress = true);
    try {
      final prefs = widget.prefs ?? await AppPreferences.load();
      if (!context.mounted) return;
      await startHousingRenewalForkFromActiveRevision(
        context: context,
        db: AppDatabase.processScope,
        listPlanId: widget.planId,
        prefs: prefs,
      );
    } finally {
      if (mounted) {
        setState(() => _renewalForkInProgress = false);
        _reload();
      }
    }
  }

  void _handleHubBack(BuildContext context) => exitHousingModule(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hub = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleHubBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: qaHousingProposalSemantics(
            identifier: kQaHousingHubBack,
            button: true,
            onTap: () => _handleHubBack(context),
            child: BackButton(onPressed: () => _handleHubBack(context)),
          ),
          title: FutureBuilder<_HubHeader?>(
            future: _headerFuture,
            builder: (context, snap) {
              final header = snap.data;
              final title = header == null
                  ? l10n.housingActiveHubTitle
                  : '${header.titlePrefix}: ${header.periodRange}';
              return Text(title, maxLines: 1, overflow: TextOverflow.ellipsis);
            },
          ),
        ),
        body: FutureBuilder<_HubHeader?>(
          future: _headerFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done &&
                _cachedHeader == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final header = snap.data ?? _cachedHeader;
            return FutureBuilder<RealizedExpensePendingSummary>(
              future: _pendingExpenseFuture,
              builder: (context, pendingSnap) {
                final pending =
                    pendingSnap.data ??
                    const RealizedExpensePendingSummary(
                      waitingForYouCount: 0,
                      waitingForOthersCount: 0,
                    );
                return FutureBuilder<bool>(
                  future: _pendingAmendmentFuture,
                  builder: (context, amendmentSnap) {
                    final hasPendingAmendment =
                        amendmentSnap.connectionState == ConnectionState.done
                            ? amendmentSnap.data == true
                            : _hubShowsPendingAmendment;
                    return FutureBuilder<HousingParticipationHubGates>(
                      future: _hubGatesFuture,
                      builder: (context, gatesSnap) {
                        final gates =
                            gatesSnap.data ??
                            const HousingParticipationHubGates(
                              showParticipationBanner: false,
                              enterExpenseEnabled: true,
                              requestAmendmentEnabled: true,
                              majorChangeEnabled: true,
                              isPastAgreementForSelf: false,
                              pendingChangeId: null,
                              isEjectionCandidate: false,
                            );
                        final ejectionCandidateSubtitle =
                            gates.isEjectionCandidate
                                ? gates.majorChangeSubtitle
                                : null;
                        return ListView(
                          padding: screenBodyScrollPadding(context),
                          children: [
                            if (hasPendingAmendment)
                              Card(
                                color: Theme.of(
                                  context,
                                ).colorScheme.tertiaryContainer,
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.edit_notifications_outlined,
                                  ),
                                  title: Text(
                                    l10n.housingActiveHubPendingAmendment,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _onAmendmentHubTap(context),
                                ),
                              ),
                            if (gates.showParticipationBanner &&
                                gates.participationBannerText != null)
                              HousingParticipationChangeBanner(
                                text: gates.participationBannerText!,
                                onTap:
                                    gates.pendingChangeId == null
                                        ? null
                                        : () => _openParticipationChangeDetail(
                                          context,
                                          gates.pendingChangeId!,
                                        ),
                              ),
                            if (_licenseView?.showReadonlyBanner == true)
                              HousingLicenseStatusBanner(
                                readonly: true,
                                body: l10n.housingLicenseReadonlyBannerBody,
                              )
                            else if (_licenseView?.showGraceBanner == true)
                              HousingLicenseStatusBanner(
                                readonly: false,
                                body: l10n.housingLicenseGraceBannerBody(
                                  _graceDaysRemaining(_licenseView!),
                                  formatPreferenceDate(
                                    _licenseView!.graceEndsAt,
                                    widget.prefs == null
                                        ? 'YYYY-MM-DD'
                                        : effectiveDateFormat(widget.prefs!),
                                  ),
                                ),
                              ),
                            if (pending.totalPendingCount > 0)
                              Card(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ListTile(
                                  leading: const Icon(Icons.pending_actions),
                                  title: Text(
                                    l10n.housingActiveHubReviewPending(
                                      pending.totalPendingCount,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openReviewList(context),
                                ),
                              ),
                            _HubTile(
                              icon: Icons.description_outlined,
                              label: l10n.housingActiveHubViewPlan,
                              onTap: () async {
                                final prefs =
                                    widget.prefs ?? await AppPreferences.load();
                                if (!context.mounted) return;
                                await navigateToChildRoute<void>(context, 
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) => HousingActivePlanReadOnlyScreen(
                                          planId: widget.planId,
                                          prefs: prefs,
                                        ),
                                  ),
                                );
                              },
                            ),
                            FutureBuilder<bool>(
                              future: _hubRenewalForkFuture,
                              builder: (context, forkSnap) {
                                if (forkSnap.data != true) {
                                  return const SizedBox.shrink();
                                }
                                return _HubTile(
                                  icon: Icons.fork_right_outlined,
                                  label: l10n.housingAgreementRenewalFork,
                                  enabled: !_renewalForkInProgress,
                                  semanticsIdentifier:
                                      kDebugMode
                                          ? 'qa-housing-hub-renewal-fork'
                                          : null,
                                  onTap: () => _startRenewalFork(context),
                                );
                              },
                            ),
                            const _HubSectionDivider(),
                            if (widget.prefs != null &&
                                SandboxMode.isActive(widget.prefs!))
                              _HubTile(
                                icon: Icons.smart_toy_outlined,
                                label: l10n.sandboxBotExpenseTitle,
                                subtitle: l10n.sandboxBotExpenseSubtitle,
                                enabled:
                                    _licenseView?.allowsNewRealizedExpense ??
                                    true,
                                onTap: () => _onSandboxBotExpense(context),
                              ),
                            FutureBuilder<HousingHubExpenseEntry>(
                              future: _hubExpenseEntryFuture,
                              builder: (context, expenseEntrySnap) {
                                final entry =
                                    expenseEntrySnap.data ??
                                    const HousingHubExpenseEntry(
                                      mode: HousingHubExpenseEntryMode.disabled,
                                    );
                                final expenseLabel = switch (entry.mode) {
                                  HousingHubExpenseEntryMode.settlementDue =>
                                    l10n.housingActiveHubEnterSettlementDue,
                                  _ => l10n.housingActiveHubEnterExpense,
                                };
                                final expenseEnabled =
                                    entry.mode !=
                                        HousingHubExpenseEntryMode.disabled &&
                                    gates.enterExpenseEnabled &&
                                    (_licenseView?.allowsNewRealizedExpense ??
                                        true);
                                final prefs = widget.prefs;
                                String? settlementSubtitle;
                                if (entry.mode ==
                                        HousingHubExpenseEntryMode.settlementDue &&
                                    entry.settlementWindowEnd != null &&
                                    prefs != null) {
                                  settlementSubtitle =
                                      l10n.housingActiveHubSettlementAvailableUntil(
                                        formatPreferenceDate(
                                          entry.settlementWindowEnd!,
                                          effectiveDateFormat(prefs),
                                        ),
                                      );
                                }
                                final expenseSubtitle =
                                    settlementSubtitle ?? ejectionCandidateSubtitle;
                                final expenseSubtitleColor =
                                    settlementSubtitle != null
                                        ? null
                                        : (ejectionCandidateSubtitle != null
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .error
                                            : null);
                                return _HubTile(
                                  icon: Icons.add_card_outlined,
                                  label: expenseLabel,
                                  enabled: expenseEnabled,
                                  subtitle: expenseSubtitle,
                                  subtitleColor: expenseSubtitleColor,
                                  semanticsIdentifier:
                                      kDebugMode
                                          ? switch (entry.mode) {
                                            HousingHubExpenseEntryMode
                                                .settlementDue =>
                                              (entry.settlementWindowEnd !=
                                                          null &&
                                                      isSettlementWindowLastDay(
                                                        settlementWindowEnd:
                                                            entry
                                                                .settlementWindowEnd!,
                                                      ))
                                                  ? 'qa-housing-hub-settlement-last-day'
                                                  : 'qa-housing-hub-settlement-due',
                                            HousingHubExpenseEntryMode
                                                .enterExpense =>
                                              'qa-housing-hub-enter-expense',
                                            HousingHubExpenseEntryMode
                                                .disabled =>
                                              'qa-housing-hub-expense-disabled',
                                          }
                                          : null,
                                  onTap: () => _openEnterExpense(context),
                                );
                              },
                            ),
                            const _HubSectionDivider(),
                            _HubTile(
                              icon: Icons.account_balance_wallet_outlined,
                              label: l10n.housingActiveHubBalances,
                              onTap: () {
                                if (header == null) return;
                                navigateToChildRoute<void>(context, 
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) => HousingBalancesScreen(
                                          planId: widget.planId,
                                          currency: header.currency,
                                        ),
                                  ),
                                );
                              },
                            ),
                            _HubTile(
                              icon: Icons.bar_chart_outlined,
                              label: l10n.housingActiveHubPaymentStatus,
                              onTap: () {
                                navigateToChildRoute<void>(context, 
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) => HousingExpensePaymentStatusScreen(
                                          packageId: widget.packageId,
                                          planId: widget.planId,
                                          prefs: widget.prefs,
                                        ),
                                  ),
                                );
                              },
                            ),
                            const _HubSectionDivider(),
                            _HubTile(
                              icon: Icons.edit_note_outlined,
                              label:
                                  hasPendingAmendment
                                      ? l10n.housingActiveHubViewPendingAmendment
                                      : l10n.housingActiveHubRequestAmendment,
                              enabled: gates.requestAmendmentEnabled,
                              subtitle: ejectionCandidateSubtitle,
                              subtitleColor:
                                  Theme.of(context).colorScheme.error,
                              onTap: () => _onAmendmentHubTap(context),
                            ),
                            _HubTile(
                              icon: Icons.groups_outlined,
                              label: l10n.housingAmendmentRosterChangeTitle,
                              enabled:
                                  HousingAmendmentUiGates.rosterChangeEnabled &&
                                  gates.majorChangeEnabled &&
                                  !(widget.prefs != null &&
                                      SandboxMode.isActive(widget.prefs!)),
                              subtitle: ejectionCandidateSubtitle,
                              subtitleColor:
                                  Theme.of(context).colorScheme.error,
                              onTap: () => _openMajorChange(context),
                            ),
                            const _HubSectionDivider(),
                            _HubTile(
                              icon: Icons.menu_book_outlined,
                              label: l10n.housingActiveHubJournals,
                              semanticsIdentifier:
                                  kDebugMode ? kQaHousingHubJournals : null,
                              onTap: () => _openJournals(context),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );

    if (!kDebugMode) return hub;
    return Semantics(
      identifier: kQaHousingActiveHub,
      container: true,
      child: hub,
    );
  }

  Future<void> _onSandboxBotExpense(BuildContext context) async {
    if (_licenseView?.allowsNewRealizedExpense == false) return;
    final prefs = widget.prefs ?? await AppPreferences.load();
    if (!context.mounted) return;
    try {
      await SandboxBotExpense.simulateRandomBotExpense(
        planId: widget.planId,
        prefs: prefs,
      );
      if (!context.mounted) return;
      setState(() {
        _pendingExpenseFuture = RealizedExpenseLedgerService(
          AppDatabase.processScope,
        ).pendingSummary(
          packageId: widget.packageId,
          planId: widget.planId,
        );
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

class _HubHeader {
  const _HubHeader({
    required this.titlePrefix,
    required this.periodRange,
    required this.currency,
  });

  final String titlePrefix;
  final String periodRange;
  final String currency;
}

class _HubSectionDivider extends StatelessWidget {
  const _HubSectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.subtitle,
    this.subtitleColor,
    this.semanticsIdentifier,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final String? subtitle;
  final Color? subtitleColor;
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final tile = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: BalancedText(label),
        subtitle:
            subtitle == null
                ? null
                : Text(
                  subtitle!,
                  style: TextStyle(color: subtitleColor),
                ),
        trailing: const Icon(Icons.chevron_right),
        enabled: enabled,
        onTap: enabled ? onTap : null,
      ),
    );
    if (semanticsIdentifier == null) return tile;
    return Semantics(
      identifier: semanticsIdentifier,
      button: true,
      label: label,
      excludeSemantics: true,
      child: tile,
    );
  }
}
