import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_decimal_text_field.dart';
import 'app_text_field.dart';

/// Centered numeric field with a fixed max width and trailing unit suffix.
///
/// For **money** amounts (major units), pass [fractionDigits]: `2` so blur pads
/// to two decimals (same behavior as [AppDecimalTextField]).
class VehicleNarrowUnitField extends StatelessWidget {
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
  }) : assert(
          fractionDigits == null ||
              fractionDigits == 1 ||
              fractionDigits == 2,
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

  @override
  Widget build(BuildContext context) {
    final errorStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        );
    final decoration = InputDecoration(
      labelText: label,
      suffixText: unitSuffix,
    );
    final field = fractionDigits != null
        ? AppDecimalTextField(
            controller: controller,
            fractionDigits: fractionDigits!,
            focusNode: focusNode,
            decoration: decoration,
            onChanged: onChanged,
          )
        : AppTextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: decimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: switch (true) {
              true when allowDecimalWithoutDecimalKeyboard => [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
              true when decimal => null,
              _ => [FilteringTextInputFormatter.digitsOnly],
            },
            decoration: decoration,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
          );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: fieldMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            field,
            if (errorText != null && errorText!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(errorText!, style: errorStyle),
            ],
          ],
        ),
      ),
    );
  }
}
