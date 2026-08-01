import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app_root_navigator.dart';
import 'config/app_config.dart';
import 'db/app_database.dart';
import 'db/repositories/contacts_repository.dart';
import 'prefs/app_preferences.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/settings/activity_log_settings_screen.dart';
import 'screens/settings/about_settings_screen.dart';
import 'screens/settings/device_data_export_import_screen.dart';
import 'screens/settings/notification_settings_screen.dart';
import 'screens/settings/profile_identity_settings_screen.dart';
import 'screens/settings/units_settings_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding/onboarding_shell.dart';
import 'screens/housing/housing_module_entry_screen.dart';
import 'screens/vehicle/vehicle_module_hub_screen.dart';
import 'screens/vehicle/vehicle_add_screen.dart';
import 'screens/vehicle/vehicle_detail_screen.dart';
import 'screens/vehicle/vehicle_statistics_screen.dart';
import 'screens/vehicle/vehicle_edit_details_screen.dart';
import 'screens/vehicle/vehicle_entry_log_screens.dart';
import 'screens/vehicle/vehicle_pending_corrections_screens.dart';
import 'screens/vehicle/vehicle_journals_screen.dart';
import 'screens/vehicle/vehicle_use_session_screen.dart';
import 'screens/vehicle/vehicle_quick_action_screens.dart';
import 'screens/vehicle_sharing/vehicle_sharing_hub_screen.dart';
import 'screens/vehicle_sharing/vehicle_sharing_invite_form_screen.dart';
import 'screens/vehicle_sharing/vehicle_sharing_other_actions_screen.dart';
import 'screens/vehicle_sharing/vehicle_sharing_shares_screen.dart';
import 'vehicle/vehicle_usage_context.dart';
import 'screens/contacts/contact_detail_screen.dart';
import 'screens/contacts/contact_edit_route_screen.dart';
import 'screens/contacts/contacts_list_screen.dart';
import 'screens/contacts/generate_invitation_screen.dart';
import 'screens/contacts/incoming_handshakes_screen.dart';
import 'screens/contacts/outstanding_invitations_screen.dart';
import 'contacts/profile_rename_policy.dart';
import 'housing/housing_plan_peer_contacts.dart';
import 'housing/housing_participant_profile_sync.dart';
import 'screens/contacts/redeem_invitation_screen.dart';
import 'relay/handshake_orchestrator.dart';
import 'notifications/closed_app_push_registration_service.dart';
import 'widgets/app_error_boundary.dart';
import 'widgets/cold_start_splash.dart';
import 'widgets/contact_invite_deep_link_listener.dart';
import 'widgets/connectivity_banner.dart';
import 'widgets/profile_label_conflict_host.dart';
import 'theme/app_theme.dart';
import 'util/native_plugin_link_error.dart';
import 'sandbox/sandbox_eight_hour_nudge.dart';
import 'sandbox/simulation_ribbon.dart';

class BojairuApp extends StatefulWidget {
  const BojairuApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<BojairuApp> createState() => _BojairuAppState();
}

