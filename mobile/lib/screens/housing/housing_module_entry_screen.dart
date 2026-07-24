import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../../housing/amendment/housing_amendment_navigation.dart';
import '../../housing/amendment/housing_amendment_summary.dart';
import '../../housing/housing_module_exit.dart';
import '../../housing/housing_inline_draft_plan.dart';
import '../../housing/housing_navigation_intent.dart';
import '../../housing/proposals/housing_proposal_transport_service.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import 'housing_active_plan_screen.dart';
import 'housing_archive_entry_screen.dart';
import 'housing_invite_proposal_screen.dart';
import 'housing_plan_missing_contacts_screen.dart';
import 'housing_plan_screen.dart';
import 'housing_past_agreement_entry_screen.dart';
import 'housing_participation_change_detail_screen.dart';
import 'housing_workbench_screen.dart';
import '../../housing/participation/housing_participation_change_service.dart';
import '../../housing/participation/housing_participation_membership_service.dart';
import 'package:compartarenta/navigation/app_navigation.dart';

/// Housing [Plan] rows where this device has a `planId:self` participant.
Future<List<Plan>> housingPlansWithSelfParticipant(AppDatabase db) async {
  final housing = await (db.select(
    db.plans,
  )..where((t) => t.type.equals('housing'))).get();
  final transport = HousingProposalTransportService(db);
  final out = <Plan>[];
  for (final p in housing) {
    if (await transport.isHiddenDraftPlan(p.id)) continue;
    final self = await (db.select(
      db.participants,
    )..where((t) => t.id.equals('${p.id}:self'))).getSingleOrNull();
    if (self == null) continue;
    if (!await transport.hasActiveRevision(p.id) &&
        await transport.anyOtherHousingPlanHasActiveRevision(
          exceptPlanId: p.id,
        )) {
      continue;
    }
    out.add(p);
  }
  return out;
}

class _HousingEntrySnapshot {
  const _HousingEntrySnapshot({
    required this.plans,
    this.package,
    this.pendingRevisionId,
    this.hasArchives = false,
    this.primaryActivePlan,
    this.primaryActivePackage,
    this.primaryActivePlanIsPastForSelf = false,
    this.inlineDraftPlanId,
  });

  final List<Plan> plans;
  final ProposalPackage? package;
  final String? pendingRevisionId;
  final bool hasArchives;
  /// When exactly one housing plan has an in-force agreement, open its hub.
  final Plan? primaryActivePlan;
  final ProposalPackage? primaryActivePackage;
  final bool primaryActivePlanIsPastForSelf;
  /// Stable wizard plan id while [plans] is still empty (no `:self` row yet).
  final String? inlineDraftPlanId;
}

/// Routes to [HousingWorkbenchScreen] when there is more than one housing plan
/// with a local self row; otherwise opens [HousingPlanScreen] directly.
class HousingModuleEntryScreen extends StatefulWidget {
  const HousingModuleEntryScreen({super.key, required this.prefs});

  final AppPreferences prefs;

  @override
  State<HousingModuleEntryScreen> createState() =>
      _HousingModuleEntryScreenState();
}

class _HousingModuleEntryScreenState extends State<HousingModuleEntryScreen> {
  /// Must be stable across rebuilds — a new [Future] each [build] restarts
  /// [FutureBuilder] forever (visible as a flickering screen).
  Future<_HousingEntrySnapshot>? _entryFuture;
  int _workbenchReloadToken = 0;
  String? _inlineDraftPlanId;

