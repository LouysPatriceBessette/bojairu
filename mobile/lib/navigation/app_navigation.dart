import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_root_navigator.dart';

/// Declarative navigation to [location] (GoRouter [GoRouter.go]).
///
/// Prefer this over [GoRouter.push] so the URL stack matches the logical
/// destination and the system back button does not walk unrelated history.
void navigateTo(BuildContext context, String location, {Object? extra}) {
  context.go(location, extra: extra);
}

/// Drill-down navigation (GoRouter [GoRouter.push]).
///
/// Use for child screens where the AppBar back affordance must return to the
/// parent (e.g. Settings → Units). [navigateTo] replaces the stack and hides
/// the automatic back button.
void navigateToChild(BuildContext context, String location, {Object? extra}) {
  context.push(location, extra: extra);
}

/// Push [location] when the user taps a notification.
///
/// Unlike [navigateTo], keeps the previous route on the stack so the screen
/// back button returns where the user was before opening the notification.
void pushFromNotificationTap(
  BuildContext context,
  String location, {
  Object? extra,
}) {
  context.push(location, extra: extra);
}

typedef NotificationTapSkipPredicate = bool Function(String matchedLocation);

/// Waits for [appRootNavigatorKey], then [pushFromNotificationTap].
///
/// When [skipPushWhenAlreadyAt] matches the current location, runs
/// [beforeNavigate] only (no stack push). Use this when the user is already
/// inside the target module (e.g. [/housing]) but sub-screens must still open.
void pushFromNotificationTapWhenReady(
  String location, {
  Object? extra,
  NotificationTapSkipPredicate? skipPushWhenAlreadyAt,
  Future<void> Function(BuildContext context)? beforeNavigate,
  int maxTries = 30,
}) {
  Future<void> attempt([int tries = 0]) async {
    final ctx = appRootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      final router = GoRouter.of(ctx);
      final skipPush =
          skipPushWhenAlreadyAt != null &&
          skipPushWhenAlreadyAt(router.state.matchedLocation);
      if (beforeNavigate != null) {
        await beforeNavigate(ctx).catchError((Object e, StackTrace st) {
          debugPrint(
            'pushFromNotificationTapWhenReady beforeNavigate: $e\n$st',
          );
        });
      }
      if (!skipPush && ctx.mounted) {
        pushFromNotificationTap(ctx, location, extra: extra);
      }
      return;
    }
    if (tries >= maxTries) {
      debugPrint(
        'pushFromNotificationTapWhenReady: skipped (no context) '
        'location=$location',
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(attempt(tries + 1));
    });
  }

  unawaited(attempt());
}

/// Opens a full-screen [route] by **replacing** the current route
/// ([Navigator.pushReplacement]).
///
/// **Warning — no automatic AppBar back:** the previous screen is removed from
/// the stack, so [AppBar] will not imply a leading back control. The user is
/// trapped unless you provide an explicit exit that navigates elsewhere, or the
/// platform system back leaves the whole module.
///
/// For drill-down (“view details”, journals, settings child, …) use
/// [navigateToChildRoute] ([Navigator.push]) instead — see skill
/// `flutter-in-app-back-navigation`.
Future<T?> navigateToRoute<T extends Object?>(
  BuildContext context,
  Route<T> route, {
  bool rootNavigator = false,
}) {
  return Navigator.of(context, rootNavigator: rootNavigator)
      .pushReplacement(route);
}

/// Drill-down navigation with a custom [Route] ([Navigator.push]).
///
/// Prefer over [navigateToRoute] whenever the AppBar back button must return to
/// the parent (e.g. housing summary → expenses in detail, hub → journals).
Future<T?> navigateToChildRoute<T extends Object?>(
  BuildContext context,
  Route<T> route, {
  bool rootNavigator = false,
}) {
  return Navigator.of(context, rootNavigator: rootNavigator).push(route);
}