class _BojairuAppState extends State<BojairuApp>
    with WidgetsBindingObserver {
  late Future<AppPreferences> _prefs = _loadPrefs();
  int _prefsLoadGeneration = 0;

  /// Reused across preference-driven rebuilds so navigation state is kept.
  GoRouter? _router;

  String _lastRoutingPushPrefsSig = '';
  String? _lastMaterialAppLocaleOverride;

  void _retryPrefsLoad() {
    setState(() {
      _prefsLoadGeneration++;
      _prefs = _loadPrefs();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) {
      if (state == AppLifecycleState.resumed) {
        unawaited(
          HandshakeOrchestrator.maybeInstance?.pollSteadyStateInboxes().catchError(
            (Object error, StackTrace stack) {
              debugPrint('Relay poll on web resume failed: $error\n$stack');
            },
          ),
        );
      }
      switch (state) {
        case AppLifecycleState.paused:
        case AppLifecycleState.hidden:
        case AppLifecycleState.detached:
          break;
        default:
          return;
      }
      try {
        unawaited(
          AppDatabase.processScope.syncWebStorageToDisk().catchError(
            (Object error, StackTrace stack) {
              debugPrint('Drift web flush on $state failed: $error\n$stack');
            },
          ),
        );
      } on StateError {
        // processScope not bound yet (tests).
      }
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ClosedAppPushRegistrationService.maybeInstance?.syncIfNeeded(),
      );
    }
  }

  Future<AppPreferences> _loadPrefs() async {
    final prefs = await AppPreferences.load();
    _wireProfileBroadcaster(prefs);
    _wireClosedAppPush(prefs);
    _wireHousingReminderTimezone(prefs);
    _wireMaterialAppLocaleRebuild(prefs);
    return prefs;
  }

  /// Rebuild [MaterialApp.router] only when the language override changes — not
  /// for unrelated prefs (timezone, units, …) which would lock the navigator.
  void _wireMaterialAppLocaleRebuild(AppPreferences prefs) {
    _lastMaterialAppLocaleOverride = prefs.languageCode;
    prefs.addListener(() {
      final next = prefs.languageCode;
      if (next == _lastMaterialAppLocaleOverride) return;
      _lastMaterialAppLocaleOverride = next;
      if (mounted) setState(() {});
    });
  }

  void _wireHousingReminderTimezone(AppPreferences prefs) {
    String sig() => '${prefs.timeZonePolicy}|${prefs.timeZoneId}';
    var last = sig();
    prefs.addListener(() {
      final next = sig();
      if (next == last) return;
      last = next;
      unawaited(
        HandshakeOrchestrator.maybeInstance?.syncHousingPaymentReminderTimezone(),
      );
    });
  }

  void _wireClosedAppPush(AppPreferences prefs) {
    if (widget.config.apiBaseUrl.host == 'example.invalid') {
      return;
    }
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch == null) {
      return;
    }
    ClosedAppPushRegistrationService.install(
      relay: orch.relayClient,
      prefs: prefs,
    );
    HandshakeOrchestrator.refreshClosedAppPushRegistration = () async {
      await ClosedAppPushRegistrationService.maybeInstance?.sync(force: true);
    };
    unawaited(ClosedAppPushRegistrationService.maybeInstance?.syncIfNeeded());

    String routingPushSig() =>
        '${prefs.notificationsEnabled}|'
        '${prefs.notificationContactAddRequests}|'
        '${prefs.notificationHousingPaymentReminders}|'
        '${prefs.notificationHousingPlanSubmission}|'
        '${prefs.notificationHousingDecisionChange}|'
        '${prefs.notificationCountryStatisticsEnabled}|'
        '${prefs.notificationCountryStatisticsCode ?? ''}';
    _lastRoutingPushPrefsSig = routingPushSig();
    prefs.addListener(() {
      final next = routingPushSig();
      if (next == _lastRoutingPushPrefsSig) {
        return;
      }
      _lastRoutingPushPrefsSig = next;
      unawaited(
        ClosedAppPushRegistrationService.maybeInstance?.sync(force: true),
      );
    });
  }

  String _lastProfileSignature = '';
  void _wireProfileBroadcaster(AppPreferences prefs) {
    _lastProfileSignature = '${prefs.displayName}|${prefs.avatarId}';
    prefs.addListener(() {
      final dn = prefs.displayName;
      final av = prefs.avatarId;
      final sig = '$dn|$av';
      if (sig == _lastProfileSignature) return;
      final prevParts = _lastProfileSignature.split('|');
      final prevDn = prevParts.isNotEmpty ? prevParts.first : '';
      _lastProfileSignature = sig;

      if (dn.trim().isNotEmpty && dn != prevDn) {
        unawaited(_clearTheirLabelsIfCanonicalMatches(dn));
        unawaited(_syncSelfParticipantsIfAllowed(dn, av));
      }

      final orch = HandshakeOrchestrator.maybeInstance;
      if (orch == null) return;
      if (prefs.displayName.isEmpty || prefs.avatarId.isEmpty) return;
      if (dn != prevDn) {
        unawaited(_broadcastProfileIfAllowed(orch, dn, av, prefs));
        return;
      }
      // Fire and forget — broadcaster catches its own errors.
      // ignore: unawaited_futures
      orch.broadcastProfileUpdate(
        displayName: prefs.displayName,
        avatarId: prefs.avatarId,
      );
    });
  }

  Future<void> _syncSelfParticipantsIfAllowed(String dn, String av) async {
    try {
      if (await profileDisplayNameChangeBlocked(AppDatabase.processScope)) {
        return;
      }
      await syncSelfParticipantRowsForProfile(
        db: AppDatabase.processScope,
        displayName: dn,
        avatarId: av,
      );
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _broadcastProfileIfAllowed(
    HandshakeOrchestrator orch,
    String dn,
    String av,
    AppPreferences prefs,
  ) async {
    try {
      if (await profileDisplayNameChangeBlocked(AppDatabase.processScope)) {
        return;
      }
      await orch.broadcastProfileUpdate(displayName: dn, avatarId: av);
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _clearTheirLabelsIfCanonicalMatches(String canonical) async {
    try {
      final repo = ContactsRepository(AppDatabase.processScope);
      await repo.clearTheirLabelForMeWhenMatchesCanonical(canonical);
      final orch = HandshakeOrchestrator.maybeInstance;
      if (orch != null) {
        orch.steadyStateInboxTick.value = orch.steadyStateInboxTick.value + 1;
      }
    } catch (_) {
      // Best-effort; profile UI still loads from DB on next open.
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = FutureBuilder(
      key: ValueKey(_prefsLoadGeneration),
      future: _prefs,
      builder: (context, snapshot) {
        final prefs = snapshot.data;
        if (snapshot.hasError) {
          final error = snapshot.error!;
          final stack = snapshot.stackTrace;
          final lang = WidgetsBinding.instance.platformDispatcher.locale
              .languageCode;
          final pluginLink = isNativePluginLinkError(error);
          final errorTheme = buildAppTheme();
          final errorDarkTheme = buildAppDarkTheme();
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: errorTheme,
            darkTheme: errorDarkTheme,
            themeMode: ThemeMode.system,
            home: Scaffold(
              body: Builder(
                builder: (context) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            lang == 'fr'
                                ? 'Démarrage impossible'
                                : 'Startup failed',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            pluginLink
                                ? nativePluginLinkErrorRecoveryMessage(
                                    languageCode: lang,
                                  )
                                : '$error',
                          ),
                          if (pluginLink && stack != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              lang == 'fr'
                                  ? 'Détail technique'
                                  : 'Technical detail',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              '$error\n\n$stack',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ] else if (!pluginLink && stack != null) ...[
                            const SizedBox(height: 16),
                            SelectableText('$stack'),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _retryPrefsLoad,
                            child: Text(
                              lang == 'fr' ? 'Réessayer' : 'Retry',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done || prefs == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            darkTheme: buildAppDarkTheme(),
            themeMode: ThemeMode.system,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        _router ??= _createRouter(widget.config, prefs);
        final router = _router!;

        final override =
            _lastMaterialAppLocaleOverride ?? prefs.languageCode;
        final locale = override == null ? null : Locale(override);

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          theme: buildAppTheme(),
          darkTheme: buildAppDarkTheme(),
          themeMode: ThemeMode.system,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => AppErrorBoundary(
            child: ProfileLabelConflictHost(
              child: ConnectivityBanner(
                child: ContactInviteDeepLinkListener(
                  router: router,
                  prefs: prefs,
                  child: SimulationRibbonHost(
                    prefs: prefs,
                    hideWhenActive:
                        widget.config.screenshotMode &&
                        !kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.android,
                    exitEnabled: !widget.config.simulationLocked,
                    child: SandboxEightHourNudgeHost(
                      prefs: prefs,
                      child: SafeArea(
                        top: false,
                        bottom: false,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    return ColdStartSplash(child: app);
  }
}

GoRouter _createRouter(AppConfig config, AppPreferences prefs) {
  String? onboardingRedirect(BuildContext context, GoRouterState state) {
    final isOnboarding = state.matchedLocation.startsWith('/onboarding');
    if (prefs.onboardingComplete) {
      return isOnboarding ? '/' : null;
    }

    final next = nextOnboardingLocation(prefs);
    if (isOnboarding) {
      return state.matchedLocation == next ? null : next;
    }
    return next;
  }

  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    refreshListenable: prefs,
    redirect: onboardingRedirect,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            SettingsScreen(config: config, prefs: prefs),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) =>
            ProfileIdentitySettingsScreen(prefs: prefs),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (context, state) => NotificationSettingsScreen(prefs: prefs),
      ),
      GoRoute(
        path: '/settings/units',
        builder: (context, state) => UnitsSettingsScreen(prefs: prefs),
      ),
      GoRoute(
        path: '/settings/activity-log',
        builder: (context, state) => ActivityLogSettingsScreen(prefs: prefs),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => AboutSettingsScreen(config: config),
      ),
      GoRoute(
        path: '/settings/export-import',
        builder: (context, state) => const DeviceDataExportImportScreen(),
      ),
      GoRoute(
        path: '/housing',
        builder: (context, state) => HousingModuleEntryScreen(prefs: prefs),
      ),
      GoRoute(
        path: '/vehicle',
        builder: (context, state) => VehicleModuleHubScreen(prefs: prefs),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => VehicleAddScreen(prefs: prefs),
          ),
          GoRoute(
            path: 'statistics',
            builder: (context, state) =>
                VehicleStatisticsScreen(prefs: prefs),
          ),
          GoRoute(
            path: 'use-session',
            builder: (context, state) => VehicleUseSessionScreen(
              initialVehicleId: state.uri.queryParameters['vehicleId'],
              prefs: prefs,
              usageContext: const VehicleUsageContext.owner(),
            ),
          ),
          GoRoute(
            path: 'fuel-purchase',
            builder: (context, state) => VehicleFuelPurchaseScreen(
              initialVehicleId: state.uri.queryParameters['vehicleId'],
              prefs: prefs,
            ),
          ),
          GoRoute(
            path: ':vehicleId',
            builder: (context, state) => VehicleDetailScreen(
              vehicleId: state.pathParameters['vehicleId']!,
              prefs: prefs,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => VehicleEditDetailsScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                ),
              ),
              GoRoute(
                path: 'journals',
                builder: (context, state) => VehicleJournalsScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                ),
              ),
              GoRoute(
                path: 'pending-corrections',
                builder: (context, state) =>
                    VehiclePendingCorrectionsListScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                ),
                routes: [
                  GoRoute(
                    path: ':correctionReadingId',
                    builder: (context, state) =>
                        VehiclePendingCorrectionDetailScreen(
                      vehicleId: state.pathParameters['vehicleId']!,
                      correctionReadingId:
                          state.pathParameters['correctionReadingId']!,
                      prefs: prefs,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'meter-log',
                builder: (context, state) => VehicleMeterLogScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                ),
                routes: [
                  GoRoute(
                    path: ':readingId',
                    builder: (context, state) => VehicleMeterReadingDetailScreen(
                      vehicleId: state.pathParameters['vehicleId']!,
                      readingId: state.pathParameters['readingId']!,
                      prefs: prefs,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'fuel-log',
                builder: (context, state) => VehicleFuelLogScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                ),
                routes: [
                  GoRoute(
                    path: ':purchaseId',
                    builder: (context, state) =>
                        VehicleFuelPurchaseDetailScreen(
                      vehicleId: state.pathParameters['vehicleId']!,
                      purchaseId: state.pathParameters['purchaseId']!,
                      prefs: prefs,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'maintenance-log',
                builder: (context, state) => VehicleMaintenanceLogScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                ),
                routes: [
                  GoRoute(
                    path: ':eventId',
                    builder: (context, state) => VehicleMaintenanceDetailScreen(
                      vehicleId: state.pathParameters['vehicleId']!,
                      eventId: state.pathParameters['eventId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'violation-log',
                builder: (context, state) => VehicleViolationLogScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                ),
                routes: [
                  GoRoute(
                    path: ':violationId',
                    builder: (context, state) => VehicleViolationDetailScreen(
                      vehicleId: state.pathParameters['vehicleId']!,
                      violationId: state.pathParameters['violationId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'use',
                builder: (context, state) => VehicleUseSessionScreen(
                  initialVehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                  usageContext: const VehicleUsageContext.owner(),
                ),
              ),
              GoRoute(
                path: 'fuel',
                builder: (context, state) => VehicleFuelPurchaseScreen(
                  initialVehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                ),
              ),
              GoRoute(
                path: 'meter-reading',
                builder: (context, state) => VehicleStandaloneMeterReadingScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                ),
              ),
              GoRoute(
                path: 'maintenance',
                builder: (context, state) => VehicleMaintenanceFormScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                ),
              ),
              GoRoute(
                path: 'violation',
                builder: (context, state) => VehicleViolationFormScreen(
                  vehicleId: state.pathParameters['vehicleId']!,
                  prefs: prefs,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/vehicle-sharing',
        builder: (context, state) =>
            VehicleSharingHubScreen(prefs: prefs),
        routes: [
          GoRoute(
            path: ':vehicleId/shares',
            builder: (context, state) => VehicleSharingSharesScreen(
              vehicleId: state.pathParameters['vehicleId']!,
              prefs: prefs,
            ),
          ),
          GoRoute(
            path: ':vehicleId/invite-form',
            builder: (context, state) => VehicleSharingInviteFormScreen(
              vehicleId: state.pathParameters['vehicleId']!,
              contactId: state.uri.queryParameters['contactId'] ?? '',
              prefs: prefs,
            ),
          ),
          GoRoute(
            path: ':vehicleId/other-actions',
            builder: (context, state) {
              final borrower = state.uri.queryParameters['borrower'] ?? '';
              return VehicleSharingOtherActionsScreen(
                vehicleId: state.pathParameters['vehicleId']!,
                borrowerContactId: borrower,
                prefs: prefs,
              );
            },
          ),
          GoRoute(
            path: ':vehicleId/use',
            builder: (context, state) {
              final borrower = state.uri.queryParameters['borrower'] ?? '';
              return VehicleUseSessionScreen(
                initialVehicleId: state.pathParameters['vehicleId']!,
                prefs: prefs,
                usageContext: VehicleUsageContext.borrower(
                  actingContactId: borrower,
                ),
              );
            },
          ),
          GoRoute(
            path: ':vehicleId/fuel',
            builder: (context, state) {
              final borrower = state.uri.queryParameters['borrower'] ?? '';
              return VehicleFuelPurchaseScreen(
                initialVehicleId: state.pathParameters['vehicleId']!,
                prefs: prefs,
                usageContext: VehicleUsageContext.borrower(
                  actingContactId: borrower,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => ContactsListScreen(config: config),
        routes: [
          GoRoute(
            path: 'new',
            redirect: (context, state) => '/contacts/invitations/new',
          ),
          GoRoute(
            path: 'invite/new',
            builder: (context, state) {
              final extra = state.extra;
              return GenerateInvitationScreen(
                reconnectContactId: extra is String ? extra : null,
              );
            },
          ),
          GoRoute(
            path: 'invite/code/:invitationId',
            redirect: (context, state) =>
                '/contacts/invitations/code/${state.pathParameters['invitationId']}',
          ),
          GoRoute(
            path: 'invitations',
            builder: (context, state) => const OutstandingInvitationsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) {
                  final extra = state.extra;
                  return GenerateInvitationScreen(
                    reconnectContactId: extra is String ? extra : null,
                  );
                },
              ),
              GoRoute(
                path: 'code/:invitationId',
                builder: (context, state) => GenerateInvitationScreen(
                  viewInvitationId: state.pathParameters['invitationId'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'redeem',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is HousingMissingContactRedeemArgs) {
                return RedeemInvitationScreen(
                  housingMissingParticipantName: extra.displayName,
                );
              }
              final initial = extra is String ? extra : null;
              return RedeemInvitationScreen(initialInvitationUri: initial);
            },
          ),
          GoRoute(
            path: 'incoming',
            builder: (context, state) => const IncomingHandshakesScreen(),
          ),
          GoRoute(
            path: ':contactId',
            builder: (context, state) => ContactDetailScreen(
              contactId: state.pathParameters['contactId']!,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => ContactEditRouteScreen(
                  contactId: state.pathParameters['contactId']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/onboarding/:step',
        builder: (context, state) {
          final step = state.pathParameters['step'] ?? 'welcome';
          return OnboardingShell(config: config, prefs: prefs, step: step);
        },
      ),
    ],
  );
}
