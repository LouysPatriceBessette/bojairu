import 'package:compartarenta/notifications/push_notification_service.dart';
import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService', () {
    test(
      'should gate housing proposal notifications with app preferences',
      () async {
        SharedPreferences.setMockInitialValues({
          'notifications.enabled': true,
          'notifications.housing.planSubmission': true,
        });
        var prefs = await AppPreferences.load();

        expect(
          PushNotificationService.shouldDisplayHousingProposalNotification(
            prefs,
          ),
          isTrue,
        );

        await prefs.setNotificationHousingPlanSubmission(false);
        expect(
          PushNotificationService.shouldDisplayHousingProposalNotification(
            prefs,
          ),
          isFalse,
        );

        await prefs.setNotificationHousingPlanSubmission(true);
        await prefs.setNotificationsEnabled(false);
        expect(
          PushNotificationService.shouldDisplayHousingProposalNotification(
            prefs,
          ),
          isFalse,
        );
      },
    );

    test('dispatchLocalNotificationTap handles contacts payload', () {
      expect(
        () => PushNotificationService.dispatchLocalNotificationTap(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'contacts',
          ),
        ),
        returnsNormally,
      );
    });

    test('borrower maintenance notification tap targets journal entry', () {
      expect(
        PushNotificationService.vehicleMaintenanceTapPayload(
          vehicleId: 'veh-1',
          eventId: 'evt-1',
        ),
        'vehicle_maintenance|veh-1|evt-1',
      );
      expect(
        PushNotificationService.vehicleMaintenanceJournalLocation(
          vehicleId: 'veh-1',
          eventId: 'evt-1',
        ),
        '/vehicle/veh-1/maintenance-log/evt-1',
      );
      expect(
        () => PushNotificationService.dispatchLocalNotificationTap(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'vehicle_maintenance|veh-1|evt-1',
          ),
        ),
        returnsNormally,
      );
    });

    test(
      'borrower traffic violation notification tap targets journal entry',
      () {
        expect(
          PushNotificationService.vehicleTrafficViolationTapPayload(
            vehicleId: 'veh-1',
            violationId: 'vio-1',
          ),
          'vehicle_traffic_violation|veh-1|vio-1',
        );
        expect(
          PushNotificationService.vehicleTrafficViolationJournalLocation(
            vehicleId: 'veh-1',
            violationId: 'vio-1',
          ),
          '/vehicle/veh-1/violation-log/vio-1',
        );
        expect(
          () => PushNotificationService.dispatchLocalNotificationTap(
            const NotificationResponse(
              notificationResponseType:
                  NotificationResponseType.selectedNotification,
              payload: 'vehicle_traffic_violation|veh-1|vio-1',
            ),
          ),
          returnsNormally,
        );
      },
    );
  });
}
