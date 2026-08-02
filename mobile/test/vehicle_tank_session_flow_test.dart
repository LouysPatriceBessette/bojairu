import 'package:compartarenta/vehicle/vehicle_tank_fill_levels.dart';
import 'package:compartarenta/vehicle/vehicle_tank_session_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sessionEndTankLevelNeedsConfirmation', () {
    test('requires highest percent and long distance since fuel purchase', () {
      expect(
        sessionEndTankLevelNeedsConfirmation(
          declaredTankPercent: VehicleTankFillLevel.highestPercent,
          distanceTenthsSinceLastFuelPurchase:
              kSessionEndHighTankConfirmMinKm * 10,
          usesHorometer: false,
        ),
        isTrue,
      );
      expect(
        sessionEndTankLevelNeedsConfirmation(
          declaredTankPercent: VehicleTankFillLevel.highestPercent,
          distanceTenthsSinceLastFuelPurchase:
              kSessionEndHighTankConfirmMinKm * 10 - 1,
          usesHorometer: false,
        ),
        isFalse,
      );
      expect(
        sessionEndTankLevelNeedsConfirmation(
          declaredTankPercent: 100,
          distanceTenthsSinceLastFuelPurchase:
              kSessionEndHighTankConfirmMinKm * 10,
          usesHorometer: false,
        ),
        isTrue,
      );
      expect(
        sessionEndTankLevelNeedsConfirmation(
          declaredTankPercent: 75,
          distanceTenthsSinceLastFuelPurchase:
              kSessionEndHighTankConfirmMinKm * 10,
          usesHorometer: false,
        ),
        isFalse,
      );
      expect(
        sessionEndTankLevelNeedsConfirmation(
          declaredTankPercent: VehicleTankFillLevel.highestPercent,
          distanceTenthsSinceLastFuelPurchase: null,
          usesHorometer: false,
        ),
        isFalse,
      );
    });
  });
}
