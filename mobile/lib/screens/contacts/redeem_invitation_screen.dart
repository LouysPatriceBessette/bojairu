import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_text_field.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../contacts/contact_duplicate_handshake_dialog_state.dart';
import '../../contacts/invitation_code.dart';
import '../../debug/qa_contact_semantics.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/screen_body_padding.dart';
import '../../notifications/contact_notification_service.dart';
import '../../notifications/notification_flow_permission_trigger.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../sandbox/sandbox_mode.dart';
import '../../util/deadline_remaining.dart';
import '../../util/display_date.dart';
import '../../util/product_legal_urls.dart';

/// Screen for the invitee to enter a received invitation code.
///
/// Performs a local checksum validation, then — when the user taps
/// Connect — dispatches the encrypted `hello` envelope to the relay via
/// [HandshakeOrchestrator]. The accepted/rejected outcome is surfaced
/// later by the orchestrator's poller (see `ContactsListScreen`).
class RedeemInvitationScreen extends StatefulWidget {
  const RedeemInvitationScreen({
    super.key,
    this.initialInvitationUri,
    this.housingMissingParticipantName,
  });

  /// Full `bojairu://contact/invite?...` URI from an app link
  /// ([GoRouterState.extra]) or tests.
  final String? initialInvitationUri;

  /// When opened from a housing proposal, names the co-participant to connect
  /// with (invitation code still required from that person).
  final String? housingMissingParticipantName;

  @override
  State<RedeemInvitationScreen> createState() => _RedeemInvitationScreenState();
}

class _RedeemInvitationScreenState extends State<RedeemInvitationScreen> {
  final _controller = TextEditingController();
  InvitationCodeParseResult? _result;
  DateTime? _resolvedExpiresAtUtc;
  bool _dispatching = false;
  String? _dispatchError;
  bool _dispatched = false;
  bool _completed = false;
  bool _rejected = false;
  bool _duplicateAnchorRejectBanner = false;
  String? _redeemHandshakeId;
  Timer? _outcomePollTimer;
  bool _outcomePollInFlight = false;
  bool _navigatingAfterCompletion = false;

