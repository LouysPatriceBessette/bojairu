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
import 'entitlement/module_entitlement_controller.dart';
import 'entitlement/participant_installation_store.dart';
import 'entitlement/plan_participant_installation_registry.dart';
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

      final appDb = AppDatabase();
      AppDatabase.bindProcessScope(appDb);
      if (kDebugMode && kIsWeb) {
        debugWebDbFlushHook = scheduleDevHostSessionSave;
        debugWebDbWriteHook = () => scheduleDevHostSessionSave(appDb);
      }
      installWebStorageFlushOnPageHide();
      AppPreferences? earlyPrefs;
      try {
        await appDb.warmUpStorage();
        earlyPrefs = await AppPreferences.load();
        if (config.simulationLocked) {
          await SandboxMode.ensureForcedSimulationPrefs(earlyPrefs);
        }
        await SandboxLifecycle.maybeRestoreCheckpointOnRealBoot(
          prefs: earlyPrefs,
          db: appDb,
        );
        if (kDebugMode && config.carDevSeed) {
          await maybeApplyCarDevSeed(appDb, enabled: true);
          earlyPrefs = await AppPreferences.load();
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
      } catch (error, stack) {
        debugPrint(
          'AppDatabase warmUpStorage failed (stop melos, force-quit app, '
          'then `dart run melos run run:dev`): $error\n$stack',
        );
      }

      final early = earlyPrefs;
      final sandboxActive = early != null && SandboxMode.isActive(early);
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

      if (early != null && SandboxMode.isActive(early)) {
        try {
          final prefs = early;
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
          EntitlementCoordinator? entitlementCoordinator;
          if (config.entitlementGateEnabled) {
            final registry = await PlanParticipantInstallationRegistry.load();
            entitlementCoordinator = EntitlementCoordinator(
              config: config,
              installationStore: ParticipantInstallationStore.secureStorage(),
              registry: registry,
            );
            EntitlementCoordinator.install(entitlementCoordinator);
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

      if (sentryDsn.isEmpty) {
        runApp(BojairuApp(config: config));
        return;
      }

      await SentryFlutter.init((options) {
        options.dsn = sentryDsn;
        options.environment = config.environment.name;
        options.tracesSampleRate = kDebugMode ? 1.0 : 0.1;
      }, appRunner: () => runApp(BojairuApp(config: config)));
    },
    (error, stack) async {
      if (sentryDsn.isNotEmpty) {
        await Sentry.captureException(error, stackTrace: stack);
      }
    },
  );
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
