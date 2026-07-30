import 'package:flutter/material.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/screen_body_padding.dart';
import 'package:go_router/go_router.dart';

import '../../contacts/avatar_palette.dart';
import '../../contacts/profile_rename_policy.dart';
import '../../housing/housing_participant_profile_sync.dart';
import '../../contacts/contact_display.dart';
import '../../db/app_database.dart';
import '../../db/repositories/contacts_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../prefs/app_preferences.dart';
import '../../relay/handshake_orchestrator.dart';
import '../../util/routing_push_country_codes.dart';
import '../../widgets/routing_push_country_picker_sheet.dart';

/// Post-onboarding editing of the user's own display name and avatar.
class ProfileIdentitySettingsScreen extends StatefulWidget {
  const ProfileIdentitySettingsScreen({super.key, required this.prefs});

  final AppPreferences prefs;

  @override
  State<ProfileIdentitySettingsScreen> createState() =>
      _ProfileIdentitySettingsScreenState();
}

class _ProfileIdentitySettingsScreenState
    extends State<ProfileIdentitySettingsScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.prefs.displayName);
  late final TextEditingController _countryField = TextEditingController();
  late String _avatarId = widget.prefs.avatarId;
  bool _saving = false;
  List<ProfileRenameBlock> _renameBlocks = const [];
  bool _renameBlocksLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRenameBlocks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCountryFieldText();
  }

  Future<void> _loadRenameBlocks() async {
    final blocks = await listProfileRenameBlocks(AppDatabase.processScope);
    if (!mounted) return;
    setState(() {
      _renameBlocks = blocks;
      _renameBlocksLoading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _countryField.dispose();
    super.dispose();
  }

  void _syncCountryFieldText() {
    final label = _effectiveCountryDisplayName(context);
    if (_countryField.text != label) {
      _countryField.text = label;
    }
  }

  String _languageCode(BuildContext context) {
    return Localizations.localeOf(context).languageCode;
  }

  String _effectiveCountryDisplayName(BuildContext context) {
    final code = _effectiveCountryCode();
    final country = supportedRoutingPushCountryByCode(code);
    if (country == null) return code;
    return country.displayName(_languageCode(context));
  }

  String _effectiveCountryCode() {
    final raw = widget.prefs.notificationCountryStatisticsCode;
    if (raw != null && raw.length == 2) {
      final found = supportedRoutingPushCountryByCode(raw);
      if (found != null) return found.code;
    }
    return kRoutingPushSupportedCountries.first.code;
  }

  Future<void> _setCountryStatisticsEnabled(bool value) async {
    await widget.prefs.setNotificationCountryStatisticsEnabled(value);
    if (value &&
        (widget.prefs.notificationCountryStatisticsCode == null ||
            widget.prefs.notificationCountryStatisticsCode!.isEmpty)) {
      await widget.prefs.setNotificationCountryStatisticsCode(
        kRoutingPushSupportedCountries.first.code,
      );
    }
    HandshakeOrchestrator.requestClosedAppPushRegistrationSync();
    if (!mounted) return;
    _syncCountryFieldText();
    setState(() {});
  }

  bool get _displayNameChanged =>
      _name.text.trim() != widget.prefs.displayName.trim();

  bool get _nameChangeBlocked =>
      !_renameBlocksLoading && _renameBlocks.isNotEmpty && _displayNameChanged;

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      _avatarId.trim().isNotEmpty &&
      !_nameChangeBlocked &&
      !_saving;

  Future<List<Contact>> _connectedContacts() async {
    final repo = ContactsRepository(AppDatabase.processScope);
    final all = await repo.list();
    return all.where((c) => c.kind == 'connected').toList();
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final newName = _name.text.trim();
    final nameChanged = _displayNameChanged;
    if (nameChanged &&
        await profileDisplayNameChangeBlocked(AppDatabase.processScope)) {
      await _loadRenameBlocks();
      if (!mounted) return;
      setState(() => _saving = false);
      return;
    }
    await widget.prefs.setProfileIdentity(
      displayName: newName,
      avatarId: _avatarId,
    );
    if (nameChanged) {
      await syncSelfParticipantRowsForProfile(
        db: AppDatabase.processScope,
        displayName: newName,
        avatarId: _avatarId,
      );
    }
    final repo = ContactsRepository(AppDatabase.processScope);
    await repo.clearTheirLabelForMeWhenMatchesCanonical(_name.text.trim());
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      orch.steadyStateInboxTick.value = orch.steadyStateInboxTick.value + 1;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    context.pop();
  }

  Widget _appearancesTable(
    BuildContext context,
    AppLocalizations l10n,
    AsyncSnapshot<List<Contact>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final connected = snapshot.data ?? const <Contact>[];
    if (connected.isEmpty) {
      return Text(
        l10n.settingsProfileAppearancesEmpty,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final withShared = connected
        .where((c) => (c.theirLabelForMe ?? '').trim().isNotEmpty)
        .toList();
    if (withShared.isEmpty) {
      return Text(
        l10n.settingsProfileAppearancesNoSharedLabels,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                l10n.settingsProfileAppearancesColumnPeer,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                l10n.settingsProfileAppearancesColumnTheirLabel,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final c in withShared) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  c.effectiveDisplayName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  c.theirLabelForMe!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsProfileIdentityTitle)),
      body: ListView(
        padding: screenBodyScrollPadding(context),
        children: [
          Text(
            l10n.settingsProfileIdentitySubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.onboardingNameLabel,
              hintText: l10n.onboardingNameHint,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_nameChangeBlocked) ...[
            const SizedBox(height: 12),
            Text(
              l10n.settingsProfileRenameBlockedBody(
                _renameBlocks.map((b) => b.planTitle).toSet().join(', '),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            l10n.onboardingAvatarTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: AvatarPalette.length,
              itemBuilder: (context, index) {
                final id = AvatarPalette.idFor(index);
                final selected = id == _avatarId;
                return InkWell(
                  onTap: () => setState(() => _avatarId = id),
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: selected ? 2 : 1,
                      ),
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                    ),
                    child: Icon(AvatarPalette.iconAt(index)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.settingsProfileAppearancesTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsProfileAppearancesBody,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          HandshakeOrchestrator.maybeInstance == null
              ? FutureBuilder<List<Contact>>(
                  future: _connectedContacts(),
                  builder: (context, snapshot) =>
                      _appearancesTable(context, l10n, snapshot),
                )
              : ListenableBuilder(
                  listenable:
                      HandshakeOrchestrator.maybeInstance!.steadyStateInboxTick,
                  builder: (context, _) {
                    return FutureBuilder<List<Contact>>(
                      key: ValueKey<int>(
                        HandshakeOrchestrator
                            .maybeInstance!.steadyStateInboxTick.value,
                      ),
                      future: _connectedContacts(),
                      builder: (context, snapshot) =>
                          _appearancesTable(context, l10n, snapshot),
                    );
                  },
                ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            l10n.settingsNotificationsCountryStatsSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsNotificationsCountryStatsSwitchTitle),
            subtitle: Text(
              l10n.settingsNotificationsCountryStatsSwitchSubtitle,
            ),
            value: widget.prefs.notificationCountryStatisticsEnabled,
            onChanged: _setCountryStatisticsEnabled,
          ),
          if (widget.prefs.notificationCountryStatisticsEnabled)
            AppTextFormField(
              key: const ValueKey('countryStatsCountryField'),
              readOnly: true,
              canRequestFocus: false,
              controller: _countryField,
              decoration: InputDecoration(
                labelText: l10n.settingsNotificationsCountryStatsPickerLabel,
                hintText: l10n.settingsNotificationsCountryStatsSearchHint,
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              onTap: () async {
                FocusScope.of(context).unfocus();
                final code = await showRoutingPushCountryPicker(
                  context,
                  searchHint: l10n.settingsNotificationsCountryStatsSearchHint,
                  emptyLabel: l10n.settingsNotificationsCountryStatsEmpty,
                  languageCode: _languageCode(context),
                  selectedCode: _effectiveCountryCode(),
                );
                if (code == null) return;
                await widget.prefs.setNotificationCountryStatisticsCode(code);
                HandshakeOrchestrator.requestClosedAppPushRegistrationSync();
                if (mounted) {
                  _syncCountryFieldText();
                  setState(() {});
                }
              },
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => context.pop(),
                child: Text(l10n.commonCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(l10n.commonSave),
              ),
            ],
          ),
          // Keep the country picker dropdown above the system nav bar.
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
