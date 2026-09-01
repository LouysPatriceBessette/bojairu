import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';
import '../entitlement/server_grant_push_background.dart';
import 'push_notification_service.dart';
import 'wake_inbox_background_poll.dart';
import 'closed_app_push_background_sync.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (PushNotificationService.isLicenseReceiptChangedRemoteMessage(message)) {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    try {
      await applyServerGrantPushInBackground(
        Map<String, dynamic>.from(message.data),
      );
    } catch (e, st) {
      log(
        'firebaseMessagingBackgroundHandler license_receipt_changed',
        error: e,
        stackTrace: st,
      );
    }
    return;
  }
  if (PushNotificationService.isWakeForInboxRemoteMessage(message)) {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await runWakeInboxPollOnce();
    await runClosedAppPushRegistrationRefreshOnce();
    return;
  }
  if (PushNotificationService.isOperatorNoticeRemoteMessage(message)) {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    try {
      await PushNotificationService.showOperatorNoticeFromRemote(
        message,
        isBackgroundIsolate: true,
      );
    } catch (e, st) {
      log(
        'firebaseMessagingBackgroundHandler operator_notice',
        error: e,
        stackTrace: st,
      );
    }
    return;
  }
  if (!PushNotificationService.isHousingProposalRemoteMessage(message)) {
    return;
  }
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  try {
    await PushNotificationService.showRemoteMessageAsLocalNotification(
      message,
      isBackgroundIsolate: true,
    );
  } catch (e, st) {
    log('firebaseMessagingBackgroundHandler', error: e, stackTrace: st);
  }
}
