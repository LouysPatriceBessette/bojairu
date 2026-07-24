import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../contacts/contact_invitations_repository.dart';
import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../debug/qa_contact_semantics.dart';
import '../../debug/qa_handshake_export.dart';
import '../../l10n/app_localizations.dart';
import '../../notifications/notification_flow_permission_trigger.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../sandbox/sandbox_mode.dart';
import '../../util/deadline_remaining.dart';
import '../../widgets/screen_body_padding.dart';
import '../../util/display_date.dart';
import '../../widgets/standard_validity_duration_bar.dart';

/// Screen that generates a new invitation code and presents it for out-of-band
/// sharing.
class GenerateInvitationScreen extends StatefulWidget {
  const GenerateInvitationScreen({
    super.key,
    this.reconnectContactId,
    this.viewInvitationId,
  });

  final String? reconnectContactId;

  /// When set, opens the share UI for an existing on-device invitation row.
  final String? viewInvitationId;

  @override
  State<GenerateInvitationScreen> createState() =>
      _GenerateInvitationScreenState();
}

class _GenerateInvitationScreenState extends State<GenerateInvitationScreen> {
  AppDatabase get _db => AppDatabase.processScope;
  late final ContactInvitationsRepository _repo = ContactInvitationsRepository(
    _db,
  );
  late final ContactsRepository _contacts = ContactsRepository(_db);

  Duration _validFor = const Duration(hours: 24);
  _GeneratedInvitation? _generated;
  Timer? _generatedPollTimer;
  bool _generating = false;
  bool _processingGeneratedPoll = false;
  bool _completingRedeem = false;
  String? _error;

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
      final viewId = widget.viewInvitationId?.trim();
      if (viewId != null && viewId.isNotEmpty) {
        unawaited(_loadExistingInvitation(viewId));
      }
    });
  }

  Future<void> _loadExistingInvitation(String invitationId) async {
    final row = await _repo.getById(invitationId);
    if (!mounted) return;
    if (row == null) {
      setState(() => _error = AppLocalizations.of(context).contactsHandshakeErrorUnknown);
      return;
    }
    if (row.status != InvitationStatus.pending &&
        row.status != InvitationStatus.expired) {
      if (!mounted) return;
      context.pop();
      return;
    }
    final share = _repo.sharePayloadFromRow(row);
    setState(() {
      _generated = _GeneratedInvitation(
        row: row,
        shortCode: share.shortCode,
        deepLink: share.deepLink,
        webLink: share.webLink,
      );
      _error = null;
    });
    final orchestrator = HandshakeOrchestrator.maybeInstance;
    if (orchestrator != null && row.status == InvitationStatus.pending) {
      _startGeneratedPolling(orchestrator);
      unawaited(_completeIfInvitationRedeemed());
    }
  }

  @override
  void dispose() {
    _generatedPollTimer?.cancel();
    super.dispose();
  }

  void _startGeneratedPolling(HandshakeOrchestrator orchestrator) {
    _generatedPollTimer?.cancel();
    _generatedPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollGeneratedInvitation(orchestrator)),
    );
    unawaited(_pollGeneratedInvitation(orchestrator));
  }

  Future<void> _pollGeneratedInvitation(
    HandshakeOrchestrator orchestrator,
  ) async {
    if (_processingGeneratedPoll || _completingRedeem || _generated == null) {
      return;
    }
    _processingGeneratedPoll = true;
    try {
      await orchestrator.processAllPendingHandshakes();
      await _completeIfInvitationRedeemed();
    } on HandshakeOrchestratorError catch (e) {
      debugPrint('Generated invitation polling failed: ${e.code}');
    } catch (error, stack) {
      debugPrint('Generated invitation polling failed: $error\n$stack');
    } finally {
      _processingGeneratedPoll = false;
    }
  }

  Future<void> _completeIfInvitationRedeemed() async {
    if (!mounted || _completingRedeem) return;
    final generated = _generated;
    if (generated == null) return;
    final stubId = generated.row.contactStubId;
    if (stubId == null || stubId.isEmpty) return;
    final contact = await _contacts.get(stubId);
    if (contact?.kind != 'connected') return;
    _completingRedeem = true;
    _generatedPollTimer?.cancel();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.contactsHandshakeCompleted)),
    );
    context.pop();
  }

  Future<void> _generate() async {
    if (_generating) return;
    final l10n = AppLocalizations.of(context);
    final orchestrator = HandshakeOrchestrator.maybeInstance;
    if (orchestrator == null) {
      setState(() {
        _error = l10n.contactsHandshakeNotAvailableYet;
      });
      return;
    }
    if (!mounted) return;
    final prefs = await AppPreferences.load();
    if (!mounted) return;
    final notificationResult = await const NotificationFlowPermissionTrigger()
        .ensure(
          context: context,
          prefs: prefs,
          switches: const {
            NotificationFlowSwitch.contactAddRequests,
            NotificationFlowSwitch.contactInvitationExpiration,
          },
        );
    if (notificationResult == NotificationFlowPermissionResult.abortFlow) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final stubName = prefs.displayName.isEmpty
          ? 'Pending invitation'
          : '${prefs.displayName}\u2019s contact';
      final stubAvatar = prefs.avatarId.isEmpty ? 'a01' : prefs.avatarId;
      final r = await orchestrator.generateInvitation(
        validFor: _validFor,
        stubDisplayName: stubName,
        stubAvatarId: stubAvatar,
        reconnectContactId: widget.reconnectContactId,
      );
      final result = _GeneratedInvitation(
        row: r.invitation,
        shortCode: r.shortCode,
        deepLink: r.deepLink,
        webLink: r.webLink,
      );
      if (!mounted) return;
      setState(() {
        _generated = result;
        _generating = false;
      });
      await qaExportHandshakeInvitationCode(r.shortCode);
      _startGeneratedPolling(orchestrator);
      unawaited(_completeIfInvitationRedeemed());
    } on HandshakeOrchestratorError catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = _handshakeErrorLabel(l10n, e.code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  String _handshakeErrorLabel(AppLocalizations l10n, String code) {
    return switch (code) {
      'relay_unavailable' ||
      'relay_error' => l10n.contactsHandshakeErrorRelayUnavailable,
      'already_completed' => l10n.contactsHandshakeErrorAlreadyCompleted,
      'nonce_already_consumed' => l10n.contactsHandshakeErrorNonceConsumed,
      'expired_code' || 'expired' => l10n.contactsHandshakeErrorExpired,
      _ => l10n.contactsHandshakeErrorUnknown,
    };
  }

  Future<void> _revoke() async {
    final invitation = _generated;
    if (invitation == null) return;
    await _repo.revoke(invitation.row.id);
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      unawaited(orch.cancelInvitationExpiryReminders(invitation.row.id));
    }
    if (!mounted) return;
    _generatedPollTimer?.cancel();
    setState(() => _generated = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final generated = _generated;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactsInviteTitle)),
      body: Padding(
        padding: screenBodyScrollPadding(context),
        child: generated == null
              ? _IntroForm(
                  selected: _validFor,
                  onSelect: (d) => setState(() => _validFor = d),
                  onGenerate: _generate,
                  busy: _generating,
                  error: _error,
                )
              : _GeneratedView(
                  shortCode: generated.shortCode,
                  deepLink: generated.deepLink,
                  webLink: generated.webLink,
                  expiresAt: generated.row.expiresAt,
                  showDeadlineRemaining:
                      generated.row.status == InvitationStatus.pending,
                  onRevoke: _revoke,
                ),
      ),
    );
  }
}

