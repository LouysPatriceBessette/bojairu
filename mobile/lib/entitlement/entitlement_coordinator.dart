import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../prefs/app_preferences.dart';
import 'entitlement_client.dart';
import 'entitlement_gate.dart';
import 'entitlement_plan_id.dart';
import 'participant_installation_store.dart';
import 'plan_participant_installation_registry.dart';
import 'store_receipt_record.dart';

/// Maps import tails (`self`, `p0`, …) to full participant ids used by the
/// registry and roster reporting (`$planId:self`, `$planId:p0`, …).
String resolvePlanParticipantId(String planId, String localParticipantId) {
  if (localParticipantId.startsWith('$planId:')) {
    return localParticipantId;
  }
  if (localParticipantId == 'self' ||
      RegExp(r'^p\d+$').hasMatch(localParticipantId)) {
    return '$planId:$localParticipantId';
  }
  return localParticipantId;
}

/// Wires local installation identity, roster metadata, and relay gates.
class EntitlementCoordinator {
  EntitlementCoordinator({
    required AppConfig config,
    required ParticipantInstallationStore installationStore,
    required PlanParticipantInstallationRegistry registry,
    EntitlementClient? client,
  })  : _config = config,
        _installationStore = installationStore,
        _registry = registry,
        _client = client ??
            (config.entitlementEnabled
                ? EntitlementClient(baseUrl: config.entitlementBaseUrl!)
                : null);

  static EntitlementCoordinator? _instance;

  static EntitlementCoordinator? get maybeInstance => _instance;

  static void install(EntitlementCoordinator coordinator) {
    _instance = coordinator;
  }

  static void uninstallForTesting() {
    _instance?.close();
    _instance = null;
  }

  final AppConfig _config;
  final ParticipantInstallationStore _installationStore;
  final PlanParticipantInstallationRegistry _registry;
  final EntitlementClient? _client;

  bool get gateEnabled => _config.entitlementGateEnabled;

  bool get httpEnabled => _config.entitlementEnabled && _client != null;

  Future<void> ensureRegistered() async {
    if (!httpEnabled) return;
    try {
      final id = await _installationStore.loadOrCreateId();
      await _client!.registerInstallation(id);
    } on Object catch (e, st) {
      debugPrint('entitlement: register failed: $e\n$st');
    }
  }

  Future<void> bindSelfParticipant({
    required String planId,
    required String selfParticipantId,
  }) async {
    if (!gateEnabled) return;
    final id = await _installationStore.loadOrCreateId();
    await _registry.setInstallationId(
      planId: planId,
      participantId: selfParticipantId,
      installationId: id,
    );
  }

  Future<String> installationIdForSnapshot({
    required String planId,
    required String participantId,
  }) async {
    final fullParticipantId = resolvePlanParticipantId(planId, participantId);
    final existing = _registry.installationIdFor(
      planId: planId,
      participantId: fullParticipantId,
    );
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    if (!fullParticipantId.endsWith(':self')) {
      return '';
    }
    await bindSelfParticipant(
      planId: planId,
      selfParticipantId: fullParticipantId,
    );
    return _registry.installationIdFor(
          planId: planId,
          participantId: fullParticipantId,
        ) ??
        await _installationStore.loadOrCreateId();
  }

  Future<void> ingestParticipantSnapshot({
    required String planId,
    required String participantId,
    required String? installationId,
  }) async {
    if (!gateEnabled || installationId == null || installationId.isEmpty) {
      return;
    }
    await _registry.setInstallationId(
      planId: planId,
      participantId: participantId,
      installationId: installationId,
    );
  }

