enum AppEnvironment { dev, staging, prod }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.entitlementBaseUrl,
    this.gitSha = '',
    bool screenshotMode = false,
    this.simulationLocked = false,
    this.carDevSeed = false,
  }) : screenshotMode = environment == AppEnvironment.dev && screenshotMode;

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  /// Entitlement service base URL. When null, entitlement client calls and
  /// relay `entitlement_gate` metadata are disabled.
  final Uri? entitlementBaseUrl;

  bool get entitlementEnabled =>
      entitlementBaseUrl != null &&
      entitlementBaseUrl!.host != 'example.invalid';

  /// Relay `entitlement_gate` metadata when a live relay is configured.
  bool get entitlementGateEnabled => apiBaseUrl.host != 'example.invalid';

  /// Short SHA of the commit the build was produced from, injected via
  /// `--dart-define=GIT_SHA=...` by `mobile/tool/compute_version.sh`. Empty
  /// string for unstamped `flutter run` development builds.
  final String gitSha;

  /// Hides the Simulation ribbon for Android screenshot capture.
  ///
  /// The constructor gates this to the dev environment. The UI additionally
  /// restricts it to native Android.
  final bool screenshotMode;

  /// When true (`--dart-define=SIMULATION=true`), start already in sandbox and
  /// disable product exit paths (ribbon tap, 8h nudge). Used by locked-in QA /
  /// closed-test builds; normal product builds omit this define.
  final bool simulationLocked;

  /// When true (`--dart-define=CARDEV=true`), flush local DB and seed vehicle-
  /// sharing development data (Simulation catalog contacts + QA Civic).
  final bool carDevSeed;

  static AppEnvironment _parseEnv(String value) {
    switch (value.trim().toLowerCase()) {
      case 'dev':
        return AppEnvironment.dev;
      case 'staging':
        return AppEnvironment.staging;
      case 'prod':
        return AppEnvironment.prod;
      default:
        return AppEnvironment.dev;
    }
  }

  static AppConfig fromDartDefines() {
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    const apiBaseUrl =
        String.fromEnvironment('API_BASE_URL', defaultValue: 'https://example.invalid');
    const entitlementBaseUrlRaw =
        String.fromEnvironment('ENTITLEMENT_BASE_URL', defaultValue: '');
    const gitSha = String.fromEnvironment('GIT_SHA', defaultValue: '');
    const screenshotMode = bool.fromEnvironment(
      'SCREENSHOT',
      defaultValue: false,
    );
    const simulationLocked = bool.fromEnvironment(
      'SIMULATION',
      defaultValue: false,
    );
    const carDevSeed = bool.fromEnvironment(
      'CARDEV',
      defaultValue: false,
    );

    Uri? entitlementBaseUrl;
    if (entitlementBaseUrlRaw.trim().isNotEmpty) {
      entitlementBaseUrl = Uri.parse(entitlementBaseUrlRaw.trim());
    }

    return AppConfig(
      environment: _parseEnv(env),
      apiBaseUrl: Uri.parse(apiBaseUrl),
      entitlementBaseUrl: entitlementBaseUrl,
      gitSha: gitSha,
      screenshotMode: screenshotMode,
      simulationLocked: simulationLocked,
      carDevSeed: carDevSeed,
    );
  }
}

