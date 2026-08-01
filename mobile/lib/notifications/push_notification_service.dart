import 'dart:async' show unawaited;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../navigation/app_navigation.dart';
import '../db/app_database.dart';
import '../housing/amendment/housing_amendment_summary.dart';
import '../housing/housing_navigation_intent.dart';
import '../housing/reminders/payment_reminder_journal_id.dart';
import '../firebase_options.dart';
import '../prefs/app_preferences.dart';
import '../relay/handshake_orchestrator.dart';
import 'closed_app_push_registration_service.dart';
import 'notification_localizations.dart';
import 'notification_qa_prefix.dart';
import 'housing_browser_notification_stub.dart'
    if (dart.library.html) 'housing_browser_notification_web.dart'
    as housing_browser;
import 'wake_inbox_background_poll.dart';
import '../housing/realized_expense/realized_expense_status.dart';

/// FCM + local notifications for housing proposals (and future message types).
///
/// Requires a real Firebase project: replace [DefaultFirebaseOptions] via
/// `flutterfire configure` and ship a matching `android/app/google-services.json`.
class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'housing_proposals_v1',
        'Housing proposals',
        description:
            'Alerts when a co-participant sends a housing plan proposal.',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel
  _androidSilentChannel = AndroidNotificationChannel(
    'housing_proposals_silent_v1',
    'Housing proposals (silent)',
    description:
        'Silent alerts when a co-participant sends a housing plan proposal.',
    importance: Importance.high,
    playSound: false,
  );
  static const AndroidNotificationChannel _vehicleSharingChannel =
      AndroidNotificationChannel(
        'vehicle_sharing_offers_v1',
        'Vehicle sharing offers',
        description:
            'Alerts when a contact offers to share a vehicle with you.',
        importance: Importance.high,
      );
  static const AndroidNotificationChannel _vehicleSharingSilentChannel =
      AndroidNotificationChannel(
        'vehicle_sharing_offers_silent_v1',
        'Vehicle sharing offers (silent)',
        description:
            'Silent alerts when a contact offers to share a vehicle with you.',
        importance: Importance.high,
        playSound: false,
      );

  static const String _housingTapPayload = 'housing_proposal';
  static const String _housingProposalPrefix = 'housing_proposal:';
  static const String _housingAmendmentPrefix = 'housing_amendment:';
  static const String _housingDecisionPrefix = 'housing_decision:';
  static const String _housingRealizedExpenseReviewPrefix =
      'housing_realized_expense:';
  static const String _housingParticipationChangePrefix =
      'housing_participation_change:';
  static const String _planPeerEstablishmentPrefix = 'plan_peer_establishment:';
  static const String _housingActiveHubPrefix = 'housing_active_hub:';
  static const String _housingPaymentReminderPrefix = 'housing_payment_reminder|';
  static const String _contactsPayload = 'contacts';
  static const String _vehicleSharingOfferTapPayload = 'vehicle_sharing_offer';
  static const String _vehicleSharingOfferAcceptTapPayload =
      'vehicle_sharing_offer_accept';

  static const List<String> _housingKinds = <String>[
    'housing_proposal',
    'expensePlanAgreementProposal',
  ];

  static bool _started = false;
  static bool _localStarted = false;

  static Future<void> initialize() async {
    if (_started) return;
    _started = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e, st) {
      debugPrint(
        'PushNotificationService: Firebase.initializeApp failed: '
        '$e\n$st',
      );
      _started = false;
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _handleOpenData(Map<String, dynamic>.from(m.data));
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleOpenData(Map<String, dynamic>.from(initial.data));
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      debugPrint(
        'PushNotificationService: FCM token refreshed (length '
        '${token.length})',
      );
      unawaited(
        ClosedAppPushRegistrationService.maybeInstance?.onTokenRefreshed(token),
      );
    });

    unawaited(ClosedAppPushRegistrationService.maybeInstance?.sync());
  }

  static Future<void> _ensureAndroidChannel() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_androidChannel);
    await android?.createNotificationChannel(_androidSilentChannel);
    await android?.createNotificationChannel(_vehicleSharingChannel);
    await android?.createNotificationChannel(_vehicleSharingSilentChannel);
  }

  static Future<void> _ensureLocalNotificationsInitialized(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    if (identical(plugin, _plugin) && _localStarted) return;
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: dispatchLocalNotificationTap,
    );
    await _ensureAndroidChannel();
    if (identical(plugin, _plugin)) {
      _localStarted = true;
      final launch = await plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      final payload = response?.payload;
      if (launch?.didNotificationLaunchApp == true &&
          payload != null &&
          payload.isNotEmpty) {
        dispatchLocalNotificationTap(response!);
      }
    }
  }

  /// Shared tap handler for all local notification payloads (housing + contacts).
  static void dispatchLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    if (payload == _vehicleSharingOfferTapPayload ||
        payload == _vehicleSharingOfferAcceptTapPayload) {
      _navigateToVehicleSharing();
      return;
    }
    if (payload == _housingTapPayload) {
      _navigateToHousing();
      return;
    }
    if (payload.startsWith(_housingProposalPrefix)) {
      final planId = payload.substring(_housingProposalPrefix.length);
      if (planId.isNotEmpty) {
        _navigateToHousingProposal(planId);
      } else {
        _navigateToHousing();
      }
      return;
    }
    if (payload.startsWith(_housingAmendmentPrefix)) {
      final planId = payload.substring(_housingAmendmentPrefix.length);
      if (planId.isNotEmpty) {
        HousingNavigationIntent.requestOpenPendingAmendment(planId);
        _navigateToHousing();
      } else {
        _navigateToHousing();
      }
      return;
    }
    if (payload.startsWith(_housingDecisionPrefix)) {
      final raw = payload.substring(_housingDecisionPrefix.length);
      final parts = raw.split('|');
      final planId = parts.isEmpty ? '' : parts.first;
      final revisionId = parts.length >= 2 ? parts[1] : '';
      if (planId.isNotEmpty && revisionId.isNotEmpty) {
        _navigateToHousingAmendmentDecision(planId, revisionId);
      } else if (planId.isNotEmpty) {
        HousingNavigationIntent.requestOpenPendingAmendment(planId);
        _navigateToHousing();
      } else {
        _navigateToHousing();
      }
      return;
    }
    if (payload.startsWith(_housingRealizedExpenseReviewPrefix)) {
      final expenseId = payload.substring(
        _housingRealizedExpenseReviewPrefix.length,
      );
      if (expenseId.isNotEmpty) {
        _navigateToRealizedExpenseReview(expenseId);
      }
      return;
    }
    if (payload.startsWith(_housingParticipationChangePrefix)) {
      final raw = payload.substring(_housingParticipationChangePrefix.length);
      final parts = raw.split('|');
      final changeId = parts.isEmpty ? '' : parts.first;
      final planId = parts.length >= 2 ? parts[1] : '';
      if (changeId.isNotEmpty && planId.isNotEmpty) {
        HousingNavigationIntent.requestOpenParticipationChangeDetail(
          planId: planId,
          changeId: changeId,
        );
        _navigateToHousing();
      }
      return;
    }
    if (payload.startsWith(_planPeerEstablishmentPrefix)) {
      final planId = payload.substring(_planPeerEstablishmentPrefix.length);
      if (planId.isNotEmpty) {
        HousingNavigationIntent.requestOpenMissingContacts(planId);
        _navigateToHousing();
      }
      return;
    }
    if (payload.startsWith(_housingActiveHubPrefix)) {
      final planId = payload.substring(_housingActiveHubPrefix.length);
      if (planId.isNotEmpty) {
        HousingNavigationIntent.requestOpenActiveHub(planId);
        _navigateToHousing();
      } else {
        _navigateToHousing();
      }
      return;
    }
    if (payload.startsWith(_housingPaymentReminderPrefix)) {
      unawaited(_handleHousingPaymentReminderTap(payload));
      return;
    }
    if (payload == _contactsPayload) {
      _navigateToContacts();
    }
  }

  /// Payload: `housing_payment_reminder|{kind}|{planId}|{lineId}|{dueMs}`.
  static Future<void> _handleHousingPaymentReminderTap(String payload) async {
    final parts = payload.split('|');
    if (parts.length < 5) {
      _navigateToHousing();
      return;
    }
    final kind = parts[1];
    final planId = parts[2];
    final lineId = parts[3];
    final dueMs = int.tryParse(parts[4]);
    if (planId.isEmpty || lineId.isEmpty || dueMs == null) {
      _navigateToHousing();
      return;
    }
    final periodDueAt = DateTime.fromMillisecondsSinceEpoch(dueMs, isUtc: true);
    final periodKey = '$dueMs';
    final recordedAt = DateTime.now().toUtc();
    final id = housingPaymentReminderJournalId(
      planId: planId,
      planLineId: lineId,
      periodKey: periodKey,
      reminderKind: kind,
      recordedAt: recordedAt,
    );
    try {
      await AppDatabase.processScope.upsertHousingPaymentOverdueJournalEntry(
        id: id,
        planId: planId,
        planLineId: lineId,
        periodKey: periodKey,
        periodDueAt: periodDueAt,
        recordedAt: recordedAt,
        reminderKind: kind,
      );
    } catch (e, st) {
      debugPrint('housing payment reminder tap journal: $e\n$st');
    }
    HousingNavigationIntent.requestOpenAcceptedExpensesJournal(planId);
    _navigateToHousing();
  }
  /// Foreground wake must poll the **installed** orchestrator (same DB + tick).
  ///
  /// [runWakeInboxPollOnce] opens a second [AppDatabase] and a non-installed
  /// orchestrator — correct for the FCM background isolate when the main app
  /// may be stopped, but in the foreground it can apply/ack envelopes the UI
  /// never observes (stale Partages, missing activity-log rows, no tick).
  static Future<void> _handleWakeForegroundMessage() async {
    final orch = HandshakeOrchestrator.maybeInstance;
    if (orch != null) {
      await orch.pollSteadyStateInboxes().catchError((Object e, StackTrace st) {
        debugPrint('PushNotificationService foreground wake poll: $e\n$st');
      });
      await ClosedAppPushRegistrationService.maybeInstance?.sync(force: true);
      return;
    }
    await runWakeInboxPollOnce();
    await ClosedAppPushRegistrationService.maybeInstance?.sync(force: true);
  }

  static void _onForegroundMessage(RemoteMessage message) {
    if (isWakeForInboxRemoteMessage(message)) {
      unawaited(_handleWakeForegroundMessage());
      return;
    }
    if (!isHousingProposalRemoteMessage(message)) return;
    unawaited(
      showRemoteMessageAsLocalNotification(message, isBackgroundIsolate: false),
    );
  }

  /// Data-only wake from the relay (`v` is ignored for forward compatibility).
  static bool isWakeForInboxRemoteMessage(RemoteMessage message) {
    return message.data['kind'] == 'wake_for_inbox';
  }

  static bool isHousingProposalRemoteMessage(RemoteMessage message) {
    final kind = message.data['kind'] as String?;
    if (kind != null && _housingKinds.contains(kind)) return true;
    if (message.notification != null) {
      final t = message.notification!.title?.toLowerCase() ?? '';
      if (t.contains('proposal') || t.contains('proposition')) return true;
    }
    return false;
  }

  static bool shouldDisplayHousingProposalNotification(AppPreferences prefs) {
    return prefs.notificationsEnabled &&
        prefs.notificationHousingPlanSubmission;
  }

  static bool shouldDisplayHousingDecisionNotification(AppPreferences prefs) {
    return prefs.notificationsEnabled &&
        prefs.notificationHousingDecisionChange;
  }

  /// Shows a heads-up notification. Used from the foreground isolate and from
  /// the FCM background isolate (separate [FlutterLocalNotificationsPlugin] there).
  static Future<void> showRemoteMessageAsLocalNotification(
    RemoteMessage message, {
    required bool isBackgroundIsolate,
  }) async {
    if (isBackgroundIsolate && message.notification != null) {
      // Background + notification payload: Android usually shows the system
      // notification already; avoid a duplicate tray entry.
      return;
    }

    final prefs = await AppPreferences.load();
    if (!shouldDisplayHousingProposalNotification(prefs)) {
      return;
    }

    final l10n = l10nForNotificationLocale(prefs: prefs);

    final title =
        message.notification?.title ??
        message.data['title'] as String? ??
        l10n.pushNotificationHousingProposalTitle;
    final body =
        message.notification?.body ??
        message.data['body'] as String? ??
        l10n.pushNotificationHousingProposalBody;
    const qaNumber = 1;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);

    final plugin = isBackgroundIsolate
        ? FlutterLocalNotificationsPlugin()
        : _plugin;

    if (isBackgroundIsolate) {
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_androidChannel);
      await android?.createNotificationChannel(_androidSilentChannel);
    }

    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;

    final androidDetails = AndroidNotificationDetails(
      androidChannel.id,
      androidChannel.name,
      channelDescription: androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: playSound,
    );
    final iosDetails = DarwinNotificationDetails(presentSound: playSound);
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id =
        message.messageId?.hashCode.abs() ??
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 30);

    await plugin.show(
      id: id,
      title: displayTitle,
      body: displayBody,
      notificationDetails: details,
      payload: _housingTapPayload,
    );
  }

  static Future<void> showLocalHousingProposalNotification({
    String? senderDisplayName,
    String? planId,
    bool isInForceAmendment = false,
  }) async {
    final prefs = await AppPreferences.load();
    if (!shouldDisplayHousingProposalNotification(prefs)) return;

    var payload = _housingTapPayload;
    var openAsAmendment = isInForceAmendment;
    if (planId != null && planId.isNotEmpty) {
      final db = AppDatabase.processScope;
      openAsAmendment = openAsAmendment ||
          await pendingRevisionIsAmendment(db, planId);
      if (openAsAmendment) {
        payload = '$_housingAmendmentPrefix$planId';
      } else {
        payload = '$_housingProposalPrefix$planId';
      }
    }

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = l10n.pushNotificationHousingProposalTitle;
    final body = l10n.pushNotificationHousingProposalBody;
    final qaNumber = openAsAmendment ? 3 : 2;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);

    if (kIsWeb) {
      await housing_browser.showHousingBrowserNotification(
        title: displayTitle,
        body: displayBody,
        openProposalPlanId: !openAsAmendment ? planId : null,
        openAmendmentPlanId: openAsAmendment ? planId : null,
      );
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: payload,
    );
  }

  static Future<void> showLocalVehicleSharingOfferNotification({
    String? senderDisplayName,
    String? vehicleLabel,
  }) async {
    final prefs = await AppPreferences.load();
    if (!prefs.notificationsEnabled) return;

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = l10n.pushNotificationVehicleSharingOfferTitle;
    final name = (senderDisplayName ?? '').trim();
    final vehicle = (vehicleLabel ?? '').trim();
    final body = name.isNotEmpty && vehicle.isNotEmpty
        ? l10n.pushNotificationVehicleSharingOfferBodyFrom(name, vehicle)
        : l10n.pushNotificationVehicleSharingOfferBody;

    if (kIsWeb) {
      // Web: no dedicated browser helper yet; rely on in-app hub refresh.
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel =
        playSound ? _vehicleSharingChannel : _vehicleSharingSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: _vehicleSharingOfferTapPayload,
    );
  }

  /// Propriétaire: Emprunteur accepted a sharing offer.
  static Future<void> showLocalVehicleSharingOfferAcceptNotification({
    String? borrowerDisplayName,
    String? vehicleLabel,
  }) async {
    final prefs = await AppPreferences.load();
    if (!prefs.notificationsEnabled) return;

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = l10n.pushNotificationVehicleSharingOfferAcceptTitle;
    final name = (borrowerDisplayName ?? '').trim();
    final vehicle = (vehicleLabel ?? '').trim();
    final body = name.isNotEmpty && vehicle.isNotEmpty
        ? l10n.pushNotificationVehicleSharingOfferAcceptBodyFrom(name, vehicle)
        : l10n.pushNotificationVehicleSharingOfferAcceptBody;

    if (kIsWeb) {
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel =
        playSound ? _vehicleSharingChannel : _vehicleSharingSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: _vehicleSharingOfferAcceptTapPayload,
    );
    debugPrint('vehicle_sharing_offer_accept notification shown');
  }

  static Future<void> showLocalHousingRealizedExpenseNotification({
    required String senderDisplayName,
    String? expenseId,
  }) async {
    final prefs = await AppPreferences.load();
    if (!shouldDisplayHousingDecisionNotification(prefs)) return;

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = l10n.pushNotificationHousingRealizedExpenseTitle;
    final body = senderDisplayName.trim().isEmpty
        ? l10n.pushNotificationHousingRealizedExpenseBody
        : l10n.pushNotificationHousingRealizedExpenseBodyFrom(
            senderDisplayName.trim(),
          );
    const qaNumber = 4;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);

    final tapPayload = expenseId == null || expenseId.isEmpty
        ? _housingTapPayload
        : '$_housingRealizedExpenseReviewPrefix$expenseId';

    if (kIsWeb) {
      await housing_browser.showHousingBrowserNotification(
        title: displayTitle,
        body: displayBody,
        expenseId: expenseId,
      );
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: tapPayload,
    );
  }

  static Future<void> showLocalHousingPaymentReminderNotification({
    required String lineTitle,
    required String reminderKind,
    String? planId,
    String? planLineId,
    DateTime? periodDueAt,
  }) async {
    final prefs = await AppPreferences.load();
    if (!prefs.notificationsEnabled || !prefs.notificationHousingPaymentReminders) {
      return;
    }

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = reminderKind == 'overdue'
        ? l10n.pushNotificationHousingPaymentReminderOverdueTitle
        : l10n.pushNotificationHousingPaymentReminderBeforeDueTitle;
    final body = reminderKind == 'overdue'
        ? l10n.pushNotificationHousingPaymentReminderOverdueBody(lineTitle)
        : l10n.pushNotificationHousingPaymentReminderBeforeDueBody(lineTitle);
    final qaNumber = reminderKind == 'overdue' ? 11 : 10;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);

    var payload = _housingTapPayload;
    if (planId != null &&
        planId.isNotEmpty &&
        planLineId != null &&
        planLineId.isNotEmpty &&
        periodDueAt != null) {
      payload =
          '$_housingPaymentReminderPrefix$reminderKind|$planId|$planLineId|'
          '${periodDueAt.toUtc().millisecondsSinceEpoch}';
    } else if (planId != null && planId.isNotEmpty) {
      payload = '$_housingTapPayload:$planId';
    }

    if (kIsWeb) return;

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: payload,
    );
  }

  static Future<void> showLocalContactInvitationExpiryNotification({
    required String reminderKind,
  }) async {
    final prefs = await AppPreferences.load();
    if (!prefs.notificationsEnabled ||
        !prefs.notificationContactInvitationExpiration) {
      return;
    }
    final l10n = l10nForNotificationLocale(prefs: prefs);
    final before = reminderKind == 'before_expiry';
    final title = before
        ? l10n.pushNotificationContactInvitationBeforeExpiryTitle
        : l10n.pushNotificationContactInvitationExpiredTitle;
    final body = before
        ? l10n.pushNotificationContactInvitationBeforeExpiryBody
        : l10n.pushNotificationContactInvitationExpiredBody;
    final displayTitle = notificationQaPrefix(12, title);
    final displayBody = notificationQaPrefix(12, body);
    if (kIsWeb) return;
    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: _contactsPayload,
    );
  }

  static Future<void> showLocalHousingProposalDeadlineNotification({
    required String revisionId,
  }) async {
    final prefs = await AppPreferences.load();
    if (!prefs.notificationsEnabled ||
        !prefs.notificationHousingOfferExpiration) {
      return;
    }
    final l10n = l10nForNotificationLocale(prefs: prefs);
    final displayTitle = notificationQaPrefix(
      13,
      l10n.pushNotificationHousingProposalDeadlineTitle,
    );
    final displayBody = notificationQaPrefix(
      13,
      l10n.pushNotificationHousingProposalDeadlineBody,
    );
    if (kIsWeb) return;
    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: revisionId.isEmpty
          ? _housingTapPayload
          : '$_housingTapPayload:$revisionId',
    );
  }

  static Future<void> showLocalHousingRealizedExpenseRejectedNotification({
    required String senderDisplayName,
    String? expenseId,
  }) async {
    final prefs = await AppPreferences.load();
    if (!shouldDisplayHousingDecisionNotification(prefs)) return;

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = l10n.pushNotificationHousingRealizedExpenseRejectedTitle;
    final body = senderDisplayName.trim().isEmpty
        ? l10n.pushNotificationHousingRealizedExpenseRejectedBody
        : l10n.pushNotificationHousingRealizedExpenseRejectedBodyFrom(
            senderDisplayName.trim(),
          );
    const qaNumber = 5;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);

    final tapPayload = expenseId == null || expenseId.isEmpty
        ? _housingTapPayload
        : '$_housingRealizedExpenseReviewPrefix$expenseId';

    if (kIsWeb) {
      await housing_browser.showHousingBrowserNotification(
        title: displayTitle,
        body: displayBody,
        expenseId: expenseId,
      );
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: tapPayload,
    );
  }

  static Future<void> showLocalHousingRealizedExpenseAcceptedNotification({
    required String senderDisplayName,
    String? expenseId,
    String expenseKind = 'normal',
    bool localUserIsPayer = true,
    String? payerDisplayName,
  }) async {
    final prefs = await AppPreferences.load();
    if (!shouldDisplayHousingDecisionNotification(prefs)) return;

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final isTransfer = expenseKind == RealizedExpenseKind.transfer ||
        expenseKind == RealizedExpenseKind.reimbursement ||
        expenseKind == RealizedExpenseKind.advance;
    final sender = senderDisplayName.trim();
    final payer = (payerDisplayName ?? '').trim();
    final usePeerPayerCopy = !localUserIsPayer && payer.isNotEmpty && sender.isNotEmpty;
    final String title;
    final String body;
    if (isTransfer) {
      title = l10n.pushNotificationHousingRealizedTransferAcceptedTitle;
      if (usePeerPayerCopy) {
        body = l10n.pushNotificationHousingRealizedTransferAcceptedBodyFromPeer(
          sender,
          payer,
        );
      } else if (sender.isEmpty) {
        body = l10n.pushNotificationHousingRealizedTransferAcceptedBody;
      } else {
        body = l10n.pushNotificationHousingRealizedTransferAcceptedBodyFrom(
          sender,
        );
      }
    } else {
      title = l10n.pushNotificationHousingRealizedExpenseAcceptedTitle;
      if (usePeerPayerCopy) {
        body = l10n.pushNotificationHousingRealizedExpenseAcceptedBodyFromPeer(
          sender,
          payer,
        );
      } else if (sender.isEmpty) {
        body = l10n.pushNotificationHousingRealizedExpenseAcceptedBody;
      } else {
        body = l10n.pushNotificationHousingRealizedExpenseAcceptedBodyFrom(
          sender,
        );
      }
    }
    const qaNumber = 6;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);

    final tapPayload = expenseId == null || expenseId.isEmpty
        ? _housingTapPayload
        : '$_housingRealizedExpenseReviewPrefix$expenseId';

    if (kIsWeb) {
      await housing_browser.showHousingBrowserNotification(
        title: displayTitle,
        body: displayBody,
        expenseId: expenseId,
      );
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: tapPayload,
    );
  }

  static void _navigateToRealizedExpenseReview(String expenseId) {
    HousingNavigationIntent.requestReview(expenseId);
    _navigateToHousing();
  }

  static Future<void> showLocalHousingParticipationChangeNotification({
    required String senderDisplayName,
    String? changeId,
    String? planId,
  }) async {
    final prefs = await AppPreferences.load();
    if (!shouldDisplayHousingDecisionNotification(prefs)) return;

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = l10n.pushNotificationHousingParticipationChangeTitle;
    final body =
        senderDisplayName.trim().isEmpty
            ? l10n.pushNotificationHousingParticipationChangeBody
            : l10n.pushNotificationHousingParticipationChangeBodyFrom(
              senderDisplayName.trim(),
            );
    const qaNumber = 9;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);

    final tapPayload =
        changeId != null &&
                changeId.isNotEmpty &&
                planId != null &&
                planId.isNotEmpty
            ? '$_housingParticipationChangePrefix$changeId|$planId'
            : _housingTapPayload;

    if (kIsWeb) {
      await housing_browser.showHousingBrowserNotification(
        title: displayTitle,
        body: displayBody,
        openParticipationChangePlanId: planId,
        openParticipationChangeId: changeId,
      );
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: tapPayload,
    );
  }

  static Future<void> showLocalHousingAgreementActivatedNotification({
    required String planId,
  }) async {
    final prefs = await AppPreferences.load();
    if (!shouldDisplayHousingProposalNotification(prefs)) return;

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = l10n.pushNotificationHousingAgreementActivatedTitle;
    final body = l10n.pushNotificationHousingAgreementActivatedBody;
    const qaNumber = 9;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);
    final tapPayload = '$_housingActiveHubPrefix$planId';

    if (kIsWeb) {
      await housing_browser.showHousingBrowserNotification(
        title: displayTitle,
        body: displayBody,
        openActiveHubPlanId: planId,
      );
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: tapPayload,
    );
  }

  static Future<void> showLocalHousingDecisionNotification({
    required String senderDisplayName,
    String? planId,
    String? revisionId,
    bool isAmendment = false,
  }) async {
    final prefs = await AppPreferences.load();
    if (!shouldDisplayHousingDecisionNotification(prefs)) return;

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = isAmendment
        ? l10n.pushNotificationHousingAmendmentDecisionTitle
        : l10n.pushNotificationHousingDecisionTitle;
    final body = senderDisplayName.trim().isEmpty
        ? (isAmendment
            ? l10n.pushNotificationHousingAmendmentDecisionBody
            : l10n.pushNotificationHousingDecisionBody)
        : (isAmendment
            ? l10n.pushNotificationHousingAmendmentDecisionBodyFrom(
                senderDisplayName.trim(),
              )
            : l10n.pushNotificationHousingDecisionBodyFrom(
                senderDisplayName.trim(),
              ));

    final hasSettledRevision = planId != null &&
        planId.isNotEmpty &&
        revisionId != null &&
        revisionId.isNotEmpty;
    final qaNumber = hasSettledRevision ? 7 : 8;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);

    final tapPayload = hasSettledRevision
        ? '$_housingDecisionPrefix$planId|$revisionId'
        : (planId != null && planId.isNotEmpty
            ? '$_housingAmendmentPrefix$planId'
            : _housingTapPayload);

    if (kIsWeb) {
      await housing_browser.showHousingBrowserNotification(
        title: displayTitle,
        body: displayBody,
      );
      return;
    }

    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: tapPayload,
    );
  }

  static Future<void> showLocalHousingResponseFailureNotification({
    required String errorCode,
  }) async {
    final prefs = await AppPreferences.load();
    if (!shouldDisplayHousingDecisionNotification(prefs)) return;

    final l10n = l10nForNotificationLocale(prefs: prefs);
    final title = l10n.pushNotificationHousingDecisionTitle;
    final body = switch (errorCode) {
      'relay_unavailable' =>
        l10n.pushNotificationHousingResponseFailureRelayUnavailableBody,
      'unknown' => l10n.pushNotificationHousingResponseFailureUnknownBody,
      'send_failed' => l10n.pushNotificationHousingResponseFailureSendBody,
      'local_error' =>
        l10n.pushNotificationHousingResponseFailureLocalErrorBody,
      _ => l10n.pushNotificationHousingResponseFailureLocalErrorBody,
    };
    const qaNumber = 12;
    final displayTitle = notificationQaPrefix(qaNumber, title);
    final displayBody = notificationQaPrefix(qaNumber, body);
    await _ensureLocalNotificationsInitialized(_plugin);
    final playSound = prefs.notificationSoundEnabled;
    final androidChannel = playSound ? _androidChannel : _androidSilentChannel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      ),
      payload: _housingTapPayload,
    );
  }

  /// Opens [/contacts] from a notification tap.
  static void openContactsFromNotificationTap() {
    _navigateToContacts();
  }

  static void _navigateToContacts() {
    pushFromNotificationTapWhenReady(
      '/contacts',
      skipPushWhenAlreadyAt: (location) => location.startsWith('/contacts'),
      beforeNavigate: _prepareContactsForNotificationTap,
    );
  }

  static Future<void> _prepareContactsForNotificationTap(
    BuildContext context,
  ) async {
    await HandshakeOrchestrator.maybeInstance
        ?.pollSteadyStateInboxes()
        .catchError((Object e, StackTrace st) {
          debugPrint('PushNotificationService contacts poll: $e\n$st');
        });
    if (!context.mounted) return;
    final location = GoRouter.of(context).state.matchedLocation;
    if (location.startsWith('/contacts') && location != '/contacts') {
      context.go('/contacts');
    }
  }

  static Future<void> _prepareHousingForNotificationTap(
    BuildContext context,
  ) async {
    await HandshakeOrchestrator.maybeInstance
        ?.pollSteadyStateInboxes()
        .catchError((Object e, StackTrace st) {
          debugPrint('PushNotificationService housing poll: $e\n$st');
        });
    if (!context.mounted) return;
    if (HousingNavigationIntent.hasRootOverlayPlanScreen) {
      final rootNav = Navigator.of(context, rootNavigator: true);
      if (rootNav.canPop()) {
        rootNav.pop();
      }
    }
    HousingNavigationIntent.requestEntryReload();
  }

  static void _navigateToHousing() {
    pushFromNotificationTapWhenReady(
      '/housing',
      skipPushWhenAlreadyAt: (location) => location.startsWith('/housing'),
      beforeNavigate: _prepareHousingForNotificationTap,
    );
  }

  static void _navigateToVehicleSharing() {
    // Only skip when already on the hub itself. Child routes such as
    // /vehicle-sharing/:id/shares must still push the hub (accept / offer taps).
    pushFromNotificationTapWhenReady(
      '/vehicle-sharing',
      skipPushWhenAlreadyAt: (location) =>
          location == '/vehicle-sharing' || location == '/vehicle-sharing/',
    );
  }

  /// Notification tap: open housing module, then proposal screen above it.
  static void _navigateToHousingProposal(String planId) {
    HousingNavigationIntent.requestOpenPendingProposal(planId);
    _navigateToHousing();
  }

  /// Notification tap: open settled amendment detail (journal card) above housing.
  static void _navigateToHousingAmendmentDecision(
    String planId,
    String revisionId,
  ) {
    HousingNavigationIntent.requestOpenSettledAmendmentDetail(
      planId: planId,
      revisionId: revisionId,
    );
    _navigateToHousing();
  }

  static void _handleOpenData(Map<String, dynamic> data) {
    final kind = data['kind'] as String?;
    if (kind != null && _housingKinds.contains(kind)) {
      _navigateToHousing();
      return;
    }
    if (data['openHousing'] == 'true' || data['route'] == '/housing') {
      _navigateToHousing();
    }
  }
}
