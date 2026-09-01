import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../entitlement/app_module_id.dart';
import '../../entitlement/entitlement_coordinator.dart';
import '../../entitlement/module_entitlement_controller.dart';
import '../../entitlement/store_billing_service.dart';
import '../../entitlement/store_product_catalog.dart';
import '../../entitlement/store_product_display_names.dart';
import '../../entitlement/store_receipt_record.dart';
import '../../entitlement/store_subscription_offer_filter.dart';
import '../../entitlement/store_subscription_price_label.dart';
import '../../entitlement/subscription_product_line.dart';
import '../../entitlement/subscription_renewal_estimate.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../theme/app_theme.dart';
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

  var _addMode = false;
  final Set<AppModuleId> _cart = <AppModuleId>{};
  String? _expandedProductId;
  String? _selectedOfferProductId;

  static const List<AppModuleId> _moduleOrder = <AppModuleId>[
    AppModuleId.housing,
    AppModuleId.vehicle,
    AppModuleId.vehicleSharing,
  ];

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
    await EntitlementCoordinator.maybeInstance?.syncServerLicenses();
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
    await entitlement.load();
    await EntitlementCoordinator.maybeInstance?.syncServerLicenses();
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
        return l10n.licensesStatusAutoRenewOn(when).replaceAll('\n', ' ');
      case SubscriptionProductLineKind.canceledStillValid:
        return l10n.licensesStatusValidUntil(when).replaceAll('\n', ' ');
    }
  }

  Set<AppModuleId> _coveredByPlay(
    Iterable<StoreReceiptRecord> receipts,
    DateTime now,
  ) {
    return <AppModuleId>{
      for (final m in _moduleOrder)
        if (moduleCoveredByPlayReceipt(
          module: m,
          receipts: receipts,
          now: now,
        ))
          m,
    };
  }

  void _enterAddMode(Set<AppModuleId> covered) {
    setState(() {
      _addMode = true;
      _cart
        ..clear()
        ..addAll(covered);
      _selectedOfferProductId = null;
      _expandedProductId = null;
    });
  }

  void _exitAddMode() {
    setState(() {
      _addMode = false;
      _cart.clear();
      _selectedOfferProductId = null;
    });
  }

  void _toggleCartModule(AppModuleId module) {
    setState(() {
      if (_cart.contains(module)) {
        _cart.remove(module);
      } else {
        _cart.add(module);
      }
      _selectedOfferProductId = null;
    });
  }

  IconData _iconFor(AppModuleId module) {
    switch (module) {
      case AppModuleId.housing:
        return MdiIcons.homeCity;
      case AppModuleId.vehicle:
        return MdiIcons.carSide;
      case AppModuleId.vehicleSharing:
        return Icons.car_rental;
    }
  }

  String _moduleLabel(AppModuleId module, AppLocalizations l10n) {
    switch (module) {
      case AppModuleId.housing:
        return l10n.homeModuleHousing;
      case AppModuleId.vehicle:
        return l10n.homeModuleVehicle;
      case AppModuleId.vehicleSharing:
        return l10n.homeModuleVehicleSharing;
    }
  }

  ProductDetails? _productDetailsFor(String productId) {
    final billing = _billing;
    if (billing == null) return null;
    for (final p in billing.products) {
      if (p.id == productId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entitlement = _entitlement;
    final billing = _billing;
    final now = DateTime.now().toUtc();
    final receipts = entitlement?.receipts ?? const <StoreReceiptRecord>[];
    final covered = _coveredByPlay(receipts, now);
    final paidIds = paidProductIdsFromReceipts(receipts: receipts, now: now);
    final allCovered = covered.length == _moduleOrder.length;

    final activeProductIds = StoreProductCatalog.entries
        .where((e) => paidIds.contains(e.productId))
        .map((e) => e.productId)
        .toList(growable: false);

    final promptSelect = shouldPromptSelectModuleToAdd(
      cart: _cart,
      coveredByPlay: covered,
    );
    final offers = promptSelect
        ? const <StoreCatalogEntry>[]
        : filterSubscriptionOffers(cart: _cart, paidProductIds: paidIds);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeModuleLicenses),
        actions: [
          IconButton(
            tooltip: l10n.licensesRestorePurchases,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _busy || billing == null ? null : _restore,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: screenBodyScrollPadding(context),
              children: [
                if (entitlement == null)
                  Text(l10n.licensesEntitlementUnavailable)
                else ...[
                  _moduleGrid(
                    context: context,
                    l10n: l10n,
                    covered: covered,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.licensesActiveHeading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (activeProductIds.isEmpty)
                    Text(l10n.licensesNoActiveSubscription)
                  else
                    for (final productId in activeProductIds)
                      _activeLicenseTile(
                        productId: productId,
                        receipts: receipts,
                        now: now,
                        l10n: l10n,
                      ),
                  if (!allCovered) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_addMode) {
                                _exitAddMode();
                              } else {
                                _enterAddMode(covered);
                              }
                            },
                      child: Text(
                        _addMode
                            ? l10n.licensesAddNothing
                            : l10n.licensesAddSubscription,
                      ),
                    ),
                  ],
                  if (_addMode && !allCovered) ...[
                    const SizedBox(height: 16),
                    if (promptSelect)
                      Text(l10n.licensesSelectModuleToAdd)
                    else if (offers.isEmpty)
                      Text(l10n.licensesNoProducts)
                    else ...[
                      RadioGroup<String>(
                        groupValue: _selectedOfferProductId,
                        onChanged: (v) {
                          if (_busy || v == null) return;
                          setState(() {
                            _selectedOfferProductId = v;
                          });
                        },
                        child: Column(
                          children: [
                            for (final entry in offers)
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  StoreProductDisplayNames.forProductId(
                                    entry.productId,
                                    l10n,
                                  ),
                                ),
                                value: entry.productId,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _busy ||
                                _selectedOfferProductId == null ||
                                _productDetailsFor(
                                      _selectedOfferProductId!,
                                    ) ==
                                    null
                            ? null
                            : () {
                                final details = _productDetailsFor(
                                  _selectedOfferProductId!,
                                );
                                if (details != null) {
                                  unawaited(_buy(details));
                                }
                              },
                        child: Text(l10n.licensesSubscribe),
                      ),
                    ],
                  ],
                ],
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
              ],
            ),
    );
  }

  Widget _moduleGrid({
    required BuildContext context,
    required AppLocalizations l10n,
    required Set<AppModuleId> covered,
  }) {
    final selectStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final module in _moduleOrder)
              Expanded(
                child: Center(
                  child: _ModuleLicenseIcon(
                    icon: _iconFor(module),
                    covered: covered.contains(module),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final module in _moduleOrder)
              Expanded(
                child: Text(
                  _moduleLabel(module, l10n),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        if (_addMode) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final module in _moduleOrder)
                Expanded(
                  child: TextButton(
                    style: selectStyle,
                    onPressed:
                        _busy ? null : () => _toggleCartModule(module),
                    child: Text(
                      _cart.contains(module)
                          ? l10n.licensesDeselectModule
                          : l10n.licensesSelectModule,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _activeLicenseTile({
    required String productId,
    required Iterable<StoreReceiptRecord> receipts,
    required DateTime now,
    required AppLocalizations l10n,
  }) {
    final kind = subscriptionProductLineKind(
      productId: productId,
      receipts: receipts,
      now: now,
    );
    final receipt = validReceiptForProductId(
      productId: productId,
      receipts: receipts,
      now: now,
    );
    final expanded = _expandedProductId == productId;
    final details = _productDetailsFor(productId);
    final price = details == null
        ? ''
        : formatSubscriptionPriceWithPeriod(product: details, l10n: l10n);
    final status = _statusLine(kind, receipt, l10n);
    final isGooglePlayReceipt = receipt?.platform == 'google_play';
    final actionButton = !isGooglePlayReceipt
        ? null
        : kind == SubscriptionProductLineKind.autoRenewing
        ? FilledButton(
            onPressed: _busy
                ? null
                : () => _openPlaySubscriptionManagement(
                      productId,
                      trackCancelTransition: true,
                    ),
            child: Text(l10n.licensesCancelThisSubscription),
          )
        : kind == SubscriptionProductLineKind.canceledStillValid
            ? FilledButton(
                onPressed: _busy
                    ? null
                    : () => _openPlaySubscriptionManagement(
                          productId,
                          trackCancelTransition: false,
                        ),
                child: Text(l10n.licensesResubscribe),
              )
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedProductId = expanded ? null : productId;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    StoreProductDisplayNames.forProductId(productId, l10n),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (price.isNotEmpty) ...[
                      Text(price),
                      const SizedBox(width: 12),
                    ],
                    if (status != null)
                      Expanded(
                        child: Text(
                          status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                if (actionButton != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionButton,
                  ),
                ],
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Module icon in a circle matching [FilledButton] primary / onPrimary
/// (same colors as « Ajout d'abonnement »), with optional green coverage dot
/// at [_ModuleLicenseIcon._dotAngleDegrees] (12h = 0° clockwise).
class _ModuleLicenseIcon extends StatelessWidget {
  const _ModuleLicenseIcon({
    required this.icon,
    required this.covered,
  });

  final IconData icon;
  final bool covered;

  static const double _circleSize = 56;
  static const double _iconSize = 28;
  static const double _dotSize = 14;
  /// Clockwise from 12 o'clock (0°) on the icon circle perimeter.
  static const double _dotAngleDegrees = 310;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final angleRad = _dotAngleDegrees * math.pi / 180;
    return SizedBox(
      width: _circleSize + _dotSize,
      height: _circleSize + _dotSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _circleSize,
            height: _circleSize,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: _iconSize,
              color: scheme.onPrimary,
            ),
          ),
          if (covered)
            Positioned(
              left: (_circleSize + _dotSize) / 2 +
                  (_circleSize / 2) * math.sin(angleRad) -
                  _dotSize / 2,
              top: (_circleSize + _dotSize) / 2 -
                  (_circleSize / 2) * math.cos(angleRad) -
                  _dotSize / 2,
              child: Container(
                width: _dotSize,
                height: _dotSize,
                decoration: const BoxDecoration(
                  color: AppBrandColors.moneyGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