  Future<void> ingestSnapshotsFromPayload({
    required String planId,
    required Map<String, dynamic> payload,
    required Map<String, String> sourceToLocalParticipant,
  }) async {
    if (!gateEnabled) return;
    final raw = payload['participantSnapshots'];
    if (raw is! List) return;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final sourcePid = entry['id'] as String?;
      final inst = entry['participantInstallationId'] as String?;
      if (sourcePid == null || inst == null || inst.isEmpty) continue;
      final localPid = sourceToLocalParticipant[sourcePid] ?? sourcePid;
      await ingestParticipantSnapshot(
        planId: planId,
        participantId: resolvePlanParticipantId(planId, localPid),
        installationId: inst,
      );
    }
  }

  Future<void> reportRosterIfComplete({
    required String planId,
    required String revisionId,
    required List<String> participantIds,
  }) async {
    if (!httpEnabled) return;
    final roster = _registry.rosterInstallationIds(
      planId: planId,
      participantIds: participantIds,
    );
    if (roster == null) {
      debugPrint(
        'entitlement: roster incomplete for $planId '
        '(${participantIds.length} participants)',
      );
      return;
    }
    final entitlementPlanId = entitlementPlanIdForLocalPlan(planId);
    try {
      await _client!.reportPlanRoster(
        planId: entitlementPlanId,
        revisionId: revisionId,
        participantInstallationIds: roster,
      );
      debugPrint(
        'entitlement: roster reported for $entitlementPlanId rev=$revisionId',
      );
    } on Object catch (e, st) {
      debugPrint('entitlement: roster report failed: $e\n$st');
    }
  }

  Future<void> reportActiveUse({required String planId}) async {
    if (!httpEnabled) return;
    try {
      final prefs = await AppPreferences.load();
      if (prefs.sandboxMode) return;
    } catch (_) {}
    final entitlementPlanId = entitlementPlanIdForLocalPlan(planId);
    try {
      await _client!.reportActiveUse(planId: entitlementPlanId);
      debugPrint('entitlement: active-use reported for $entitlementPlanId');
    } on Object catch (e, st) {
      debugPrint('entitlement: active-use report failed: $e\n$st');
    }
  }

  /// POSTs a Google Play purchase token. Returns server expiry when present.
  /// Failures (including Play verifier not yet configured) are logged, not thrown.
  Future<DateTime?> uploadGooglePlayReceipt(StoreReceiptRecord record) async {
    if (!httpEnabled) return null;
    if (record.platform != 'google_play') return null;
    if (record.purchaseTokenOrReceipt.isEmpty) return null;
    try {
      await ensureRegistered();
      final id = await _installationStore.loadOrCreateId();
      final verified = await _client!.uploadPlayToken(
        participantInstallationId: id,
        productId: record.productId,
        purchaseToken: record.purchaseTokenOrReceipt,
      );
      return verified.expiresAt;
    } on EntitlementClientError catch (e, st) {
      debugPrint('entitlement: play-token failed: $e\n$st');
      return null;
    } on Object catch (e, st) {
      debugPrint('entitlement: play-token failed: $e\n$st');
      return null;
    }
  }

  Future<EntitlementGate?> gateFor({
    required String planId,
    required String selfParticipantId,
    required int kind,
    String? expenseId,
    String? revisionId,
    String? decisionKind,
  }) async {
    if (!gateEnabled || !EntitlementGate.isGatedKind(kind)) return null;
    await bindSelfParticipant(planId: planId, selfParticipantId: selfParticipantId);
    final entitlementPlanId = entitlementPlanIdForLocalPlan(planId);
    final installationId = _registry.installationIdFor(
      planId: planId,
      participantId: selfParticipantId,
    );
    if (installationId == null || installationId.isEmpty) {
      final fallback = await _installationStore.loadOrCreateId();
      await _registry.setInstallationId(
        planId: planId,
        participantId: selfParticipantId,
        installationId: fallback,
      );
      return EntitlementGate.forHousing(
        participantInstallationId: fallback,
        planId: entitlementPlanId,
        kind: kind,
        expenseId: expenseId,
        revisionId: revisionId,
        decisionKind: decisionKind,
      );
    }
    return EntitlementGate.forHousing(
      participantInstallationId: installationId,
      planId: entitlementPlanId,
      kind: kind,
      expenseId: expenseId,
      revisionId: revisionId,
      decisionKind: decisionKind,
    );
  }

  void close() => _client?.close();
}
