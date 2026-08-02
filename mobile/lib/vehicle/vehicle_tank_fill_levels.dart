/// Approximate tank fill level when a purchase is not a full tank.
class VehicleTankFillLevel {
  const VehicleTankFillLevel({
    required this.fractionNumerator,
    required this.fractionDenominator,
    required this.percent,
    this.displayLabel,
  });

  final int fractionNumerator;
  final int fractionDenominator;
  final int percent;
  final String? displayLabel;

  String label() =>
      displayLabel ?? '$fractionNumerator/$fractionDenominator - $percent%';

  /// Full tank (100%). Not in [choices] (those feed the switch + approximate
  /// dropdown). Included via [dropdownChoices] when the full-tank switch is
  /// hidden (e.g. session end), and by gap-correction ranges.
  static const full = VehicleTankFillLevel(
    fractionNumerator: 1,
    fractionDenominator: 1,
    percent: 100,
  );

  static const List<VehicleTankFillLevel> choices = [
    VehicleTankFillLevel(fractionNumerator: 7, fractionDenominator: 8, percent: 87),
    VehicleTankFillLevel(fractionNumerator: 3, fractionDenominator: 4, percent: 75),
    VehicleTankFillLevel(fractionNumerator: 5, fractionDenominator: 8, percent: 62),
    VehicleTankFillLevel(fractionNumerator: 1, fractionDenominator: 2, percent: 50),
    VehicleTankFillLevel(fractionNumerator: 3, fractionDenominator: 8, percent: 37),
    VehicleTankFillLevel(fractionNumerator: 1, fractionDenominator: 4, percent: 25),
    VehicleTankFillLevel(fractionNumerator: 1, fractionDenominator: 8, percent: 12),
    VehicleTankFillLevel(
      fractionNumerator: 0,
      fractionDenominator: 1,
      percent: 1,
      displayLabel: 'VIDE - 1%',
    ),
  ];

  /// Approximate dropdown levels. When [includeFull] is true (no full-tank
  /// switch), [full] is listed first.
  static List<VehicleTankFillLevel> dropdownChoices({
    bool includeFull = false,
  }) {
    if (!includeFull) return choices;
    return [full, ...choices];
  }

  static final VehicleTankFillLevel defaultChoice = choices.first;

  static int get highestPercent =>
      choices.map((c) => c.percent).reduce((a, b) => a > b ? a : b);

  static VehicleTankFillLevel? fromPercent(int? percent) {
    if (percent == null) return null;
    if (percent >= 100) return full;
    for (final c in choices) {
      if (c.percent == percent) return c;
    }
    return null;
  }
}
