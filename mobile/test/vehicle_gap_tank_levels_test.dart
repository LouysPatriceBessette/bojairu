import 'package:compartarenta/vehicle/vehicle_gap_tank_levels.dart';
import 'package:compartarenta/vehicle/vehicle_tank_fill_levels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tankFillLevelsBetween includes full when either end is full', () {
    final levels = tankFillLevelsBetween(
      previousPercent: 100,
      triggerPercent: 87,
    );
    expect(levels.first, VehicleTankFillLevel.full);
    expect(levels.map((l) => l.percent), contains(87));
    expect(levels.map((l) => l.percent), isNot(contains(75)));
  });

  test('tankFillLevelsBetween includes full when tank unknown (null)', () {
    final levels = tankFillLevelsBetween(
      previousPercent: null,
      triggerPercent: 50,
    );
    expect(levels.first, VehicleTankFillLevel.full);
    expect(levels.map((l) => l.percent), containsAll([87, 50]));
  });

  test('tankFillLevelsBetween omits full when both ends below 100', () {
    final levels = tankFillLevelsBetween(
      previousPercent: 50,
      triggerPercent: 75,
    );
    expect(levels.map((l) => l.percent), isNot(contains(100)));
    expect(levels.map((l) => l.percent), containsAll([75, 50]));
  });

  test('fromPercent maps 100 to full', () {
    expect(VehicleTankFillLevel.fromPercent(100), VehicleTankFillLevel.full);
  });

  test('dropdownChoices includes full first when requested', () {
    final withFull = VehicleTankFillLevel.dropdownChoices(includeFull: true);
    expect(withFull.first, VehicleTankFillLevel.full);
    expect(withFull.skip(1), VehicleTankFillLevel.choices);

    final without = VehicleTankFillLevel.dropdownChoices();
    expect(without, VehicleTankFillLevel.choices);
    expect(without.map((l) => l.percent), isNot(contains(100)));
  });
}
