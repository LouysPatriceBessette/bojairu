import 'package:compartarenta/prefs/app_preferences.dart';
import 'package:compartarenta/util/display_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('litersPer100KmToDisplay converts miles and gallons', () {
    // 10 L/100 km → 10 * 1.609344 L/100 miles ≈ 16.09344 L/100 miles
    final litersPer100Miles = litersPer100KmToDisplay(
      10,
      volumeUnit: LiquidVolumeUnit.liter,
      distanceUnit: DistanceUnit.miles,
    );
    expect(litersPer100Miles, closeTo(10 * kmPerMile, 0.0001));

    final usGalPer100Miles = litersPer100KmToDisplay(
      10,
      volumeUnit: LiquidVolumeUnit.usGallon,
      distanceUnit: DistanceUnit.miles,
    );
    expect(usGalPer100Miles, closeTo(litersPer100Miles / 3.785411784, 0.0001));
  });

  test('pricePerLiterMinorToDisplayMinor scales by volume unit', () {
    // 200 minor/L → per US gallon ≈ 200 * 3.785411784
    expect(
      pricePerLiterMinorToDisplayMinor(
        200,
        volumeUnit: LiquidVolumeUnit.usGallon,
      ),
      closeTo(200 * 3.785411784, 0.0001),
    );
    expect(
      pricePerLiterMinorToDisplayMinor(
        200,
        volumeUnit: LiquidVolumeUnit.liter,
      ),
      200,
    );
  });

  test('rate per km ↔ display distance unit round-trip', () {
    const perKm = 10.0;
    final perMile = ratePerKmMinorToDisplay(
      perKm,
      distanceUnit: DistanceUnit.miles,
    );
    expect(perMile, closeTo(10 * kmPerMile, 0.0001));
    expect(
      displayRateToPerKmMinor(perMile, distanceUnit: DistanceUnit.miles),
      closeTo(perKm, 0.0001),
    );
  });
}
