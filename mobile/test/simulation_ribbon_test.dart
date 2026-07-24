import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/sandbox/simulation_ribbon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppPreferences> activeSimulationPrefs() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPreferences.load();
    await prefs.setSandboxMode(true);
    return prefs;
  }

  Widget app({
    required AppPreferences prefs,
    required bool hideWhenActive,
    bool exitEnabled = true,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: SimulationRibbonHost(
        prefs: prefs,
        hideWhenActive: hideWhenActive,
        exitEnabled: exitEnabled,
        child: const Scaffold(body: Text('Screenshot content')),
      ),
    );
  }

  testWidgets('active Simulation keeps its ribbon by default', (tester) async {
    final prefs = await activeSimulationPrefs();

    await tester.pumpWidget(app(prefs: prefs, hideWhenActive: false));
    await tester.pumpAndSettle();

    expect(find.text('Simulation mode'), findsOneWidget);
    expect(find.text('Screenshot content'), findsOneWidget);
  });

  testWidgets('screenshot mode hides only the Simulation ribbon', (
    tester,
  ) async {
    final prefs = await activeSimulationPrefs();

    await tester.pumpWidget(app(prefs: prefs, hideWhenActive: true));
    await tester.pumpAndSettle();

    expect(find.text('Simulation mode'), findsNothing);
    expect(find.text('Screenshot content'), findsOneWidget);
  });

  testWidgets('locked-in simulation shows ribbon but tap does not exit', (
    tester,
  ) async {
    final prefs = await activeSimulationPrefs();

    await tester.pumpWidget(
      app(prefs: prefs, hideWhenActive: false, exitEnabled: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Simulation mode'), findsOneWidget);
    await tester.tap(find.text('Simulation mode'));
    await tester.pumpAndSettle();

    expect(find.text('Leave simulation mode?'), findsNothing);
    expect(prefs.sandboxMode, isTrue);
  });
}
