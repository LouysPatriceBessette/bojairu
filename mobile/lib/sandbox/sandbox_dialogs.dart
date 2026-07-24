import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app_root_navigator.dart';
import '../db/app_database.dart';
import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import '../relay/handshake_orchestrator.dart';
import 'peer_simulator.dart';
import 'sandbox_lifecycle.dart';
import 'sandbox_mode.dart';

NavigatorState? get _sandboxRootNavigator => appRootNavigatorKey.currentState;

/// Exit simulation confirmation (ribbon tap, eight-hour nudge).
Future<bool> showSandboxExitConfirmDialog() async {
  final nav = _sandboxRootNavigator;
  if (nav == null || !nav.mounted) return false;
  final context = nav.context;
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(l10n.sandboxExitDialogTitle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.commonYes),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Leave simulation: leave housing screens, show restart dialog, wipe on Ok.
///
/// Wipe runs only after Ok so routes/listeners still see a bound
/// [AppDatabase.processScope] until the app closes.
Future<void> performSandboxExitWithRestartDialog({
  required AppPreferences prefs,
}) async {
  if (SandboxMode.lockedByBuild) return;

  PeerSimulator.maybeInstance?.pauseReactions();
  HandshakeOrchestrator.maybeInstance?.stopPolling();

  final navContext = appRootNavigatorKey.currentContext;
  if (navContext != null && navContext.mounted) {
    GoRouter.of(navContext).go('/');
  }
  await SchedulerBinding.instance.endOfFrame;

  final nav = _sandboxRootNavigator;
  if (nav == null || !nav.mounted) {
    final db = AppDatabase.maybeProcessScope;
    if (db != null) {
      await SandboxLifecycle.exitSimulation(prefs: prefs, db: db);
    }
    SystemNavigator.pop();
    return;
  }

  final context = nav.context;
  if (!context.mounted) {
    final db = AppDatabase.maybeProcessScope;
    if (db != null) {
      await SandboxLifecycle.exitSimulation(prefs: prefs, db: db);
    }
    SystemNavigator.pop();
    return;
  }
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Text(l10n.sandboxEnterRestartMessage),
      actions: [
        FilledButton(
          onPressed: () async {
            final db = AppDatabase.maybeProcessScope;
            if (db != null) {
              await SandboxLifecycle.exitSimulation(prefs: prefs, db: db);
            }
            // Close the process; skip Navigator.pop to avoid rebuilding routes
            // that may still hold steady-inbox listeners.
            SystemNavigator.pop();
          },
          child: Text(l10n.commonOk),
        ),
      ],
    ),
  );
}

/// After entering simulation: inform user and close the app.
///
/// Uses the same copy as enter (`sandboxEnterRestartMessage`).
Future<void> showSandboxRestartRequiredDialog() async {
  final nav = _sandboxRootNavigator;
  if (nav == null || !nav.mounted) {
    SystemNavigator.pop();
    return;
  }
  final context = nav.context;
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Text(l10n.sandboxEnterRestartMessage),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            SystemNavigator.pop();
          },
          child: Text(l10n.commonOk),
        ),
      ],
    ),
  );
}

/// After entering simulation: inform user and close the app.
Future<void> showSandboxEnterRestartDialog() async {
  final nav = _sandboxRootNavigator;
  if (nav == null || !nav.mounted) return;
  final context = nav.context;
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Text(l10n.sandboxEnterRestartMessage),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            SystemNavigator.pop();
          },
          child: Text(l10n.commonOk),
        ),
      ],
    ),
  );
}

void showSandboxErrorSnackBar(Object error) {
  final nav = _sandboxRootNavigator;
  if (nav == null || !nav.mounted) return;
  ScaffoldMessenger.of(nav.context).showSnackBar(
    SnackBar(content: Text('$error')),
  );
}
