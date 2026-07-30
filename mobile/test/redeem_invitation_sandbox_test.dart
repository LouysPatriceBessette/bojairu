import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/screens/contacts/redeem_invitation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('simulation mode pops redeem screen without staying', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPreferences.load();
    await prefs.setSandboxMode(true);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const RedeemInvitationScreen(),
                    ),
                  );
                },
                child: const Text('open-redeem'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open-redeem'));
    await tester.pumpAndSettle();

    expect(find.byType(RedeemInvitationScreen), findsNothing);
    expect(
      find.text(
        'Ce module n\'est pas disponible en mode simulation.',
      ),
      findsOneWidget,
    );
  });
}
