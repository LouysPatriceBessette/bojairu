import 'package:compartarenta/db/app_database.dart';
import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:compartarenta/screens/contacts/contact_picker_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('simulation mode disables Invite a contact button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          body: ContactPickerSheet(db: db, allowInvite: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final invite = find.widgetWithText(OutlinedButton, 'Inviter un contact');
    expect(invite, findsOneWidget);
    expect(tester.widget<OutlinedButton>(invite).onPressed, isNull);
  });

  testWidgets('allowInvite true keeps Invite a contact enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          body: ContactPickerSheet(db: db, allowInvite: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final invite = find.widgetWithText(OutlinedButton, 'Inviter un contact');
    expect(invite, findsOneWidget);
    expect(tester.widget<OutlinedButton>(invite).onPressed, isNotNull);
  });
}
