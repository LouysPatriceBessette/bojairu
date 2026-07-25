import 'package:flutter/material.dart';

import '../../contacts/avatar_palette.dart';
import '../../contacts/contact_display.dart';
import '../../db/app_database.dart';
import '../../debug/qa_contact_semantics.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_dialog.dart';
import 'generate_invitation_screen.dart';

/// Bottom sheet used by modules to select an existing Contact as a participant.
class ContactPickerSheet extends StatefulWidget {
  const ContactPickerSheet({
    super.key,
    required this.db,
    this.excludeContactIds = const <String>{},
    this.allowInvite = true,
  });

  final AppDatabase db;
  final Set<String> excludeContactIds;

  /// When false (e.g. Simulation mode), the invite CTA stays visible but
  /// disabled — real handshake invites are out of scope while sandboxed.
  final bool allowInvite;

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  late Future<List<Contact>> _future = _loadContacts();

  Future<List<Contact>> _loadContacts() async {
    final contacts = await widget.db.listContacts();
    return contacts
        .where(
          (c) =>
              c.kind == 'connected' &&
              !c.isBlocked &&
              !widget.excludeContactIds.contains(c.id),
        )
        .toList();
  }

  void _reload() {
    setState(() {
      _future = _loadContacts();
    });
  }

  Future<void> _inviteContact() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const GenerateInvitationScreen()),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            qaContactSemantics(
              identifier: kQaContactsPickerSheet,
              header: true,
              child: Text(
              l10n.contactsPickerTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<Contact>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final contacts = snapshot.data ?? const <Contact>[];
                  if (contacts.isEmpty) {
                    return const _ContactPickerEmptyState();
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return qaContactSemantics(
                        identifier: qaContactsRowSemanticsId(
                          contact.effectiveDisplayName,
                        ),
                        button: true,
                        onTap: () => Navigator.of(context).pop(contact),
                        child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(AvatarPalette.iconFor(contact.avatarId)),
                        ),
                        title: Text(contact.effectiveDisplayName),
                        subtitle: Text(_kindLabel(l10n, contact)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop(contact),
                      ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.send),
                label: Text(l10n.contactsInviteAction),
                onPressed: widget.allowInvite ? _inviteContact : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(AppLocalizations l10n, Contact contact) {
    if (contact.isBlocked) return l10n.contactsKindBlocked;
    return l10n.contactsKindConnected;
  }
}

class _ContactPickerEmptyState extends StatelessWidget {
  const _ContactPickerEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.contactsPickerEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.contactsPickerEmptyBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

Future<Contact?> showContactPickerSheet({
  required BuildContext context,
  required AppDatabase db,
  Set<String> excludeContactIds = const <String>{},
  bool allowInvite = true,
}) {
  return showAppModalBottomSheet<Contact>(
    context: context,
    guardKey: 'contactPicker',
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ContactPickerSheet(
      db: db,
      excludeContactIds: excludeContactIds,
      allowInvite: allowInvite,
    ),
  );
}
