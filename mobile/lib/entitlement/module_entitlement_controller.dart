import 'package:flutter/foundation.dart';

import 'app_module_id.dart';
import 'housing_lifecycle_source.dart';
import 'local_store_receipt_store.dart';
import 'module_entitlement_evaluator.dart';
import 'module_entitlement_state.dart';
import 'receipt_play_reconcile.dart';
import 'receipt_to_candidates.dart';
import 'server_grant_receipt.dart';
import 'store_receipt_record.dart';

/// Uploads a Google Play receipt and returns the server expiry when known.
typedef PlayTokenUploader = Future<DateTime?> Function(StoreReceiptRecord record);

/// Holds one effective [ModuleEntitlementState] per [AppModuleId].
///
/// Combines local store receipts + optional housing lifecycle. Google Play
/// tokens are POSTed when [playTokenUploader] is set; Licenses dates then use
/// the server `expiryTime`.
class ModuleEntitlementController extends ChangeNotifier {
  ModuleEntitlementController({
    LocalStoreReceiptStore? receiptStore,
    DateTime Function()? clock,
    this.playTokenUploader,
  })  : _receiptStore = receiptStore ?? LocalStoreReceiptStore(),
        _clock = clock ?? DateTime.now;

  static ModuleEntitlementController? _instance;

  static ModuleEntitlementController? get maybeInstance => _instance;

  static void install(ModuleEntitlementController controller) {
    _instance = controller;
  }

  static void uninstall() {
    _instance = null;
  }

  final LocalStoreReceiptStore _receiptStore;
  final DateTime Function() _clock;

  /// Set after entitlement HTTP is wired (bootstrap). Null = local-only.
  PlayTokenUploader? playTokenUploader;

  final Map<AppModuleId, ModuleEntitlementState> _effective =
      <AppModuleId, ModuleEntitlementState>{
    for (final m in AppModuleId.values) m: ModuleEntitlementState.free,
  };

  List<StoreReceiptRecord> _receipts = const <StoreReceiptRecord>[];
  HousingLifecycleSnapshot? _housingLifecycle;
  HousingLifecycleSnapshot? _vehicleLifecycle;

  ModuleEntitlementState stateOf(AppModuleId module) =>
      _effective[module] ?? ModuleEntitlementState.free;

  bool isActivePaid(AppModuleId module) =>
      stateOf(module) == ModuleEntitlementState.activePaid;

  bool hasUsableAccess(AppModuleId module) {
    switch (stateOf(module)) {
      case ModuleEntitlementState.activePaid:
      case ModuleEntitlementState.activeTrial:
      case ModuleEntitlementState.delinquentGrace:
        return true;
      case ModuleEntitlementState.free:
      case ModuleEntitlementState.linkedNotActive:
      case ModuleEntitlementState.delinquentReadonly:
        return false;
    }
  }

  List<StoreReceiptRecord> get receipts =>
      List<StoreReceiptRecord>.unmodifiable(_receipts);

  Future<void> load() async {
    _receipts = await _receiptStore.loadAll();
    _recompute();
  }

  void setHousingLifecycle(HousingLifecycleSnapshot? snapshot) {
    if (_housingLifecycle == snapshot) return;
    _housingLifecycle = snapshot;
    _recompute();
  }

  void setVehicleLifecycle(HousingLifecycleSnapshot? snapshot) {
    if (_vehicleLifecycle == snapshot) return;
    _vehicleLifecycle = snapshot;
    _recompute();
  }

  /// Re-evaluates trial / grace / read-only against the current clock.
  void refreshClock() {
    _recompute();
  }

  Future<void> upsertReceipt(StoreReceiptRecord record) async {
    _receipts = await _receiptStore.upsert(record);
    _recompute();
    await _applyServerExpiryIfUploaded(record);
  }

  /// Re-POSTs every local Google Play token (e.g. after HTTP client is wired).
  Future<void> uploadPendingPlayTokens() async {
    final snapshot = List<StoreReceiptRecord>.from(_receipts);
    for (final record in snapshot) {
      await _applyServerExpiryIfUploaded(record);
    }
  }

  Future<void> _applyServerExpiryIfUploaded(StoreReceiptRecord record) async {
    final uploader = playTokenUploader;
    if (uploader == null) return;
    if (record.platform != 'google_play') return;
    if (record.purchaseTokenOrReceipt.isEmpty) return;
    try {
      final expiresAt = await uploader(record);
      if (expiresAt == null) return;
      if (record.expiresAt != null &&
          record.expiresAt!.toUtc() == expiresAt.toUtc()) {
        return;
      }
      _receipts = await _receiptStore.upsert(
        record.copyWith(expiresAt: expiresAt.toUtc()),
      );
      _recompute();
    } on Object catch (e, st) {
      debugPrint('entitlement: play-token upload skipped: $e\n$st');
    }
  }

  Future<void> replaceReceipts(List<StoreReceiptRecord> rows) async {
    await _receiptStore.saveAll(rows);
    _receipts = List<StoreReceiptRecord>.from(rows);
    _recompute();
  }

  Future<void> reconcileServerGrant(StoreReceiptRecord? serverGrant) async {
    await replaceReceipts(
      reconcileServerGrantReceipts(
        local: _receipts,
        serverGrant: serverGrant,
      ),
    );
  }

  /// After a successful Play purchase query: keep only Google Play rows whose
  /// purchase token is still present (plus any non-Play rows).
  Future<void> retainGooglePlayPurchaseTokens(
    Set<String> livePurchaseTokens,
  ) async {
    final next = reconcileGooglePlayReceipts(
      local: _receipts,
      livePurchaseTokens: livePurchaseTokens,
    );
    if (next.length == _receipts.length &&
        listEquals(
          next.map((r) => r.purchaseTokenOrReceipt).toList(),
          _receipts.map((r) => r.purchaseTokenOrReceipt).toList(),
        )) {
      return;
    }
    await replaceReceipts(next);
  }

  void _recompute() {
    final now = _clock().toUtc();
    final fromReceipts = ReceiptToCandidates.fromReceipts(
      _receipts,
      now: now,
    );

    var changed = false;
    for (final module in AppModuleId.values) {
      final candidates = <EntitlementSourceCandidate>[
        ...fromReceipts[module]!,
      ];
      if (module == AppModuleId.housing && _housingLifecycle != null) {
        final life = HousingLifecycleSource.candidateFor(
          _housingLifecycle!,
          now: now,
        );
        if (life != null) candidates.add(life);
      }
      if (module == AppModuleId.vehicle && _vehicleLifecycle != null) {
        final life = HousingLifecycleSource.candidateFor(
          _vehicleLifecycle!,
          now: now,
        );
        if (life != null) candidates.add(life);
      }
      final next = ModuleEntitlementEvaluator.evaluate(candidates);
      if (_effective[module] != next) {
        _effective[module] = next;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }
}