  @override
  void initState() {
    super.initState();
    _entryFuture = _loadEntry();
    // Register after the first frame so an inbox tick during build cannot
    // call setState while the route is still mounting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HousingNavigationIntent.openAmendmentTick.addListener(
        _onOpenAmendmentIntent,
      );
      HousingNavigationIntent.openProposalTick.addListener(
        _onOpenProposalIntent,
      );
      HousingNavigationIntent.openParticipationChangeTick.addListener(
        _onOpenParticipationChangeIntent,
      );
      HousingNavigationIntent.openMissingContactsTick.addListener(
        _onOpenMissingContactsIntent,
      );
      HousingNavigationIntent.openActiveHubTick.addListener(
        _onOpenActiveHubIntent,
      );
      HousingNavigationIntent.entryReloadTick.addListener(_onEntryReloadIntent);
      HandshakeOrchestrator.maybeInstance?.steadyStateInboxTick.addListener(
        _onSteadyInboxTick,
      );
      _openPendingAmendmentFromNotificationIfAny();
      _openPendingProposalFromNotificationIfAny();
      _openParticipationChangeFromNotificationIfAny();
      _openMissingContactsFromNotificationIfAny();
      _openActiveHubFromNotificationIfAny();
    });
  }

  @override
  void dispose() {
    HousingNavigationIntent.openAmendmentTick.removeListener(
      _onOpenAmendmentIntent,
    );
    HousingNavigationIntent.openProposalTick.removeListener(
      _onOpenProposalIntent,
    );
    HousingNavigationIntent.openParticipationChangeTick.removeListener(
      _onOpenParticipationChangeIntent,
    );
    HousingNavigationIntent.openMissingContactsTick.removeListener(
      _onOpenMissingContactsIntent,
    );
    HousingNavigationIntent.openActiveHubTick.removeListener(
      _onOpenActiveHubIntent,
    );
    HousingNavigationIntent.entryReloadTick.removeListener(
      _onEntryReloadIntent,
    );
    HandshakeOrchestrator.maybeInstance?.steadyStateInboxTick.removeListener(
      _onSteadyInboxTick,
    );
    super.dispose();
  }

  void _onSteadyInboxTick() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reloadEntry();
    });
  }

  void _onEntryReloadIntent() {
    if (!mounted) return;
    _reloadEntry();
  }

  void _onOpenParticipationChangeIntent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openParticipationChangeFromNotificationIfAny();
    });
  }

  void _onOpenAmendmentIntent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openPendingAmendmentFromNotificationIfAny();
    });
  }

  void _onOpenProposalIntent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openPendingProposalFromNotificationIfAny();
    });
  }

  void _onOpenMissingContactsIntent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openMissingContactsFromNotificationIfAny();
    });
  }

  void _onOpenActiveHubIntent() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openActiveHubFromNotificationIfAny();
    });
  }

  Future<void> _openActiveHubFromNotificationIfAny() async {
    final planId = HousingNavigationIntent.takePendingOpenActiveHubPlanId();
    if (planId == null || planId.isEmpty || !mounted) return;
    final db = AppDatabase.processScope;
    final transport = HousingProposalTransportService(db);
    if (!await transport.hasActiveRevision(planId)) {
      _reloadEntry();
      return;
    }
    if (!mounted) return;
    // Drop amendment/proposal overlays so the entry body's hub is visible.
    // Do not pushReplacement another [HousingActivePlanScreen] (duplicate hub
    // left "Modifier le plan" under the stack → extra Back).
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
    if (mounted) _reloadEntry();
  }

  Future<void> _openMissingContactsFromNotificationIfAny() async {
    var planId = HousingNavigationIntent.takePendingOpenMissingContactsPlanId();
    if (!mounted) return;
    final db = AppDatabase.processScope;
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      await orch.pollSteadyStateInboxes().catchError((Object e, StackTrace st) {
        debugPrint('housing missing contacts open poll: $e\n$st');
      });
    }
    if (planId == null || planId.isEmpty) {
      for (final row in await db.listAllPlanPeerEstablishments()) {
        if (row.inboundPendingAt != null) {
          planId = row.planId;
          break;
        }
      }
    }
    if (planId == null || planId.isEmpty) {
      debugPrint('housing: notification tap but no pending missing-contacts plan');
      return;
    }
    if (!mounted) return;
    await navigateToRoute<void>(context, 
      MaterialPageRoute<void>(
        builder: (_) => HousingPlanMissingContactsScreen(
          db: db,
          planId: planId!,
        ),
      ),
    );
    if (mounted) _reloadEntry();
  }

  Future<void> _openPendingAmendmentFromNotificationIfAny() async {
    var planId = HousingNavigationIntent.takePendingOpenAmendmentPlanId();
    if (!mounted) return;
    final db = AppDatabase.processScope;
    final transport = HousingProposalTransportService(db);
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      await orch.pollSteadyStateInboxes().catchError((Object e, StackTrace st) {
        debugPrint('housing amendment open poll: $e\n$st');
      });
    }
    planId ??= await transport.housingPlanIdWithAmendmentAwaitingLocalResponse();
    if (planId == null) {
      debugPrint('housing: notification tap but no pending amendment plan');
      return;
    }
    final pendingId = await transport.pendingRevisionIdForPlan(planId);
    if (pendingId == null) {
      debugPrint('housing: no pendingRevisionId on plan $planId');
      return;
    }
    if (!mounted) return;
    await openHousingPendingProposalOrAmendment(
      context,
      db: db,
      planId: planId,
      prefs: widget.prefs,
      revisionId: pendingId,
      isAmendment: true,
    );
    if (mounted) _reloadEntry();
  }

  Future<void> _openPendingProposalFromNotificationIfAny() async {
    final planId = HousingNavigationIntent.takePendingOpenProposalPlanId();
    if (planId == null || planId.isEmpty) {
      // No notification intent — [build] already routes to the invite screen.
      return;
    }
    if (!mounted) return;
    final db = AppDatabase.processScope;
    final transport = HousingProposalTransportService(db);
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      await orch.pollSteadyStateInboxes().catchError((Object e, StackTrace st) {
        debugPrint('housing proposal open poll: $e\n$st');
      });
    }
    final pendingId = await transport.resolvePendingRevisionIdForPlan(planId);
    if (pendingId == null) {
      final pkg = await (db.select(db.proposalPackages)
            ..where((t) => t.planId.equals(planId)))
          .getSingleOrNull();
      debugPrint(
        'housing: no pendingRevisionId on plan $planId '
        '(proposalPackage=${pkg == null ? 'missing' : 'present'})',
      );
      return;
    }
    if (!mounted) return;
    if (await _moduleEntryWouldShowPendingProposalInvite(db, planId)) {
      return;
    }
    if (!mounted) return;
    await openHousingPendingProposalOrAmendment(
      context,
      db: db,
      planId: planId,
      prefs: widget.prefs,
      revisionId: pendingId,
      isAmendment: false,
    );
    if (mounted) _reloadEntry();
  }

  /// Whether [build] already embeds [HousingInviteProposalScreen] for [planId].
  Future<bool> _moduleEntryWouldShowPendingProposalInvite(
    AppDatabase db,
    String planId,
  ) async {
    final plans = await housingPlansWithSelfParticipant(db);
    if (plans.length != 1 || plans.single.id != planId) return false;
    final transport = HousingProposalTransportService(db);
    if (await transport.hasActiveRevision(planId)) return false;
    final pendingId = await transport.resolvePendingRevisionIdForPlan(planId);
    if (pendingId == null) return false;
    return !(await pendingRevisionIsAmendment(
      db,
      planId,
      revisionId: pendingId,
      reconcileFirst: false,
    ));
  }

  Future<void> _openParticipationChangeFromNotificationIfAny() async {
    final pending = HousingNavigationIntent.takePendingOpenParticipationChange();
    if (pending == null || !mounted) return;
    final db = AppDatabase.processScope;
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      await orch.pollSteadyStateInboxes().catchError((Object e, StackTrace st) {
        debugPrint('housing participation change open poll: $e\n$st');
      });
    }
    final change = await HousingParticipationChangeService(db).getById(
      pending.changeId,
    );
    if (change == null || !mounted) return;
    await navigateToRoute<void>(context, 
      MaterialPageRoute<void>(
        builder:
            (_) => HousingParticipationChangeDetailScreen(
              changeId: pending.changeId,
              planId: pending.planId,
              packageId: change.packageId,
              prefs: widget.prefs,
            ),
      ),
    );
    if (mounted) _reloadEntry();
  }

  void _reloadEntry() {
    setState(() {
      _workbenchReloadToken++;
      _entryFuture = _loadEntry();
    });
  }

  Future<_HousingEntrySnapshot> _loadEntry() async {
    final db = AppDatabase.processScope;
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) {
      debugPrint('housing entry inbox poll skipped: relay not configured');
    } else {
      await orch.pollSteadyStateInboxes().catchError((Object e, StackTrace st) {
        debugPrint('housing entry inbox poll: $e\n$st');
      });
    }
    final plans = await housingPlansWithSelfParticipant(db);
    final transport = HousingProposalTransportService(db);
    for (final plan in plans) {
      final expiredRevisionId = await transport.expireOpenRevisionsForPlan(
        plan.id,
      );
      if (expiredRevisionId != null) {
        unawaited(orch?.cancelProposalDeadlineReminders(expiredRevisionId));
      }
      await transport.reconcileStalePackagePending(plan.id);
    }

    Plan? primaryActivePlan;
    ProposalPackage? primaryActivePackage;
    var primaryActivePlanIsPastForSelf = false;
    for (final plan in plans) {
      if (!await transport.hasActiveRevision(plan.id)) continue;
      if (primaryActivePlan != null) {
        primaryActivePlan = null;
        primaryActivePackage = null;
        primaryActivePlanIsPastForSelf = false;
        break;
      }
      primaryActivePlan = plan;
      final packageId = await transport.primaryPackageIdForPlan(plan.id);
      primaryActivePackage = packageId == null
          ? null
          : await (db.select(db.proposalPackages)
                ..where((t) => t.id.equals(packageId)))
              .getSingleOrNull();
      final membership = HousingParticipationMembershipService(db);
      await membership.ensureMembershipsForPlan(plan.id);
      primaryActivePlanIsPastForSelf = !await membership.isActiveMember(
        plan.id,
        '${plan.id}:self',
      );
    }

    String? inlineDraftPlanId;
    if (plans.isEmpty) {
      _inlineDraftPlanId ??= await resolveInlineHousingDraftPlanId(db);
      inlineDraftPlanId = _inlineDraftPlanId;
    } else {
      _inlineDraftPlanId = null;
    }

    if (plans.length != 1) {
      return _HousingEntrySnapshot(
        plans: plans,
        primaryActivePlan: primaryActivePlan,
        primaryActivePackage: primaryActivePackage,
        primaryActivePlanIsPastForSelf: primaryActivePlanIsPastForSelf,
        inlineDraftPlanId: inlineDraftPlanId,
      );
    }
    final planId = plans.single.id;
    final packageId = await transport.primaryPackageIdForPlan(planId);
    final pkg = packageId == null
        ? null
        : await (db.select(db.proposalPackages)
              ..where((t) => t.id.equals(packageId)))
            .getSingleOrNull();
    final pendingRevisionId = await transport.resolvePendingRevisionIdForPlan(
      planId,
    );
    final hasArchives = await transport.planHasArchives(planId);
    return _HousingEntrySnapshot(
      plans: plans,
      package: pkg,
      pendingRevisionId: pendingRevisionId,
      hasArchives: hasArchives,
      primaryActivePlan: primaryActivePlan,
      primaryActivePackage: primaryActivePackage,
      primaryActivePlanIsPastForSelf: primaryActivePlanIsPastForSelf,
      inlineDraftPlanId: inlineDraftPlanId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) exitHousingModule(context);
      },
      child: FutureBuilder<_HousingEntrySnapshot>(
        future: _entryFuture ?? _loadEntry(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            final l10n = AppLocalizations.of(context);
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.housingPlanLoadError('${snap.error}'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _reloadEntry,
                        child: Text(l10n.commonRestart),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final entry =
              snap.data ?? const _HousingEntrySnapshot(plans: <Plan>[]);
          final plans = entry.plans;
          final primary = entry.primaryActivePlan;
          final primaryPkg = entry.primaryActivePackage;
          if (primary != null && primaryPkg != null) {
            if (entry.primaryActivePlanIsPastForSelf) {
              return HousingPastAgreementEntryScreen(
                key: ValueKey('past-entry-${primary.id}'),
                planId: primary.id,
                packageId: primaryPkg.id,
                prefs: widget.prefs,
              );
            }
            return HousingActivePlanScreen(
              key: ValueKey('active-hub-${primary.id}'),
              planId: primary.id,
              packageId: primaryPkg.id,
              prefs: widget.prefs,
            );
          }
          if (plans.length > 1) {
            return HousingWorkbenchScreen(
              key: ValueKey(_workbenchReloadToken),
              prefs: widget.prefs,
            );
          }
          if (plans.isEmpty) {
            final draftId = entry.inlineDraftPlanId;
            if (draftId == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return HousingPlanScreen(
              key: ValueKey('inline-draft-$draftId'),
              prefs: widget.prefs,
              planId: draftId,
            );
          }
          if (entry.pendingRevisionId != null) {
            return FutureBuilder<bool>(
              future: pendingRevisionIsAmendment(
                AppDatabase.processScope,
                plans.single.id,
              ),
              builder: (context, amendmentSnap) {
                if (amendmentSnap.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final isAmendment = amendmentSnap.data ?? false;
                if (isAmendment && primary != null && primaryPkg != null) {
                  return HousingActivePlanScreen(
                    key: ValueKey('active-hub-${primary.id}'),
                    planId: primary.id,
                    packageId: primaryPkg.id,
                    prefs: widget.prefs,
                  );
                }
                return HousingInviteProposalScreen(
                  db: AppDatabase.processScope,
                  planId: plans.single.id,
                  prefs: widget.prefs,
                );
              },
            );
          }
          if (entry.hasArchives) {
            return HousingArchiveEntryScreen(
              prefs: widget.prefs,
              planId: plans.single.id,
            );
          }
          return HousingPlanScreen(
            prefs: widget.prefs,
            planId: plans.single.id,
          );
        },
      ),
    );
  }
}