  /// Local polling cadence used while the invitee is sitting on this
  /// screen waiting for the inviter to accept/reject. The orchestrator's
  /// own poller already ticks every 10s; the short cadence here lets us
  /// react within ~2s when both peers are physically together (the QR
  /// case), without churning the relay when the screen is hidden — the
  /// timer is cancelled in [dispose].
  static const Duration _outcomePollInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await AppPreferences.load();
      if (!mounted) return;
      if (SandboxMode.isActive(prefs)) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sandboxModuleDisabled)),
        );
        Navigator.of(context).maybePop();
        return;
      }
      final initial = widget.initialInvitationUri?.trim();
      if (initial != null && initial.isNotEmpty) {
        _controller.text = initial;
        _validate();
      }
    });
  }

  @override
  void dispose() {
    _outcomePollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final value = _controller.text;
    final parsed = parseInvitationInput(value);
    DateTime? expiresAt;
    if (parsed is InvitationCodeOk) {
      expiresAt = parsed.expiresAtUtc;
    }
    setState(() {
      _result = parsed;
      _resolvedExpiresAtUtc = expiresAt;
      _dispatchError = null;
      _dispatched = false;
      _completed = false;
      // Keep _rejected / _duplicateAnchorRejectBanner until navigation or retry.
      _outcomePollTimer?.cancel();
      _outcomePollTimer = null;
      _redeemHandshakeId = null;
    });
    if (parsed is InvitationCodeOk && expiresAt == null) {
      unawaited(_resolveExpiryFromLocalInvitation(parsed.code));
    }
  }

  Future<void> _resolveExpiryFromLocalInvitation(InvitationCode code) async {
    final orchestrator = HandshakeOrchestrator.maybeInstance;
    if (orchestrator == null) return;
    final expiresAt = await orchestrator.lookupInvitationExpiresAtUtc(code);
    if (!mounted || expiresAt == null) return;
    setState(() => _resolvedExpiresAtUtc = expiresAt);
  }

  bool _isInvitationExpired() {
    final expiresAt = _resolvedExpiresAtUtc;
    if (expiresAt == null) return false;
    return DeadlineRemaining.compute(expiresAt, DateTime.now().toUtc()).isExpired;
  }

  Future<void> _connect(InvitationCode code) async {
    if (_dispatching) return;
    final orchestrator = HandshakeOrchestrator.maybeInstance;
    if (orchestrator == null) {
      _showHandshakeUnavailable(context);
      return;
    }
    if (!mounted) return;
    final prefs = await AppPreferences.load();
    if (!mounted) return;
    if (SandboxMode.isActive(prefs)) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sandboxModuleDisabled)),
      );
      return;
    }
    final notificationResult = await const NotificationFlowPermissionTrigger()
        .ensure(
          context: context,
          prefs: prefs,
          switches: const <NotificationFlowSwitch>{
            NotificationFlowSwitch.contactAddRequests,
          },
        );
    if (notificationResult == NotificationFlowPermissionResult.abortFlow ||
        !mounted) {
      return;
    }
    setState(() {
      _dispatching = true;
      _dispatchError = null;
      _dispatched = false;
      _completed = false;
      _rejected = false;
      _duplicateAnchorRejectBanner = false;
    });
    try {
      final selfName = prefs.displayName.isEmpty
          ? 'Unknown'
          : prefs.displayName;
      final selfAvatar = prefs.avatarId.isEmpty ? 'a01' : prefs.avatarId;
      final redeem = await orchestrator.redeemInvitation(
        code: code,
        selfDisplayName: selfName,
        selfAvatarId: selfAvatar,
      );
      // Kick the poller once; further relay reads use the orchestrator timer.
      // ignore: unawaited_futures
      orchestrator.processAllPendingHandshakes();
      if (!mounted) return;
      setState(() {
        _dispatching = false;
        _dispatched = true;
        _redeemHandshakeId = redeem.handshakeId;
      });
      _startOutcomePolling(orchestrator);
    } on HandshakeOrchestratorError catch (e) {
      await const DefaultContactNotificationSink().contactAddRequestFailed(
        errorCode: e.code,
      );
      if (!mounted) return;
      setState(() {
        _dispatching = false;
        _dispatchError = e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dispatching = false;
        _dispatchError = e.toString();
      });
    }
  }

  void _startOutcomePolling(HandshakeOrchestrator orchestrator) {
    _outcomePollTimer?.cancel();
    _outcomePollTimer = Timer.periodic(
      _outcomePollInterval,
      (_) => unawaited(_pollOutcome(orchestrator)),
    );
    unawaited(_pollOutcome(orchestrator));
  }

  Future<void> _pollOutcome(HandshakeOrchestrator orchestrator) async {
    if (_outcomePollInFlight || _navigatingAfterCompletion) return;
    final handshakeId = _redeemHandshakeId;
    if (handshakeId == null) return;
    _outcomePollInFlight = true;
    try {
      await orchestrator.processAllPendingHandshakes();
      final state = await orchestrator.pendingHandshakeState(handshakeId);
      if (!mounted || state == null) return;
      switch (state) {
        case HandshakeState.completed:
          _onHandshakeCompleted();
        case HandshakeState.rejected:
          _onHandshakeRejected();
        case HandshakeState.failed:
          final code = await orchestrator.pendingHandshakeErrorCode(
            handshakeId,
          );
          if (!mounted) return;
          _onHandshakeFailed(code);
      }
    } on HandshakeOrchestratorError catch (e) {
      debugPrint('Outcome polling failed: ${e.code}');
    } catch (error, stack) {
      debugPrint('Outcome polling failed: $error\n$stack');
    } finally {
      _outcomePollInFlight = false;
    }
  }

  void _onHandshakeCompleted() {
    if (_navigatingAfterCompletion) return;
    _navigatingAfterCompletion = true;
    _outcomePollTimer?.cancel();
    setState(() {
      _completed = true;
      _rejected = false;
      _dispatched = false;
    });
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.contactsHandshakeCompleted)));
    // Defer navigation by one frame so the snackbar is enqueued on the
    // root messenger before we leave this route. Only navigate when the
    // user is still on this screen — `mounted` guards the post-frame
    // callback, so a manual return mid-flight keeps the user wherever
    // they navigated to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/contacts');
      }
    });
  }

  void _onHandshakeRejected() {
    _outcomePollTimer?.cancel();
    final pending =
        HandshakeOrchestrator.maybeInstance?.pendingContactDuplicateDialog.value;
    final anchorReject =
        pending?.kind == ContactDuplicateDialogKind.inviteeRejectedAnchor;
    setState(() {
      _rejected = true;
      _duplicateAnchorRejectBanner = anchorReject;
      _completed = false;
      _dispatched = false;
    });
  }

  void _onHandshakeFailed(String? code) {
    final errorCode = (code == null || code.isEmpty) ? 'failed' : code;
    unawaited(
      const DefaultContactNotificationSink().contactAddRequestFailed(
        errorCode: errorCode,
      ),
    );
    _outcomePollTimer?.cancel();
    setState(() {
      _completed = false;
      _rejected = false;
      _dispatched = false;
      _dispatchError = errorCode;
    });
  }

  String _errorLabel(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context);
    return switch (code) {
      'relay_unavailable' => l10n.contactsHandshakeErrorRelayUnavailable,
      'relay_error' => l10n.contactsHandshakeErrorRelayUnavailable,
      'already_completed' => l10n.contactsHandshakeErrorAlreadyCompleted,
      'nonce_already_consumed' => l10n.contactsHandshakeErrorNonceConsumed,
      'expired_code' || 'expired' => l10n.contactsHandshakeErrorExpired,
      'failed' => l10n.contactsHandshakeFailed,
      _ => l10n.contactsHandshakeErrorUnknown,
    };
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    final text = _displayTextForScannedValue(data?.text ?? '');
    _controller.text = text;
    _validate();
  }

  Future<void> _scanQrCode() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _InvitationQrScannerScreen()),
    );
    if (!mounted || scanned == null) return;
    _controller.text = _displayTextForScannedValue(scanned);
    _validate();
  }

  String _displayTextForScannedValue(String value) {
    final parsed = parseInvitationInput(value);
    if (parsed is InvitationCodeOk) {
      return parsed.code.renderShort();
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _result;
    final expiresAt = _resolvedExpiresAtUtc;
    final showDeadline =
        result is InvitationCodeOk &&
        expiresAt != null &&
        !_dispatched &&
        !_completed &&
        !_rejected;
    final codeExpired = _isInvitationExpired();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactsEnterInviteCodeTitle)),
      body: SingleChildScrollView(
        padding: screenBodyScrollPadding(context),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.housingMissingParticipantName != null &&
                  widget.housingMissingParticipantName!.trim().isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      l10n.housingInviteMissingContactsRedeemBanner(
                        widget.housingMissingParticipantName!.trim(),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                l10n.contactsEnterInviteCodeIntro,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              qaContactSemantics(
                identifier: kQaContactsRedeemCodeField,
                label: l10n.contactsEnterInviteCodeFieldLabel,
                textField: true,
                child: AppTextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: l10n.contactsEnterInviteCodeFieldLabel,
                    hintText: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste),
                      tooltip: l10n.commonPaste,
                      onPressed: _pasteFromClipboard,
                    ),
                  ),
                  onChanged: (_) => _validate(),
                  textCapitalization: TextCapitalization.none,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l10n.contactsEnterInviteCodeScanQr),
                onPressed: _scanQrCode,
              ),
              const SizedBox(height: 16),
              if (result is InvitationCodeOk)
                _OkResult(invitationIdHex: result.code.invitationIdHex()),
              if (showDeadline) ...[
                const SizedBox(height: 8),
                FutureBuilder<AppPreferences>(
                  future: AppPreferences.load(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    return Center(
                      child: DeadlineDisplay(
                        title: l10n.contactsInviteDeadlineTitle,
                        deadlineUtc: expiresAt,
                        dateFormat: effectiveDateFormat(snap.data!),
                        l10n: l10n,
                      ),
                    );
                  },
                ),
              ],
              if (result is InvitationCodeBad) _BadResult(error: result.error),
              if (_dispatchError != null) ...[
                const SizedBox(height: 8),
                qaContactSemantics(
                  identifier: kQaContactsHandshakeError,
                  label: _errorLabel(context, _dispatchError!),
                  child: Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off_outlined),
                      title: Text(_errorLabel(context, _dispatchError!)),
                    ),
                  ),
                ),
              ],
              if (_dispatched) ...[
                const SizedBox(height: 8),
                qaContactSemantics(
                  identifier: kQaContactsHandshakeDispatched,
                  label: l10n.contactsHandshakeDispatched,
                  child: Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_top_outlined),
                      title: Text(l10n.contactsHandshakeDispatched),
                    ),
                  ),
                ),
              ],
              if (_duplicateAnchorRejectBanner) ...[
                const SizedBox(height: 8),
                const _DuplicateAnchorRejectBanner(),
              ] else if (_rejected) ...[
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.cancel_outlined),
                    title: Text(l10n.contactsHandshakeRejected),
                  ),
                ),
              ],
              if (_completed) ...[
                const SizedBox(height: 8),
                qaContactSemantics(
                  identifier: kQaContactsHandshakeCompleted,
                  label: l10n.contactsHandshakeCompleted,
                  child: Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(l10n.contactsHandshakeCompleted),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  final canSubmit = result is InvitationCodeOk &&
                      !_dispatching &&
                      !_dispatched &&
                      !_completed &&
                      !_rejected &&
                      !codeExpired;
                  final submit = canSubmit ? () => _connect(result.code) : null;
                  return qaContactSemantics(
                    identifier: kQaContactsRedeemSubmit,
                    label: _dispatching
                        ? l10n.contactsHandshakeDispatching
                        : l10n.contactsEnterInviteCodeSubmit,
                    button: true,
                    enabled: canSubmit,
                    onTap: submit,
                    child: FilledButton.icon(
                      icon: _dispatching
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(
                        _dispatching
                            ? l10n.contactsHandshakeDispatching
                            : l10n.contactsEnterInviteCodeSubmit,
                      ),
                      onPressed: submit,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
    );
  }

  void _showHandshakeUnavailable(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.contactsHandshakeNotAvailableYet)),
    );
  }
}

