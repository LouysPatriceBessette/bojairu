import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../contacts/avatar_palette.dart';
import '../../contacts/contact_duplicate_handshake_dialog.dart';
import '../../contacts/contact_display.dart';
import '../../debug/qa_contact_semantics.dart';
import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../sandbox/peer_simulator.dart';
import '../../sandbox/sandbox_bot_catalog.dart';
import '../../sandbox/sandbox_mode.dart';
import 'package:compartarenta/navigation/app_navigation.dart';

/// Connected contacts first (A–Z), then other non-invitation rows (A–Z).
List<Contact> sortContactsForMainList(List<Contact> contacts) {
  bool isPendingInvitationStub(Contact contact) =>
      contact.id.startsWith('contact:handshake:') &&
      contact.kind != 'connected';

  int tier(Contact contact) {
    if (contact.kind == 'connected') return 0;
    if (isPendingInvitationStub(contact)) return -1;
    return 1;
  }

  final sorted = contacts.where((c) => !isPendingInvitationStub(c)).toList();
  sorted.sort((a, b) {
    final tierA = tier(a);
    final tierB = tier(b);
    if (tierA != tierB) return tierA.compareTo(tierB);
    return _compareDisplayNames(a, b);
  });
  return sorted;
}

int _compareDisplayNames(Contact a, Contact b) {
  final nameA = a.effectiveDisplayName.toLowerCase();
  final nameB = b.effectiveDisplayName.toLowerCase();
  final byName = nameA.compareTo(nameB);
  if (byName != 0) return byName;
  return a.id.compareTo(b.id);
}

/// Main entry point for the Contacts area.
class ContactsListScreen extends StatefulWidget {
  const ContactsListScreen({super.key, required this.config});

  final AppConfig config;

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  AppDatabase get _db => AppDatabase.processScope;
  late final ContactsRepository _repo = ContactsRepository(_db);
  HandshakeOrchestrator? get _orchestrator =>
      HandshakeOrchestrator.maybeInstance;

  Future<List<Contact>>? _future;
  bool _refreshingIncoming = false;
  bool _sandboxActive = false;

  /// Last seen length of [HandshakeOrchestrator.incomingHandshakes]. When it
  /// changes (e.g. inviter accepts the last request), we reload contacts so
  /// the list reflects [ContactsRepository.promoteToConnected] without leaving
  /// the screen.
  int _lastIncomingHandshakesCount = -1;
  bool _duplicateDialogInFlight = false;

  GoRouter? _router;

  void _onRouterChanged() {
    if (!mounted || _router == null) return;
    final path = _router!.routerDelegate.currentConfiguration.uri.path;
    if (path == '/contacts') _reload();
  }

