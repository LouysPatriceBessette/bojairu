import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:compartarenta/screens/operator_notice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    int? targetBuild,
    bool consultSite = false,
    required int installed,
    List<Uri>? launched,
    Uri? siteUri,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: OperatorNoticeScreen(
          targetBuild: targetBuild,
          consultSite: consultSite,
          installedBuildNumber: installed,
          siteUri: siteUri,
          launchUri: launched == null
              ? null
              : (uri) async {
                  launched.add(uri);
                  return true;
                },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('user-facing title is developer message, not Message manuel', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      locale: const Locale('fr'),
      consultSite: true,
      installed: 38,
    );
    expect(find.text('Message du développeur'), findsOneWidget);
    expect(find.text('Message manuel'), findsNothing);
  });

  testWidgets('shows Play badge only when installed is below target', (
    tester,
  ) async {
    final launched = <Uri>[];
    await pumpScreen(
      tester,
      targetBuild: 39,
      installed: 38,
      launched: launched,
    );
    expect(find.text('A new version is available.'), findsOneWidget);
    expect(find.text('Tap to update your application.'), findsOneWidget);
    expect(find.byKey(OperatorNoticeScreen.playBadgeKey), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    await tester.tap(find.byKey(OperatorNoticeScreen.playBadgeKey));
    await tester.pumpAndSettle();
    expect(launched, [
      Uri.parse(
        'https://play.google.com/store/apps/details?id=app.incoherences.bojairu',
      ),
    ]);
  });

  testWidgets('hides Play update when installed meets target', (tester) async {
    await pumpScreen(
      tester,
      targetBuild: 39,
      installed: 39,
    );
    expect(find.text('A new version is available.'), findsNothing);
    expect(find.byKey(OperatorNoticeScreen.playBadgeKey), findsNothing);
  });

  testWidgets('consult site opens locale developer-message URL', (tester) async {
    final launched = <Uri>[];
    await pumpScreen(
      tester,
      locale: const Locale('fr'),
      consultSite: true,
      installed: 38,
      launched: launched,
    );
    expect(
      find.text('Un message du développeur de l’application a été publié.'),
      findsOneWidget,
    );
    expect(find.text('Lire le message'), findsOneWidget);
    expect(find.byKey(OperatorNoticeScreen.playBadgeKey), findsNothing);
    await tester.tap(find.text('Lire le message'));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse('https://bojairu.app/fr/message')]);
  });
}
