import 'package:compartarenta/vehicle/vehicle_consumption_reliability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('consumptionReliabilityFromPeriodCount', () {
    test('maps period counts to reliability levels', () {
      expect(
        consumptionReliabilityFromPeriodCount(0),
        VehicleConsumptionReliability.none,
      );
      expect(
        consumptionReliabilityFromPeriodCount(1),
        VehicleConsumptionReliability.preliminary,
      );
      expect(
        consumptionReliabilityFromPeriodCount(2),
        VehicleConsumptionReliability.reliable,
      );
      expect(
        consumptionReliabilityFromPeriodCount(3),
        VehicleConsumptionReliability.reliable,
      );
      expect(
        consumptionReliabilityFromPeriodCount(4),
        VehicleConsumptionReliability.reliable,
      );
      expect(
        consumptionReliabilityFromPeriodCount(5),
        VehicleConsumptionReliability.veryReliable,
      );
      expect(
        consumptionReliabilityFromPeriodCount(8),
        VehicleConsumptionReliability.veryReliable,
      );
    });
  });
}