class _GeneratedInvitation {
  const _GeneratedInvitation({
    required this.row,
    required this.shortCode,
    required this.deepLink,
    required this.webLink,
  });

  final ContactInvitation row;
  final String shortCode;
  final String deepLink;
  final String webLink;
}

class _IntroForm extends StatelessWidget {
  const _IntroForm({
    required this.selected,
    required this.onSelect,
    required this.onGenerate,
    required this.busy,
    this.error,
  });

  final Duration selected;
  final ValueChanged<Duration> onSelect;
  final VoidCallback onGenerate;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.contactsInviteIntroTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.contactsInviteIntroBody),
        const SizedBox(height: 16),
        Text(
          l10n.contactsInviteValidityLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        StandardValidityDurationSegmented(
          selected: selected,
          onChanged: onSelect,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const Spacer(),
        qaContactSemantics(
          identifier: kQaContactsGenerateCode,
          label: l10n.contactsInviteGenerateAction,
          button: true,
          onTap: busy ? null : onGenerate,
          child: FilledButton.icon(
            icon: const Icon(Icons.send),
            label: Text(l10n.contactsInviteGenerateAction),
            onPressed: busy ? null : onGenerate,
          ),
        ),
      ],
    );
  }
}

class _GeneratedView extends StatelessWidget {
  const _GeneratedView({
    required this.shortCode,
    required this.deepLink,
    required this.webLink,
    required this.expiresAt,
    required this.showDeadlineRemaining,
    required this.onRevoke,
  });

  final String shortCode;
  final String deepLink;
  final String webLink;
  final DateTime expiresAt;
  final bool showDeadlineRemaining;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shareText = l10n.contactsInviteShareText(webLink, shortCode);
    // The QR card + buttons easily exceed a phone viewport. Make the
    // upper portion scrollable so it never overflows, then keep the
    // action buttons docked at the bottom of the available space.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDeadlineRemaining) ...[
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
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Semantics(
                            label: l10n.contactsInviteQrSemantics,
                            child: QrImageView(
                              data: deepLink,
                              version: QrVersions.auto,
                              size: 192,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.contactsInviteQrLabel,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.contactsInviteShortCodeLabel,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        qaContactSemantics(
                          identifier: kQaContactsInvitationShortCode,
                          label: shortCode,
                          child: SelectableText(
                            shortCode,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.copy),
                              label: Text(l10n.commonCopy),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: shortCode),
                                );
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.link),
                              label: Text(l10n.contactsInviteCopyShareText),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: shareText),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.contactsInviteShareWarning,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.cancel_outlined),
          label: Text(l10n.contactsInviteRevokeAction),
          onPressed: onRevoke,
        ),
      ],
    );
  }
}
