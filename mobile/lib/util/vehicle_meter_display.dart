import 'package:flutter/material.dart';

import '../prefs/app_preferences.dart';
import 'display_units.dart';

const double _kmPerMile = 1.609344;

String _groupThousands(int whole) {
  final digits = whole.toString();
  if (digits.length <= 3) return digits;
  final buffer = StringBuffer();
  final leading = digits.length % 3;
  if (leading > 0) {
    buffer.write(digits.substring(0, leading));
  }
  for (var i = leading; i < digits.length; i += 3) {
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(digits.substring(i, i + 3));
  }
  return buffer.toString();
}

String _formatStoredTenthsCore(int storedTenths) {
  final negative = storedTenths < 0;
  final abs = storedTenths.abs();
  final whole = abs ~/ 10;
  final decimal = abs % 10;
  final grouped = _groupThousands(whole);
  return '${negative ? '-' : ''}$grouped.$decimal';
}

/// Stored meter values use tenths of the display unit (km, miles, or hours).
int? parseMeterInputToStoredTenths(
  String text, {
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) {
  final normalized = text.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0) return null;
  if (usesHorometer) {
    return (parsed * 10).round();
  }
  final km = switch (distanceUnit) {
    DistanceUnit.km => parsed,
    DistanceUnit.miles => parsed * _kmPerMile,
  };
  return (km * 10).round();
}

int _displayDistanceToStoredKmTenths(double display, DistanceUnit unit) {
  final km = switch (unit) {
    DistanceUnit.km => display,
    DistanceUnit.miles => display * _kmPerMile,
  };
  return (km * 10).round();
}

int _storedKmTenthsToDisplayTenths(int storedKmTenths, DistanceUnit unit) {
  if (unit == DistanceUnit.km) return storedKmTenths;
  final km = storedKmTenths / 10.0;
  final miles = km / _kmPerMile;
  return (miles * 10).round();
}

/// Stored tenths formatted for a meter input field (no unit suffix).
String formatStoredMeterForInput(
  int storedTenths, {
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) {
  if (usesHorometer) {
    return _formatStoredTenthsCore(storedTenths);
  }
  final displayTenths =
      _storedKmTenthsToDisplayTenths(storedTenths, distanceUnit);
  return _formatStoredTenthsCore(displayTenths);
}

/// Reformats a meter/horometer text field on blur only (never while typing).
///
/// Empty or unparsable input is left unchanged.
void applyMeterInputFormatOnBlur(
  TextEditingController controller, {
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) {
  final parsed = parseMeterInputToStoredTenths(
    controller.text,
    usesHorometer: usesHorometer,
    distanceUnit: distanceUnit,
  );
  if (parsed == null) return;
  final formatted = formatStoredMeterForInput(
    parsed,
    usesHorometer: usesHorometer,
    distanceUnit: distanceUnit,
  );
  if (controller.text == formatted) return;
  controller.value = TextEditingValue(
    text: formatted,
    selection: TextSelection.collapsed(offset: formatted.length),
  );
}

String formatStoredMeterForDisplay(
  BuildContext context,
  int storedTenths, {
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) {
  if (usesHorometer) {
    return '${_formatStoredTenthsCore(storedTenths)} h';
  }
  final displayTenths =
      _storedKmTenthsToDisplayTenths(storedTenths, distanceUnit);
  return '${_formatStoredTenthsCore(displayTenths)} ${distanceUnitAbbrev(distanceUnit)}';
}

String formatStoredMeterDeltaForDisplay(
  BuildContext context,
  int storedTenthsDelta, {
  required bool usesHorometer,
  required DistanceUnit distanceUnit,
}) {
  final sign = storedTenthsDelta < 0 ? '-' : '';
  final abs = storedTenthsDelta.abs();
  return '$sign${formatStoredMeterForDisplay(
    context,
    abs,
    usesHorometer: usesHorometer,
    distanceUnit: distanceUnit,
  )}';
}

/// Converts user display distance input to stored km tenths.
int? parseDisplayDistanceToStoredKmTenths(
  String text,
  DistanceUnit distanceUnit,
) {
  final normalized = text.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed < 0) return null;
  return _displayDistanceToStoredKmTenths(parsed, distanceUnit);
}
