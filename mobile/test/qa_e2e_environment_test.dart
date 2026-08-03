import 'package:compartarenta/debug/qa_e2e_environment.dart';
import 'package:compartarenta/debug/qa_e2e_meter_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => QaE2eFlags.setMeterPhotoOptional(false));

  test('QaE2eEnvironmentSnapshot round-trip json', () {
    const snapshot = QaE2eEnvironmentSnapshot(
      scenarioId: 'vehicle_use_session',
      languageCode: 'fr',
      meterPhotoOptional: true,
    );
    final restored = QaE2eEnvironmentSnapshot.fromJson(snapshot.toJson());
    expect(restored?.scenarioId, snapshot.scenarioId);
    expect(restored?.languageCode, snapshot.languageCode);
    expect(restored?.meterPhotoOptional, snapshot.meterPhotoOptional);
  });

  test('applyQaE2eEnvironmentSnapshot writes prefs and QA flag', () async {
    SharedPreferences.setMockInitialValues({});
    QaE2eFlags.setMeterPhotoOptional(false);

    await applyQaE2eEnvironmentSnapshot(
      const QaE2eEnvironmentSnapshot(
        scenarioId: 'vehicle_use_session',
        languageCode: 'fr',
        meterPhotoOptional: true,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('prefs.languageCode'), 'fr');
    expect(prefs.getBool(kQaE2eMeterPhotoOptionalPrefKey), isTrue);
    expect(prefs.getString(kQaE2eLastScenarioIdPrefKey), 'vehicle_use_session');
    expect(QaE2eFlags.meterPhotoOptional, isTrue);
  });

  test('persistQaE2eEnvironment defaults meterPhotoOptional to false', () async {
    SharedPreferences.setMockInitialValues({});
    QaE2eFlags.setMeterPhotoOptional(true);

    await persistQaE2eEnvironment(scenarioId: 'vehicle_sharing_active_owner');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kQaE2eMeterPhotoOptionalPrefKey), isFalse);
    expect(QaE2eFlags.meterPhotoOptional, isFalse);
  });
}
