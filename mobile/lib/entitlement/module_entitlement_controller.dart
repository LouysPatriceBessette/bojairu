import 'package:flutter/foundation.dart';

import 'app_module_id.dart';
import 'housing_lifecycle_source.dart';
import 'local_store_receipt_store.dart';
import 'module_entitlement_evaluator.dart';
import 'module_entitlement_state.dart';
import 'receipt_to_candidates.dart';
import 'store_receipt_record.dart';

/// Holds one effective [ModuleEntitlementState] per [AppModuleId].
///
/// Étape 1: combines local store receipts + optional housing lifecycle.
/// Does not POST proofs or license-status to the entitlement server.
class ModuleEntitlementController extends ChangeNotifier {
  ModuleEntitlementController({
    LocalStoreReceiptStore? receiptStore,
    DateTime Function()? clock,
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

  final Map<AppModuleId, ModuleEntitlementState> _effective =
      <AppModuleId, ModuleEntitlementState>{
    for (final m in AppModuleId.values) m: ModuleEntitlementState.free,
  };

  List<StoreReceiptRecord> _receipts = const <StoreReceiptRecord>[];
  HousingLifecycleSnapshot? _housingLifecycle;

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
    _housingLifecycle = snapshot;
    _recompute();
  }

  Future<void> upsertReceipt(StoreReceiptRecord record) async {
    _receipts = await _receiptStore.upsert(record);
    _recompute();
  }

  Future<void> replaceReceipts(List<StoreReceiptRecord> rows) async {
    await _receiptStore.saveAll(rows);
    _receipts = List<StoreReceiptRecord>.from(rows);
    _recompute();
  }

  void _recompute() {
    final now = _clock().toUtc();
    final fromReceipts = ReceiptToCandidates.fromReceipts(
      _receipts,
      now: now,
    );

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
      // vehicle / vehicle-sharing: paid or bundle only (no local trial).
      _effective[module] = ModuleEntitlementEvaluator.evaluate(candidates);
    }
    notifyListeners();
  }
}
