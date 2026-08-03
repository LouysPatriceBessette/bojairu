import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/util/vehicle_meter_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('formatStoredMeterForDisplay uses one decimal and grouping', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(
              formatStoredMeterForDisplay(
                context,
                1750004,
                usesHorometer: false,
                distanceUnit: DistanceUnit.km,
              ),
              '175 000.4 Km',
            );
            expect(
              formatStoredMeterForDisplay(
                context,
                147438,
                usesHorometer: false,
                distanceUnit: DistanceUnit.km,
              ),
              '14 743.8 Km',
            );
            expect(
              formatStoredMeterForDisplay(
                context,
                1438,
                usesHorometer: false,
                distanceUnit: DistanceUnit.km,
              ),
              '143.8 Km',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  test('parseMeterInputToStoredTenths accepts one decimal place', () {
    expect(
      parseMeterInputToStoredTenths(
        '175000.4',
        usesHorometer: false,
        distanceUnit: DistanceUnit.km,
      ),
      1750004,
    );
    expect(
      parseMeterInputToStoredTenths(
        '14 743,8',
        usesHorometer: false,
        distanceUnit: DistanceUnit.km,
      ),
      147438,
    );
  });

  test('applyMeterInputFormatOnBlur matches display-style input', () {
    final controller = TextEditingController(text: '50010');
    applyMeterInputFormatOnBlur(
      controller,
      usesHorometer: false,
      distanceUnit: DistanceUnit.km,
    );
    expect(controller.text, '50 010.0');
  });
}
