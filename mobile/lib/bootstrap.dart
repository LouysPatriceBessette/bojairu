import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'debug/car_dev_seed.dart';
import 'debug/local_storage_startup_log.dart';
import 'debug/qa_db_snapshot.dart';
import 'debug/qa_e2e_environment.dart';
import 'debug/qa_e2e_meter_photo.dart';
import 'debug/qa_post_seed_actions.dart';
import 'debug/qa_scenario_seed.dart';
import 'debug/web_dev_db_write_observer.dart';
import 'debug/web_dev_host_session.dart';
import 'entitlement/entitlement_coordinator.dart';
import 'entitlement/housing_license_lifecycle_sync.dart';
import 'entitlement/module_entitlement_controller.dart';
import 'entitlement/app_module_id.dart';
import 'entitlement/participant_installation_store.dart';
import 'entitlement/plan_participant_installation_registry.dart';
import 'entitlement/store_billing_service.dart';
import 'relay/relay_diagnostics.dart';
import 'debug/web_storage_flush.dart';
import 'contacts/contact_invitations_repository.dart';
import 'db/app_database.dart';
import 'db/repositories/contacts_repository.dart';
import 'device/device_binding_service.dart';
import 'notifications/notification_permission_gate.dart';
import 'notifications/push_notification_service.dart';
import 'notifications/push_background_registration_stub.dart'
    if (dart.library.io) 'notifications/push_background_registration_io.dart';
import 'notifications/closed_app_push_workmanager_stub.dart'
    if (dart.library.io) 'notifications/closed_app_push_workmanager_io.dart';
import 'prefs/app_preferences.dart';
import 'relay/handshake_orchestrator.dart';
import 'relay/identity_keystore.dart';
import 'relay/relay_client.dart';
import 'sandbox/peer_simulator.dart';
import 'sandbox/sandbox_lifecycle.dart';
import 'sandbox/sandbox_mode.dart';
import 'sandbox/sandbox_relay.dart';

Future<void> bootstrap() async {
  final config = AppConfig.fromDartDefines();
  final sentryDsn = const String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  await runZonedGuarded(
    () async {
      // Drift (path_provider), secure storage, and plugins require binding first.
      // Opening [AppDatabase] before this can hang on Android (stuck native splash).
      WidgetsFlutterBinding.ensureInitialized();
      registerPushBackgroundHandler();

      final appDb = AppDatabase();
      AppDatabase.bindProcessScope(appDb);
      if (kDebugMode && kIsWeb) {
        debugWebDbFlushHook = scheduleDevHostSessionSave;
        debugWebDbWriteHook = () => scheduleDevHostSessionSave(appDb);
      }
      installWebStorageFlushOnPageHide();
      _startupMark('binding_done');

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (sentryDsn.isNotEmpty) {
          Sentry.captureException(details.exception, stackTrace: details.stack);
        }
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        if (sentryDsn.isNotEmpty) {
          Sentry.captureException(error, stackTrace: stack);
        }
        return false;
      };

      final ready = completeAppStartup(appDb: appDb, config: config);
      runApp(BojairuApp(config: config, ready: ready));

      if (sentryDsn.isNotEmpty) {
        unawaited(
          SentryFlutter.init((options) {
            options.dsn = sentryDsn;
            options.environment = config.environment.name;
            options.tracesSampleRate = kDebugMode ? 1.0 : 0.1;
          }),
        );
      }
    },
    (error, stack) async {
      if (sentryDsn.isNotEmpty) {
        await Sentry.captureException(error, stackTrace: stack);
      }
    },
  );
}

