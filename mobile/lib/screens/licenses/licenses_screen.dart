import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../entitlement/app_module_id.dart';
import '../../entitlement/module_entitlement_controller.dart';
import '../../entitlement/module_entitlement_state.dart';
import '../../entitlement/store_billing_service.dart';
import '../../entitlement/store_product_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/screen_body_padding.dart';

/// Purchase / restore entry for module and bundle subscriptions.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  StoreBillingService? _billing;
  ModuleEntitlementController? _entitlement;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final entitlement = ModuleEntitlementController.maybeInstance;
    if (entitlement == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    await entitlement.load();
    final billing = StoreBillingService(entitlement: entitlement);
    await billing.start();
    if (!mounted) {
      billing.dispose();
      return;
    }
    setState(() {
      _entitlement = entitlement;
      _billing = billing;
      _loading = false;
    });
    entitlement.addListener(_onEntitlement);
  }

  void _onEntitlement() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entitlement?.removeListener(_onEntitlement);
    final billing = _billing;
    _billing = null;
    billing?.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final billing = _billing;
    if (billing == null) return;
    setState(() => _busy = true);
    try {
      await billing.restore();
    } finally {
      if (mounted) setState(() => _busy = false);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entitlement = _entitlement;
    final billing = _billing;

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
                if (billing?.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    billing!.lastError!,
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(product.title),
                      subtitle: Text(
                        '${product.price}\n${product.id}',
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: _busy ? null : () => _buy(product),
                        child: Text(l10n.licensesSubscribe),
                      ),
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
