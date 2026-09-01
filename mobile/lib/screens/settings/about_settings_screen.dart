import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/app_config.dart';
import '../../entitlement/participant_installation_store.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/async_state.dart';
import '../../widgets/screen_body_padding.dart';

class AboutSettingsScreen extends StatefulWidget {
  const AboutSettingsScreen({
    super.key,
    required this.config,
    this.installationId,
  });

  final AppConfig config;
  final Future<String>? installationId;

  @override
  State<AboutSettingsScreen> createState() => _AboutSettingsScreenState();
}

class _AboutSettingsScreenState extends State<AboutSettingsScreen> {
  late Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  late final Future<String> _installationId =
      widget.installationId ??
      ParticipantInstallationStore.secureStorage().loadOrCreateId();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAboutTitle)),
      body: ListView(
        padding: screenBodyScrollPadding(context, content: EdgeInsets.zero),
        children: [
          ListTile(
            title: Text(l10n.settingsEnvironmentTitle),
            subtitle: Text(widget.config.environment.name),
          ),
          ListTile(
            title: Text(l10n.settingsApiBaseUrlTitle),
            subtitle: Text(widget.config.apiBaseUrl.toString()),
          ),
          FutureBuilder(
            future: _installationId,
            builder: (context, snapshot) => ListTile(
              title: Text(l10n.settingsInstallationIdTitle),
              subtitle: Text(
                snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData
                    ? snapshot.data!
                    : l10n.commonNotSet,
              ),
            ),
          ),
          FutureBuilder(
            future: _packageInfo,
            builder: (context, snapshot) {
              final info = snapshot.data;
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingView(),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ErrorView(
                    title: l10n.errorSomethingWentWrongTitle,
                    body: l10n.errorSomethingWentWrongBody,
                    onRetry: () {
                      setState(() {
                        _packageInfo = PackageInfo.fromPlatform();
                      });
                    },
                  ),
                );
              }

              final subtitle = info == null
                  ? l10n.commonNotSet
                  : _formatVersionLine(
                      version: info.version,
                      buildNumber: info.buildNumber,
                      gitSha: widget.config.gitSha,
                    );

              return ListTile(
                title: Text(l10n.settingsAppVersionTitle),
                subtitle: Text(subtitle),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _formatVersionLine({
  required String version,
  required String buildNumber,
  required String gitSha,
}) {
  final base = '$version ($buildNumber)';
  if (gitSha.isEmpty) return base;
  return '$base · $gitSha';
}
