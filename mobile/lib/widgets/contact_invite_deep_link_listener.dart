import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../contacts/invitation_code.dart';
import '../l10n/app_localizations.dart';
import '../prefs/app_preferences.dart';
import '../sandbox/sandbox_mode.dart';

/// Listens for `bojairu://contact/invite?...` app links and navigates
/// to the redeem screen with the full URI as [GoRouterState.extra].
///
/// Skips routing while onboarding is incomplete (the global redirect would
/// override `/contacts/redeem`); the invitee can paste the link after setup.
class ContactInviteDeepLinkListener extends StatefulWidget {
  const ContactInviteDeepLinkListener({
    super.key,
    required this.router,
    required this.prefs,
    required this.child,
  });

  final GoRouter router;
  final AppPreferences prefs;
  final Widget child;

  @override
  State<ContactInviteDeepLinkListener> createState() =>
      _ContactInviteDeepLinkListenerState();
}

class _ContactInviteDeepLinkListenerState
    extends State<ContactInviteDeepLinkListener> {
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    unawaited(_listen());
  }

  Future<void> _listen() async {
    if (kIsWeb) {
      // `bojairu://` is handled on Android/iOS; Flutter web uses https.
      return;
    }
    final appLinks = AppLinks();
    final initial = await appLinks.getInitialLink();
    if (!mounted) return;
    if (initial != null && isContactInvitationAppLink(initial)) {
      _scheduleGo(initial);
    }
    _subscription = appLinks.uriLinkStream.listen((uri) {
      if (!mounted) return;
      if (isContactInvitationAppLink(uri)) {
        _scheduleGo(uri);
      }
    });
  }

  void _scheduleGo(Uri uri) {
    if (!widget.prefs.onboardingComplete) {
      if (kDebugMode) {
        debugPrint(
          'Contact invite deep link ignored until onboarding completes.',
        );
      }
      return;
    }
    if (SandboxMode.isActive(widget.prefs)) {
      if (kDebugMode) {
        debugPrint(
          'Contact invite deep link ignored while simulation mode is active.',
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sandboxModuleDisabled)),
        );
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.router.go('/contacts/redeem', extra: uri.toString());
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