/// Opens storage, loads prefs, and starts relay after the first Flutter frame.
///
/// Bound [AppDatabase] is still lazy until [AppDatabase.warmUpStorage]; do not
/// start handshake polling before that returns.
@visibleForTesting
Future<AppPreferences> completeAppStartup({
  required AppDatabase appDb,
  required AppConfig config,
}) async {
  if (kDebugMode && kIsWeb) {
    await wipeWebDevBrowserStorageOnLaunchIfRequested(
      clearRelayIdentity: config.apiBaseUrl.host != 'example.invalid',
    );
  }

  // Snapshot steal/restore: identity before Drift open and before relay
  // IdentityKeystore.loadOrCreate in the blocks below.
  if (kDebugMode && !kIsWeb) {
    await maybeExportQaDbSnapshotIdentity();
    await maybeRestoreQaDbSnapshotIdentity();
  }

  try {
    await appDb.warmUpStorage();
  } catch (error, stack) {
    debugPrint(
      'AppDatabase warmUpStorage failed (stop melos, force-quit app, '
      'then `dart run melos run run:dev`): $error\n$stack',
    );
    return AppPreferences.load();
  }
  _startupMark('warmup_done');

  var prefs = await AppPreferences.load();
  try {
    if (config.simulationLocked) {
      await SandboxMode.ensureForcedSimulationPrefs(prefs);
    }
    await SandboxLifecycle.maybeRestoreCheckpointOnRealBoot(
      prefs: prefs,
      db: appDb,
    );
    if (kDebugMode && config.carDevSeed) {
      await maybeApplyCarDevSeed(appDb, enabled: true);
      prefs = await AppPreferences.load();
    }
    if (kDebugMode && !kIsWeb) {
      await restoreQaE2eEnvironmentIfPresent();
      await maybeApplyQaAndroidSeed(appDb);
      await restoreQaE2eEnvironmentIfPresent();
      await syncQaE2eFlagsFromPrefs();
    }
    if (kDebugMode && kIsWeb) {
      await restoreDevSessionFromHostIfNeeded(appDb);
      await reconcileDevOnboardingIfNeeded(appDb);
    }
    await logLocalStorageStartupDiagnostics(appDb);

    final moduleEntitlement = ModuleEntitlementController();
    ModuleEntitlementController.install(moduleEntitlement);
    await moduleEntitlement.load();
    unawaited(
      HousingLicenseLifecycleSync.apply(db: AppDatabase.maybeProcessScope),
    );
    var housingPaid = moduleEntitlement.isActivePaid(AppModuleId.housing);
    moduleEntitlement.addListener(() {
      final paid = moduleEntitlement.isActivePaid(AppModuleId.housing);
      if (paid == housingPaid) return;
      housingPaid = paid;
      unawaited(
        HousingLicenseLifecycleSync.apply(db: AppDatabase.maybeProcessScope),
      );
    });

    if (config.entitlementEnabled) {
      final registry = await PlanParticipantInstallationRegistry.load();
      final coordinator = EntitlementCoordinator(
        config: config,
        installationStore: ParticipantInstallationStore.secureStorage(),
        registry: registry,
      );
      EntitlementCoordinator.install(coordinator);
      moduleEntitlement.playTokenUploader = coordinator.uploadGooglePlayReceipt;
      unawaited(coordinator.ensureRegistered());
      unawaited(moduleEntitlement.uploadPendingPlayTokens());
    }

    // Listen to store purchaseStream for the whole process — not only while
    // Licenses is open (Flutter IAP: listen as early as possible).
    if (!kIsWeb) {
      final storeBilling = StoreBillingService(
        entitlement: moduleEntitlement,
      );
      StoreBillingService.install(storeBilling);
      unawaited(
        storeBilling.start().catchError((Object error, StackTrace stack) {
          debugPrint('StoreBillingService.start failed: $error\n$stack');
          return false;
        }),
      );
    }
  } catch (error, stack) {
    debugPrint('App startup after storage warm-up failed: $error\n$stack');
  }

  final sandboxActive = SandboxMode.isActive(prefs);
  if (!sandboxActive) {
    unawaited(_initializePushIfAlreadyAuthorized());
    if (!kIsWeb) {
      unawaited(
        scheduleClosedAppPushKeepAlive().catchError((
          Object error,
          StackTrace stack,
        ) {
          debugPrint(
            'Closed-app push WorkManager schedule failed: $error\n$stack',
          );
        }),
      );
    }
  }

  if (sandboxActive) {
    try {
      final identity = IdentityKeystore.secureStorage();
      final relay = SandboxRelay.instance;
      final orchestrator = HandshakeOrchestrator(
        db: appDb,
        identity: identity,
        relay: relay,
        contacts: ContactsRepository(appDb),
        invitations: ContactInvitationsRepository(appDb),
        entitlement: null,
        deviceBinding: DeviceBindingService(),
      );
      HandshakeOrchestrator.install(orchestrator);
      final peerSimulator = PeerSimulator.ensureInstalled(
        relay: relay,
        prefs: prefs,
      );
      // Bot peers are process-local; prefs + human contacts survive cold
      // start. Rebuild bots before the first proposal/amendment react.
      await peerSimulator.restoreInvitedBotsIfNeeded(
        humanOrchestrator: orchestrator,
      );
      if (kDebugMode) {
        RelayDiagnostics.steadyInboxPollLogging = true;
      }
      unawaited(
        orchestrator.processAllPendingHandshakes().catchError((
          Object error,
          StackTrace stack,
        ) {
          debugPrint('Initial handshake polling failed: $error\n$stack');
        }),
      );
      unawaited(
        orchestrator.pollSteadyStateInboxes().catchError((
          Object error,
          StackTrace stack,
        ) {
          debugPrint('Initial steady inbox poll failed: $error\n$stack');
        }),
      );
      orchestrator.startPolling();
    } catch (error, stack) {
      debugPrint('Sandbox relay bootstrap failed: $error\n$stack');
    }
  } else if (config.apiBaseUrl.host != 'example.invalid') {
    try {
      final identity = IdentityKeystore.secureStorage();
      final relay = HttpRelayClient(baseUrl: config.apiBaseUrl);
      EntitlementCoordinator? entitlementCoordinator =
          EntitlementCoordinator.maybeInstance;
      if (config.entitlementGateEnabled) {
        if (entitlementCoordinator == null) {
          final registry = await PlanParticipantInstallationRegistry.load();
          entitlementCoordinator = EntitlementCoordinator(
            config: config,
            installationStore: ParticipantInstallationStore.secureStorage(),
            registry: registry,
          );
          EntitlementCoordinator.install(entitlementCoordinator);
        }
        if (config.entitlementEnabled) {
          unawaited(entitlementCoordinator.ensureRegistered());
        }
      }
      final orchestrator = HandshakeOrchestrator(
        db: appDb,
        identity: identity,
        relay: relay,
        contacts: ContactsRepository(appDb),
        invitations: ContactInvitationsRepository(appDb),
        entitlement: entitlementCoordinator,
        deviceBinding: DeviceBindingService(),
      );
      HandshakeOrchestrator.install(orchestrator);
      if (kDebugMode) {
        RelayDiagnostics.steadyInboxPollLogging = true;
      }
      unawaited(
        orchestrator.processAllPendingHandshakes().catchError((
          Object error,
          StackTrace stack,
        ) {
          debugPrint('Initial handshake polling failed: $error\n$stack');
        }),
      );
      unawaited(
        orchestrator.pollSteadyStateInboxes().catchError((
          Object error,
          StackTrace stack,
        ) {
          debugPrint('Initial steady inbox poll failed: $error\n$stack');
        }),
      );
      orchestrator.startPolling();
      if (kDebugMode) {
        unawaited(
          runQaPostSeedActionsIfNeeded().catchError((
            Object error,
            StackTrace stack,
          ) {
            debugPrint('QA post-seed actions failed: $error\n$stack');
          }),
        );
      }
    } catch (error, stack) {
      debugPrint('Relay handshake bootstrap failed: $error\n$stack');
    }
  }

  _startupMark('startup_ready');
  return prefs;
}

void _startupMark(String label) {
  if (!kDebugMode) return;
  debugPrint('startup: $label');
}

Future<void> _initializePushIfAlreadyAuthorized() async {
  try {
    final status = await NotificationPermissionGate.instance.status();
    if (status == NotificationSystemPermissionStatus.granted ||
        status == NotificationSystemPermissionStatus.provisional) {
      await PushNotificationService.initialize();
    }
  } catch (e, st) {
    debugPrint('Push notification authorization check failed: $e\n$st');
  }
}
