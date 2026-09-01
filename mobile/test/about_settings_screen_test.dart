import 'package:compartarenta/config/app_config.dart';
import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:compartarenta/screens/settings/about_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the full installation id in About', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AboutSettingsScreen(
          config: AppConfig(
            environment: AppEnvironment.dev,
            apiBaseUrl: Uri.parse('https://sync.incoherences.org'),
          ),
          installationId: Future.value('installation-device-full-id'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Identifiant d’installation'), findsOneWidget);
    expect(find.text('installation-device-full-id'), findsOneWidget);
  });
}
