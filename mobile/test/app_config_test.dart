import 'package:compartarenta/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiBaseUrl = 'https://example.invalid';

  test('screenshot mode is available in dev', () {
    final config = AppConfig(
      environment: AppEnvironment.dev,
      apiBaseUrl: Uri.parse(apiBaseUrl),
      screenshotMode: true,
    );

    expect(config.screenshotMode, isTrue);
  });

  test('screenshot mode is disabled outside dev', () {
    for (final environment in [AppEnvironment.staging, AppEnvironment.prod]) {
      final config = AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse(apiBaseUrl),
        screenshotMode: true,
      );

      expect(config.screenshotMode, isFalse);
    }
  });

  test('simulationLocked is independent of environment', () {
    for (final environment in AppEnvironment.values) {
      final config = AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse(apiBaseUrl),
        simulationLocked: true,
      );

      expect(config.simulationLocked, isTrue);
    }
  });
}
