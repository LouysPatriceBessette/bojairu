import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../prefs/app_preferences.dart';
import '../util/vehicle_meter_display.dart';
import 'app_decimal_text_field.dart';
import 'app_text_field.dart';

/// Centered numeric field with a fixed max width and trailing unit suffix.
///
/// For **money** amounts (major units), pass [fractionDigits]: `2` so blur pads
/// to two decimals (same behavior as [AppDecimalTextField]).
///
/// For **odometer / horometer** readings, pass [meterUsesHorometer] and
/// [meterDistanceUnit] so blur reformats via [formatStoredMeterForInput]
/// (e.g. `50010` → `50 010.0`).
class VehicleNarrowUnitField extends StatefulWidget {
  const VehicleNarrowUnitField({
    super.key,
    required this.controller,
    required this.label,
    required this.unitSuffix,
    this.decimal = false,
    this.fractionDigits,
    this.allowDecimalWithoutDecimalKeyboard = false,
    this.focusNode,
    this.errorText,
    this.onChanged,
    this.onEditingComplete,
    this.meterUsesHorometer,
    this.meterDistanceUnit,
  }) : assert(
          fractionDigits == null ||
              fractionDigits == 1 ||
              fractionDigits == 2,
        ),
        assert(
          (meterUsesHorometer == null) == (meterDistanceUnit == null),
          'meterUsesHorometer and meterDistanceUnit must be set together',
        );

  static const double fieldMaxWidth = 200;

  final TextEditingController controller;
  final String label;
  final String unitSuffix;
  final bool decimal;

  /// When 1 or 2, uses [AppDecimalTextField] (blur pads fractional digits).
  /// Use `2` for every monetary major-unit field.
  final int? fractionDigits;

  /// Integer keyboard but accepts one decimal separator (no decimal key hint).
  final bool allowDecimalWithoutDecimalKeyboard;
  final FocusNode? focusNode;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  /// When set with [meterDistanceUnit], formats meter input on blur.
  final bool? meterUsesHorometer;
  final DistanceUnit? meterDistanceUnit;

  bool get _formatMeterOnBlur =>
      meterUsesHorometer != null && meterDistanceUnit != null;

  @override
  State<VehicleNarrowUnitField> createState() => _VehicleNarrowUnitFieldState();
}

class _VehicleNarrowUnitFieldState extends State<VehicleNarrowUnitField> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null && widget._formatMeterOnBlur) {
      _ownedFocusNode = FocusNode();
    }
    if (widget._formatMeterOnBlur) {
      _focusNode.addListener(_handleMeterFocusChange);
    }
  }

  @override
  void didUpdateWidget(covariant VehicleNarrowUnitField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode ||
        oldWidget._formatMeterOnBlur != widget._formatMeterOnBlur) {
      if (oldWidget._formatMeterOnBlur) {
        (oldWidget.focusNode ?? _ownedFocusNode)
            ?.removeListener(_handleMeterFocusChange);
      }
      if (widget._formatMeterOnBlur) {
        if (widget.focusNode == null && _ownedFocusNode == null) {
          _ownedFocusNode = FocusNode();
        }
        _focusNode.addListener(_handleMeterFocusChange);
      }
    }
  }

  @override
  void dispose() {
    if (widget._formatMeterOnBlur) {
      widget.focusNode?.removeListener(_handleMeterFocusChange);
      _ownedFocusNode?.removeListener(_handleMeterFocusChange);
    }
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _handleMeterFocusChange() {
    if (_focusNode.hasFocus) return;
    applyMeterInputFormatOnBlur(
      widget.controller,
      usesHorometer: widget.meterUsesHorometer!,
      distanceUnit: widget.meterDistanceUnit!,
    );
    widget.onChanged?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final errorStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        );
    final decoration = InputDecoration(
      labelText: widget.label,
      suffixText: widget.unitSuffix,
    );
    final focusForField =
        widget._formatMeterOnBlur ? _focusNode : widget.focusNode;
    final field = widget.fractionDigits != null
        ? AppDecimalTextField(
            controller: widget.controller,
            fractionDigits: widget.fractionDigits!,
            focusNode: focusForField,
            decoration: decoration,
            onChanged: widget.onChanged,
          )
        : AppTextField(
            controller: widget.controller,
            focusNode: focusForField,
            keyboardType: widget.decimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: switch (true) {
              true when widget.allowDecimalWithoutDecimalKeyboard => [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
              true when widget.decimal => null,
              _ => [FilteringTextInputFormatter.digitsOnly],
            },
            decoration: decoration,
            onChanged: widget.onChanged,
            onEditingComplete: widget.onEditingComplete,
          );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: VehicleNarrowUnitField.fieldMaxWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field,
            if (widget.errorText != null && widget.errorText!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.errorText!, style: errorStyle),
            ],
          ],
        ),
      ),
    );
  }
}