class _InvitationQrScannerScreen extends StatefulWidget {
  const _InvitationQrScannerScreen();

  @override
  State<_InvitationQrScannerScreen> createState() =>
      _InvitationQrScannerScreenState();
}

class _InvitationQrScannerScreenState
    extends State<_InvitationQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _returned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_returned) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.trim().isEmpty) continue;
      _returned = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactsEnterInviteCodeScanQr)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.contactsEnterInviteCodeScanQrHint,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateAnchorRejectBanner extends StatefulWidget {
  const _DuplicateAnchorRejectBanner();

  @override
  State<_DuplicateAnchorRejectBanner> createState() =>
      _DuplicateAnchorRejectBannerState();
}

class _DuplicateAnchorRejectBannerState
    extends State<_DuplicateAnchorRejectBanner> {
  late final TapGestureRecognizer _readMoreRecognizer;

  @override
  void initState() {
    super.initState();
    _readMoreRecognizer = TapGestureRecognizer()
      ..onTap = () {
        final locale = Localizations.localeOf(context);
        unawaited(
          launchUrl(
            contactDuplicateFaqUrlForLocale(locale),
            mode: LaunchMode.externalApplication,
          ),
        );
      };
  }

  @override
  void dispose() {
    _readMoreRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return qaContactSemantics(
      identifier: kQaContactsDuplicateAnchorRejectBanner,
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(text: l10n.contactsDuplicateInviteeRejectedBannerBody),
                const TextSpan(text: ' '),
                TextSpan(
                  text: l10n.contactsDuplicateReadMore,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: _readMoreRecognizer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OkResult extends StatelessWidget {
  const _OkResult({required this.invitationIdHex});

  final String invitationIdHex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(l10n.contactsEnterInviteCodeValid),
        subtitle: Text(
          l10n.contactsEnterInviteCodeInvitationId(invitationIdHex),
        ),
      ),
    );
  }
}

class _BadResult extends StatelessWidget {
  const _BadResult({required this.error});

  final InvitationCodeError error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (error) {
      InvitationCodeError.empty => l10n.contactsCodeErrorEmpty,
      InvitationCodeError.tooShort => l10n.contactsCodeErrorTooShort,
      InvitationCodeError.tooLong => l10n.contactsCodeErrorTooLong,
      InvitationCodeError.invalidCharacters =>
        l10n.contactsCodeErrorInvalidCharacters,
      InvitationCodeError.badChecksum => l10n.contactsCodeErrorBadChecksum,
      InvitationCodeError.unsupportedVersion =>
        l10n.contactsCodeErrorUnsupportedVersion,
    };
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(message),
      ),
    );
  }
}
