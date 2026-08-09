import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';

import '../entitlement/module_entitlement_controller.dart';
import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import '../sandbox/sandbox_mode.dart';
import '../vehicle/vehicle_module_access.dart';
import 'package:compartarenta/navigation/app_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _welcomeChecked = false;
  ModuleEntitlementController? _entitlement;

  @override
  void initState() {
    super.initState();
    _entitlement = ModuleEntitlementController.maybeInstance;
    _entitlement?.addListener(_onEntitlementChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSandboxWelcome());
  }

  void _onEntitlementChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entitlement?.removeListener(_onEntitlementChanged);
    super.dispose();
  }

  Future<void> _maybeShowSandboxWelcome() async {
    if (_welcomeChecked || !mounted) return;
    _welcomeChecked = true;
    final prefs = await AppPreferences.load();
    if (!mounted) return;
    if (!SandboxMode.isActive(prefs) || !prefs.sandboxShowHomeWelcome) return;
    await prefs.setSandboxShowHomeWelcome(false);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.sandboxHomeWelcomeBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final access = const VehicleModuleAccess();

    return FutureBuilder<AppPreferences>(
      future: AppPreferences.load(),
      builder: (context, prefsSnap) {
        final prefs = prefsSnap.data;
        final sandbox = prefs != null && SandboxMode.isActive(prefs);
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.appTitle),
            actions: [
              IconButton(
                onPressed: () => navigateToChild(context, '/settings'),
                icon: const Icon(Icons.settings),
                tooltip: l10n.navSettings,
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final landscape =
                  MediaQuery.orientationOf(context) == Orientation.landscape;
              final viewPadding = MediaQuery.viewPaddingOf(context);
              const contentInset = 16.0;
              const gap = 12.0;

              final rawContentW = constraints.maxWidth -
                  2 * contentInset -
                  viewPadding.left -
                  viewPadding.right;
              final contentW = rawContentW.clamp(0.0, double.infinity);
              final moduleTileW = landscape
                  ? ((contentW - gap) / 2).clamp(0.0, double.infinity)
                  : contentW;

              final tiles = <Widget>[
                SizedBox(
                  width: contentW,
                  child: _HomeActionCard(
                    icon: MdiIcons.accountMultipleOutline,
                    label: l10n.homeModuleContacts,
                    onTap: () => navigateTo(context, '/contacts'),
                    semanticsIdentifier:
                        kDebugMode ? 'qa-home-contacts' : null,
                  ),
                ),
                SizedBox(
                  width: moduleTileW,
                  child: _HomeActionCard(
                    icon: MdiIcons.homeCity,
                    label: l10n.homeModuleHousing,
                    onTap: () => navigateTo(context, '/housing'),
                    semanticsIdentifier:
                        kDebugMode ? 'qa-home-housing' : null,
                  ),
                ),
              ];

              if (access.showVehicleHomeTile) {
                tiles.add(
                  SizedBox(
                    width: moduleTileW,
                    child: _HomeActionCard(
                      icon: MdiIcons.carSide,
                      label: l10n.homeModuleVehicle,
                      onTap: sandbox
                          ? null
                          : () => navigateTo(context, '/vehicle'),
                      enabled: !sandbox,
                      semanticsIdentifier:
                          kDebugMode ? 'qa-home-vehicle' : null,
                    ),
                  ),
                );
              }

              if (access.showVehicleSharingHomeTile) {
                tiles.add(
                  SizedBox(
                    width: moduleTileW,
                    child: _HomeActionCard(
                      icon: Icons.car_rental,
                      label: l10n.homeModuleVehicleSharing,
                      onTap: sandbox
                          ? null
                          : () => navigateTo(context, '/vehicle-sharing'),
                      enabled: !sandbox,
                      semanticsIdentifier:
                          kDebugMode ? 'qa-home-vehicle-sharing' : null,
                    ),
                  ),
                );
              }

              tiles.add(
                SizedBox(
                  width: moduleTileW,
                  child: _HomeActionCard(
                    icon: Icons.workspace_premium_outlined,
                    label: l10n.homeModuleLicenses,
                    onTap: () => navigateToChild(context, '/licenses'),
                    semanticsIdentifier:
                        kDebugMode ? 'qa-home-licenses' : null,
                  ),
                ),
              );

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  contentInset + viewPadding.left,
                  contentInset + viewPadding.top,
                  contentInset + viewPadding.right,
                  contentInset + viewPadding.bottom,
                ),
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: tiles,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.semanticsIdentifier,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticsIdentifier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground =
        enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38);

    final card = InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foreground,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (semanticsIdentifier == null) return card;
    return Semantics(
      identifier: semanticsIdentifier,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: card,
    );
  }
}
