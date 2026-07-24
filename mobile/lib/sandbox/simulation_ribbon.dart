import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import 'sandbox_dialogs.dart';
import 'sandbox_mode.dart';

/// Full-width top banner in sandbox. Tap opens exit confirmation when enabled.
///
/// Pushes page content down so AppBar actions (e.g. Settings) stay reachable.
class SimulationRibbonHost extends StatelessWidget {
  const SimulationRibbonHost({
    super.key,
    required this.prefs,
    required this.child,
    this.hideWhenActive = false,
    this.exitEnabled = true,
  });

  final AppPreferences prefs;
  final Widget child;
  final bool hideWhenActive;

  /// When false (locked-in `SIMULATION` builds), the ribbon stays visible but
  /// is not tappable and does not advertise as a button.
  final bool exitEnabled;

  /// Previous diagonal label used 11; horizontal banner is 10% larger.
  static const double _labelFontSize = 11 * 1.10;

  Future<void> _onTap() async {
    final confirmed = await showSandboxExitConfirmDialog();
    if (!confirmed) return;

    try {
      await performSandboxExitWithRestartDialog(prefs: prefs);
    } catch (e) {
      showSandboxErrorSnackBar(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SandboxMode.isActive(prefs) || hideWhenActive) return child;
    final label = AppLocalizations.of(context).sandboxRibbonLabel;
    final topInset = MediaQuery.paddingOf(context).top;

    final bannerBody = Padding(
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: _labelFontSize,
              letterSpacing: 0.4,
              height: 1.1,
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xA0CC0000),
          child: Semantics(
            button: exitEnabled,
            label: label,
            child: exitEnabled
                ? InkWell(
                    onTap: _onTap,
                    child: bannerBody,
                  )
                : bannerBody,
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
