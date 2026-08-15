import 'package:compartarenta/config/app_config.dart';
import 'package:compartarenta/entitlement/app_module_id.dart';
import 'package:compartarenta/entitlement/housing_lifecycle_source.dart';
import 'package:compartarenta/entitlement/local_store_receipt_store.dart';
import 'package:compartarenta/entitlement/module_entitlement_controller.dart';
import 'package:compartarenta/entitlement/module_entitlement_state.dart';
import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ModuleEntitlementController.uninstall();
  });

  testWidgets('settings keeps export row when housing is read-only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.complete': true,
      'prefs.languageCode': 'en',
    });
    final now = DateTime.utc(2026, 8, 15);
    final controller = ModuleEntitlementController(
      receiptStore: LocalStoreReceiptStore(),
      clock: () => now,
    );
    ModuleEntitlementController.install(controller);
    await controller.load();
    controller.setHousingLifecycle(
      HousingLifecycleSource.afterTrialExpired(
        trialStartedAt: DateTime.utc(2026, 7, 1),
        trialEndsAt: DateTime.utc(2026, 7, 15),
      ),
    );
    expect(
      controller.stateOf(AppModuleId.housing),
      ModuleEntitlementState.delinquentReadonly,
    );

    final prefs = await AppPreferences.load();
    final config = AppConfig(
      environment: AppEnvironment.dev,
      apiBaseUrl: Uri.parse('https://example.invalid'),
    );
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              SettingsScreen(config: config, prefs: prefs),
        ),
        GoRoute(
          path: '/settings/export-import',
          builder: (context, state) => const Scaffold(
            body: Text('Export / import data'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Export / import data'), findsOneWidget);
    await tester.tap(find.text('Export / import data'));
    await tester.pumpAndSettle();
    expect(find.text('Export / import data'), findsWidgets);
  });
}
