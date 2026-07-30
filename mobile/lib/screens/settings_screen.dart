import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/app_dialog.dart';
import '../widgets/screen_body_padding.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../db/db_reset.dart';
import '../debug/web_dev_host_session.dart';
import '../l10n/app_localizations.dart';
import '../notifications/developer_test_notification.dart';
import '../notifications/developer_test_notification_result.dart';
import '../prefs/app_preferences.dart';
import '../relay/handshake_orchestrator.dart';
import '../relay/identity_keystore.dart';
import '../util/product_legal_urls.dart';
import 'package:compartarenta/navigation/app_navigation.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.config, required this.prefs});

  final AppConfig config;
  final AppPreferences prefs;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final privacyPolicyUrl = privacyPolicyUrlForLocale(locale);
    final faqIndexUrl = faqIndexUrlForLocale(locale);
    final showDevTools = widget.config.environment != AppEnvironment.prod;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: screenBodyScrollPadding(context, content: EdgeInsets.zero),
        children: [
          ListTile(
            title: Text(l10n.settingsLanguageTitle),
            subtitle: Text(l10n.settingsLanguageSubtitle),
            trailing: DropdownButton<String?>(
              value: widget.prefs.languageCode,
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.languageSystem)),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(l10n.languageEnglish),
                ),
                DropdownMenuItem(value: 'fr', child: Text(l10n.languageFrench)),
                DropdownMenuItem(
                  value: 'es',
                  child: Text(l10n.languageSpanish),
                ),
              ],
              onChanged: (value) async {
                await widget.prefs.setLanguageCode(value);
              },
            ),
          ),
          ListTile(
            title: Text(l10n.settingsProfileTitle),
            subtitle: Text(
              widget.prefs.displayName.isEmpty
                  ? l10n.commonNotSet
                  : widget.prefs.displayName,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => navigateToChild(context, '/settings/profile'),
          ),
          ListTile(
            title: Text(l10n.settingsNotificationsTitle),
            subtitle: Text(l10n.settingsNotificationsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => navigateToChild(context, '/settings/notifications'),
          ),
          ListTile(
            title: Text(l10n.settingsUnitsTitle),
            subtitle: Text(l10n.settingsUnitsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => navigateToChild(context, '/settings/units'),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.settingsActivityLogTitle),
            subtitle: Text(l10n.settingsActivityLogSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => navigateToChild(context, '/settings/activity-log'),
          ),
          ListTile(
            title: Text(l10n.settingsExportImportTitle),
            subtitle: Text(l10n.settingsExportImportSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => navigateToChild(context, '/settings/export-import'),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.helpFaqTitle),
            subtitle: Text(l10n.helpFaqIntro),
            onTap: () async {
              await launchUrl(
                faqIndexUrl,
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          ListTile(
            title: Text(l10n.settingsPrivacyPolicyTitle),
            subtitle: Text(l10n.settingsPrivacyPolicySubtitle),
            onTap: () async {
              await launchUrl(
                privacyPolicyUrl,
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          ListTile(
            title: Text(l10n.settingsAboutTitle),
            subtitle: Text(l10n.settingsAboutSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => navigateToChild(context, '/settings/about'),
          ),
          if (showDevTools) ...[
            const Divider(),
            ListTile(
              title: const Text('Developer tools'),
              subtitle: const Text('Development-only actions'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Send test notification'),
              subtitle: const Text(
                'Sends a local notification with TEST text.',
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final result = await sendDeveloperTestNotification(
                  widget.prefs,
                );
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(_testNotificationMessage(result))),
                );
              },
            ),
            ListTile(
              title: const Text('Reset onboarding & preferences'),
              subtitle: const Text(
                'Clears onboarding progress and saved preferences.',
              ),
              onTap: () async {
                final confirmed = await showAppDialog<bool>(
                  context: context,
                  guardKey: 'settings.resetOnboarding',
                  builder: (context) => AlertDialog(
                    title: const Text('Reset onboarding & preferences?'),
                    content: const Text(
                      'This will clear onboarding progress and preferences stored on this device. '
                      'Use only during development.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );

                if (confirmed != true) return;
                await widget.prefs.resetOnboardingAndPreferences();
                if (kDebugMode && kIsWeb) {
                  await clearDevHostSessionAfterWipe();
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      kIsWeb
                          ? 'Onboarding, preferences, and web host session backup cleared.'
                          : 'Onboarding and preferences reset.',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Reset local database'),
              subtitle: Text(
                kIsWeb
                    ? 'Deletes browser Drift storage (OPFS), housing draft '
                        'mirrors, and ~/.cache/compartarenta/web-dev-session.json '
                        'via the dev server. Clears relay test identity when configured.'
                    : 'Deletes on-device SQLite (plans, agreements, contacts, '
                        'invitations, handshakes). Clears relay test identity '
                        'when a relay URL is configured.',
              ),
              onTap: () async {
                final confirmed = await showAppDialog<bool>(
                  context: context,
                  guardKey: 'settings.resetDatabase',
                  builder: (context) => AlertDialog(
                    title: const Text('Reset local database?'),
                    content: Text(
                      kIsWeb
                          ? 'This will delete the local Drift database in '
                              'browser storage (OPFS), housing draft mirrors '
                              'in localStorage, and the host web-dev-session '
                              'backup file, including contacts and housing data. '
                              'If this build targets a relay, the local X25519 '
                              'test identity is cleared as well.\n\n'
                              'Hard-reload this page afterward (not hot '
                              'restart) so the database and relay stack are '
                              'recreated cleanly. Use only during development.'
                          : 'This will delete the local database directory on '
                              'this device, including all Contacts module data '
                              'stored in SQLite. If this build targets a relay '
                              '(non-placeholder API URL), the local X25519 '
                              'test identity in secure storage is cleared as '
                              'well.\n\n'
                              'Fully restart the app afterward so the database '
                              'and relay stack are recreated cleanly. '
                              'Use only during development.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );

                if (confirmed != true) return;

                final orch = HandshakeOrchestrator.maybeInstance;
                if (orch != null) {
                  await orch.releaseLocalDatabaseConnectionForDevReset();
                  HandshakeOrchestrator.clearInstalledInstanceAfterDevDatabaseReset();
                }
                if (widget.config.apiBaseUrl.host != 'example.invalid') {
                  await IdentityKeystore.secureStorage().deleteForTesting();
                }
                await DbReset.deleteLocalDbFiles(prefs: widget.prefs);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      kIsWeb
                          ? 'Browser database, mirrors, and host session backup '
                              'cleared. Hard-reload this tab (F5).'
                          : 'Local database and contact-related storage cleared. '
                              'Restart the app.',
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _testNotificationMessage(DeveloperTestNotificationResult result) {
    return switch (result) {
      DeveloperTestNotificationResult.shown => 'Test notification sent.',
      DeveloperTestNotificationResult.appNotificationsDisabled =>
        'App notifications are disabled in Settings.',
      DeveloperTestNotificationResult.permissionDenied =>
        'System notification permission is not granted.',
      DeveloperTestNotificationResult.unsupported =>
        'Test notifications are not supported on this platform.',
      DeveloperTestNotificationResult.failed =>
        'Could not send test notification.',
    };
  }
}