  @override
  void initState() {
    super.initState();
    _reload();
    unawaited(_loadSandboxFlag());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router = GoRouter.of(context);
      _router!.routerDelegate.addListener(_onRouterChanged);
    });
    final orch = _orchestrator;
    if (orch != null) {
      _lastIncomingHandshakesCount = orch.incomingHandshakes.value.length;
      orch.incomingHandshakes.addListener(_onIncomingChanged);
      orch.steadyStateInboxTick.addListener(_onSteadyInboxTick);
      orch.pendingContactDuplicateDialog.addListener(_onPendingDuplicateDialog);
      unawaited(() async {
        await orch.processAllPendingHandshakes();
        await orch.refreshIncomingHandshakes();
      }());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeShowPendingDuplicateDialog());
      });
    }
  }

  Future<void> _loadSandboxFlag() async {
    final prefs = await AppPreferences.load();
    if (!mounted) return;
    setState(() => _sandboxActive = SandboxMode.isActive(prefs));
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouterChanged);
    _orchestrator?.incomingHandshakes.removeListener(_onIncomingChanged);
    _orchestrator?.steadyStateInboxTick.removeListener(_onSteadyInboxTick);
    _orchestrator?.pendingContactDuplicateDialog.removeListener(
      _onPendingDuplicateDialog,
    );
    super.dispose();
  }

  void _onPendingDuplicateDialog() {
    if (!mounted) return;
    unawaited(_maybeShowPendingDuplicateDialog());
  }

  Future<void> _maybeShowPendingDuplicateDialog() async {
    if (!mounted || _duplicateDialogInFlight) return;
    final orch = _orchestrator;
    final pending = orch?.pendingContactDuplicateDialog.value;
    if (pending == null) return;
    _duplicateDialogInFlight = true;
    try {
      await showContactDuplicateHandshakeDialog(context, pending: pending);
    } finally {
      orch?.pendingContactDuplicateDialog.value = null;
      _duplicateDialogInFlight = false;
    }
  }

  void _onSteadyInboxTick() {
    if (!mounted) return;
    _reload();
  }

  void _onIncomingChanged() {
    if (!mounted) return;
    final orch = _orchestrator;
    final n = orch?.incomingHandshakes.value.length ?? 0;
    if (n != _lastIncomingHandshakesCount) {
      _lastIncomingHandshakesCount = n;
      _reload();
      if (n == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future<void>.delayed(const Duration(milliseconds: 48), () {
            if (mounted) _reload();
          });
        });
      }
    }
    setState(() {});
  }

  void _reload() {
    setState(() {
      _future = _loadContacts();
    });
  }

  Future<List<Contact>> _loadContacts() async {
    final contacts = await _repo.list();
    return sortContactsForMainList(contacts);
  }

  void _openIncoming() {
    navigateTo(context, '/contacts/incoming');
  }

  void _openInviteContact() {
    unawaited(_openInviteContactAsync());
  }

  Future<void> _openInviteContactAsync() async {
    final prefs = await AppPreferences.load();
    if (!mounted) return;
    if (SandboxMode.isActive(prefs)) {
      final l10n = AppLocalizations.of(context);
      final sim = PeerSimulator.maybeInstance;
      if (sim == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sandboxEnterFailed)),
        );
        return;
      }
      if (sim.invitedCount >= SandboxBotCatalog.maxBots) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(l10n.sandboxBotsExhausted),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
        return;
      }
      final orch = _orchestrator;
      if (orch == null) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(l10n.sandboxInvitingBot)),
              ],
            ),
          ),
        ),
      );
      try {
        await sim.inviteNextBot(
          humanOrchestrator: orch,
          humanDisplayName: prefs.displayName,
          humanAvatarId: prefs.avatarId.isEmpty ? 'mdi:0' : prefs.avatarId,
        );
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        _reload();
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      return;
    }
    navigateTo(context, '/contacts/invitations/new');
  }

  Future<void> _refreshIncomingNow() async {
    final orch = _orchestrator;
    if (orch == null || _refreshingIncoming) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _refreshingIncoming = true);
    try {
      final showDiagnostics =
          widget.config.environment != AppEnvironment.prod;
      var activeCount = 0;
      var totalCount = 0;
      var latest = 'none';
      if (showDiagnostics) {
        final activeBefore = await orch.activePendingHandshakeRows();
        final allBefore = await orch.allPendingHandshakeRowsForDiagnostics();
        activeCount = activeBefore.length;
        totalCount = allBefore.length;
        final latestError =
            allBefore.isEmpty ? '' : allBefore.last.lastErrorCode;
        latest = allBefore.isEmpty
            ? 'none'
            : latestError.isEmpty
            ? allBefore.last.state
            : '${allBefore.last.state}/$latestError';
      }
      await orch.processAllPendingHandshakes();
      await orch.pollSteadyStateInboxes();
      await orch.refreshIncomingHandshakes();
      if (!mounted) return;
      _lastIncomingHandshakesCount = orch.incomingHandshakes.value.length;
      _reload();
      final count = orch.incomingHandshakes.value.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? showDiagnostics
                    ? l10n.contactsRefreshIncomingDiagnostics(
                        activeCount,
                        totalCount,
                        latest,
                      )
                    : l10n.contactsRefreshIncomingNone
                : l10n.contactsRefreshIncomingFound(count),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshingIncoming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(l10n.contactsTitle),
        actions: [
          IconButton(
            tooltip: l10n.contactsInvitationsTitle,
            icon: const Icon(Icons.outgoing_mail),
            onPressed: () => navigateTo(context, '/contacts/invitations'),
          ),
          qaContactSemantics(
            identifier: kQaContactsRedeemOpen,
            label: l10n.contactsEnterInviteCodeTitle,
            button: true,
            child: IconButton(
              tooltip: l10n.contactsEnterInviteCodeTitle,
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _sandboxActive
                  ? null
                  : () => navigateTo(context, '/contacts/redeem'),
            ),
          ),
          IconButton(
            tooltip: l10n.contactsRefreshIncomingTooltip,
            icon: _refreshingIncoming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _refreshingIncoming ? null : _refreshIncomingNow,
          ),
        ],
      ),
      floatingActionButton: qaContactSemantics(
        identifier: kQaContactsInviteFab,
        label: l10n.contactsAddContactAction,
        button: true,
        child: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add),
          label: Text(l10n.contactsAddContactAction),
          onPressed: _openInviteContact,
        ),
      ),
      body: Column(
        children: [
          _IncomingBanner(orchestrator: _orchestrator, onTap: _openIncoming),
          Expanded(
            child: FutureBuilder<List<Contact>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <Contact>[];
                if (items.isEmpty) {
                  return qaContactSemantics(
                    identifier: kQaContactsEmptyState,
                    label: l10n.contactsEmptyTitle,
                    child: const _ContactsEmptyState(),
                  );
                }
                final duplicateConnectedRowIds =
                    _duplicateConnectedRowSemanticsIds(items);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final rowId in duplicateConnectedRowIds)
                      qaContactSemantics(
                        identifier:
                            qaContactsDuplicateConnectedSemanticsId(rowId),
                        label: rowId,
                        child: Material(
                          color:
                              Theme.of(context).colorScheme.errorContainer,
                          child: ListTile(
                            dense: true,
                            title: Text(
                              'QA duplicate connected contact ($rowId)',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 0),
                        itemBuilder: (context, index) {
                          final contact = items[index];
                          return _ContactTile(
                            contact: contact,
                            onTap: () => navigateTo(
                              context,
                              '/contacts/${contact.id}',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingBanner extends StatelessWidget {
  const _IncomingBanner({required this.orchestrator, required this.onTap});

  final HandshakeOrchestrator? orchestrator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orch = orchestrator;
    if (orch == null) return const SizedBox.shrink();
    return ValueListenableBuilder<List<IncomingHandshakeView>>(
      valueListenable: orch.incomingHandshakes,
      builder: (context, value, _) {
        if (value.isEmpty) return const SizedBox.shrink();
        final count = value.length;
        return qaContactSemantics(
          identifier: kQaContactsIncomingBanner,
          label: count == 1
              ? l10n.contactsIncomingBannerOne
              : l10n.contactsIncomingBannerMany(count),
          button: true,
          child: Material(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        count == 1
                            ? l10n.contactsIncomingBannerOne
                            : l10n.contactsIncomingBannerMany(count),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Connected contacts that share a display-name slug (bug 1.22: duplicate Monica).
List<String> _duplicateConnectedRowSemanticsIds(List<Contact> items) {
  final counts = <String, int>{};
  for (final contact in items) {
    if (contact.kind != 'connected') continue;
    final rowId = qaContactsRowSemanticsId(contact.effectiveDisplayName);
    counts[rowId] = (counts[rowId] ?? 0) + 1;
  }
  return counts.entries
      .where((e) => e.value > 1)
      .map((e) => e.key)
      .toList(growable: false);
}

class _ContactsEmptyState extends StatelessWidget {
  const _ContactsEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(MdiIcons.accountMultipleOutline, size: 64),
          const SizedBox(height: 16),
          Text(
            l10n.contactsEmptyTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.contactsEmptyBody,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final Contact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blocked = contact.isBlocked;
    final connected = contact.kind == 'connected';
    final disconnected = contact.showsDisconnectedStatus;
    final statusLine = blocked
        ? l10n.contactsKindBlocked
        : connected
        ? l10n.contactsKindConnected
        : disconnected
        ? l10n.contactsKindDisconnected
        : l10n.contactsKindLocalOnly;
    final rowId = connected
        ? qaContactsRowSemanticsId(contact.effectiveDisplayName)
        : null;
    final tile = ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: blocked
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(AvatarPalette.iconFor(contact.avatarId)),
      ),
      title: Text(contact.effectiveDisplayName),
      subtitle: Text(statusLine),
      trailing: connected
          ? Icon(
              Icons.link,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.chevron_right),
    );
    if (rowId == null) return tile;
    return qaContactSemantics(
      identifier: rowId,
      label: contact.effectiveDisplayName,
      button: true,
      child: tile,
    );
  }
}
