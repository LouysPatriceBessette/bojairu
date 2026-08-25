import 'package:compartarenta/l10n/app_localizations.dart';
import 'package:compartarenta/screens/vehicle_sharing/vehicle_sharing_module_capabilities_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpDialog(
    WidgetTester tester, {
    required bool vehiclePaid,
    required bool sharingPaid,
  }) async {
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showVehicleSharingModuleCapabilitiesDialog(
                context: context,
                vehiclePaid: vehiclePaid,
                sharingPaid: sharingPaid,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('capabilities dialog: unpaid licenses show red close icons',
      (tester) async {
    await pumpDialog(tester, vehiclePaid: false, sharingPaid: false);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.text('Ok'), findsOneWidget);
  });

  testWidgets('capabilities dialog: paid licenses show green checks',
      (tester) async {
    await pumpDialog(tester, vehiclePaid: true, sharingPaid: true);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('capabilities dialog: mixed license marks', (tester) async {
    await pumpDialog(tester, vehiclePaid: true, sharingPaid: false);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('capabilities dialog Ok closes it', (tester) async {
    await pumpDialog(tester, vehiclePaid: false, sharingPaid: false);
    await tester.tap(find.text('Ok'));
    await tester.pumpAndSettle();
    expect(find.byType(VehicleSharingModuleCapabilitiesDialog), findsNothing);
  });
}
