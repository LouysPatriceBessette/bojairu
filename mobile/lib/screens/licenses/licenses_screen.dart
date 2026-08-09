import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../entitlement/app_module_id.dart';
import '../../entitlement/module_entitlement_controller.dart';
import '../../entitlement/module_entitlement_state.dart';
import '../../entitlement/store_billing_service.dart';
import '../../entitlement/store_product_catalog.dart';
import '../../entitlement/store_receipt_record.dart';
import '../../entitlement/subscription_product_line.dart';
import '../../entitlement/subscription_renewal_estimate.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../util/display_date.dart';
import '../../widgets/screen_body_padding.dart';

/// Purchase / restore entry for module and bundle subscriptions.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen>
    with WidgetsBindingObserver {
  StoreBillingService? _billing;
  ModuleEntitlementController? _entitlement;
  AppPreferences? _prefs;
  var _loading = true;
  var _busy = false;
  var _playSyncFailed = false;

  /// Product opened in Play for cancel; checked after restore / receipt upsert.
  String? _pendingUnsubscribeProductId;
  StoreReceiptRecord? _receiptBeforeUnsubscribe;
  var _cancelDialogInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResumed());
    }
  }

  Future<void> _onResumed() async {
    final billing = _billing;
    if (billing == null) return;
    if (mounted) setState(() => _loading = true);
    // After Play's sheet closes — and on every return — re-query Play.
    final ok = await billing.refreshFromPlayStore();
    if (!mounted) return;
    setState(() {
      _playSyncFailed = !ok;
      _loading = false;
    });
    await _maybeShowCancelDialog();
  }

  Future<void> _bootstrap() async {
    final entitlement = ModuleEntitlementController.maybeInstance;
    if (entitlement == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    // Load local prefs/controller wiring first; do not paint subscription
    // rows until Play has answered (see [StoreBillingService.refreshFromPlayStore]).
    await entitlement.load();
    final prefs = await AppPreferences.load();

    var billing = StoreBillingService.maybeInstance;
    if (billing == null) {
      billing = StoreBillingService(entitlement: entitlement);
      StoreBillingService.install(billing);
    }
    if (mounted) {
      setState(() {
        _entitlement = entitlement;
        _billing = billing;
        _prefs = prefs;
        _loading = true;
      });
    }
    entitlement.addListener(_onChanged);
    billing.addListener(_onChanged);

    final ok = await billing.start();
    if (!mounted) return;
    setState(() {
      _playSyncFailed = !ok;
      _loading = false;
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
    if (_pendingUnsubscribeProductId != null) {
      unawaited(_maybeShowCancelDialog());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entitlement?.removeListener(_onChanged);
    _billing?.removeListener(_onChanged);
    // Do not dispose [StoreBillingService] — purchaseStream must stay subscribed
    // for the app process (see bootstrap + store_billing_service.dart).
    super.dispose();
  }

  Future<void> _restore() async {
    final billing = _billing;
    if (billing == null) return;
    setState(() {
      _busy = true;
      _loading = true;
    });
    try {
      final ok = await billing.refreshFromPlayStore();
      if (mounted) _playSyncFailed = !ok;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _buy(ProductDetails product) async {
    final billing = _billing;
    if (billing == null) return;
    setState(() => _busy = true);
    try {
      await billing.buy(product);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens Play subscription management (cancel or restore / re-enable renew).
  ///
  /// When [trackCancelTransition] is true, a post-resume dialog is shown if
  /// auto-renew flips from on → off. Resubscribe uses the same deep link without
  /// that tracking (Play restore keeps the same purchase token).
  Future<void> _openPlaySubscriptionManagement(
    String productId, {
    required bool trackCancelTransition,
  }) async {
    final billing = _billing;
    final entitlement = _entitlement;
    if (billing == null || entitlement == null) return;

    final before = validReceiptForProductId(
      productId: productId,
      receipts: entitlement.receipts,
      now: DateTime.now().toUtc(),
    );

    setState(() {
      _busy = true;
      if (trackCancelTransition) {
        _pendingUnsubscribeProductId = productId;
        _receiptBeforeUnsubscribe = before;
      }
    });
    try {
      await billing.openManageSubscription(productId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _maybeShowCancelDialog() async {
    if (_cancelDialogInFlight) return;
    final productId = _pendingUnsubscribeProductId;
    final before = _receiptBeforeUnsubscribe;
    final entitlement = _entitlement;
    if (productId == null || before == null || entitlement == null) return;

    _cancelDialogInFlight = true;
    try {
      await entitlement.load();
      if (!mounted) return;

      final now = DateTime.now().toUtc();
      final after = validReceiptForProductId(
        productId: productId,
        receipts: entitlement.receipts,
        now: now,
      );

      final canceled = didCancelAutoRenew(
        before: before,
        after: after,
        now: now,
      );
      if (!canceled) return;

      _pendingUnsubscribeProductId = null;
      _receiptBeforeUnsubscribe = null;

      final boundary = accessBoundaryForDisplay(
        purchasedAt: after!.purchasedAt,
        now: now,
        expiresAt: after.expiresAt,
      );
      final when = _formatWhen(boundary ?? now);
      final l10n = AppLocalizations.of(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.licensesCancelAccessUntilTitle),
          content: Text(l10n.licensesCancelAccessUntilBody(when)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.licensesCancelAccessUntilOk),
            ),
          ],
        ),
      );
    } finally {
      _cancelDialogInFlight = false;
    }
  }

  String _formatWhen(DateTime utc) {
    final prefs = _prefs;
    final fmt = prefs == null ? 'YYYY-MM-DD' : effectiveDateFormat(prefs);
    return formatPreferenceDateTime(utc, fmt);
  }

  String? _statusLine(
    SubscriptionProductLineKind kind,
    StoreReceiptRecord? receipt,
    AppLocalizations l10n,
  ) {
    if (receipt == null) return null;
    final now = DateTime.now().toUtc();
    final boundary = accessBoundaryForDisplay(
      purchasedAt: receipt.purchasedAt,
      now: now,
      expiresAt: receipt.expiresAt,
    );
    if (boundary == null) return null;
    final when = _formatWhen(boundary);
    switch (kind) {
      case SubscriptionProductLineKind.none:
        return null;
      case SubscriptionProductLineKind.autoRenewing:
        return l10n.licensesStatusAutoRenewOn(when);
      case SubscriptionProductLineKind.canceledStillValid:
        return l10n.licensesStatusValidUntil(when);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entitlement = _entitlement;
    final billing = _billing;
    final now = DateTime.now().toUtc();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeModuleLicenses)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: screenBodyScrollPadding(context),
              children: [
                Text(
                  l10n.licensesEffectiveHeading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (entitlement == null)
                  Text(l10n.licensesEntitlementUnavailable)
                else ...[
                  _stateTile(
                    context,
                    l10n.homeModuleHousing,
                    entitlement.stateOf(AppModuleId.housing),
                    l10n,
                  ),
                  _stateTile(
                    context,
                    l10n.homeModuleVehicle,
                    entitlement.stateOf(AppModuleId.vehicle),
                    l10n,
                  ),
                  _stateTile(
                    context,
                    l10n.homeModuleVehicleSharing,
                    entitlement.stateOf(AppModuleId.vehicleSharing),
                    l10n,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: _busy || billing == null ? null : _restore,
                  child: Text(l10n.licensesRestorePurchases),
                ),
                if (billing != null && !billing.isAvailable) ...[
                  const SizedBox(height: 12),
                  Text(l10n.licensesStoreUnavailable),
                ],
                if (_playSyncFailed) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.licensesPlaySyncFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (billing?.lastError != null &&
                    billing!.lastError != 'store_unavailable') ...[
                  const SizedBox(height: 8),
                  Text(
                    billing.lastError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  l10n.licensesProductsHeading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (billing == null || billing.products.isEmpty)
                  Text(l10n.licensesNoProducts)
                else
                  for (final product in billing.products)
                    _productTile(
                      product: product,
                      entitlement: entitlement,
                      now: now,
                      l10n: l10n,
                    ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Text(
                    'productIds: ${StoreProductCatalog.allProductIds.join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _productTile({
    required ProductDetails product,
    required ModuleEntitlementController? entitlement,
    required DateTime now,
    required AppLocalizations l10n,
  }) {
    final receipts = entitlement?.receipts ?? const <StoreReceiptRecord>[];
    final kind = subscriptionProductLineKind(
      productId: product.id,
      receipts: receipts,
      now: now,
    );
    final receipt = validReceiptForProductId(
      productId: product.id,
      receipts: receipts,
      now: now,
    );
    final status = _statusLine(kind, receipt, l10n);
    final subtitle = status == null ? product.price : '${product.price}\n$status';

    Widget? trailing;
    switch (kind) {
      case SubscriptionProductLineKind.none:
        trailing = FilledButton(
          onPressed: _busy ? null : () => _buy(product),
          child: Text(l10n.licensesSubscribe),
        );
      case SubscriptionProductLineKind.autoRenewing:
        trailing = FilledButton(
          onPressed: _busy
              ? null
              : () => _openPlaySubscriptionManagement(
                    product.id,
                    trackCancelTransition: true,
                  ),
          child: Text(l10n.licensesUnsubscribe),
        );
      case SubscriptionProductLineKind.canceledStillValid:
        // Play restore (same deep link as cancel) re-enables renew on the
        // existing token — do not start a new in-app purchase.
        trailing = FilledButton(
          onPressed: _busy
              ? null
              : () => _openPlaySubscriptionManagement(
                    product.id,
                    trackCancelTransition: false,
                  ),
          child: Text(l10n.licensesResubscribe),
        );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(product.title),
      subtitle: Text(subtitle),
      isThreeLine: status != null,
      trailing: trailing,
    );
  }

  Widget _stateTile(
    BuildContext context,
    String label,
    ModuleEntitlementState state,
    AppLocalizations l10n,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(_stateLabel(state, l10n)),
    );
  }

  String _stateLabel(ModuleEntitlementState state, AppLocalizations l10n) {
    switch (state) {
      case ModuleEntitlementState.free:
        return l10n.licensesStateFree;
      case ModuleEntitlementState.linkedNotActive:
        return l10n.licensesStateLinkedNotActive;
      case ModuleEntitlementState.activeTrial:
        return l10n.licensesStateActiveTrial;
      case ModuleEntitlementState.activePaid:
        return l10n.licensesStateActivePaid;
      case ModuleEntitlementState.delinquentGrace:
        return l10n.licensesStateGrace;
      case ModuleEntitlementState.delinquentReadonly:
        return l10n.licensesStateReadonly;
    }
  }
}
